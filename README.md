# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール、Lua言語ベース

## ビルド・インストール
とりあえずLua5.3.0＆VC++12＆gcc (Ubuntu 4.9.2-10ubuntu13) 4.9.2でビルド確認済み
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、files/visual_studio_solution/visual_studio_solution.slnを開いてF5
* Windows用の実行ファイルはfiles/bin/streamreader.exe


## 使い方・機能
引数なしで起動した場合はLuaのインタプリタとして起動されます。

第２引数にファイル名を入れるとscript/default.luaで対応づけられた拡張子で解析が始まるようにしています

    // windowsの場合はstreamreader.exeにファイルをドロップとおなじ。
    S./a.out test.wav
    
コンソールで起動した場合はオプション指定も可能です。
最初の'-オプション'より前に指定された引数はテーブルargv[]に文字列として代入され、script/default.luaが起動されます。
（argvに実行ファイル名は含まれません。現状のdefault.luaはarg[1]をファイル名として拡張子を判別し、対応するスクリプトをコールするようにしています。）

    S./a.out --help
    S./a.out --lua script/wav.lua --arg test.wav
    S./a.out "01 23 45 67 79" -l script/dat.lua

## 定義ファイルの書き方

ストリームの構造はLuaスクリプトで記述します。
（Luaの文法は http://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html あたり参照のこと。）

以下のような関数・クラスがバインドされています。
（関数仕様はfiles/src/streamreader.cpp参照のこと。）

    // 関数バインド
    lua->def("reverse_16", LuaGlue::reverse_endian_16);
    lua->def("reverse_32", LuaGlue::reverse_endian_32);

    // クラスバインド
	lua->def_class<LuaGlue>("Bitstream")->
		def("open",               &LuaGlue::open).                            // 解析ファイルオープン
		def("file_size",          &LuaGlue::file_size).                       // 解析ファイルサイズ取得
		def("enable_print",       &LuaGlue::enable_print).                    // コンソール出力ON/OFF
		def("seek",               &LuaGlue::seek).                            // ファイルポインタ移動
		def("dump",               (bool(LuaGlue::*)()) &LuaGlue::dump_byte).  // 現在位置から最大256バイト表示
		def("cur_bit",            &LuaGlue::cur_bit).                         // 現在のビットオフセットを取得
		def("cur_byte",           &LuaGlue::cur_byte).                        // 現在のバイトオフセットを取得
		def("read_bit",           &LuaGlue::read_bit).                        // ビット単位で読み込み
		def("read_byte",          &LuaGlue::read_byte).                       // バイト単位で読み込み
		def("read_string",        &LuaGlue::read_string).                     // バイト単位で文字列として読み込み
		def("comp_bit",           &LuaGlue::compare_bit).                     // ビット単位で比較
		def("comp_byte",          &LuaGlue::compare_byte).                    // バイト単位で比較
		def("comp_string",        &LuaGlue::compare_string).                  // バイト単位で文字列として比較
		def("out_byte",           &LuaGlue::output_byte).                     // バイト単位でファイルに出力
		def("search_byte",        &LuaGlue::search_byte).                     // １バイトの一致を検索
		def("search_byte_string", &LuaGlue::search_byte_string).              // 数バイト分の一致を検索
		def("write",              &LuaGlue::write);                           // 指定したバイト列をファイルに出力

ぶっちゃけ↑のままだと使いにくいので、files/bin/script/mylib.luaに書いた関数を利用したほうがいいです。
（files/bin/script/wav.luaあたり参照のこと。）

    dofile("script/mylib.lua")                -- Luaに関数登録ロード
    init_stream("test.wav")          -- ファイルオープン＆初期化
    print_status()                            -- 情報表示する
    dump(256)                                 -- 現在行から256バイト表示する 
    
    cstr("'hoge'",           4, "hoge")       -- 4バイトを文字列として読み込み比較する
    rbyte("file_size+muns8", 4)               -- 4バイトをバイナリデータとして読み込む

    -- 中略

    local data = {}                           -- 情報取得用テーブル
    rbyte("size_audio_data", 4, data)         -- テーブルにサイズ情報を取得
    obyte("out.pcm", data["size_audio_data"]) -- ファイル書き出し
