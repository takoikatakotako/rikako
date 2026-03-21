package importer

// QuestionYAML はYAMLファイルの問題データ構造
type QuestionYAML struct {
	ID          string   `yaml:"id"`
	Type        string   `yaml:"type"`
	Text        string   `yaml:"text"`
	Choices     []string `yaml:"choices"`
	Correct     int      `yaml:"correct"`
	Explanation string   `yaml:"explanation"`
	Images      []string `yaml:"images"`
}

// WorkbookYAML はYAMLファイルの問題集データ構造
type WorkbookYAML struct {
	ID          string   `yaml:"id"`
	Title       string   `yaml:"title"`
	Description string   `yaml:"description"`
	Questions   []string `yaml:"questions"`
}

// CategoryYAML はYAMLファイルのカテゴリデータ構造
type CategoryYAML struct {
	ID          string   `yaml:"id"`
	Title       string   `yaml:"title"`
	Description string   `yaml:"description"`
	Workbooks   []string `yaml:"workbooks"`
}
