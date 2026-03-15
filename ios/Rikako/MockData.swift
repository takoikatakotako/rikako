import Foundation

enum MockData {
    static let questions: [Question] = [
        Question(
            id: 1,
            type: .singleChoice,
            text: "水の化学式はどれか？",
            choices: ["H2O", "CO2", "NaCl", "O2"],
            correct: 0,
            explanation: "水の化学式はH2Oです。水素原子2つと酸素原子1つから構成されます。",
            images: []
        ),
        Question(
            id: 2,
            type: .singleChoice,
            text: "塩化ナトリウムの化学式はどれか？",
            choices: ["KCl", "NaCl", "CaCl2", "MgCl2"],
            correct: 1,
            explanation: "塩化ナトリウム（食塩）の化学式はNaClです。",
            images: []
        ),
        Question(
            id: 3,
            type: .singleChoice,
            text: "酸素の原子番号はいくつか？",
            choices: ["6", "7", "8", "9"],
            correct: 2,
            explanation: "酸素の原子番号は8です。",
            images: []
        ),
        Question(
            id: 4,
            type: .singleChoice,
            text: "二酸化炭素の化学式はどれか？",
            choices: ["CO", "CO2", "C2O", "CO3"],
            correct: 1,
            explanation: "二酸化炭素の化学式はCO2です。炭素原子1つと酸素原子2つから構成されます。",
            images: []
        ),
        Question(
            id: 5,
            type: .singleChoice,
            text: "周期表で最も軽い元素はどれか？",
            choices: ["ヘリウム", "リチウム", "水素", "ベリリウム"],
            correct: 2,
            explanation: "水素（H）は原子番号1で、周期表で最も軽い元素です。",
            images: []
        ),
    ]

    static let workbooks: [Workbook] = [
        Workbook(
            id: 1,
            title: "基礎化学",
            description: "化学の基本的な問題集です。",
            questionCount: 5
        ),
        Workbook(
            id: 2,
            title: "有機化学入門",
            description: "有機化学の基礎を学ぶ問題集です。",
            questionCount: 3
        ),
        Workbook(
            id: 3,
            title: "無機化学",
            description: "無機化学の問題集です。",
            questionCount: 4
        ),
    ]

    static let workbookDetails: [Int64: WorkbookDetail] = [
        1: WorkbookDetail(
            id: 1,
            title: "基礎化学",
            description: "化学の基本的な問題集です。",
            questions: Array(questions)
        ),
        2: WorkbookDetail(
            id: 2,
            title: "有機化学入門",
            description: "有機化学の基礎を学ぶ問題集です。",
            questions: Array(questions.prefix(3))
        ),
        3: WorkbookDetail(
            id: 3,
            title: "無機化学",
            description: "無機化学の問題集です。",
            questions: Array(questions.prefix(4))
        ),
    ]
}
