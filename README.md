# Stream Reader

各種バイナリをビット単位で解析するツールです。
（現在の対応フォーマット:mp4, mpg (ts, tts), jpg(jfif, exif), iff(avi, wav, aiff), bmp, pes, h264, h265, など）

## 使い方

実行時引数にファイル名を指定すると解析が始まります。
```
// windowsの場合はstreamreader.exeにファイルをドロップとおなじ。
S./a.out test.wav
```
解析が完了したら幾つかの簡易コマンドで結果を参照することが可能です。
```
-- とりあえず取得した値を全部見る
cmd>info
-- 名前に foo もしくは bar を含む値の情報を表示
cmd>grep foo bar
cmd>list foo bar
-- 名前に foo を含む値の3つ目付近をダンプ表示
cmd>dump foo 3
-- ヘルプ
cmd>help
```
[もっと詳しく..](https://github.com/rflab/stream_reader/blob/master/README.md)
