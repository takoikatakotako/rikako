# 動画試作：インクの色を分ける（採用版）

- 題材：[化学基礎・問679](../../../data/questions/679.yml)（ペーパークロマトグラフィー）
- 形式：縦型クイズ動画、1080 × 1920、H.264 / AAC、約38秒
- 理科子さん：共通のカメ素材が登場。Live2Dモデルは使用していない
- 画面：濃緑と生成りの共通デザイン。冒頭は黒い点だけを見せ、正解以降に分離後の色を見せる
- 音声：Vertex AI Gemini TTS の Sulafat、BGMなし
- 状態：**ローカル試作、未投稿**

紙の上で水性インクの色素が異なる速さで移動する様子を段階的に見せる。特定の黒インクが必ず複数の色に分かれるとは限らないため、撮影素材を使う版では使うインクを実際に試してから脚本を確定する。

## 採用版の再生成

共通の[動画デザインガイド](../../STYLE_GUIDE.md)に合わせた版を採用。同じ台詞と Sulafat の音声を使い、ヘッダー・選択肢・3秒カウントダウンをIT動画と揃えた。問い・正解・締めには共通のカメ素材を置き、締めに化学アプリのアイコンを載せた。実験の段階図と写真も使用する。

[`movie.yml`](movie.yml) が採用版の台本。背景は [`render_v3.py`](render_v3.py) で作り、Daihon が音声と動画を合成する。企画フォルダの直下で実行する。macOS、ImageMagick、FFmpeg が必要。

```sh
cd video/list/2026-10-26-pilot-chromatography
python3 render_v3.py
export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
# 初回は gcloud auth application-default login も必要
daihon check -f movie.yml
daihon build -f movie.yml
```

- 絵コンテ：[`storyboard-style-guide.png`](storyboard-style-guide.png)
- 動画：[`out/chromatography-style-guide.mp4`](out/chromatography-style-guide.mp4)
- 声の比較：[`voice-comparison/README.md`](voice-comparison/README.md)。以前の Kore 版の動画はローカルの `out/chromatography-editorial-v2-kore.mp4` に保存
- 写真素材：[`assets/hero-chromatography-question-v2.webp`](assets/hero-chromatography-question-v2.webp)、[`assets/hero-chromatography-v2.webp`](assets/hero-chromatography-v2.webp)

写真は Codex の画像生成で作った演出素材。実験の手順と色素の移動は `render_v3.py` の図解で表現する。Gemini TTS のキャッシュがない環境では API 呼び出しで料金が発生する。

## 比較用の旧版

以前の雑誌風デザインは [`render_v2.py`](render_v2.py) と [`movie-v2.yml`](movie-v2.yml) に残してある。Sulafat の音声とアプリの立ち絵を使う。

```sh
cd video/list/2026-10-26-pilot-chromatography
python3 render_v2.py
export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
daihon check -f movie-v2.yml
daihon build -f movie-v2.yml
```

- 絵コンテ：[`storyboard-v2.png`](storyboard-v2.png)
- 動画：[`out/chromatography-editorial-v2.mp4`](out/chromatography-editorial-v2.mp4)

## 初期版

以前の明るい緑の構図は [`render.py`](render.py) と [`movie-v1.yml`](movie-v1.yml) に残してある。macOS `Kyoko` 音声の初期版は `python3 render.py --graphics`、`--voice`、`--video` で再生成できる。Gemini TTS 版の旧構図は企画フォルダ直下で `daihon build -f movie-v1.yml` で再生成できる。

旧版の背景素材は [`assets/ink-wash.png`](assets/ink-wash.png)。生成画像を入れる前の版も `chromatography-standing-diagram-only.mp4` と `storyboard-diagram-only.png` に残してある。

**旧版の画像生成プロンプトの要点:** 白いろ紙の繊維へ黒い点から青とマゼンタの水彩色素が広がる、文字・器具・人物なしの透過背景イラスト。実験の正確な段階図としては使わない。
