package datasync

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// YAML types (same as importer)

type QuestionYAML struct {
	ID          int64    `yaml:"id"`
	Type        string   `yaml:"type"`
	Text        string   `yaml:"text"`
	Choices     []string `yaml:"choices"`
	Correct     int      `yaml:"correct"`
	Explanation string   `yaml:"explanation"`
	Images      []int64  `yaml:"images"`
}

type WorkbookYAML struct {
	ID          int64   `yaml:"id"`
	Title       string  `yaml:"title"`
	Description string  `yaml:"description"`
	Questions   []int64 `yaml:"questions"`
}

type CategoryYAML struct {
	ID          int64   `yaml:"id"`
	Title       string  `yaml:"title"`
	Description string  `yaml:"description"`
	Workbooks   []int64 `yaml:"workbooks"`
}

// DB types

type QuestionDB struct {
	ID          int64
	Type        string
	Text        string
	Explanation string
	Choices     []ChoiceDB
	Images      []int64
}

type ChoiceDB struct {
	Index     int
	Text      string
	IsCorrect bool
}

type WorkbookDB struct {
	ID          int64
	Title       string
	Description string
	Questions   []int64
}

type CategoryDB struct {
	ID          int64
	Title       string
	Description string
	Workbooks   []int64
}

type ImageDB struct {
	ID   int64
	Path string
}

// Diff types

type Action string

const (
	ActionAdd    Action = "+"
	ActionChange Action = "~"
	ActionDelete Action = "-"
)

type DiffItem struct {
	Action  Action
	ID      int64
	Label   string
	Details []string
}

type PlanResult struct {
	Images     []DiffItem
	Questions  []DiffItem
	Workbooks  []DiffItem
	Categories []DiffItem
}

func (p *PlanResult) HasChanges() bool {
	return len(p.Images) > 0 || len(p.Questions) > 0 || len(p.Workbooks) > 0 || len(p.Categories) > 0
}

func (p *PlanResult) Summary() (add, change, destroy int) {
	for _, items := range [][]DiffItem{p.Images, p.Questions, p.Workbooks, p.Categories} {
		for _, item := range items {
			switch item.Action {
			case ActionAdd:
				add++
			case ActionChange:
				change++
			case ActionDelete:
				destroy++
			}
		}
	}
	return
}

type Syncer struct {
	db      *sql.DB
	dataDir string
}

func New(db *sql.DB, dataDir string) *Syncer {
	return &Syncer{db: db, dataDir: dataDir}
}

// Plan compares YAML data against DB and returns the diff.
func (s *Syncer) Plan() (*PlanResult, error) {
	result := &PlanResult{}

	imageDiff, err := s.planImages()
	if err != nil {
		return nil, fmt.Errorf("images: %w", err)
	}
	result.Images = imageDiff

	questionDiff, err := s.planQuestions()
	if err != nil {
		return nil, fmt.Errorf("questions: %w", err)
	}
	result.Questions = questionDiff

	workbookDiff, err := s.planWorkbooks()
	if err != nil {
		return nil, fmt.Errorf("workbooks: %w", err)
	}
	result.Workbooks = workbookDiff

	categoryDiff, err := s.planCategories()
	if err != nil {
		return nil, fmt.Errorf("categories: %w", err)
	}
	result.Categories = categoryDiff

	return result, nil
}

