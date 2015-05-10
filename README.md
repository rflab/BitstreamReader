# Stream Reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール

## TODO

とりあえずLua5.3.0＆VC++12でビルド確認してます。mingw/g++は多分無理。

## 機能
引数なしで起動した場合はLuaのインタプリタがそのまま起動される。

引数を一つだけ指定した場合はLuaの変数arg1に代入してscript/default.luaを起動します。

    // 使用例
    ./a.out test.wav

コンソール上で起動する場合はちまちま引数を指定する

    // 使用例
    ./a.out --stream test.wav --lua wav.lua

以下のクラスがバインドされています。
(もっと色々バインド予定。。。)

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
ストリームの構造はLuaスクリプトで記述。

    -- example
    
    -- ファイルオープン
    s = BitStream.new()
    s:open("test.dat")
    s:dump(0, 255)                          -- 先頭から255バイト表示してみる

    s:read_byte("hoge", 4)                  -- "hoge"としてデータを４バイト読み込む
    local length = s:read_byte("length", 4) -- ４バイト読み込み変数に記憶
    if length >= 4 then
      s:read_byte("payload", length-1)
      s:read_bit("foo[0-2]", 3)             -- ビット単位で読み込みこの行をコンソール上に表示
      s:read_bit("foo[3-7]", 5)             -- ビット単位で続けて読み込み
    end
