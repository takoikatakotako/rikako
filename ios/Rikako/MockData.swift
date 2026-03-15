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
        // 中学理科
        Workbook(id: 1, title: "物質のすがた", description: "身のまわりの物質について学びます。", questionCount: 5, category: .juniorHighScience),
        Workbook(id: 2, title: "化学変化と原子・分子", description: "化学変化の基礎を学びます。", questionCount: 4, category: .juniorHighScience),
        // 高校 化学基礎
        Workbook(id: 3, title: "物質の構成", description: "原子の構造と化学結合を学びます。", questionCount: 5, category: .highSchoolBasicChemistry),
        Workbook(id: 4, title: "物質の変化", description: "化学反応と量的関係を学びます。", questionCount: 3, category: .highSchoolBasicChemistry),
        // 高校 化学
        Workbook(id: 5, title: "有機化学入門", description: "有機化合物の基礎を学びます。", questionCount: 4, category: .highSchoolChemistry),
        Workbook(id: 6, title: "無機化学", description: "無機物質の性質と反応を学びます。", questionCount: 4, category: .highSchoolChemistry),
        // 大学 一般化学
        Workbook(id: 7, title: "熱力学基礎", description: "化学熱力学の基礎を学びます。", questionCount: 3, category: .universityGeneralChemistry),
    ]

    static let workbookDetails: [Int64: WorkbookDetail] = [
        1: WorkbookDetail(id: 1, title: "物質のすがた", description: "身のまわりの物質について学びます。", questions: Array(questions)),
        2: WorkbookDetail(id: 2, title: "化学変化と原子・分子", description: "化学変化の基礎を学びます。", questions: Array(questions.prefix(4))),
        3: WorkbookDetail(id: 3, title: "物質の構成", description: "原子の構造と化学結合を学びます。", questions: Array(questions)),
        4: WorkbookDetail(id: 4, title: "物質の変化", description: "化学反応と量的関係を学びます。", questions: Array(questions.prefix(3))),
        5: WorkbookDetail(id: 5, title: "有機化学入門", description: "有機化合物の基礎を学びます。", questions: Array(questions.prefix(4))),
        6: WorkbookDetail(id: 6, title: "無機化学", description: "無機物質の性質と反応を学びます。", questions: Array(questions.prefix(4))),
        7: WorkbookDetail(id: 7, title: "熱力学基礎", description: "化学熱力学の基礎を学びます。", questions: Array(questions.prefix(3))),
    ]

    static func workbooks(for category: Category) -> [Workbook] {
        workbooks.filter { $0.category == category }
    }
}
