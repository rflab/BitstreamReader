# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール

## ビルド・インストール
とりあえずLua5.3.0＆VC++12＆gcc (Ubuntu 4.9.2-10ubuntu13) 4.9.2でビルド確認済み
* VC++の場合はsrcを全部突っ込んで、src/luaをインクルードディレクトリに追加してF5
* gccはfiles/srcでmake build
* VisualStudio2013がインストールされていない環境の場合はVC++2013ランタイムが必要です。 https://www.microsoft.com/ja-jp/download/details.aspx?id=40784


## 使い方・機能
引数なしで起動した場合はLuaのインタプリタとして起動されます。

引数に'-オプション'を使用しない場合はarg1 arg2 ...に文字列として代入された状態でscript/default.luaが起動されます。
（現状のdefault.luaはarg1をファイル名として拡張子を判定し、対応するスクリプトをコールするようにしています。）

    // windowsの場合はfiles/bin/visual_studio_solution.exeにファイルをドロップとおなじ。
    S./a.out test.wav

コンソールで起動した場合はオプション指定も可能です。

    S./a.out --lua wav.lua --arg test.wav

## 定義ファイルの書き方

ストリームの構造はLuaスクリプトで記述します。
（Lua文法はhttp://milkpot.sakura.ne.jp/lua/lua52_manual_ja.html あたり参照のこと）

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

ぶっちゃけ↑のままだと使いにくいので、以下のサンプルではfiles/bin/script/mylib.luaに書いた関数を利用したほうがいいです。
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
