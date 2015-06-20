# Stream Reader

各種ファイルストリームを解析するツールです。（現在の対応拡張子:.wav, .bmp, .jpg, .ts, .tts, .m2ts, .mpg, .mp4, .pes, .h264, h265, など）

windowsなら実行ファイルにファイルをドロップすれば解析が始まります。

スクリプトを書けばビット単位、可変長でどんなバイナリデータも解析できます

## 実行ファイル
Windows用の実行ファイルはfiles/bin/streamreader.exeです。

自分でビルドする場合、
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、files/visual_studio_solution/visual_studio_solution.slnを開いてF5

Lua5.3.0＆VC++12＆gcc version 4.9.2 (Ubuntu 4.9.2-10ubuntu13) でもたまにビルド確認しています。

## 詳細
引数なしで起動した場合はLuaのインタプリタとして起動されます。

第２引数にファイル名を入れると解析が始まるようにしています。

    // windowsの場合はbin/streamreader.exeにファイルをドロップとおなじ。
    S./a.out test.wav
    
起動時のオプション指定も可能です。

    S./a.out --help
    S./a.out --lua script/wav.lua
    S./a.out "01 23 45 67 79" -l script/dat.lua

* 起動時のオプションでluaファイルを指定しなかった場合はscript/default.luaが起動されます。
* 現状のdefault.luaはarg[1]をファイル名とみなして拡張子による解析の切り分けを行っています。
* 実行時引数はすべてluaでargc、argv[]としてアクセスできます。

## 定義ファイルの書き方

解析方法はLuaスクリプトで記述します。
（Luaの文法は http://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html あたり参照のこと。）

通常はfiles/bin/script/module/util.luaに書いた関数を利用したほうが簡単です。

```lua
--test.lua--

-- 準備
dofile("script/util.lua")     -- Luaに関数登録ロード
open("test.dat")              -- ファイルオープン＆初期化

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
C++側からは以下のような関数・クラスがバインドされています。
細かい拡張はこちら。
（関数・クラスの仕様はfiles/src/streamreader.cpp参照のこと。）

```cpp
// streamreader.cpp

// 関数バインド
lua->def("stdout_to_file",       FileManager::stdout_to_file);             // コンソール出力の出力先切り替え
lua->def("write_to_file",        FileManager::write_to_file);              // 指定したバイト列をファイルに出力
lua->def("transfer_to_file",     LuaGlueBitstream::transfer_to_file);      // 指定したストリームををファイルに出力
lua->def("reverse_16",           reverse_endian_16);                       // 16ビットエンディアン変換
lua->def("reverse_32",           reverse_endian_32);                       // 32ビットエンディアン変換
                                                 
