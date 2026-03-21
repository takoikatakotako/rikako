package importer

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	"gopkg.in/yaml.v3"
)

type Importer struct {
	db       *sql.DB
	dataDir  string
	imageDir string
}

func New(db *sql.DB, dataDir string) *Importer {
	return &Importer{
		db:       db,
		dataDir:  dataDir,
		imageDir: filepath.Join(dataDir, "images"),
	}
}

func (i *Importer) Run() error {
	// トランザクション開始
	tx, err := i.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// 既存データを削除
	if err := i.clearData(tx); err != nil {
		return fmt.Errorf("failed to clear data: %w", err)
	}

	// 画像をインポート
	imageCount, err := i.importImages(tx)
	if err != nil {
		return fmt.Errorf("failed to import images: %w", err)
	}
	fmt.Printf("Imported %d images\n", imageCount)

	// 問題をインポート
	questionCount, err := i.importQuestions(tx)
	if err != nil {
		return fmt.Errorf("failed to import questions: %w", err)
	}
	fmt.Printf("Imported %d questions\n", questionCount)

	// 問題集をインポート
	workbookCount, err := i.importWorkbooks(tx)
	if err != nil {
		return fmt.Errorf("failed to import workbooks: %w", err)
	}
	fmt.Printf("Imported %d workbooks\n", workbookCount)

	// カテゴリをインポート
	categoryCount, err := i.importCategories(tx)
	if err != nil {
		return fmt.Errorf("failed to import categories: %w", err)
	}
	fmt.Printf("Imported %d categories\n", categoryCount)

	// シーケンスをリセット
	if err := i.resetSequences(tx); err != nil {
		return fmt.Errorf("failed to reset sequences: %w", err)
	}

	// コミット
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit: %w", err)
	}

	return nil
}

func (i *Importer) clearData(tx *sql.Tx) error {
	tables := []string{
		"workbook_questions",
		"workbooks",
		"categories",
		"question_images",
		"questions_single_choice_choices",
		"questions_single_choice",
		"questions",
		"images",
	}
	for _, table := range tables {
		if _, err := tx.Exec(fmt.Sprintf("DELETE FROM %s", table)); err != nil {
			return fmt.Errorf("failed to clear %s: %w", table, err)
		}
	}
	return nil
}

func (i *Importer) importImages(tx *sql.Tx) (int, error) {
	files, err := filepath.Glob(filepath.Join(i.imageDir, "*.png"))
	if err != nil {
		return 0, err
	}

	count := 0
	for _, file := range files {
		filename := filepath.Base(file)
		name := filename[:len(filename)-4] // .png を除去

		id, err := strconv.ParseInt(name, 10, 64)
		if err != nil {
			return 0, fmt.Errorf("invalid image filename %s: %w", filename, err)
		}

		_, err = tx.Exec(
			"INSERT INTO images (id, path) VALUES ($1, $2)",
			id, filename,
		)
		if err != nil {
			return 0, fmt.Errorf("failed to insert image %s: %w", filename, err)
		}

		count++
	}

	return count, nil
}

func (i *Importer) importQuestions(tx *sql.Tx) (int, error) {
	questionsDir := filepath.Join(i.dataDir, "questions")
	files, err := filepath.Glob(filepath.Join(questionsDir, "*.yml"))
	if err != nil {
		return 0, err
	}

	count := 0
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return 0, fmt.Errorf("failed to read %s: %w", file, err)
		}

		var q QuestionYAML
		if err := yaml.Unmarshal(data, &q); err != nil {
			return 0, fmt.Errorf("failed to parse %s: %w", file, err)
		}

		// questions テーブルに挿入
		_, err = tx.Exec(
			"INSERT INTO questions (id, type) VALUES ($1, $2)",
			q.ID, q.Type,
		)
		if err != nil {
			return 0, fmt.Errorf("failed to insert question %d: %w", q.ID, err)
		}

		// questions_single_choice テーブルに挿入
		var singleChoiceID int64
		err = tx.QueryRow(
			"INSERT INTO questions_single_choice (question_id, text, explanation) VALUES ($1, $2, $3) RETURNING id",
			q.ID, q.Text, q.Explanation,
		).Scan(&singleChoiceID)
		if err != nil {
			return 0, fmt.Errorf("failed to insert single_choice %d: %w", q.ID, err)
		}

		// 選択肢を挿入
		for idx, choice := range q.Choices {
			isCorrect := idx == q.Correct
			_, err = tx.Exec(
				"INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct) VALUES ($1, $2, $3, $4)",
				singleChoiceID, idx, choice, isCorrect,
			)
			if err != nil {
				return 0, fmt.Errorf("failed to insert choice for %d: %w", q.ID, err)
			}
		}

		// 画像を紐付け
		for idx, imageID := range q.Images {
			_, err = tx.Exec(
				"INSERT INTO question_images (question_id, image_id, order_index) VALUES ($1, $2, $3)",
				q.ID, imageID, idx,
			)
			if err != nil {
				return 0, fmt.Errorf("failed to link image for %d: %w", q.ID, err)
			}
		}

		count++
	}

	return count, nil
}

