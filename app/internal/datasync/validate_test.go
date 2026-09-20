package datasync

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// 選択肢が空のまま DB に入る事故（#390）を datasync の入口で止める。
func TestQuestionYAMLValidate(t *testing.T) {
	valid := func() QuestionYAML {
		return QuestionYAML{ID: 1, Type: "single_choice", Text: "Q", Choices: []string{"a", "b", "c"}, Correct: 1}
	}

	if q := valid(); q.Validate() != nil {
		t.Fatalf("valid question rejected: %v", q.Validate())
	}

	cases := map[string]func(q *QuestionYAML){
		"empty choice":         func(q *QuestionYAML) { q.Choices[1] = "" },
		"whitespace choice":    func(q *QuestionYAML) { q.Choices[2] = "  " },
		"single choice":        func(q *QuestionYAML) { q.Choices = []string{"only"} },
		"no choices":           func(q *QuestionYAML) { q.Choices = nil },
		"empty text":           func(q *QuestionYAML) { q.Text = "" },
		"correct out of range": func(q *QuestionYAML) { q.Correct = 3 },
		"negative correct":     func(q *QuestionYAML) { q.Correct = -1 },
		"non-positive id":      func(q *QuestionYAML) { q.ID = 0 },
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			q := valid()
			mutate(&q)
			if err := q.Validate(); err == nil {
				t.Errorf("expected error for %s", name)
			}
		})
	}
}

// 問題集 → 問題、問題 → 画像の参照が閉じていないと plan の時点で止まる（#390）。
func TestValidateReferences(t *testing.T) {
	dir := t.TempDir()
	mkdir := func(sub string) string {
		p := filepath.Join(dir, sub)
		if err := os.MkdirAll(p, 0o755); err != nil {
			t.Fatal(err)
		}
		return p
	}
	qdir, wdir, idir := mkdir("questions"), mkdir("workbooks"), mkdir("images")
	write := func(path, body string) {
		if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(filepath.Join(idir, "5.png"), "png")
	write(filepath.Join(qdir, "1.yml"), "id: 1\ntype: single_choice\ntext: Q1\nchoices: [a, b]\ncorrect: 0\nimages: [5]\n")
	write(filepath.Join(wdir, "w.yml"), "id: 1\ntitle: W\nquestions: [1]\n")

	s := &Syncer{dataDir: dir}
	if err := s.validateReferences(); err != nil {
		t.Fatalf("consistent data rejected: %v", err)
	}

	// 問題集が消えた問題を参照している
	write(filepath.Join(wdir, "w.yml"), "id: 1\ntitle: W\nquestions: [1, 2]\n")
	if err := s.validateReferences(); err == nil || !strings.Contains(err.Error(), "question 2") {
		t.Errorf("missing question reference not detected: %v", err)
	}
	write(filepath.Join(wdir, "w.yml"), "id: 1\ntitle: W\nquestions: [1]\n")

	// 問題が消えた画像を参照している
	write(filepath.Join(qdir, "1.yml"), "id: 1\ntype: single_choice\ntext: Q1\nchoices: [a, b]\ncorrect: 0\nimages: [5, 9]\n")
	if err := s.validateReferences(); err == nil || !strings.Contains(err.Error(), "image 9") {
		t.Errorf("missing image reference not detected: %v", err)
	}
}
