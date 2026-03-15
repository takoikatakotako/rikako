# iOS アプリ

## 画面遷移図

### オンボーディングフロー

```mermaid
flowchart LR
    A[アプリ起動] --> B{初回起動?}
    B -->|Yes| C[ウェルカム画面]
    C --> D[アプリ紹介 1/3]
    D --> E[アプリ紹介 2/3]
    E --> F[アプリ紹介 3/3]
    F --> G[カテゴリ選択]
    G --> H{アカウント}
    H -->|新規登録| I[サインアップ画面]
    H -->|ログイン| J[ログイン画面]
    H -->|スキップ| K[問題集一覧]
    I --> K
    J --> K
    B -->|No| L{ログイン済み?}
    L -->|Yes| K
    L -->|No| J
```

### メインフロー

```mermaid
flowchart LR
    A[問題集一覧] --> B[問題集詳細]
    B --> C[クイズ解答]
    C --> D{解答}
    D --> E[正誤表示 + 解説]
    E --> F{最後の問題?}
    F -->|No| C
    F -->|Yes| G[結果画面]
    G --> A
```

### 全体画面一覧

```mermaid
flowchart LR
    subgraph オンボーディング
        Welcome[ウェルカム]
        Intro1[紹介 1/3]
        Intro2[紹介 2/3]
        Intro3[紹介 3/3]
        CategorySelect[カテゴリ選択]
    end

    subgraph 認証
        SignUp[サインアップ]
        Login[ログイン]
    end

    subgraph メイン
        WorkbookList[問題集一覧]
        WorkbookDetail[問題集詳細]
        Quiz[クイズ解答]
        Result[結果]
    end

    subgraph 設定
        Settings[設定]
        Profile[プロフィール]
    end

    Welcome --> Intro1 --> Intro2 --> Intro3 --> CategorySelect
    CategorySelect --> SignUp
    CategorySelect --> Login
    CategorySelect --> WorkbookList
    SignUp --> WorkbookList
    Login --> WorkbookList
    WorkbookList --> WorkbookDetail --> Quiz --> Result --> WorkbookList
    WorkbookList --> Settings --> Profile
```

## 画面詳細

| 画面 | 状態 | 説明 |
|------|------|------|
| ウェルカム | 実装済み | 初回起動時のウェルカム画面 |
| アプリ紹介 (1-3) | 実装済み | アプリの機能紹介スライド |
| カテゴリ選択 | 実装済み | 学習カテゴリの選択（中学理科・化学基礎・化学・大学一般化学） |
| サインアップ | 実装済み | メール+パスワード（モック） |
| ログイン | 実装済み | メール+パスワード（モック） |
| 問題集一覧 | 実装済み | 問題集のリスト表示（タイトル、説明、問題数） |
| 問題集詳細 | 実装済み | 問題リスト + 「この問題集を解く」ボタン |
| クイズ解答 | 実装済み | 問題文 + 選択肢、正誤表示 + 解説 |
| 結果 | 実装済み | スコア、正誤一覧、一覧に戻る |
| 設定 | 実装済み | カテゴリ変更、アカウント情報、学習統計、ログアウト |
| プロフィール | 実装済み | ユーザー情報、学習記録 |