func (i *Importer) importWorkbooks(tx *sql.Tx) (int, error) {
	workbooksDir := filepath.Join(i.dataDir, "workbooks")
	files, err := filepath.Glob(filepath.Join(workbooksDir, "*.yml"))
	if err != nil {
		return 0, err
	}

	count := 0
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return 0, fmt.Errorf("failed to read %s: %w", file, err)
		}

		var w WorkbookYAML
		if err := yaml.Unmarshal(data, &w); err != nil {
			return 0, fmt.Errorf("failed to parse %s: %w", file, err)
		}

		// workbooks テーブルに挿入
		_, err = tx.Exec(
			"INSERT INTO workbooks (id, title, description) VALUES ($1, $2, $3)",
			w.ID, w.Title, w.Description,
		)
		if err != nil {
			return 0, fmt.Errorf("failed to insert workbook %d: %w", w.ID, err)
		}

		// 問題を紐付け
		for idx, questionID := range w.Questions {
			_, err = tx.Exec(
				"INSERT INTO workbook_questions (workbook_id, question_id, order_index) VALUES ($1, $2, $3)",
				w.ID, questionID, idx,
			)
			if err != nil {
				return 0, fmt.Errorf("failed to link question for %d: %w", w.ID, err)
			}
		}

		count++
	}

	return count, nil
}

func (i *Importer) importCategories(tx *sql.Tx) (int, error) {
	categoriesDir := filepath.Join(i.dataDir, "categories")
	files, err := filepath.Glob(filepath.Join(categoriesDir, "*.yml"))
	if err != nil {
		return 0, err
	}

	count := 0
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return 0, fmt.Errorf("failed to read %s: %w", file, err)
		}

		var c CategoryYAML
		if err := yaml.Unmarshal(data, &c); err != nil {
			return 0, fmt.Errorf("failed to parse %s: %w", file, err)
		}

		// categories テーブルに挿入
		_, err = tx.Exec(
			"INSERT INTO categories (id, title, description) VALUES ($1, $2, $3)",
			c.ID, c.Title, c.Description,
		)
		if err != nil {
			return 0, fmt.Errorf("failed to insert category %d: %w", c.ID, err)
		}

		// 問題集にカテゴリIDを設定
		for _, workbookID := range c.Workbooks {
			_, err = tx.Exec(
				"UPDATE workbooks SET category_id = $1 WHERE id = $2",
				c.ID, workbookID,
			)
			if err != nil {
				return 0, fmt.Errorf("failed to set category for workbook %d: %w", workbookID, err)
			}
		}

		count++
	}

	return count, nil
}

// resetSequences は明示的IDインサート後にシーケンスを最大ID+1にリセットする
func (i *Importer) resetSequences(tx *sql.Tx) error {
	sequences := []struct {
		table    string
		sequence string
	}{
		{"images", "images_id_seq"},
		{"questions", "questions_id_seq"},
		{"questions_single_choice", "questions_single_choice_id_seq"},
		{"questions_single_choice_choices", "questions_single_choice_choices_id_seq"},
		{"workbooks", "workbooks_id_seq"},
		{"categories", "categories_id_seq"},
	}
	for _, s := range sequences {
		_, err := tx.Exec(fmt.Sprintf(
			"SELECT setval('%s', COALESCE((SELECT MAX(id) FROM %s), 0) + 1, false)",
			s.sequence, s.table,
		))
		if err != nil {
			return fmt.Errorf("failed to reset sequence %s: %w", s.sequence, err)
		}
	}
	return nil
}
