# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール、Lua言語ベース

## ビルド・インストール
とりあえずLua5.3.0＆VC++12＆gcc (Ubuntu 4.9.2-10ubuntu13) 4.9.2でビルド確認済み
* gccの場合はfiles/srcでmake build
* VisualStudio2013の場合は、visual_studio_solution/visual_studio_solution.slnを開いてF5
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

ぶっちゃけ↑のままだと使いにくいので、files/bin/script/mylib.luaに書いた関数を利用したほうがいいです。
（files/bin/script/wav.luaあたり参照のこと。）

    dofile("script/mylib.lua")                -- Luaに関数登録ロード
    stream = init_stream("test.wav")          -- ファイルオープン＆初期化
    print_status()                            -- 情報表示する
    dump(256)                                 -- 現在行から256バイト表示する 
    
    cstr("'hoge'",           4, "hoge")       -- 4バイトを文字列として読み込み比較する
    rbyte("file_size+muns8", 4)               -- 4バイトをバイナリデータとして読み込む

    -- 中略

    local data = {}                           -- 情報取得用テーブル
    rbyte("size_audio_data", 4, data)         -- テーブルにサイズ情報を取得
    obyte("out.pcm", data["size_audio_data"]) -- ファイル書き出し