// Apply executes the plan to sync DB with YAML.
func (s *Syncer) Apply() (*PlanResult, error) {
	plan, err := s.Plan()
	if err != nil {
		return nil, err
	}

	if !plan.HasChanges() {
		return plan, nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// 適用順序: FK制約を考慮
	// 1. images (他テーブルから参照される)
	// 2. questions (workbook_questionsから参照される)
	// 3. categories (workbooks.category_idから参照される)
	// 4. workbooks (categoriesとquestionsに依存)
	if err := s.applyImages(tx, plan.Images); err != nil {
		return nil, fmt.Errorf("images: %w", err)
	}
	if err := s.applyQuestions(tx, plan.Questions); err != nil {
		return nil, fmt.Errorf("questions: %w", err)
	}
	if err := s.applyCategories(tx, plan.Categories); err != nil {
		return nil, fmt.Errorf("categories: %w", err)
	}
	if err := s.applyWorkbooks(tx, plan.Workbooks); err != nil {
		return nil, fmt.Errorf("workbooks: %w", err)
	}

	if err := s.resetSequences(tx); err != nil {
		return nil, fmt.Errorf("sequences: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit: %w", err)
	}

	return plan, nil
}

// ========== Images ==========

func (s *Syncer) loadImagesYAML() (map[int64]string, error) {
	imageDir := filepath.Join(s.dataDir, "images")
	files, err := filepath.Glob(filepath.Join(imageDir, "*.png"))
	if err != nil {
		return nil, err
	}

	images := make(map[int64]string)
	for _, file := range files {
		filename := filepath.Base(file)
		name := filename[:len(filename)-4]
		id, err := strconv.ParseInt(name, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid image filename %s: %w", filename, err)
		}
		images[id] = filename
	}
	return images, nil
}

func (s *Syncer) loadImagesDB() (map[int64]ImageDB, error) {
	rows, err := s.db.Query("SELECT id, path FROM images ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	images := make(map[int64]ImageDB)
	for rows.Next() {
		var img ImageDB
		if err := rows.Scan(&img.ID, &img.Path); err != nil {
			return nil, err
		}
		images[img.ID] = img
	}
	return images, rows.Err()
}

func (s *Syncer) planImages() ([]DiffItem, error) {
	yamlImages, err := s.loadImagesYAML()
	if err != nil {
		return nil, err
	}
	dbImages, err := s.loadImagesDB()
	if err != nil {
		return nil, err
	}

	var diffs []DiffItem

	for id, path := range yamlImages {
		dbImg, exists := dbImages[id]
		if !exists {
			diffs = append(diffs, DiffItem{Action: ActionAdd, ID: id, Label: path})
		} else if dbImg.Path != path {
			diffs = append(diffs, DiffItem{
				Action:  ActionChange,
				ID:      id,
				Details: []string{fmt.Sprintf("path: %q → %q", dbImg.Path, path)},
			})
		}
	}

	for id, img := range dbImages {
		if _, exists := yamlImages[id]; !exists {
			diffs = append(diffs, DiffItem{Action: ActionDelete, ID: id, Label: img.Path})
		}
	}

	sort.Slice(diffs, func(i, j int) bool { return diffs[i].ID < diffs[j].ID })
	return diffs, nil
}

func (s *Syncer) applyImages(tx *sql.Tx, diffs []DiffItem) error {
	yamlImages, err := s.loadImagesYAML()
	if err != nil {
		return err
	}

	for _, d := range diffs {
		switch d.Action {
		case ActionAdd:
			_, err := tx.Exec("INSERT INTO images (id, path) VALUES ($1, $2)", d.ID, yamlImages[d.ID])
			if err != nil {
				return fmt.Errorf("add image %d: %w", d.ID, err)
			}
		case ActionChange:
			_, err := tx.Exec("UPDATE images SET path = $1 WHERE id = $2", yamlImages[d.ID], d.ID)
			if err != nil {
				return fmt.Errorf("update image %d: %w", d.ID, err)
			}
		case ActionDelete:
			_, err := tx.Exec("DELETE FROM question_images WHERE image_id = $1", d.ID)
			if err != nil {
				return fmt.Errorf("delete image refs %d: %w", d.ID, err)
			}
			_, err = tx.Exec("DELETE FROM images WHERE id = $1", d.ID)
			if err != nil {
				return fmt.Errorf("delete image %d: %w", d.ID, err)
			}
		}
	}
	return nil
}

// ========== Questions ==========

func (s *Syncer) loadQuestionsYAML() (map[int64]*QuestionYAML, error) {
	questionsDir := filepath.Join(s.dataDir, "questions")
	files, err := filepath.Glob(filepath.Join(questionsDir, "*.yml"))
	if err != nil {
		return nil, err
	}

	questions := make(map[int64]*QuestionYAML)
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", file, err)
		}
		var q QuestionYAML
		if err := yaml.Unmarshal(data, &q); err != nil {
			return nil, fmt.Errorf("parse %s: %w", file, err)
		}
		questions[q.ID] = &q
	}
	return questions, nil
}

