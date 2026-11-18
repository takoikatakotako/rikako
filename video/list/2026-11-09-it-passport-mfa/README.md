# ITパスポート動画試作：多要素認証

- 形式：縦型4択クイズ、1080 × 1920、Gemini TTS（Sulafat）、Daihon合成
- 画面：共通の[動画デザインガイド](../../STYLE_GUIDE.md)に合わせた深緑と生成り。問い・答え・締めに[理科子のカメさん](../../assets/README.md)が登場
- 題材：パスワードに認証アプリを組み合わせると「知識」と「所持」の2要素になる
- 状態：ローカル試作、未投稿
- 問題と図解はオリジナル。IPAの公開問題の文章・図は転載していない

現在の[ITパスポート試験シラバス Ver.6.5](https://www.ipa.go.jp/shiken/syllabus/omgdg50000005kn1-att/syllabus_ip_ver6_5.pdf)の「利用者認証」に多要素認証、SMS認証、ワンタイムパスワードが含まれる。要素の分類は[IPAの解説](https://www.ipa.go.jp/security/10threats/omgdg50000008fi8-att/kaisetsu_2026_soshiki.pdf)と照合した。

## 再生成

```sh
cd video/list/2026-11-09-it-passport-mfa
python3 render.py
export GOOGLE_CLOUD_PROJECT=sandbox-492513
daihon check -f movie.yml
daihon build -f movie.yml
```

- 絵コンテ：[`storyboard.png`](storyboard.png)
- 台本：[`movie.yml`](movie.yml)
- 動画：[`out/it-passport-mfa-pilot.mp4`](out/it-passport-mfa-pilot.mp4)

`frames/`、絵コンテ、書き出し動画、音声キャッシュはローカル生成物としてGitの対象外。音声キャッシュがない環境ではGemini TTSの利用料金が発生する。
