# Stream Reader

各種バイナリをビット単位で解析するツールです。
windowsならstream_reader/files/bin/streamreader.exeにファイルをドロップすれば解析が始まります。

（現在の対応フォーマット:mp4, mpeg-2 ts(tts), jpg, riff(avi, wav等), bmp, pes, h264, h265 and etc.）


Lua言語/SQLiteベースでスクリプトを書けばビット単位、可変長でどんなバイナリデータも解析/作成できます

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
```
より正確には以下の挙動となります。
* コマンドライン引数なしで起動した場合は、Luaのコマンドインタプリタとして起動されます。
* コマンドライン引数ありでLuaのファイルを指定しなかった場合は、[default.lua][1]が先に実行されます。
* コマンドライン引数はLua側でもargc、argv[]としてアクセスできます。
* 現状の[default.lua][1]は[check_stream.lua][2]でファイル識別を行い、処理の振り分けを行います
* 現状の[default.lua][1]は解析終了後にcmd()関数をコールし、cmd()関数が簡易コマンドを受け付けています。


### 定義ファイルの書き方

解析方法はLuaスクリプトで記述します。
* [Lua基礎文法最速マスター](http://handasse.blogspot.com/2010/02/lua.html)
* [Lua Lua 5.3 Reference Manual(本家)](http://www.lua.org/manual/5.3/)
* [Lua 5.2 リファレンスマニュアル(日本語)](http://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html)

C++側からはinit_lua関数で関数・クラスがバインドされています。細かい拡張はこちらを使用します。
* [ソースコード(streamreader.cpp)](https://github.com/rflab/stream_reader/blob/master/files/src/streamreader.cpp)

通常はutil.luaにある関数を利用すると簡単です。
* [util.lua](https://github.com/rflab/stream_reader/blob/master/files/bin/script/util/util.lua)
* [その他のライブラリ](https://github.com/rflab/stream_reader/blob/master/files/bin/script/util/)

```lua
-- ストリーム解析例 --

-- 準備
dofile("script/util/include.lua") -- Luaに関数登録ロード
open("test.dat")                 -- ファイルオープン＆初期化
dump()                           -- 現在位置から数バイト表示してみる

-- 基本的な読み込み
rbit ("flagA", 1)             -- 1ビットを読み込み
rbit ("flagB", 7)             -- 7ビットを読み込み
rbit ("flagC", 80)            -- 80ビットを読み込み
rbyte("dataA", 1)             -- 1バイトを読み込み
rstr ("dataB", 4)             -- 4バイトを文字列として読み込み
tbyte("pcm",   16, "pcm.dat") -- 16バイトをファイルに書き写す
print(get("flagC"))           -- 取得済みのデータを参照する
```
util.luaのよく使う関数の使用は以下の通りです。
```lua
-- 表記： "戻り値 = 関数名(引数...)) -- 機能"

-- 読み込み設定
stream, prev_stream = open(file_name) -- ファイルストリームを作成し、解析対象として登録
stream, prev_stream = open(size)      -- 固定長のバッファストリームを作成し、解析対象として登録
stream, prev_stream = open()          -- 可変長のバッファストリームを作成、解析対象として登録
prev_stream = swap(stream)            -- ストリームを解析対象として登録し、先に登録されていたストリームを返す

-- シーク系
byte, bit = cur()                -- 現在のバイトオフセット、ビットオフセットを取得
size = get_size()                -- ストリームファイルサイズ取得
seek(byte, bit)                  -- 絶対位置シーク
seekoff(byte, bit)               -- 相対位置シーク

-- 解析
val = get(name)                  -- 値を取得する
reset(name, value)               -- 値を設定する
val = rbit(name, size)           -- ビット単位で読み進める
val = rbyte(name, size)          -- バイト単位で読み進める
val = rstr(name, size)           -- 文字列として読み進める
val = rexp(name)                 -- 指数ゴロムで読み進める
bool = cbit(name, size, comp)    -- ビット単位で読み進め、compとの一致を確認
bool = cbyte(name, size, comp)   -- バイト単位で読み進め、compとの一致を確認
bool = cstr(name, size, comp)    -- 文字列として読み進め、compとの一致を確認
bool = cexp(name)                -- 指数ゴロムで読み進め、compとの一致を確認
val = lbit(size)                 -- ビット単位で見るが、ポインタは進めない
val = lbyte(size)                -- バイト単位で見るが、ポインタは進めない
val = lexp(size)                 -- 指数ゴロムで見るが、ポインタは進めない
offset = fbyte(char, advance)    -- charを検索、advance=trueでポインタを移動
offset = fstr(pattern, advance)  -- "00 01 ..." のような文字列パターンでバイナリ列を検索
tbyte(name, size, stream)        -- ストリームから別のstreamにデータを転送
tbyte(name, size, filename)      -- ストリームからからファイルにデータを転送

-- その他
dump(size)                       -- ストリームを最大256バイト出力
print_table(tbl)　　　　         -- テーブルの内容を表示する
hexstr(value)                    -- 値をHHHH(DDDD)な感じの文字列にする
write(filename, pattern)         -- char配列 or "00 01 ..." のような文字列パターンでファイル追記
```
## ビルド方法

自分でビルドする場合、
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、files/visual_studio_solution/visual_studio_solution.slnを開いてF5

Lua5.3.0＆VC++12でビルド確認済み
gcc version 4.9.2 (Ubuntu 4.9.2-10ubuntu13) でもたまにビルド確認しています。

[1]: https://github.com/rflab/stream_reader/blob/master/files/bin/script/default.lua
[2]: https://github.com/rflab/stream_reader/blob/master/files/bin/script/util/check_stream.lua
