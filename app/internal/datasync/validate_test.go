package datasync

import "testing"

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
