package importer

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

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
	imageIDMap, err := i.importImages(tx)
	if err != nil {
		return fmt.Errorf("failed to import images: %w", err)
	}
	fmt.Printf("Imported %d images\n", len(imageIDMap))

	// 問題をインポート
	questionIDMap, err := i.importQuestions(tx, imageIDMap)
	if err != nil {
		return fmt.Errorf("failed to import questions: %w", err)
	}
	fmt.Printf("Imported %d questions\n", len(questionIDMap))

	// 問題集をインポート
	workbookCount, err := i.importWorkbooks(tx, questionIDMap)
	if err != nil {
		return fmt.Errorf("failed to import workbooks: %w", err)
	}
	fmt.Printf("Imported %d workbooks\n", workbookCount)

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

func (i *Importer) importImages(tx *sql.Tx) (map[string]int64, error) {
	imageIDMap := make(map[string]int64) // UUID -> DB ID

	files, err := filepath.Glob(filepath.Join(i.imageDir, "*.png"))
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		filename := filepath.Base(file)
		uuid := filename[:len(filename)-4] // .png を除去

		var id int64
		err := tx.QueryRow(
			"INSERT INTO images (path) VALUES ($1) RETURNING id",
			filename,
		).Scan(&id)
		if err != nil {
			return nil, fmt.Errorf("failed to insert image %s: %w", filename, err)
		}

		imageIDMap[uuid] = id
	}

	return imageIDMap, nil
}

func (i *Importer) importQuestions(tx *sql.Tx, imageIDMap map[string]int64) (map[string]int64, error) {
	questionIDMap := make(map[string]int64) // UUID -> DB ID

	questionsDir := filepath.Join(i.dataDir, "questions")
	files, err := filepath.Glob(filepath.Join(questionsDir, "*.yml"))
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("failed to read %s: %w", file, err)
		}

		var q QuestionYAML
		if err := yaml.Unmarshal(data, &q); err != nil {
			return nil, fmt.Errorf("failed to parse %s: %w", file, err)
		}

		// questions テーブルに挿入
		var questionID int64
		err = tx.QueryRow(
			"INSERT INTO questions (type) VALUES ($1) RETURNING id",
			q.Type,
		).Scan(&questionID)
		if err != nil {
			return nil, fmt.Errorf("failed to insert question %s: %w", q.ID, err)
		}

		questionIDMap[q.ID] = questionID

		// questions_single_choice テーブルに挿入
		var singleChoiceID int64
		err = tx.QueryRow(
			"INSERT INTO questions_single_choice (question_id, text, explanation) VALUES ($1, $2, $3) RETURNING id",
			questionID, q.Text, q.Explanation,
		).Scan(&singleChoiceID)
		if err != nil {
			return nil, fmt.Errorf("failed to insert single_choice %s: %w", q.ID, err)
		}

		// 選択肢を挿入
		for idx, choice := range q.Choices {
			isCorrect := idx == q.Correct
			_, err = tx.Exec(
				"INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct) VALUES ($1, $2, $3, $4)",
				singleChoiceID, idx, choice, isCorrect,
			)
			if err != nil {
				return nil, fmt.Errorf("failed to insert choice for %s: %w", q.ID, err)
			}
		}

		// 画像を紐付け
		for idx, imageUUID := range q.Images {
			imageID, ok := imageIDMap[imageUUID]
			if !ok {
				fmt.Printf("Warning: image %s not found for question %s\n", imageUUID, q.ID)
				continue
			}
			_, err = tx.Exec(
				"INSERT INTO question_images (question_id, image_id, order_index) VALUES ($1, $2, $3)",
				questionID, imageID, idx,
			)
			if err != nil {
				return nil, fmt.Errorf("failed to link image for %s: %w", q.ID, err)
			}
		}
	}

	return questionIDMap, nil
}

func (i *Importer) importWorkbooks(tx *sql.Tx, questionIDMap map[string]int64) (int, error) {
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
		var workbookID int64
		err = tx.QueryRow(
			"INSERT INTO workbooks (title, description) VALUES ($1, $2) RETURNING id",
			w.Title, w.Description,
		).Scan(&workbookID)
		if err != nil {
			return 0, fmt.Errorf("failed to insert workbook %s: %w", w.ID, err)
		}

		// 問題を紐付け
		for idx, questionUUID := range w.Questions {
			questionID, ok := questionIDMap[questionUUID]
			if !ok {
				fmt.Printf("Warning: question %s not found for workbook %s\n", questionUUID, w.ID)
				continue
			}
			_, err = tx.Exec(
				"INSERT INTO workbook_questions (workbook_id, question_id, order_index) VALUES ($1, $2, $3)",
				workbookID, questionID, idx,
			)
			if err != nil {
				return 0, fmt.Errorf("failed to link question for %s: %w", w.ID, err)
			}
		}

		count++
	}

	return count, nil
}
