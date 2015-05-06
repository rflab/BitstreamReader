# stream_reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール

とりあえずLua5.3.0＆VC++12でビルド確認、mingw/g++は多分無理です。

最初に実行するスクリプトはtest.luaです。コンソールで指定とかは後日。

## 機能
実行するとLuaインタプリタが起動します。
以下のクラスがバインドされています。
(もっと色々バインド予定。。。)

	lua->def_class<LuaGlue_Bitstream>("BitStream")->
		def("open",     (bool(LuaGlue_Bitstream::*)(const char*)) &LuaGlue_Bitstream::open). // 引数明示
		def("dump",     &LuaGlue_Bitstream::glue_dump).
		def("bit",      &LuaGlue_Bitstream::read_bit ).
		def("byte",     &LuaGlue_Bitstream::read_byte).
		def("cur_bit",  &LuaGlue_Bitstream::cur_bit  ).
		def("cur_byte", &LuaGlue_Bitstream::cur_byte ).
		def("b",        &LuaGlue_Bitstream::read_bit ).
		def("B",        &LuaGlue_Bitstream::read_byte).
		def("cb",       &LuaGlue_Bitstream::cur_bit  ).
		def("cB",       &LuaGlue_Bitstream::cur_byte );

	
	
## 定義ファイルの書き方
ストリームの構造はluaスクリプトで記述

    -- example
    s = BitStream.new()                       -- クラス作成
    s:open("test.dat")
    s:byte("hoge", 4, true)                   -- "hoge"のデータを４倍と読み込み、コンソール上に表示許可
    local length = s:byte("length", 4, false) -- "length"のデータを４バイト読み込み変数に記憶
    if length ~= 0 then
      s:byte("payload", 3, true)
      s:bit("foo[0-2]", 3, true)              -- ビット単位で読み込みこの行をコンソール上に表示
      s:bit("foo[3-7]", 5, true)              -- ビット単位で続けて読み込み
    end
