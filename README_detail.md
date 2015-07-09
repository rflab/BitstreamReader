# Stream Reader

各種バイナリをビット単位で解析するツールです。
（現在の対応フォーマット:mp4, mpg (ts, tts), jpg(jfif, exif), iff(avi, wav, aiff), bmp, pes, h264, h265, など）

windowsならstream_reader/files/bin/streamreader.exeにファイルをドロップすれば解析が始まります。
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
* 現状の[default.lua][1]は[stream_dispatcher.lua][2]でファイル識別を行い、処理の振り分けを行います
* 現状の[default.lua][1]は解析終了後にcmd()関数をコールし、cmd()関数が簡易コマンドを受け付けています。


### 定義ファイルの書き方

解析方法はLuaスクリプトで記述します。
* [Lua基礎文法最速マスター](http://handasse.blogspot.com/2010/02/lua.html)
* [Lua Lua 5.3 Reference Manual(本家)](http://www.lua.org/manual/5.3/)
* [Lua 5.2 リファレンスマニュアル(日本語)](http://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html)

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
stream, prev_stream = open(file_name) -- ファイルストリームを開く
stream, prev_stream = open(size)      -- 固定長のバッファストリームを開く
stream, prev_stream = open()          -- 可変長のバッファストリームを開く
prev_stream = swap(stream)            -- 解析対象のストリームを交換する

-- シーク系
byte, bit = cur()                -- 現在の解析位置を取得
size = get_size()                -- ストリームサイズ取得
seek(byte, bit)                  -- 絶対位置シーク
seekoff(byte, bit)               -- 相対位置シーク

-- 解析
val = get(name)                  -- 値を取得する
reset(name, value)               -- 値を設定する
val = rbit(name, size)           -- ビット単位で読み進め、データベースに登録
val = rbyte(name, size)          -- バイト単位で読み進め、データベースに登録
str = rstr(name, size)           -- 文字列として読み進め、データベースに登録
val = rexp(name)                 -- 指数ゴロムで読み進め、データベースに登録
bool = cbit(name, size, comp)    -- ビット単位で読み進め、compとの一致を確認
bool = cbyte(name, size, comp)   -- バイト単位で読み進め、compとの一致を確認
bool = cstr(name, size, comp)    -- 文字列として読み進め、compとの一致を確認
bool = cexp(name)                -- 指数ゴロムで読み進め、compとの一致を確認
val = lbit(size)                 -- ビット単位で先読みし、ポインタは進めない
val = lbyte(size)                -- バイト単位で先読みし、ポインタは進めない
str = lstr(size)                 -- 文字列として先読みし、ポインタは進めない
val = lexp(size)                 -- 指数ゴロムで先読みし、ポインタは進めない
offset = fbyte(char, advance)    -- charを検索、advance=trueでポインタを移動
offset = fstr(pattern, advance)  -- "00 01 ..."パターンでバイナリ列を検索
tbyte(name, size, stream)        -- ストリームから別のstreamにデータを転送
tbyte(name, size, filename)      -- ストリームからからファイルにデータを転送

-- その他
dump(size)                       -- ストリームを最大256バイト出力
print_table(tbl)　　　　         -- テーブルの内容を表示する
hexstr(value)                    -- 値をHHHH(DDDD)な感じの文字列にする
write(filename, pattern)         -- 文字列 or "00 01 ..."パターンでファイル追記
```
C++側からはinit_lua関数で関数・クラスがバインドされています。細かい拡張はこちらを使用します。
* [ソースコード(streamreader.cpp)](https://github.com/rflab/stream_reader/blob/master/files/src/streamreader.cpp)
```cpp
// 関数バインド
lua->def("stdout_to_file",   FileManager::stdout_to_file);        // コンソール出力の出力先切り替え
lua->def("write_to_file",    FileManager::write_to_file);         // 指定したバイト列をファイルに出力
lua->def("transfer_to_file", LuaGlueBitstream::transfer_to_file); // 指定したストリームををファイルに出力
lua->def("reverse_16",       reverse_endian_16);                  // 16ビットエンディアン変換
lua->def("reverse_32",       reverse_endian_32);                  // 32ビットエンディアン変換

// インターフェース
lua->def_class<LuaGlueBitstream>("IBitstream")->
	def("size",               &LuaGlueBitstream::size).              // ファイルサイズ取得
	def("enable_print",       &LuaGlueBitstream::enable_print).      // 解析ログのON/OFF
	def("little_endian",      &LuaGlueBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
	def("seekpos_bit",        &LuaGlueBitstream::seekpos_bit).       // 先頭からファイルポインタ移動
	def("seekpos_byte",       &LuaGlueBitstream::seekpos_byte).      // 先頭からファイルポインタ移動
	def("seekpos",            &LuaGlueBitstream::seekpos).           // 先頭からファイルポインタ移動
	def("seekoff_bit",        &LuaGlueBitstream::seekoff_bit).       // 現在位置からファイルポインタ移動
	def("seekoff_byte",       &LuaGlueBitstream::seekoff_byte).      // 現在位置からファイルポインタ移動
	def("seekoff",            &LuaGlueBitstream::seekoff).           // 現在位置からファイルポインタ移動
	def("bit_pos",            &LuaGlueBitstream::bit_pos).           // 現在のビットオフセットを取得
	def("byte_pos",           &LuaGlueBitstream::byte_pos).          // 現在のバイトオフセットを取得
	def("read_bit",           &LuaGlueBitstream::read_bit).          // ビット単位で読み込み
	def("read_byte",          &LuaGlueBitstream::read_byte).         // バイト単位で読み込み
	def("read_string",        &LuaGlueBitstream::read_string).       // 文字列を読み込み
	def("read_expgolomb",     &LuaGlueBitstream::read_expgolomb).    // 指数ゴロムとしてビットを読む
	def("comp_bit",           &LuaGlueBitstream::compare_bit).       // ビット単位で比較
	def("comp_byte",          &LuaGlueBitstream::compare_byte).      // バイト単位で比較
	def("comp_string",        &LuaGlueBitstream::compare_string).    // 文字列を比較
	def("comp_expgolomb",     &LuaGlueBitstream::compare_expgolomb). // 指数ゴロムを比較
	def("look_bit",           &LuaGlueBitstream::look_bit).          // ポインタを進めないでビット値を取得、4byteまで
	def("look_byte",          &LuaGlueBitstream::look_byte).         // ポインタを進めないでバイト値を取得、4byteまで
	def("look_byte_string",   &LuaGlueBitstream::look_byte_string).  // ポインタを進めないで文字列を取得
	def("look_expgolomb",     &LuaGlueBitstream::look_expgolomb).    // ポインタを進めないで指数ゴロムを取得、4byteまで
	def("find_byte",          &LuaGlueBitstream::find_byte).         // １バイトの一致を検索
	def("find_byte_string",   &LuaGlueBitstream::find_byte_string).  // 数バイト分の一致を検索
	def("transfer_byte",      &LuaGlueBitstream::transfer_byte).     // 部分ストリーム(Bitstream)を作成
	def("write",              &LuaGlueBitstream::write).             // ビットストリームの現在位置に書き込む
	def("put_char",           &LuaGlueBitstream::put_char).          // ビットストリームの現在位置に書き込む
	def("append",             &LuaGlueBitstream::append).            // ビットストリームの終端に書き込む
	def("append_char",        &LuaGlueBitstream::append_char).       // ビットストリームの終端に書き込む
	def("dump",
		(bool(LuaGlueBitstream::*)(int)) &LuaGlueBitstream::dump); // 現在位置からバイト表示

// std::filebufによるビットストリームクラス
lua->def_class<LuaGlueFileBitstream>("FileBitstream", "IBitstream")->
	def("new",     LuaBinder::constructor<LuaGlueFileBitstream(const string&, const string&)>()).
	def("open",    &LuaGlueFileBitstream::open); // ファイルオープン

// std::stringbufによるビットストリームクラス
lua->def_class<LuaGlueBufBitstream>("Buffer", "IBitstream")->
	def("new",     LuaBinder::constructor<LuaGlueBufBitstream()>());

// FIFO（リングバッファ）によるビットストリームクラスクラス
// ヘッド/テールの監視がなく挙動が特殊なのでメモリに余裕がある処理なら"Buffer"クラスを使ったほうが良い
lua->def_class<LuaGlueFifoBitstream>("Fifo", "IBitstream")->
	def("new",     LuaBinder::constructor<LuaGlueFifoBitstream(int)>()).
	def("reserve", &LuaGlueFifoBitstream::reserve); // バッファを再確保、書き込み済みデータは破棄

// SQLiterラッパー
lua->rawset("SQLITE_ROW",        SQLITE_ROW);
lua->rawset("SQLITE_INTEGER",    SQLITE_INTEGER);
lua->rawset("SQLITE_FLOAT",      SQLITE_FLOAT);
lua->rawset("SQLITE_TEXT",       SQLITE_TEXT);
lua->rawset("SQLITE_BLOB",       SQLITE_BLOB);
lua->rawset("SQLITE_NULL",       SQLITE_NULL);
lua->def_class<SqliteWrapper>("SQLite")->
	def("new",          LuaBinder::constructor<SqliteWrapper(const string&)>()).
	def("exec",         &SqliteWrapper::exec).
	def("prepare",      &SqliteWrapper::prepare).
	def("step",         &SqliteWrapper::step).
	def("reset",        &SqliteWrapper::reset).
	def("bind_int",     &SqliteWrapper::bind_int).
	def("bind_text",    &SqliteWrapper::bind_text).
	def("bind_real",    &SqliteWrapper::bind_real).
	def("column_name",  &SqliteWrapper::column_name).
	def("column_type",  &SqliteWrapper::column_type).
	def("column_count", &SqliteWrapper::column_count).
	def("column_int",   &SqliteWrapper::column_int).
	def("column_text",  &SqliteWrapper::column_text).
	def("column_real",  &SqliteWrapper::column_real);
```
## ビルド方法

自分でビルドする場合、
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、files/visual_studio_solution/visual_studio_solution.slnを開いてF5

Lua5.3.0＆VC++12でビルド確認済み
gcc version 4.9.2 (Ubuntu 4.9.2-10ubuntu13) でもたまにビルド確認しています。

[1]: https://github.com/rflab/stream_reader/blob/master/files/bin/script/default.lua
[2]: https://github.com/rflab/stream_reader/blob/master/files/bin/script/streamdef/stream_dispatcher.lua
