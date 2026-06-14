package handler

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/openai"
)

const maxTurns = 5
const maxExplanationLen = 2000

func (h *Handler) ChatWithQuestion(ctx context.Context, request api.ChatWithQuestionRequestObject) (api.ChatWithQuestionResponseObject, error) {
	messages := request.Body.Messages

	// role バリデーション & ターン数カウント
	userTurns := 0
	for _, m := range messages {
		if m.Role != api.User && m.Role != api.Assistant {
			return api.ChatWithQuestion400JSONResponse{Code: "INVALID_PARAMETER", Message: "invalid message role"}, nil
		}
		if m.Role == api.User {
			userTurns++
		}
	}
	if userTurns > maxTurns {
		return api.ChatWithQuestion400JSONResponse{Code: "TURN_LIMIT_EXCEEDED", Message: "最大5往復を超えています"}, nil
	}
	if messages[len(messages)-1].Role != api.User {
		return api.ChatWithQuestion400JSONResponse{Code: "INVALID_PARAMETER", Message: "最後のメッセージはuserである必要があります"}, nil
	}

	// 問題取得
	row, err := h.queries.GetQuestionByID(ctx, request.QuestionId)
	if err == sql.ErrNoRows {
		return api.ChatWithQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get question for chat", "error", err, "question_id", request.QuestionId)
		return nil, err
	}

	// 選択肢・正解取得
	choiceRows, err := h.queries.GetChoicesByQuestionID(ctx, row.ID)
	if err != nil {
		h.logger.Error("failed to get choices for chat", "error", err, "question_id", row.ID)
		return nil, err
	}

	var choices []string
	correctIndex := 0
	for _, c := range choiceRows {
		choices = append(choices, c.Text)
		if c.IsCorrect {
			correctIndex = int(c.ChoiceIndex)
		}
	}

	// システムプロンプト構築
	selectedChoice := -1
	if request.Body.SelectedChoice != nil {
		selectedChoice = *request.Body.SelectedChoice
	}
	systemPrompt := buildSystemPrompt(row.Text, choices, correctIndex, selectedChoice, row.Explanation)

	// OpenAI API呼び出し
	apiMessages := []openai.Message{{Role: "system", Content: systemPrompt}}
	for _, m := range messages {
		apiMessages = append(apiMessages, openai.Message{
			Role:    string(m.Role),
			Content: m.Content,
		})
	}

	reply, err := h.openaiClient.Chat(ctx, apiMessages)
	if err != nil {
		h.logger.Error("openai chat failed", "error", err, "question_id", request.QuestionId)
		return nil, err
	}

	remainingTurns := maxTurns - userTurns
	return api.ChatWithQuestion200JSONResponse{
		Reply:          reply,
		TurnCount:      userTurns,
		RemainingTurns: remainingTurns,
	}, nil
}

func buildSystemPrompt(text string, choices []string, correctIndex int, selectedChoice int, explanation sql.NullString) string {
	var sb strings.Builder
	sb.WriteString("あなたは問題集アプリのAI家庭教師です。以下の問題についてのみ回答してください。\n\n")
	sb.WriteString(fmt.Sprintf("【問題】\n%s\n\n", text))

	sb.WriteString("【選択肢】\n")
	for i, c := range choices {
		sb.WriteString(fmt.Sprintf("%d: %s\n", i, c))
	}
	sb.WriteString("\n")

	correctText := ""
	if correctIndex < len(choices) {
		correctText = choices[correctIndex]
	}
	sb.WriteString(fmt.Sprintf("【正解】\n選択肢 %d (%s)\n\n", correctIndex, correctText))

	if selectedChoice >= 0 && selectedChoice != correctIndex && selectedChoice < len(choices) {
		sb.WriteString(fmt.Sprintf("【ユーザーが選んだ回答】\n選択肢 %d (%s)（不正解）\n\n", selectedChoice, choices[selectedChoice]))
	}

	if explanation.Valid && explanation.String != "" {
		exp := explanation.String
		if len([]rune(exp)) > maxExplanationLen {
			runes := []rune(exp)
			exp = string(runes[:maxExplanationLen])
		}
		sb.WriteString(fmt.Sprintf("【解説】\n%s\n\n", exp))
	}

	sb.WriteString("ユーザーがこの問題を理解できるよう、丁寧に説明してください。\nユーザーが間違えた選択肢を選んだ場合は、その選択肢を選んだ理由に寄り添いながら、なぜ正解でないかを解説してください。\n問題の理解に役立つ関連知識の説明も積極的に行ってください。")
	return sb.String()
}
