# Stream Reader

各種ファイルストリームを解析するツールです。Lua言語ベース。（現在の対応拡張子:.wav, .bmp, .jpg, .ts, .tts, .m2ts, .mpg, .mp4, .pes, .h264, h265, など）

windowsなら実行ファイルにファイルをドロップすれば解析が始まります。

スクリプトを書けばビット単位、可変長でどんなバイナリデータも解析できます

## 実行ファイル
Windows用の実行ファイルはfiles/bin/streamreader.exeです。

自分でビルドする場合、
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、files/visual_studio_solution/visual_studio_solution.slnを開いてF5

Lua5.3.0＆VC++12＆gcc version 4.9.2 (Ubuntu 4.9.2-10ubuntu13) でもたまにビルド確認しています。

## 実行方法

実行時引数にファイル名を入れると解析が始まります。
```
    // windowsの場合はbin/streamreader.exeにファイルをドロップとおなじ。
    S./a.out test.wav
```
解析が完了したら幾つかのコマンドで結果を参照できます。
```
    -- とりあえず取得した値を全部見る
    all
    -- 名前に foo もしくは bar を含む値を列挙
    get foo bar
```
より正確には以下の挙動となります。
* 以下のような起動オプションが指定可能です。
```
    S./a.out --help
    S./a.out --lua script/wav.lua
    S./a.out "01 23 45 67 79" -l script/dat.lua
```
* 引数なしで起動した場合はLuaのコマンドインタプリタとして起動されます。
* 実行時引数でluaのファイルを指定しなかった場合はscript/default.luaが起動されます。
* 実行時引数はすべてluaでargc、argv[]としてアクセスできます。
* 現状のdefault.luaはarg[1]をファイル名とみなして拡張子による解析の切り分けが実行されます。
* default.luaを通して解析が正常終了した場合はcmd.luaが起動され、簡易コマンドで値を参照できます。

### 定義ファイルの書き方

解析方法はLuaスクリプトで記述します。
（Luaの文法は http://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html あたり参照のこと。）

```lua
-- ストリーム解析例 --

-- 準備
dofile("script/module/util.lua") -- Luaに関数登録ロード
open("test.dat")                 -- ファイルオープン＆初期化

-- 基本的な読み込み
dump()                        -- 現在位置から数バイト表示してみる
rbit ("flagA", 1)             -- 1ビットを読み込み
rbit ("flagB", 7)             -- 7ビットを読み込み
rbit ("flagC", 80)            -- 80ビットを読み込み
rbyte("dataA", 1)             -- 1バイトを読み込み
rstr ("dataB", 4)             -- 4バイトを文字列として読み込み
tbyte("pcm",   16, "pcm.dat") -- 16バイトをファイルに書き写す
print(get("flagC"))           -- 取得済みのデータを参照する

-- その他
local next16bit = lbit(16)           -- 16bit先読み、ポインタは進まない
local ofs = fstr("00 00 03", false)  -- 00 00 03のバイナリ列を検索、リードポインタは進めない
store("data", get("flagA"))          -- csvファイル用データの記憶
save_as_csv(result.csv)              -- csvファイルに書き出す
```

