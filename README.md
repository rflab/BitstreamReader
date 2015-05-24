# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール、Lua言語ベース

MPEG-2 TS(PES)、MP4のタイムスタンプ、その他JPEGのExifを解析するサンプルを含みます。
bmp, wavもおまけ程度に見ることができます。 

## ビルド・インストール
とりあえずLua5.3.0＆VC++12＆gcc version 4.9.2 (Ubuntu 4.9.2-10ubuntu13) でビルド確認済み
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、files/visual_studio_solution/visual_studio_solution.slnを開いてF5
* Windows用の実行ファイルはfiles/bin/streamreader.exe


## 使い方・機能
引数なしで起動した場合はLuaのインタプリタとして起動されます。

第２引数にファイル名を入れると解析が始まるようにしています。

    // windowsの場合はbin/streamreader.exeにファイルをドロップとおなじ。
    S./a.out test.wav
    
より詳しくは、起動時のオプション指定によります。
引数がある場合、最初の'-'付きオプションより前のものはluaのテーブル'argv[]'に文字列として代入され、script/default.luaが起動されます。
（現状のdefault.luaはarg[1]をファイル名とみなして拡張子を判定し、対応する解析スクリプトをコールするようにしています。）

    S./a.out --help
    S./a.out --lua script/wav.lua --arg test.wav
    S./a.out "01 23 45 67 79" -l script/dat.lua

## 定義ファイルの書き方

解析方法はLuaスクリプトで記述します。
（Luaの文法は http://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html あたり参照のこと。）

通常はfiles/bin/script/module/util.luaに書いた関数を利用したほうが簡単です。
（files/bin/script/wav.luaあたり参照のこと。）

    -- 準備
    dofile("script/util.lua")    -- Luaに関数登録ロード
    open("test.dat")             -- ファイルオープン＆初期化
    
    -- 読み込み
    dump()                       -- 現在行から数バイト表示してみる
    rstr ("tag",   4)            -- 4バイトを文字列として読み込み
    rbyte("dataA", 1)            -- 1バイトを読み込み
    rbit ("flagA", 1)            -- 1ビットを読み込み
    rbit ("flagB", 7)            -- 7ビットを読み込み
    rbit ("flagC", 80)           -- 80ビットを読み込み
    wbyte("out.pcm", 16)         -- 16バイトをファイルに書き写す
    print(get("flagC"))          -- 取得済みのデータを参照する

    -- その他
    store(rbyte("size_audio_data", 4))  -- csvファイルに書き出すデータ１
    store("data", get("flafA"))         -- csvファイルに書き出すデータ２
    save_as_csv(result.csv)             -- csvファイルに書き出す

C++側からは以下のような関数・クラスがバインドされています。
（関数・クラスの仕様はfiles/src/streamreader.cpp参照のこと。）

	// 関数バインド
	lua->def("stdout_to_file", stdout_to_file);                     // コンソール出力の出力先切り替え
	lua->def("reverse_16",     LuaGlue::reverse_endian_16);         // 16ビットエンディアン変換
	lua->def("reverse_32",     LuaGlue::reverse_endian_32);         // 32ビットエンディアン変換

	// クラスバインド
	lua->def_class<LuaGlue>("Bitstream")->
		def("open",                  &LuaGlue::open).               // 解析ファイルオープン
		def("file_size",             &LuaGlue::file_size).          // 解析ファイルサイズ取得
		def("enable_print",          &LuaGlue::enable_print).       // コンソール出力ON/OFF
		def("little_endian",         &LuaGlue::little_endian).      // ２or４バイトの読み込み時のエンディアン指定
		def("seek",                  &LuaGlue::seek).               // 先頭からファイルポインタ移動
		def("offset_bit",            &LuaGlue::offset_by_bit).      // 現在位置からファイルポインタ移動
		def("offset_byte",           &LuaGlue::offset_by_byte).     // 現在位置からファイルポインタ移動
		def("dump",                  &LuaGlue::dump).               // 現在位置からバイト表示
		def("cur_bit",               &LuaGlue::cur_bit).            // 現在のビットオフセットを取得
		def("cur_byte",              &LuaGlue::cur_byte).           // 現在のバイトオフセットを取得
		def("read_bit",              &LuaGlue::read_by_bit).        // ビット単位で読み込み
		def("read_byte",             &LuaGlue::read_by_byte).       // バイト単位で読み込み
		def("read_string",           &LuaGlue::read_by_string).     // バイト単位で文字列として読み込み
		def("comp_bit",              &LuaGlue::compare_by_bit).     // ビット単位で比較
		def("comp_byte",             &LuaGlue::compare_by_byte).    // バイト単位で比較
		def("comp_string",           &LuaGlue::compare_by_string).  // バイト単位で文字列として比較
		def("search_byte",           &LuaGlue::search_byte).        // １バイトの一致を検索
		def("search_byte_string",    &LuaGlue::search_byte_string). // 数バイト分の一致を検索
		def("copy_byte",             &LuaGlue::copy_by_byte).       // ストリームからファイルに出力
		def("write",                 &LuaGlue::write);              // 指定したバイト列をファイルに出力
		
