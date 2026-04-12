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

    static let questionsWithImages: [Question] = [
        Question(
            id: 101,
            type: .singleChoice,
            text: "次の図の器具を使った実験で発生する気体として最も適切なものはどれか？",
            choices: ["酸素", "水素", "二酸化炭素", "窒素"],
            correct: 1,
            explanation: "金属と酸の反応では水素が発生する。図のような装置では発生した気体を集めて性質を確認する。",
            images: ["https://d1ovm6exq28tn1.cloudfront.net/1.png"]
        ),
        Question(
            id: 102,
            type: .singleChoice,
            text: "この粒子モデルが表している状態として最も適切なものはどれか？",
            choices: ["固体", "液体", "気体", "プラズマ"],
            correct: 2,
            explanation: "粒子どうしの間隔が大きく自由に動いているので気体のモデルと考えられる。",
            images: ["https://d1ovm6exq28tn1.cloudfront.net/2.png"]
        ),
        Question(
            id: 103,
            type: .singleChoice,
            text: "このグラフから読み取れる中和反応の関係として正しいものはどれか？",
            choices: ["酸を加えるほどpHは下がる", "塩基を加えるほどpHは上がる", "中和点付近でpHが急変する", "pHは常に7で一定である"],
            correct: 2,
            explanation: "中和滴定の曲線では、中和点付近でpHが大きく変化するのが特徴である。",
            images: ["https://d1ovm6exq28tn1.cloudfront.net/3.png"]
        ),
    ]
}
