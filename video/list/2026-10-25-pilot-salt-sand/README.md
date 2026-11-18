# ４択化学 ショート動画試作: 食塩と砂

- 現行試作: [`out/salt-sand-sulafat-hiyoko.mp4`](out/salt-sand-sulafat-hiyoko.mp4)（約35.5秒、1080 × 1920、H.264 / AAC）
- 絵コンテ: `storyboard.png`
- 出典: リポジトリの `data/questions/668.yml`、[Web の同じ問題](https://chemistry.rikako.org/questions/668/)
- 日本語ナレーション: Daihon経由のVertex AI Gemini TTS `Sulafat`。BGMは[BGMer「ひよこの冒険」](https://bgmer.net/music/372/)のSHORT版
- 冒頭の図では白い四角を食塩、茶色い丸を砂として凡例で示す。常時表示のロゴ・アプリ名・ジャンル表示は入れない。
- 3・2・1のカウントダウン中は選択肢を表示し続け、数字だけを右上に重ねる。
- 投稿状態: **未投稿**。プロフィールリンクの設定後に使う想定。

## 仮の投稿文

**タイトル:** 食塩と砂、どう分ける？【化学基礎・4択クイズ】

**説明文:** 食塩は水に溶け、砂は溶けない。この違いで「溶かす→ろ過→蒸発」すると食塩を取り出せます。続きはプロフィールのリンクから1問どうぞ。#化学基礎 #化学 #勉強 #4択クイズ

**プロフィールのリンク候補:** `https://chemistry.rikako.org/questions/668/?utm_source=youtube&utm_medium=organic_social&utm_campaign=chemistry_short_pilot&utm_content=salt_sand`

YouTube Shorts の説明文・コメントの URL はクリックできないため、動画内ではプロフィールリンクへ案内しています。

## 現行試作の再生成

[`movie.yml`](movie.yml) がDaihonの台本。背景画像は [`render.py`](render.py) で作る。BGMは[共通アセット](../../assets/BGM.md)に保存した。冒頭1秒はBGMだけを流してからSulafatが話し始める。Daihonは音声の長さに合わせて各場面の尺を決める。

```sh
cd video/list/2026-10-25-pilot-salt-sand
python3 render.py --graphics
export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
daihon check -f movie.yml
daihon build -f movie.yml
```

Gemini TTSの音声キャッシュがない環境では、ビルド時にAPIの利用料金が発生する。公開前に音声の読み・音量・投稿先での表示を確認する。

## 比較用の旧版

- [`salt-sand-hiyoko.mp4`](salt-sand-hiyoko.mp4): Kyoko＋ひよこの冒険、31秒
- [`salt-sand-happy-create.mp4`](salt-sand-happy-create.mp4): Kyoko＋ハッピークリエイト、31秒
- [`salt-sand-short.mp4`](salt-sand-short.mp4): Kyoko、BGMなし、30秒

旧版は `render.py` の `SCENES` とSVG描画を編集する。macOS、ImageMagick、FFmpegが必要。

```sh
python3 render.py --graphics
python3 render.py --voice
python3 render.py --video
python3 render.py --mix-bgm
```

`--mix-bgm` はBGMなしの旧版から2本の比較版を作る。冒頭の画面を1秒先に表示してBGMを流し、その後に本編の映像とナレーションを始める。音源をそれぞれ -12 dB / -19 dB に下げ、BGMの冒頭0.5秒と最後1.5秒をフェードする。

`frames/` に SVG と PNG、`voice/` に AIFF が残るので、字幕やナレーションの差し替えもできます。
