# iOS Navigation

## 概要
- エントリーポイントは `RootView`
- `StudyStore` の状態に応じて `OnboardingView` または `MainView` を出し分ける
- `MainView` の直下は `NavigationStack` で、最初に `LegacyTopView` を表示する

## Root からの分岐

```mermaid
flowchart TD
    A[RootView] --> B{hasCompletedOnboarding?}
    B -- No --> C[OnboardingView]
    B -- Yes --> D[MainView]

    C --> G[オンボーディング完了]
    G --> H[studyStore.completeOnboarding()]
    H --> D
```

## MainView 配下

```mermaid
flowchart TD
    A[MainView] --> B[NavigationStack]
    B --> C[LegacyTopView]
```

## MainView からの主な遷移

```mermaid
flowchart TD
    A[MainView] --> B[LegacyTopView]
    B --> C[復習ボタン]
    B --> D[未学習ボタン]
    B --> E[次に解くカード]

    C --> F[WrongAnswersView]
    D --> G[WorkbookDetailView]
    E --> G

    G --> H[QuizView]
    H --> I[ResultView]
```

## 補足
- 現在はオンボーディング完了後、そのまま `MainView` に入る
- `LoginView` と `SignUpView` は残っているが、Root の初期遷移では使っていない
- 画面遷移の中心は `LegacyTopView -> WorkbookDetailView -> QuizView -> ResultView`
