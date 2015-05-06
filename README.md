# stream_reader

ビット単位、可変長でバイナリデータを構造体解析できるコンソールツール

## TODO

とりあえずLua5.3.0＆VC++12でビルド確認してます。mingw/g++は多分無理です。

最初に実行するスクリプトはtest.luaです。コンソールで指定とかは後日。

ファイルシークとか、大きいサイズの読み込みは未対応、後日

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
ストリームの構造はLuaスクリプトで記述

    -- example
    
    -- ファイルオープン
    s = BitStream.new()
    s:open("test.dat")
    s:dump(0, 255)                            -- 先頭から255バイト表示してみる

    s:byte("hoge", 4, true)                   -- "hoge"としてデータを４倍と読み込み、コンソール上に表示許可
    local length = s:byte("length", 4, false) -- ４バイト読み込み変数に記憶
    if length >= 4 then
      s:byte("payload", length-1, true)
      s:bit("foo[0-2]", 3, true)              -- ビット単位で読み込みこの行をコンソール上に表示
      s:bit("foo[3-7]", 5, true)              -- ビット単位で続けて読み込み
    end
