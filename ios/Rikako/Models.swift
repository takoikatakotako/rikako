import Foundation

enum Category: String, CaseIterable, Identifiable {
    case juniorHighScience = "junior_high_science"
    case highSchoolBasicChemistry = "high_school_basic_chemistry"
    case highSchoolChemistry = "high_school_chemistry"
    case universityGeneralChemistry = "university_general_chemistry"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .juniorHighScience: return "中学理科"
        case .highSchoolBasicChemistry: return "高校 化学基礎"
        case .highSchoolChemistry: return "高校 化学"
        case .universityGeneralChemistry: return "大学 一般化学"
        }
    }

    var icon: String {
        switch self {
        case .juniorHighScience: return "graduationcap"
        case .highSchoolBasicChemistry: return "flask"
        case .highSchoolChemistry: return "flask.fill"
        case .universityGeneralChemistry: return "atom"
        }
    }
}

struct Question: Identifiable {
    let id: Int64
    let type: QuestionType
    let text: String
    let choices: [String]
    let correct: Int
    let explanation: String
    let images: [String]

    enum QuestionType: String {
        case singleChoice = "single_choice"
    }
}

struct Workbook: Identifiable {
    let id: Int64
    let title: String
    let description: String
    let questionCount: Int
    let category: Category
}

struct WorkbookDetail: Identifiable {
    let id: Int64
    let title: String
    let description: String
    let questions: [Question]
}