func (s *Syncer) loadQuestionsDB() (map[int64]*QuestionDB, error) {
	rows, err := s.db.Query(`
		SELECT q.id, q.type, qsc.text, COALESCE(qsc.explanation, '')
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		ORDER BY q.id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	questions := make(map[int64]*QuestionDB)
	for rows.Next() {
		var q QuestionDB
		if err := rows.Scan(&q.ID, &q.Type, &q.Text, &q.Explanation); err != nil {
			return nil, err
		}
		questions[q.ID] = &q
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Load choices
	for id, q := range questions {
		choiceRows, err := s.db.Query(`
			SELECT choice_index, text, is_correct
			FROM questions_single_choice_choices
			WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
			ORDER BY choice_index
		`, id)
		if err != nil {
			return nil, err
		}
		for choiceRows.Next() {
			var c ChoiceDB
			if err := choiceRows.Scan(&c.Index, &c.Text, &c.IsCorrect); err != nil {
				choiceRows.Close()
				return nil, err
			}
			q.Choices = append(q.Choices, c)
		}
		choiceRows.Close()
	}

	// Load image associations
	for id, q := range questions {
		imgRows, err := s.db.Query(`
			SELECT image_id FROM question_images WHERE question_id = $1 ORDER BY order_index
		`, id)
		if err != nil {
			return nil, err
		}
		for imgRows.Next() {
			var imgID int64
			if err := imgRows.Scan(&imgID); err != nil {
				imgRows.Close()
				return nil, err
			}
			q.Images = append(q.Images, imgID)
		}
		imgRows.Close()
	}

	return questions, nil
}

func (s *Syncer) planQuestions() ([]DiffItem, error) {
	yamlQuestions, err := s.loadQuestionsYAML()
	if err != nil {
		return nil, err
	}
	dbQuestions, err := s.loadQuestionsDB()
	if err != nil {
		return nil, err
	}

	var diffs []DiffItem

	for id, yq := range yamlQuestions {
		dq, exists := dbQuestions[id]
		if !exists {
			diffs = append(diffs, DiffItem{Action: ActionAdd, ID: id, Label: truncate(yq.Text, 40)})
			continue
		}
		details := diffQuestion(yq, dq)
		if len(details) > 0 {
			diffs = append(diffs, DiffItem{Action: ActionChange, ID: id, Details: details})
		}
	}

	for id, dq := range dbQuestions {
		if _, exists := yamlQuestions[id]; !exists {
			diffs = append(diffs, DiffItem{Action: ActionDelete, ID: id, Label: truncate(dq.Text, 40)})
		}
	}

	sort.Slice(diffs, func(i, j int) bool { return diffs[i].ID < diffs[j].ID })
	return diffs, nil
}

func diffQuestion(yq *QuestionYAML, dq *QuestionDB) []string {
	var details []string

	if yq.Type != dq.Type {
		details = append(details, fmt.Sprintf("type: %q → %q", dq.Type, yq.Type))
	}
	if yq.Text != dq.Text {
		details = append(details, fmt.Sprintf("text: %q → %q", truncate(dq.Text, 30), truncate(yq.Text, 30)))
	}
	if yq.Explanation != dq.Explanation {
		details = append(details, fmt.Sprintf("explanation: changed"))
	}

	// Compare choices
	if len(yq.Choices) != len(dq.Choices) {
		details = append(details, fmt.Sprintf("choices: %d → %d items", len(dq.Choices), len(yq.Choices)))
	} else {
		for i, yc := range yq.Choices {
			if i < len(dq.Choices) && yc != dq.Choices[i].Text {
				details = append(details, fmt.Sprintf("choice[%d]: changed", i))
			}
		}
	}

	// Compare correct answer (only when both have choices)
	if len(yq.Choices) > 0 && len(dq.Choices) > 0 {
		yamlCorrect := yq.Correct
		dbCorrect := -1
		for _, c := range dq.Choices {
			if c.IsCorrect {
				dbCorrect = c.Index
				break
			}
		}
		if yamlCorrect != dbCorrect {
			details = append(details, fmt.Sprintf("correct: %d → %d", dbCorrect, yamlCorrect))
		}
	}

	// Compare images
	if !int64SliceEqual(yq.Images, dq.Images) {
		details = append(details, fmt.Sprintf("images: %v → %v", dq.Images, yq.Images))
	}

	return details
}

func (s *Syncer) applyQuestions(tx *sql.Tx, diffs []DiffItem) error {
	yamlQuestions, err := s.loadQuestionsYAML()
	if err != nil {
		return err
	}

	// Delete first (to avoid FK conflicts)
	for _, d := range diffs {
		if d.Action != ActionDelete {
			continue
		}
		for _, table := range []string{"question_images", "questions_single_choice_choices"} {
			if table == "questions_single_choice_choices" {
				_, err := tx.Exec(`
					DELETE FROM questions_single_choice_choices
					WHERE single_choice_id IN (SELECT id FROM questions_single_choice WHERE question_id = $1)
				`, d.ID)
				if err != nil {
					return fmt.Errorf("delete choices for %d: %w", d.ID, err)
				}
			} else {
				_, err := tx.Exec(fmt.Sprintf("DELETE FROM %s WHERE question_id = $1", table), d.ID)
				if err != nil {
					return fmt.Errorf("delete %s for %d: %w", table, d.ID, err)
				}
			}
		}
		if _, err := tx.Exec("DELETE FROM questions_single_choice WHERE question_id = $1", d.ID); err != nil {
			return fmt.Errorf("delete single_choice %d: %w", d.ID, err)
		}
		if _, err := tx.Exec("DELETE FROM workbook_questions WHERE question_id = $1", d.ID); err != nil {
			return fmt.Errorf("delete workbook_questions %d: %w", d.ID, err)
		}
		if _, err := tx.Exec("DELETE FROM questions WHERE id = $1", d.ID); err != nil {
			return fmt.Errorf("delete question %d: %w", d.ID, err)
		}
	}

	// Add and Change
	for _, d := range diffs {
		if d.Action == ActionDelete {
			continue
		}
		q := yamlQuestions[d.ID]

		if d.Action == ActionAdd {
			if _, err := tx.Exec("INSERT INTO questions (id, type) VALUES ($1, $2)", q.ID, q.Type); err != nil {
				return fmt.Errorf("add question %d: %w", q.ID, err)
			}
			if err := s.insertQuestionDetails(tx, q); err != nil {
				return err
			}
		} else { // ActionChange
			if _, err := tx.Exec("UPDATE questions SET type = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", q.Type, q.ID); err != nil {
				return fmt.Errorf("update question %d: %w", q.ID, err)
			}
			// Delete and re-insert details
			if _, err := tx.Exec(`
				DELETE FROM questions_single_choice_choices
				WHERE single_choice_id IN (SELECT id FROM questions_single_choice WHERE question_id = $1)
			`, q.ID); err != nil {
				return fmt.Errorf("clear choices %d: %w", q.ID, err)
			}
			if _, err := tx.Exec("DELETE FROM question_images WHERE question_id = $1", q.ID); err != nil {
				return fmt.Errorf("clear images %d: %w", q.ID, err)
			}
			if _, err := tx.Exec("UPDATE questions_single_choice SET text = $1, explanation = $2, updated_at = CURRENT_TIMESTAMP WHERE question_id = $3",
				q.Text, q.Explanation, q.ID); err != nil {
				return fmt.Errorf("update single_choice %d: %w", q.ID, err)
			}
			// Re-insert choices and images
			var scID int64
			if err := tx.QueryRow("SELECT id FROM questions_single_choice WHERE question_id = $1", q.ID).Scan(&scID); err != nil {
				return fmt.Errorf("get single_choice id %d: %w", q.ID, err)
			}
			for idx, choice := range q.Choices {
				isCorrect := idx == q.Correct
				if _, err := tx.Exec(
					"INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct) VALUES ($1, $2, $3, $4)",
					scID, idx, choice, isCorrect,
				); err != nil {
					return fmt.Errorf("insert choice %d[%d]: %w", q.ID, idx, err)
				}
			}
			for idx, imgID := range q.Images {
				if _, err := tx.Exec(
					"INSERT INTO question_images (question_id, image_id, order_index) VALUES ($1, $2, $3)",
					q.ID, imgID, idx,
				); err != nil {
					return fmt.Errorf("insert image %d[%d]: %w", q.ID, idx, err)
				}
			}
		}
	}

	return nil
}

func (s *Syncer) insertQuestionDetails(tx *sql.Tx, q *QuestionYAML) error {
	var scID int64
	err := tx.QueryRow(
		"INSERT INTO questions_single_choice (question_id, text, explanation) VALUES ($1, $2, $3) RETURNING id",
		q.ID, q.Text, q.Explanation,
	).Scan(&scID)
	if err != nil {
		return fmt.Errorf("insert single_choice %d: %w", q.ID, err)
	}

	for idx, choice := range q.Choices {
		isCorrect := idx == q.Correct
		if _, err := tx.Exec(
			"INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct) VALUES ($1, $2, $3, $4)",
			scID, idx, choice, isCorrect,
		); err != nil {
			return fmt.Errorf("insert choice %d[%d]: %w", q.ID, idx, err)
		}
	}

	for idx, imgID := range q.Images {
		if _, err := tx.Exec(
			"INSERT INTO question_images (question_id, image_id, order_index) VALUES ($1, $2, $3)",
			q.ID, imgID, idx,
		); err != nil {
			return fmt.Errorf("insert image %d[%d]: %w", q.ID, idx, err)
		}
	}

	return nil
}

// ========== Workbooks ==========

func (s *Syncer) loadWorkbooksYAML() (map[int64]*WorkbookYAML, error) {
	workbooksDir := filepath.Join(s.dataDir, "workbooks")
	files, err := filepath.Glob(filepath.Join(workbooksDir, "*.yml"))
	if err != nil {
		return nil, err
	}

	workbooks := make(map[int64]*WorkbookYAML)
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", file, err)
		}
		var w WorkbookYAML
		if err := yaml.Unmarshal(data, &w); err != nil {
			return nil, fmt.Errorf("parse %s: %w", file, err)
		}
		workbooks[w.ID] = &w
	}
	return workbooks, nil
}

func (s *Syncer) loadWorkbooksDB() (map[int64]*WorkbookDB, error) {
	rows, err := s.db.Query("SELECT id, title, COALESCE(description, '') FROM workbooks ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	workbooks := make(map[int64]*WorkbookDB)
	for rows.Next() {
		var w WorkbookDB
		if err := rows.Scan(&w.ID, &w.Title, &w.Description); err != nil {
			return nil, err
		}
		workbooks[w.ID] = &w
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	for id, w := range workbooks {
		qRows, err := s.db.Query("SELECT question_id FROM workbook_questions WHERE workbook_id = $1 ORDER BY order_index", id)
		if err != nil {
			return nil, err
		}
		for qRows.Next() {
			var qid int64
			if err := qRows.Scan(&qid); err != nil {
				qRows.Close()
				return nil, err
			}
			w.Questions = append(w.Questions, qid)
		}
		qRows.Close()
	}

	return workbooks, nil
}

func (s *Syncer) planWorkbooks() ([]DiffItem, error) {
	yamlWorkbooks, err := s.loadWorkbooksYAML()
	if err != nil {
		return nil, err
	}
	dbWorkbooks, err := s.loadWorkbooksDB()
	if err != nil {
		return nil, err
	}

	var diffs []DiffItem

	for id, yw := range yamlWorkbooks {
		dw, exists := dbWorkbooks[id]
		if !exists {
			diffs = append(diffs, DiffItem{Action: ActionAdd, ID: id, Label: yw.Title})
			continue
		}
		var details []string
		if yw.Title != dw.Title {
			details = append(details, fmt.Sprintf("title: %q → %q", dw.Title, yw.Title))
		}
		if yw.Description != dw.Description {
			details = append(details, fmt.Sprintf("description: changed"))
		}
		if !int64SliceEqual(yw.Questions, dw.Questions) {
			details = append(details, fmt.Sprintf("questions: %d → %d items", len(dw.Questions), len(yw.Questions)))
		}
		if len(details) > 0 {
			diffs = append(diffs, DiffItem{Action: ActionChange, ID: id, Details: details})
		}
	}

	for id, dw := range dbWorkbooks {
		if _, exists := yamlWorkbooks[id]; !exists {
			diffs = append(diffs, DiffItem{Action: ActionDelete, ID: id, Label: dw.Title})
		}
	}

	sort.Slice(diffs, func(i, j int) bool { return diffs[i].ID < diffs[j].ID })
	return diffs, nil
}

func (s *Syncer) applyWorkbooks(tx *sql.Tx, diffs []DiffItem) error {
	yamlWorkbooks, err := s.loadWorkbooksYAML()
	if err != nil {
		return err
	}

	// カテゴリYAMLからworkbook→category_idマッピングを構築
	categoryMap, err := s.buildCategoryMap()
	if err != nil {
		return err
	}

	for _, d := range diffs {
		switch d.Action {
		case ActionDelete:
			if _, err := tx.Exec("DELETE FROM workbook_questions WHERE workbook_id = $1", d.ID); err != nil {
				return fmt.Errorf("delete workbook_questions %d: %w", d.ID, err)
			}
			if _, err := tx.Exec("DELETE FROM workbooks WHERE id = $1", d.ID); err != nil {
				return fmt.Errorf("delete workbook %d: %w", d.ID, err)
			}
		case ActionAdd:
			w := yamlWorkbooks[d.ID]
			catID := categoryMap[w.ID]
			if catID > 0 {
				_, err = tx.Exec("INSERT INTO workbooks (id, title, description, category_id) VALUES ($1, $2, $3, $4)",
					w.ID, w.Title, w.Description, catID)
			} else {
				_, err = tx.Exec("INSERT INTO workbooks (id, title, description) VALUES ($1, $2, $3)",
					w.ID, w.Title, w.Description)
			}
			if err != nil {
				return fmt.Errorf("add workbook %d: %w", w.ID, err)
			}
			for idx, qid := range w.Questions {
				if _, err := tx.Exec("INSERT INTO workbook_questions (workbook_id, question_id, order_index) VALUES ($1, $2, $3)",
					w.ID, qid, idx); err != nil {
					return fmt.Errorf("add workbook_question %d: %w", w.ID, err)
				}
			}
		case ActionChange:
			w := yamlWorkbooks[d.ID]
			catID := categoryMap[w.ID]
			if catID > 0 {
				_, err = tx.Exec("UPDATE workbooks SET title = $1, description = $2, category_id = $3, updated_at = CURRENT_TIMESTAMP WHERE id = $4",
					w.Title, w.Description, catID, w.ID)
			} else {
				_, err = tx.Exec("UPDATE workbooks SET title = $1, description = $2, category_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $3",
					w.Title, w.Description, w.ID)
			}
			if err != nil {
				return fmt.Errorf("update workbook %d: %w", w.ID, err)
			}
			if _, err := tx.Exec("DELETE FROM workbook_questions WHERE workbook_id = $1", w.ID); err != nil {
				return fmt.Errorf("clear workbook_questions %d: %w", w.ID, err)
			}
			for idx, qid := range w.Questions {
				if _, err := tx.Exec("INSERT INTO workbook_questions (workbook_id, question_id, order_index) VALUES ($1, $2, $3)",
					w.ID, qid, idx); err != nil {
					return fmt.Errorf("re-add workbook_question %d: %w", w.ID, err)
				}
			}
		}
	}
	return nil
}

// ========== Categories ==========

func (s *Syncer) loadCategoriesYAML() (map[int64]*CategoryYAML, error) {
	categoriesDir := filepath.Join(s.dataDir, "categories")
	files, err := filepath.Glob(filepath.Join(categoriesDir, "*.yml"))
	if err != nil {
		return nil, err
	}

	categories := make(map[int64]*CategoryYAML)
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", file, err)
		}
		var c CategoryYAML
		if err := yaml.Unmarshal(data, &c); err != nil {
			return nil, fmt.Errorf("parse %s: %w", file, err)
		}
		categories[c.ID] = &c
	}
	return categories, nil
}

func (s *Syncer) loadCategoriesDB() (map[int64]*CategoryDB, error) {
	rows, err := s.db.Query("SELECT id, title, COALESCE(description, '') FROM categories ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	categories := make(map[int64]*CategoryDB)
	for rows.Next() {
		var c CategoryDB
		if err := rows.Scan(&c.ID, &c.Title, &c.Description); err != nil {
			return nil, err
		}
		categories[c.ID] = &c
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Load workbook associations
	for id, c := range categories {
		wbRows, err := s.db.Query("SELECT id FROM workbooks WHERE category_id = $1 ORDER BY id", id)
		if err != nil {
			return nil, err
		}
		for wbRows.Next() {
			var wbID int64
			if err := wbRows.Scan(&wbID); err != nil {
				wbRows.Close()
				return nil, err
			}
			c.Workbooks = append(c.Workbooks, wbID)
		}
		wbRows.Close()
	}

	return categories, nil
}

func (s *Syncer) planCategories() ([]DiffItem, error) {
	yamlCategories, err := s.loadCategoriesYAML()
	if err != nil {
		return nil, err
	}
	dbCategories, err := s.loadCategoriesDB()
	if err != nil {
		return nil, err
	}

	var diffs []DiffItem

	for id, yc := range yamlCategories {
		dc, exists := dbCategories[id]
		if !exists {
			diffs = append(diffs, DiffItem{Action: ActionAdd, ID: id, Label: yc.Title})
			continue
		}
		var details []string
		if yc.Title != dc.Title {
			details = append(details, fmt.Sprintf("title: %q → %q", dc.Title, yc.Title))
		}
		if yc.Description != dc.Description {
			details = append(details, "description: changed")
		}
		if !int64SetEqual(yc.Workbooks, dc.Workbooks) {
			details = append(details, fmt.Sprintf("workbooks: %v → %v", dc.Workbooks, yc.Workbooks))
		}
		if len(details) > 0 {
			diffs = append(diffs, DiffItem{Action: ActionChange, ID: id, Details: details})
		}
	}

	for id, dc := range dbCategories {
		if _, exists := yamlCategories[id]; !exists {
			diffs = append(diffs, DiffItem{Action: ActionDelete, ID: id, Label: dc.Title})
		}
	}

	sort.Slice(diffs, func(i, j int) bool { return diffs[i].ID < diffs[j].ID })
	return diffs, nil
}

func (s *Syncer) applyCategories(tx *sql.Tx, diffs []DiffItem) error {
	yamlCategories, err := s.loadCategoriesYAML()
	if err != nil {
		return err
	}

	for _, d := range diffs {
		switch d.Action {
		case ActionDelete:
			// カテゴリ削除時はworkbooksのcategory_idをNULLに
			if _, err := tx.Exec("UPDATE workbooks SET category_id = NULL WHERE category_id = $1", d.ID); err != nil {
				return fmt.Errorf("clear category_id %d: %w", d.ID, err)
			}
			if _, err := tx.Exec("DELETE FROM categories WHERE id = $1", d.ID); err != nil {
				return fmt.Errorf("delete category %d: %w", d.ID, err)
			}
		case ActionAdd:
			c := yamlCategories[d.ID]
			if _, err := tx.Exec("INSERT INTO categories (id, title, description) VALUES ($1, $2, $3)",
				c.ID, c.Title, c.Description); err != nil {
				return fmt.Errorf("add category %d: %w", c.ID, err)
			}
			for _, wbID := range c.Workbooks {
				if _, err := tx.Exec("UPDATE workbooks SET category_id = $1 WHERE id = $2", c.ID, wbID); err != nil {
					return fmt.Errorf("set category for workbook %d: %w", wbID, err)
				}
			}
		case ActionChange:
			c := yamlCategories[d.ID]
			if _, err := tx.Exec("UPDATE categories SET title = $1, description = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3",
				c.Title, c.Description, c.ID); err != nil {
				return fmt.Errorf("update category %d: %w", c.ID, err)
			}
			// Reset workbook associations
			if _, err := tx.Exec("UPDATE workbooks SET category_id = NULL WHERE category_id = $1", c.ID); err != nil {
				return fmt.Errorf("clear category_id %d: %w", c.ID, err)
			}
			for _, wbID := range c.Workbooks {
				if _, err := tx.Exec("UPDATE workbooks SET category_id = $1 WHERE id = $2", c.ID, wbID); err != nil {
					return fmt.Errorf("set category for workbook %d: %w", wbID, err)
				}
			}
		}
	}
	return nil
}

// ========== Helpers ==========

func (s *Syncer) buildCategoryMap() (map[int64]int64, error) {
	yamlCategories, err := s.loadCategoriesYAML()
	if err != nil {
		return nil, err
	}
	// workbook_id → category_id
	m := make(map[int64]int64)
	for _, c := range yamlCategories {
		for _, wbID := range c.Workbooks {
			m[wbID] = c.ID
		}
	}
	return m, nil
}

func (s *Syncer) resetSequences(tx *sql.Tx) error {
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
			return fmt.Errorf("reset sequence %s: %w", s.sequence, err)
		}
	}
	return nil
}

func int64SliceEqual(a, b []int64) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func int64SetEqual(a, b []int64) bool {
	if len(a) != len(b) {
		return false
	}
	sa := make([]int64, len(a))
	copy(sa, a)
	sb := make([]int64, len(b))
	copy(sb, b)
	sort.Slice(sa, func(i, j int) bool { return sa[i] < sa[j] })
	sort.Slice(sb, func(i, j int) bool { return sb[i] < sb[j] })
	return int64SliceEqual(sa, sb)
}

func truncate(s string, n int) string {
	s = strings.ReplaceAll(s, "\n", " ")
	if len([]rune(s)) > n {
		return string([]rune(s)[:n]) + "..."
	}
	return s
}
