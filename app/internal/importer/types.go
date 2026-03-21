package importer

// QuestionYAML はYAMLファイルの問題データ構造
type QuestionYAML struct {
	ID          int64    `yaml:"id"`
	Type        string   `yaml:"type"`
	Text        string   `yaml:"text"`
	Choices     []string `yaml:"choices"`
	Correct     int      `yaml:"correct"`
	Explanation string   `yaml:"explanation"`
	Images      []int64  `yaml:"images"`
}

// WorkbookYAML はYAMLファイルの問題集データ構造
type WorkbookYAML struct {
	ID          int64   `yaml:"id"`
	Title       string  `yaml:"title"`
	Description string  `yaml:"description"`
	Questions   []int64 `yaml:"questions"`
}

// CategoryYAML はYAMLファイルのカテゴリデータ構造
type CategoryYAML struct {
	ID          int64   `yaml:"id"`
	Title       string  `yaml:"title"`
	Description string  `yaml:"description"`
	Workbooks   []int64 `yaml:"workbooks"`
}