// std::filebufによるビットストリームクラス
lua->def_class<LuaGlueFileBitstream>("FileBitstream")->
	def("open",                  &LuaGlueFileBitstream::open).             // ファイルオープン
	def("size",                  &LuaGlueFileBitstream::size).             // ファイルサイズ取得
	def("enable_print",          &LuaGlueFileBitstream::enable_print).     // 解析ログのON/OFF
	def("little_endian",         &LuaGlueFileBitstream::little_endian).    // ２バイト/４バイトの読み込み時はエンディアンを変換する
	def("seekpos_bit",           &LuaGlueFileBitstream::seekpos_by_bit).   // 先頭からファイルポインタ移動
	def("seekpos_byte",          &LuaGlueFileBitstream::seekpos_by_byte).  // 先頭からファイルポインタ移動
	def("seekpos",               &LuaGlueFileBitstream::seekpos).          // 先頭からファイルポインタ移動
	def("seekoff_bit",           &LuaGlueFileBitstream::seekoff_by_bit).   // 現在位置からファイルポインタ移動
	def("seekoff_byte",          &LuaGlueFileBitstream::seekoff_by_byte).  // 現在位置からファイルポインタ移動
	def("seekoff",               &LuaGlueFileBitstream::seekoff).          // 現在位置からファイルポインタ移動
	def("bit_pos",               &LuaGlueFileBitstream::bit_pos).          // 現在のビットオフセットを取得
	def("byte_pos",              &LuaGlueFileBitstream::byte_pos).         // 現在のバイトオフセットを取得
	def("read_bit",              &LuaGlueFileBitstream::read_by_bit).      // ビット単位で読み込み
	def("read_byte",             &LuaGlueFileBitstream::read_by_byte).     // バイト単位で読み込み
	def("read_string",           &LuaGlueFileBitstream::read_by_string).   // バイト単位で文字列として読み込み
	def("read_expgolomb",        &LuaGlueFileBitstream::read_by_expgolomb).// 指数ごロムとしてビットを読む
	def("comp_bit",              &LuaGlueFileBitstream::compare_by_bit).   // ビット単位で比較
	def("comp_byte",             &LuaGlueFileBitstream::compare_by_byte).  // バイト単位で比較
	def("comp_string",           &LuaGlueFileBitstream::compare_by_string).// バイト単位で文字列として比較
	def("look_bit",              &LuaGlueFileBitstream::look_by_bit).      // ポインタを進めないで値を取得、4byteまで
	def("look_byte",             &LuaGlueFileBitstream::look_by_byte).     // ポインタを進めないで値を取得、4byteまで
	def("find_byte",             &LuaGlueFileBitstream::find_byte).        // １バイトの一致を検索
	def("find_byte_string",      &LuaGlueFileBitstream::find_byte_string). // 数バイト分の一致を検索
	def("transfer_byte",         &LuaGlueFileBitstream::transfer_by_byte). // 別ストリームの終端に転送
	def("write",                 &LuaGlueFileBitstream::write_by_buf).     // ビットストリームの終端に書き込む
	def("put_char",              &LuaGlueFileBitstream::put_char).         // ビットストリームの終端に書き込む
	def("dump",                                            
		(bool(LuaGlueFileBitstream::*)(int)) &LuaGlueFileBitstream::dump); // 現在位置からバイト表示