通常はfiles/bin/script/module/util.luaにある関数や、files/module内の各種クラス利用すると簡単です。
util.luaのよく使う関数の使用は以下の通りです。
```lua
-- 表記： "戻り値 = 関数名(引数...)) -- 機能"

-- 読み込み設定
stream      = open(file_name)    -- ファイルストリームを作成し、解析対象として登録
stream      = open(size)         -- 固定長のバッファストリームを作成し、解析対象として登録
stream      = open()             -- 可変長のバッファストリームを作成、解析対象として登録
prev_stream = swap(stream)       -- ストリームを解析対象として登録し、先に登録されていたストリームを返す
print_status()                   -- ストリーム状態表示
size = get_size()                -- ストリームファイルサイズ取得
enable_print(b)                  -- 解析結果表示のON/OFF
little_endian(enable)            -- ２バイト/４バイトの読み込みでエンディアンを変換する

-- シーク系
byte, bit = cur()                -- 現在のバイトオフセット、ビットオフセットを取得
seek(byte, bit)                  -- 絶対位置シーク
seekoff(byte, bit)               -- 相対位置シーク

-- 解析
val = get(name)                  -- 値を取得する
reset(name, value)               -- 値を設定する
val = peek(name)                 -- nilが返ることをいとわない場合はこちらでget
val = rbit(name, size)           -- ビット単位読み込み
val = rbyte(name, size)          -- バイト単位読み込み
val = rstr(name, size)           -- 文字列として読み込み
val = rexp(name)                 -- 指数ゴロムとして読み込み
val = cbit(name, size, comp)     -- ビット単位で読み込み、compとの一致を確認
val = cbyte(name, size, comp)    -- バイト単位で読み込み、compとの一致を確認
val = cstr(name, size, comp)     -- 文字列として読み込み、compとの一致を確認
val = cexp(name)                 -- 指数ゴロムとして読み込み、compとの一致を確認
val = lbit(size)                 -- bit単位で読み込むがポインタは進めない
val = lbyte(size)                -- バイト単位で読み込むがポインタは進めない
val = lexp(size)                 -- 指数ゴロムとして読み込むがポインタは進めない
offset = fbyte(char, advance)    -- 指定の１バイト検索、advance=trueでポインタを移動
offset = fstr(pattern, advance)  -- 文字列を検索、もしくは"00 11 22"のようなバイナリパターンで追記
tbyte(name, size, target)        -- ストリームからtargetにデータを転送
dump(size)                       -- ストリームを最大256バイト出力

-- その他
stream = sub_stream(name, size)  -- 現在位置からsize文のデータをストリームとして切り出す
do_until(closure, offset)        -- cur()==offsetまでclosure()を実行する
store(key, value)                -- csv保存用に値を記憶する
save_as_csv(file_name)           -- store()した値をcsvに書き出す
hexstr(value)                    -- 値をHHHH(DDDD)な感じの文字列にする
print_table(tbl, indent)         -- テーブルをダンプする
store_to_table(tbl, name, value) -- tbl[name].tblの末尾とtbl[name].valに値を入れる
str2val(buf_str, little_endian)  -- 4文字までの16進数文字列を数値に変換
pat2str(pattern)                 -- 00 01 ... のような文字列パターンをchar配列に変換する
hex2str(val, size, le)           -- 数値をchar配列に変える
write(filename, pattern)         -- ファイルを開いてchar配列もしくは"00 11 22"のようなバイナリパターンで追記
putchar(filename, char)          -- ファイルに一文字追記

```
C++側からは以下のような関数・クラスがバインドされています。
細かい拡張はこちら。
（関数・クラスの仕様はfiles/src/streamreader.cpp参照のこと。）
```cpp
// streamreader.cpp

// 関数バインド
lua->def("stdout_to_file",   FileManager::stdout_to_file);        // コンソール出力の出力先切り替え
lua->def("write_to_file",    FileManager::write_to_file);         // 指定したバイト列をファイルに出力
lua->def("transfer_to_file", LuaGlueBitstream::transfer_to_file); // 指定したストリームををファイルに出力
lua->def("reverse_16",       reverse_endian_16);                  // 16ビットエンディアン変換
lua->def("reverse_32",       reverse_endian_32);                  // 32ビットエンディアン変換

// クラスインターフェース
lua->def_class<LuaGlueBitstream>("IBitstream")->
	def("size",             &LuaGlueBitstream::size).              // ファイルサイズ取得
	def("enable_print",     &LuaGlueBitstream::enable_print).      // 解析ログのON/OFF
	def("little_endian",    &LuaGlueBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
	def("seekpos_bit",      &LuaGlueBitstream::seekpos_bit).       // 先頭からファイルポインタ移動
	def("seekpos_byte",     &LuaGlueBitstream::seekpos_byte).      // 先頭からファイルポインタ移動
	def("seekpos",          &LuaGlueBitstream::seekpos).           // 先頭からファイルポインタ移動
	def("seekoff_bit",      &LuaGlueBitstream::seekoff_bit).       // 現在位置からファイルポインタ移動
	def("seekoff_byte",     &LuaGlueBitstream::seekoff_byte).      // 現在位置からファイルポインタ移動
	def("seekoff",          &LuaGlueBitstream::seekoff).           // 現在位置からファイルポインタ移動
	def("bit_pos",          &LuaGlueBitstream::bit_pos).           // 現在のビットオフセットを取得
	def("byte_pos",         &LuaGlueBitstream::byte_pos).          // 現在のバイトオフセットを取得
	def("read_bit",         &LuaGlueBitstream::read_bit).          // ビット単位で読み込み
	def("read_byte",        &LuaGlueBitstream::read_byte).         // バイト単位で読み込み
	def("read_string",      &LuaGlueBitstream::read_string).       // バイト単位で文字列として読み込み
	def("read_expgolomb",   &LuaGlueBitstream::read_expgolomb).    // 指数ゴロムとしてビットを読む
	def("comp_bit",         &LuaGlueBitstream::compare_bit).       // ビット単位で比較
	def("comp_byte",        &LuaGlueBitstream::compare_byte).      // バイト単位で比較
	def("comp_string",      &LuaGlueBitstream::compare_string).    // バイト単位で文字列として比較
	def("comp_expgolomb",   &LuaGlueBitstream::compare_expgolomb). // 指数ゴロムとして比較
	def("look_bit",         &LuaGlueBitstream::look_bit).          // ポインタを進めないでビット値を取得、4byteまで
	def("look_byte",        &LuaGlueBitstream::look_byte).         // ポインタを進めないでバイト値を取得、4byteまで
	def("look_expgolomb",   &LuaGlueBitstream::look_expgolomb).    // ポインタを進めないで指数ゴロム値を取得、4byteまで
	def("find_byte",        &LuaGlueBitstream::find_byte).         // １バイトの一致を検索
	def("find_byte_string", &LuaGlueBitstream::find_byte_string).  // 数バイト分の一致を検索
	def("transfer_byte",    &LuaGlueBitstream::transfer_byte).     // 部分ストリーム(Bitstream)を作成
	def("write",            &LuaGlueBitstream::write_byte_string). // ビットストリームの終端に書き込む
	def("put_char",         &LuaGlueBitstream::put_char).          // ビットストリームの終端に書き込む
	def("dump",
		(bool(LuaGlueBitstream::*)(int)) &LuaGlueBitstream::dump); // 現在位置からバイト表示

// std::filebufによるビットストリームクラス
lua->def_subclass<LuaGlueFileBitstream>("FileBitstream", "IBitstream")->
	def("new",     LuaBinder::constructor<LuaGlueFileBitstream(string, string)>()).
	def("open",    &LuaGlueFileBitstream::open); // ファイルオープン

// std::stringbufによるビットストリームクラス
lua->def_subclass<LuaGlueBufBitstream>("Buffer", "IBitstream")->
	def("new",     LuaBinder::constructor<LuaGlueBufBitstream()>());

// FIFO（リングバッファ）によるビットストリームクラスクラス
// ヘッド/テールの監視がなく挙動が特殊なのでメモリに余裕がある処理なら"Buffer"クラスを使ったほうが良い
lua->def_subclass<LuaGlueFifoBitstream>("Fifo", "IBitstream")->
	def("new",     LuaBinder::constructor<LuaGlueFifoBitstream(int)>()).
	def("reserve", &LuaGlueFifoBitstream::reserve); // バッファを再確保、書き込み済みデータは破棄
```
