# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール

## TODO

とりあえずLua5.3.0＆VC++12でビルド確認してます。mingw/g++はビルド未確認。

（VC++の場合はsrcを全部突っ込んで、src/luaをインクルードディレクトリに追加してF5、mingw/g++はfiles/srcでmake build）

## 機能
引数なしで起動した場合はLuaのインタプリタがそのまま起動されます。

引数を一つだけ指定した場合はLuaの変数arg1に代入してscript/default.luaを起動します。

    // 使用例
    ./a.out test.wav

一応ちまちま引数指定も可能です。

    // 使用例
    ./a.out --stream test.wav --lua wav.lua

以下のような関数・クラスがバインドされています。
関数仕様はfiles/src/streamreader.cpp参照のこと。

        // 関数バインド
	lua->def("reverse16", LuaGlue_Bitstream::reverse_endian_16);
	lua->def("reverse32", LuaGlue_Bitstream::reverse_endian_32);

	// クラスバインド
	lua->def_class<LuaGlue_Bitstream>("BitStream")->
		def("open", &LuaGlue_Bitstream::open).
		def("enable_print", &LuaGlue_Bitstream::enable_print).
		def("get_file_size", &LuaGlue_Bitstream::file_size).
		def("dump", &LuaGlue_Bitstream::glue_dump).
		def("seek", &LuaGlue_Bitstream::seek).
		def("search", &LuaGlue_Bitstream::search_byte).
		def("cur_bit", &LuaGlue_Bitstream::cur_bit).
		def("cur_byte", &LuaGlue_Bitstream::cur_byte).
		def("read_bit", &LuaGlue_Bitstream::read_bit).
		def("read_byte", &LuaGlue_Bitstream::read_byte).
		def("read_string", &LuaGlue_Bitstream::read_string).
		def("comp_bit", &LuaGlue_Bitstream::compare_bit).
		def("comp_byte", &LuaGlue_Bitstream::compare_byte).
		def("comp_str", &LuaGlue_Bitstream::compare_string).
		def("write", &LuaGlue_Bitstream::write);

## 定義ファイルの書き方

ストリームの構造はLuaスクリプトで記述します。
（Lua文法はhttp://milkpot.sakura.ne.jp/lua/lua52_manual_ja.htmlあたり参照のこと）

実際はfiles/bin/script/mylib.luaに幾つか便利関数を用意しているのでそれを使うといいと思います。
files/bin/script/default.luaあたり参照のこと。

    -- <<example>>

    dofile("script/mylib.lua")          -- Luaに関数登録ロード
    stream = init_stream("test.wav")    -- ファイルオープン＆初期化
    print_status()                      -- 情報表示する
    dump(256)                           -- 現在行から256バイト表示する 
    
    
    cstr("'RIFF'",           4, "RIFF") -- 4バイトを文字列として読み込み比較する
    byte("file_size+muns8",  4)         -- 4バイトをバイナリデータとして読み込む
    str("'wave'",            4, "wave") -- 4バイトを文字列として読み込む
    
    -- 中略
    
    local data = {}                     -- ここに読み込んだデータを保存する
    byte("size_audio_data",  4, data)
    write("out.pcm",                     reverse_32(data["size_audio_data"]))

