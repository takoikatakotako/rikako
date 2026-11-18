# 理科子・女性声の日本語比較

現在の動画と同じ Gemini 3.8 Flash TTS と話し方の指定で、同じ日本語の台詞を6種類の声に読ませる。Sulafat が現行動画の声で、Kore は以前の声。

台詞：「黒い水性インク、ほんとうに一色かな？ 紙でインクの色を分ける方法は、どれ？」

| ファイル | 声 | 公式の特徴 |
| --- | --- | --- |
| `out/01-Kore.wav` | Kore | Firm |
| `out/02-Leda.wav` | Leda | Youthful |
| `out/03-Achernar.wav` | Achernar | Soft |
| `out/04-Aoede.wav` | Aoede | Breezy |
| `out/05-Zephyr.wav` | Zephyr | Bright |
| `out/06-Sulafat.wav` | Sulafat | Warm |

音声はローカルの `out/` に保存され、Git には含めない。再生成は以下のとおり。

```sh
cd video/list/2026-10-26-pilot-chromatography/voice-comparison
export GOOGLE_CLOUD_PROJECT=sandbox-492513
daihon check -f movie.yml
daihon voice -f movie.yml
python3 export_samples.py
```

声の特徴：[Google Cloud 公式のプリセット一覧](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/text-to-speech/overview#prebuilt_voices)。
