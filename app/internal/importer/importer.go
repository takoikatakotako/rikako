package importer

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/takoikatakotako/rikako/internal/db"
	"gopkg.in/yaml.v3"
)

type Importer struct {
	sqlDB    *sql.DB
	queries  *db.Queries
	dataDir  string
	imageDir string
}

func New(d *sql.DB, dataDir string) *Importer {
	return &Importer{
		sqlDB:    d,
		queries:  db.New(d),
		dataDir:  dataDir,
		imageDir: filepath.Join(dataDir, "images"),
	}
}

func (i *Importer) Run() error {
	return i.RunPhases(false)
}

func (i *Importer) RunWorkbooksOnly() error {
	return i.RunPhases(true)
}

func (i *Importer) RunPhases(workbooksOnly bool) error {
	ctx := context.Background()

	if !workbooksOnly {
		// フェーズ1: 既存データを削除
		if err := i.runInTx(ctx, func(qtx *db.Queries, tx *sql.Tx) error {
			return i.clearData(ctx, qtx)
		}); err != nil {
			return fmt.Errorf("failed to clear data: %w", err)
		}

		// フェーズ2: 画像をインポート
		imageCount, err := i.importImages(ctx)
		if err != nil {
			return fmt.Errorf("failed to import images: %w", err)
		}
		fmt.Printf("Imported %d images\n", imageCount)

		// フェーズ3: 問題をインポート（1問ずつリトライ付き）
		questionCount, err := i.importQuestions(ctx)
		if err != nil {
			return fmt.Errorf("failed to import questions: %w", err)
		}
		fmt.Printf("Imported %d questions\n", questionCount)
	}

	// フェーズ4: 問題集をインポート
	workbookCount, err := i.importWorkbooks(ctx)
	if err != nil {
		return fmt.Errorf("failed to import workbooks: %w", err)
	}
	fmt.Printf("Imported %d workbooks\n", workbookCount)

	// フェーズ5: カテゴリをインポート
	categoryCount, err := i.importCategories(ctx)
	if err != nil {
		return fmt.Errorf("failed to import categories: %w", err)
	}
	fmt.Printf("Imported %d categories\n", categoryCount)

	// フェーズ6: シーケンスをリセット
	if err := i.runInTx(ctx, func(qtx *db.Queries, tx *sql.Tx) error {
		return i.resetSequences(tx)
	}); err != nil {
		return fmt.Errorf("failed to reset sequences: %w", err)
	}

	return nil
}

func (i *Importer) runInTx(ctx context.Context, fn func(*db.Queries, *sql.Tx) error) error {
	tx, err := i.sqlDB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := fn(i.queries.WithTx(tx), tx); err != nil {
		return err
	}
	return tx.Commit()
}

func isRetryableError(err error) bool {
	if err == nil {
		return false
	}
	s := err.Error()
	return strings.Contains(s, "connection reset") ||
		strings.Contains(s, "broken pipe") ||
		strings.Contains(s, "EOF") ||
		strings.Contains(s, "connection refused") ||
		strings.Contains(s, "no connection")
}

func (i *Importer) runInTxWithRetry(ctx context.Context, fn func(*db.Queries, *sql.Tx) error) error {
	var lastErr error
	for attempt := 0; attempt < 5; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * 2 * time.Second)
		}
		lastErr = i.runInTx(ctx, fn)
		if lastErr == nil {
			return nil
		}
		if !isRetryableError(lastErr) {
			return lastErr
		}
	}
	return lastErr
}

func (i *Importer) clearData(ctx context.Context, qtx *db.Queries) error {
	deleters := []func(context.Context) error{
		qtx.DeleteAllWorkbookQuestions,
		qtx.DeleteAllWorkbooks,
		qtx.DeleteAllCategories,
		qtx.DeleteAllQuestionImages,
		qtx.DeleteAllChoices,
		qtx.DeleteAllSingleChoices,
		qtx.DeleteAllQuestions,
		qtx.DeleteAllImages,
	}
	for _, del := range deleters {
		if err := del(ctx); err != nil {
			return err
		}
	}
	return nil
}

func (i *Importer) importImages(ctx context.Context) (int, error) {
	files, err := filepath.Glob(filepath.Join(i.imageDir, "*.png"))
	if err != nil {
		return 0, err
	}

	count := 0
	err = i.runInTx(ctx, func(qtx *db.Queries, tx *sql.Tx) error {
		for _, file := range files {
			filename := filepath.Base(file)
			name := filename[:len(filename)-4]

			id, err := strconv.ParseInt(name, 10, 64)
			if err != nil {
				return fmt.Errorf("invalid image filename %s: %w", filename, err)
			}

			if err := qtx.ImportImage(ctx, db.ImportImageParams{
				ID:   id,
				Path: filename,
			}); err != nil {
				return fmt.Errorf("failed to insert image %s: %w", filename, err)
			}
			count++
		}
		return nil
	})
	return count, err
}

const questionBatchSize = 1

