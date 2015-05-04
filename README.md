# stream_reader

ビット単位、可変長で構造体解析できるコンソールツール

ストリームの構造はluaスクリプト

    readbyte("hoge", 4, true) -- "hoge"のデータを４倍と読み込み、コンソール上に表示許可
    local length = readbyte("length", 4, false) -- "length"のデータを４バイト読み込み変数に記憶
    readbyte("payload", length-1, false)
    readbit("foo[0-2]", 3, false) -- ビット単位で読み込みこの行をコンソール上に表示
    readbit("foo[3-7]", 5, false) -- ビット単位で続けて読み込み

LUAにバインドした関数は以下

    lua.def("open",     glue_stream_open);
    lua.def("dump",     glue_dump);
    lua.def("readbit",  glue_read_bit);
    lua.def("readbyte", glue_read_byte);
    lua.def("search",   glue_serch_byte);
    lua.def("cur_byte", glue_cur_byte);
    lua.def("cur_bit",  glue_cur_byte);
	
もっと色々バインド予定。。。
	