// std::stringbufによるビットストリームクラス
lua->def_class<LuaGlueBufBitstream>("Buffer")->
	def("size",                  &LuaGlueBufBitstream::size).              // バッファサイズ取得
	def("enable_print",          &LuaGlueBufBitstream::enable_print).      // 解析ログのON/OFF
	def("little_endian",         &LuaGlueBufBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
	def("seekpos_bit",           &LuaGlueBufBitstream::seekpos_by_bit).    // 先頭からファイルポインタ移動
	def("seekpos_byte",          &LuaGlueBufBitstream::seekpos_by_byte).   // 先頭からファイルポインタ移動
	def("seekpos",               &LuaGlueBufBitstream::seekpos).           // 先頭からファイルポインタ移動
	def("seekoff_bit",           &LuaGlueBufBitstream::seekoff_by_bit).    // 現在位置からファイルポインタ移動
	def("seekoff_byte",          &LuaGlueBufBitstream::seekoff_by_byte).   // 現在位置からファイルポインタ移動
	def("seekoff",               &LuaGlueBufBitstream::seekoff).           // 現在位置からファイルポインタ移動
	def("bit_pos",               &LuaGlueBufBitstream::bit_pos).           // 現在のビットオフセットを取得
	def("byte_pos",              &LuaGlueBufBitstream::byte_pos).          // 現在のバイトオフセットを取得
	def("read_bit",              &LuaGlueBufBitstream::read_by_bit).       // ビット単位で読み込み
	def("read_byte",             &LuaGlueBufBitstream::read_by_byte).      // バイト単位で読み込み
	def("read_string",           &LuaGlueBufBitstream::read_by_string).    // バイト単位で文字列として読み込み
	def("read_expgolomb",        &LuaGlueBufBitstream::read_by_expgolomb). // 指数ごロムとしてビットを読む
	def("comp_bit",              &LuaGlueBufBitstream::compare_by_bit).    // ビット単位で比較
	def("comp_byte",             &LuaGlueBufBitstream::compare_by_byte).   // バイト単位で比較
	def("comp_string",           &LuaGlueBufBitstream::compare_by_string). // バイト単位で文字列として比較
	def("look_bit",              &LuaGlueBufBitstream::look_by_bit).       // ポインタを進めないで値を取得、4byteまで
	def("look_byte",             &LuaGlueBufBitstream::look_by_byte).      // ポインタを進めないで値を取得、4byteまで
	def("find_byte",             &LuaGlueBufBitstream::find_byte).         // １バイトの一致を検索
	def("find_byte_string",      &LuaGlueBufBitstream::find_byte_string).  // 数バイト分の一致を検索
	def("transfer_byte",         &LuaGlueBufBitstream::transfer_by_byte).  // 部分ストリーム(Bitstream)を作成
	def("write",                 &LuaGlueBufBitstream::write_by_buf).      // ビットストリームの終端に書き込む
	def("put_char",              &LuaGlueBufBitstream::put_char).          // ビットストリームの終端に書き込む
	def("dump",                                            
		(bool(LuaGlueBufBitstream::*)(int)) &LuaGlueBufBitstream::dump);   // 現在位置からバイト表示

// FIFO（リングバッファ）によるビットストリームクラスクラス
// ヘッド/テールの監視がないのでメモリに余裕がある処理なら"Buffer"クラスを使ったほうが良い
lua->def_class<LuaGlueFifoBitstream>("Fifo")->
	def("size",                  &LuaGlueFifoBitstream::size).              // 書き込み済みサイズ取得
	def("reserve",               &LuaGlueFifoBitstream::reserve).           // バッファサイズ設定、使う前に必須
	def("enable_print",          &LuaGlueFifoBitstream::enable_print).      // コンソール出力ON/OFF
	def("little_endian",         &LuaGlueFifoBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
	def("seekpos_bit",           &LuaGlueFifoBitstream::seekpos_by_bit).    // 先頭からファイルポインタ移動
	def("seekpos_byte",          &LuaGlueFifoBitstream::seekpos_by_byte).   // 先頭からファイルポインタ移動
	def("seekpos",               &LuaGlueFifoBitstream::seekpos).           // 先頭からファイルポインタ移動
	def("seekoff_bit",           &LuaGlueFifoBitstream::seekoff_by_bit).    // 現在位置からファイルポインタ移動
	def("seekoff_byte",          &LuaGlueFifoBitstream::seekoff_by_byte).   // 現在位置からファイルポインタ移動
	def("seekoff",               &LuaGlueFifoBitstream::seekoff).           // 現在位置からファイルポインタ移動
	def("bit_pos",               &LuaGlueFifoBitstream::bit_pos).           // 現在のビットオフセットを取得
	def("byte_pos",              &LuaGlueFifoBitstream::byte_pos).          // 現在のバイトオフセットを取得
	def("read_bit",              &LuaGlueFifoBitstream::read_by_bit).       // ビット単位で読み込み
	def("read_byte",             &LuaGlueFifoBitstream::read_by_byte).      // バイト単位で読み込み
	def("read_string",           &LuaGlueFifoBitstream::read_by_string).    // バイト単位で文字列として読み込み
	def("read_expgolomb",        &LuaGlueFifoBitstream::read_by_expgolomb). // 指数ごロムとしてビットを読む
	def("comp_bit",              &LuaGlueFifoBitstream::compare_by_bit).    // ビット単位で比較
	def("comp_byte",             &LuaGlueFifoBitstream::compare_by_byte).   // バイト単位で比較
	def("comp_string",           &LuaGlueFifoBitstream::compare_by_string). // バイト単位で文字列として比較
	def("look_bit",              &LuaGlueFifoBitstream::look_by_bit).       // ポインタを進めないで値を取得、4byteまで
	def("look_byte",             &LuaGlueFifoBitstream::look_by_byte).      // ポインタを進めないで値を取得、4byteまで
	def("find_byte",             &LuaGlueFifoBitstream::find_byte).         // １バイトの一致を検索
	def("find_byte_string",      &LuaGlueFifoBitstream::find_byte_string).  // 数バイト分の一致を検索
	def("transfer_byte",         &LuaGlueFifoBitstream::transfer_by_byte).  // 部分ストリーム(Bitstream)を作成
	def("write",                 &LuaGlueFifoBitstream::write_by_buf).      // ビットストリームの終端に書き込む
	def("put_char",              &LuaGlueFifoBitstream::put_char).          // ビットストリームの終端に書き込む
	def("dump",                                            
		(bool(LuaGlueFifoBitstream::*)(int)) &LuaGlueFifoBitstream::dump);  // 現在位置からバイト表示
```