func (i *Importer) importQuestions(ctx context.Context) (int, error) {
	questionsDir := filepath.Join(i.dataDir, "questions")
	files, err := filepath.Glob(filepath.Join(questionsDir, "*.yml"))
	if err != nil {
		return 0, err
	}

	total := 0
	for start := 0; start < len(files); start += questionBatchSize {
		end := start + questionBatchSize
		if end > len(files) {
			end = len(files)
		}
		batch := files[start:end]

		err := i.runInTxWithRetry(ctx, func(qtx *db.Queries, tx *sql.Tx) error {
			for _, file := range batch {
				data, err := os.ReadFile(file)
				if err != nil {
					return fmt.Errorf("failed to read %s: %w", file, err)
				}

				var q QuestionYAML
				if err := yaml.Unmarshal(data, &q); err != nil {
					return fmt.Errorf("failed to parse %s: %w", file, err)
				}

				if err := qtx.ImportQuestion(ctx, db.ImportQuestionParams{
					ID:   q.ID,
					Type: q.Type,
				}); err != nil {
					return fmt.Errorf("failed to insert question %d: %w", q.ID, err)
				}

				singleChoiceID, err := qtx.ImportSingleChoice(ctx, db.ImportSingleChoiceParams{
					QuestionID:  q.ID,
					Text:        q.Text,
					Explanation: sql.NullString{String: q.Explanation, Valid: q.Explanation != ""},
				})
				if err != nil {
					return fmt.Errorf("failed to insert single_choice %d: %w", q.ID, err)
				}

				for idx, choice := range q.Choices {
					if err := qtx.ImportChoice(ctx, db.ImportChoiceParams{
						SingleChoiceID: singleChoiceID,
						ChoiceIndex:    int32(idx),
						Text:           choice,
						IsCorrect:      idx == q.Correct,
					}); err != nil {
						return fmt.Errorf("failed to insert choice for %d: %w", q.ID, err)
					}
				}

				for idx, imageID := range q.Images {
					if err := qtx.ImportQuestionImage(ctx, db.ImportQuestionImageParams{
						QuestionID: q.ID,
						ImageID:    imageID,
						OrderIndex: int32(idx),
					}); err != nil {
						return fmt.Errorf("failed to link image for %d: %w", q.ID, err)
					}
				}
			}
			return nil
		})
		if err != nil {
			return 0, err
		}
		total += len(batch)
		fmt.Printf("  questions %d/%d\n", total, len(files))
	}

	return total, nil
}

func (i *Importer) importWorkbooks(ctx context.Context) (int, error) {
	workbooksDir := filepath.Join(i.dataDir, "workbooks")
	files, err := filepath.Glob(filepath.Join(workbooksDir, "*.yml"))
	if err != nil {
		return 0, err
	}

	count := 0
	for _, file := range files {
		err := i.runInTxWithRetry(ctx, func(qtx *db.Queries, tx *sql.Tx) error {
			data, err := os.ReadFile(file)
			if err != nil {
				return fmt.Errorf("failed to read %s: %w", file, err)
			}

			var w WorkbookYAML
			if err := yaml.Unmarshal(data, &w); err != nil {
				return fmt.Errorf("failed to parse %s: %w", file, err)
			}

			if err := qtx.ImportWorkbook(ctx, db.ImportWorkbookParams{
				ID:          w.ID,
				Title:       w.Title,
				Description: sql.NullString{String: w.Description, Valid: w.Description != ""},
			}); err != nil {
				return fmt.Errorf("failed to insert workbook %d: %w", w.ID, err)
			}

			for idx, questionID := range w.Questions {
				if err := qtx.ImportWorkbookQuestion(ctx, db.ImportWorkbookQuestionParams{
					WorkbookID: w.ID,
					QuestionID: questionID,
					OrderIndex: int32(idx),
				}); err != nil {
					return fmt.Errorf("failed to link question for %d: %w", w.ID, err)
				}
			}
			return nil
		})
		if err != nil {
			return 0, err
		}
		count++
	}
	return count, nil
}

func (i *Importer) importCategories(ctx context.Context) (int, error) {
	categoriesDir := filepath.Join(i.dataDir, "categories")
	files, err := filepath.Glob(filepath.Join(categoriesDir, "*.yml"))
	if err != nil {
		return 0, err
	}

	count := 0
	for _, file := range files {
		err := i.runInTxWithRetry(ctx, func(qtx *db.Queries, tx *sql.Tx) error {
			data, err := os.ReadFile(file)
			if err != nil {
				return fmt.Errorf("failed to read %s: %w", file, err)
			}

			var c CategoryYAML
			if err := yaml.Unmarshal(data, &c); err != nil {
				return fmt.Errorf("failed to parse %s: %w", file, err)
			}

			if err := qtx.ImportCategory(ctx, db.ImportCategoryParams{
				ID:          c.ID,
				Title:       c.Title,
				Description: sql.NullString{String: c.Description, Valid: c.Description != ""},
			}); err != nil {
				return fmt.Errorf("failed to insert category %d: %w", c.ID, err)
			}

			for _, workbookID := range c.Workbooks {
				if err := qtx.SetWorkbookCategory(ctx, db.SetWorkbookCategoryParams{
					CategoryID: sql.NullInt64{Int64: c.ID, Valid: true},
					ID:         workbookID,
				}); err != nil {
					return fmt.Errorf("failed to set category for workbook %d: %w", workbookID, err)
				}
			}
			return nil
		})
		if err != nil {
			return 0, err
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
