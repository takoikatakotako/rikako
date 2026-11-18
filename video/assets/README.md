# 動画の共通アセット

アプリで使っている画像のコピーと、動画向けに加工した共通素材を置く。

| ファイル | 用途 | 元画像 |
| --- | --- | --- |
| [`app-icon-chemistry.png`](app-icon-chemistry.png) | 化学動画の締め・サムネイル候補 | [`chemi-icon.png`](../../ios/Rikako/Assets.xcassets/AppIconHighSchoolChemistryProd.appiconset/chemi-icon.png) |
| [`app-icon-it-passport.png`](app-icon-it-passport.png) | ITパスポート動画の締め・サムネイル候補 | [`it-passport-icon.png`](../../ios/Rikako/Assets.xcassets/AppIconItPassportProd.appiconset/it-passport-icon.png) |
| [`rikako-standing.png`](rikako-standing.png) | 理科子さんとカメさんの立ち絵 | [`rikako-standing@2x.png`](../../ios/Rikako/Assets.xcassets/images/Top/top-rikako-standing.imageset/rikako-standing@2x.png) |
| [`rikako-wordmark.png`](rikako-wordmark.png) | ロゴ文字 | [`appLogo@2x.png`](../../ios/Rikako/Assets.xcassets/images/Top/top-app-logo.imageset/appLogo@2x.png) |

元のアプリアイコンは正方形で文字入り。小さな表示では読みにくいため、用途に合わせて大きさを決める。

BGMの候補・利用条件・保存方法は [`BGM.md`](BGM.md) にまとめる。音源ファイルは `bgm/` に置き、Gitから除外する。

## rikako-turtle-v1.png

理科子の[`rikako-standing.png`](rikako-standing.png)の左下にいるカメを参照し、Codexの画像生成で単体の透過PNGにした。元絵から見えない部分は補完されているため、完全なピクセル切り出しではない。

生成に使用した指示（内蔵 image_gen ツール）：

> Use case: background-extraction. Asset type: reusable small mascot cutout for vertical educational videos. Input image: the attached Rikako standing illustration is the edit target. Primary request: isolate ONLY the small turtle companion near the lower left of the character, as a clean standalone full-body turtle on a genuinely transparent background. Preserve its identity and hand-drawn style: pale yellow smiling head on the left, bright green segmented shell with dark outlines, little feet, friendly expression. Remove Rikako, her legs, the book, and all other objects. Reconstruct only turtle parts that are hidden by the person so it reads as one complete mascot. Keep the original proportions and colors as closely as possible. Center the turtle with comfortable transparent margins. No text, no shadow, no backdrop, no new accessories.
