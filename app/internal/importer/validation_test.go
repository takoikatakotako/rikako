package importer

import (
	"os"
	"path/filepath"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestQuestionYAML_SingleChoiceHasValidChoices(t *testing.T) {
	t.Parallel()

	files, err := filepath.Glob(filepath.Join("..", "..", "..", "data", "questions", "*.yml"))
	if err != nil {
		t.Fatalf("glob question YAML files: %v", err)
	}
	if len(files) == 0 {
		t.Fatal("no question YAML files found")
	}

	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("read %s: %v", file, err)
		}

		var q QuestionYAML
		if err := yaml.Unmarshal(data, &q); err != nil {
			t.Fatalf("parse %s: %v", file, err)
		}

		if q.Type != "single_choice" {
			continue
		}
		if len(q.Choices) < 2 {
			t.Fatalf("%s: single_choice question %d must have at least 2 choices", file, q.ID)
		}
		if q.Correct < 0 || q.Correct >= len(q.Choices) {
			t.Fatalf("%s: single_choice question %d has out-of-range correct index %d for %d choices", file, q.ID, q.Correct, len(q.Choices))
		}
	}
}

func TestQuestionYAMLFixturePath(t *testing.T) {
	if _, err := os.Stat(filepath.Join("..", "..", "..", "data", "questions")); err != nil {
		t.Fatalf("question fixture directory missing: %v", err)
	}
}
