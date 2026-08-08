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

    /// ITパスポート版のプレビュー/スクショ用問題（it-passport フレーバー）。
    static let itQuestions: [Question] = [
        Question(
            id: 1,
            type: .singleChoice,
            text: "PDCAサイクルの「A」が表すものはどれか？",
            choices: ["Plan（計画）", "Do（実行）", "Check（評価）", "Act（改善）"],
            correct: 3,
            explanation: "PDCAはPlan（計画）→Do（実行）→Check（評価）→Act（改善）の頭文字です。Aは改善を表します。",
            images: []
        ),
        Question(
            id: 2,
            type: .singleChoice,
            text: "2進数の 1010 を10進数で表すといくつか？",
            choices: ["8", "10", "12", "20"],
            correct: 1,
            explanation: "1010(2) = 8+0+2+0 = 10 です。各桁は 2^3, 2^2, 2^1, 2^0 の重みを持ちます。",
            images: []
        ),
        Question(
            id: 3,
            type: .singleChoice,
            text: "情報セキュリティの3要素に含まれないものはどれか？",
            choices: ["機密性", "完全性", "可用性", "再現性"],
            correct: 3,
            explanation: "情報セキュリティの3要素は機密性・完全性・可用性（CIA）です。再現性は含まれません。",
            images: []
        ),
        Question(
            id: 4,
            type: .singleChoice,
            text: "Webページの閲覧に主に使われるプロトコルはどれか？",
            choices: ["SMTP", "HTTP", "FTP", "POP3"],
            correct: 1,
            explanation: "Webページのやり取りにはHTTP（HTTPS）が使われます。SMTP/POP3はメール、FTPはファイル転送用です。",
            images: []
        ),
        Question(
            id: 5,
            type: .singleChoice,
            text: "プロジェクトの進捗管理に使う図はどれか？",
            choices: ["ER図", "ガントチャート", "フローチャート", "散布図"],
            correct: 1,
            explanation: "ガントチャートは作業の期間と進捗を横棒で表し、プロジェクトの進捗管理に使われます。",
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
