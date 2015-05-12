# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール

## TODO

とりあえずLua5.3.0＆VC++12でビルド確認してます。mingw/gccはビルド未確認。

（VC++の場合はsrcを全部突っ込んで、src/luaをインクルードディレクトリに追加してF5、mingw/gccはfiles/srcでmake build）

## 機能
引数なしで起動した場合はLuaのインタプリタがそのまま起動されます。

オプションを指定しない場合はarg1 arg2 ...に文字列として代入された状態でscript/default.luaが起動されます。
（現状はdefault.luaで拡張子を判定し、対応するスクリプトをコールするようにしています。）

    ./a.out test.wav

一応ちまちまオプション指定も可能です。

    ./a.out --lua wav.lua --arg test.wav

以下のような関数・クラスがバインドされています。
関数仕様はfiles/src/streamreader.cpp参照のこと。

    // 関数バインド
    lua->def("reverse_16", LuaGlue::reverse_endian_16);
    lua->def("reverse_32", LuaGlue::reverse_endian_32);

    // クラスバインド
    lua->def_class<LuaGlue>("BitStream")->
        def("open",          &LuaGlue::open).
        def("enable_print",  &LuaGlue::enable_print).
        def("file_size",     &LuaGlue::file_size).
        def("seek",          &LuaGlue::seek).
        def("search",        &LuaGlue::search_byte).
        def("dump",          &LuaGlue::dump_byte).
        def("cur_bit",       &LuaGlue::cur_bit).
        def("cur_byte",      &LuaGlue::cur_byte).
        def("read_bit",      &LuaGlue::read_bit).
        def("read_byte",     &LuaGlue::read_byte).
        def("read_string",   &LuaGlue::read_string).
        def("comp_bit",      &LuaGlue::compare_bit).
        def("comp_byte",     &LuaGlue::compare_byte).
        def("comp_str",      &LuaGlue::compare_string).
        def("out_byte",      &LuaGlue::output_byte);

## 定義ファイルの書き方

ストリームの構造はLuaスクリプトで記述します。
（Lua文法はhttp://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html あたり参照のこと）

以下のサンプルではfiles/bin/script/mylib.luaに書いた関数を利用しています。
（files/bin/script/default.luaあたり参照のこと。）

    -- <<example>>

    dofile("script/mylib.lua")                -- Luaに関数登録ロード
    stream = init_stream("test.wav")          -- ファイルオープン＆初期化
    print_status()                            -- 情報表示する
    dump(256)                                 -- 現在行から256バイト表示する 
    
    -- 解析開始
    cstr("'hoge'",           4, "hoge")       -- 4バイトを文字列として読み込み比較する
    rbyte("file_size+muns8", 4)               -- 4バイトをバイナリデータとして読み込む

    -- 中略
    
    local data = {}                           -- 情報取得用テーブル
    rbyte("size_audio_data", 4, data)        -- テーブルにサイズ情報を取得
    obyte("out.pcm", data["size_audio_data"]) -- ファイル書き出し
