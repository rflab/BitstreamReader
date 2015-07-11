open(__stream_path__)
little_endian(false)
enable_print(true)

-- fifo
function test_fifo()
	local fifo1 = stream:new(6)
	local fifo2 = stream:new(4)

	-- �I�[�o�[����
	-- �T�C�Y�I�[�o�[����̂�00��05�ŏ㏑�������
	print(fifo1:get_size(), fifo1:cur())
	fifo1:write("01 02 03 04 05 06")
	fifo1:rbyte("01 02 03 04 05 06", 6)
	fifo1:putc(1)
	fifo1:putc(2)
	fifo1:putc(3)
	fifo1:putc(4)
	fifo1:putc(5)
	fifo1:rbyte("1", 1)
	fifo1:rbyte("2", 1)
	fifo1:rbyte("3", 1)
	fifo1:rbyte("4", 1)
	fifo1:rbyte("5", 1)
	print(fifo1:get_size(), fifo1:cur())
		
    -- �ʂ�Fifo�ɓ]��
	fifo1:write("06 07 08 09 0A")
	fifo1:tbyte(">> ", 5, fifo2)
	print(fifo2:get_size(), fifo2:cur())
	fifo2:rbit("fifo2_1_h", 4)
	fifo2:rbit("fifo2_1_l", 4)
	fifo2:rbit("fifo2_2_h", 4)
	fifo2:rbit("fifo2_2_l", 4)
	fifo2:rbit("fifo2_3_h", 4)
	fifo2:rbit("fifo2_3_l", 4)
	fifo2:rbit("fifo2_4_h", 4)
	fifo2:rbit("fifo2_4_l", 4)
	fifo2:rbit("fifo2_5_h", 4)
	fifo2:rbit("fifo2_5_l", 4)
	
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:write("01 02 03 04 05 06")
	fifo1:dump()
end

function test_sql1()
	local db = SQLite:new("db.db")
	db:exec("create table mytable (id integer primary key, name text)");
	--db:exec(".schema")
	db:exec("insert into mytable values (1, 'hoge')");
	db:exec("insert into mytable values (2, 'fuga')");
	db:exec("insert into mytable values (3, 'foo')");
	db:exec("insert into mytable values (4, 'bar')");
	db:exec("select * from mytable") -- �f�[�^���o���K�v
	db:exec("select name from mytable")
	assert(false)
end

function test_sql()
	local sql 
	if windows then
	-- �}���`�o�C�g�Ńn���O
		db = SQLite:new(__stream_name__..".db")
	else
		db = SQLite:new(__stream_dir__..__stream_name__..".db")
	end
	db:exec("drop table if exists mytable");
	db:exec("create table mytable (id integer primary key, name text)");

	local insert_stmt_ix= db:prepare("insert into mytable values (?, ?)");
	function insert_stmt(id, name)
		db:reset(insert_stmt_ix)
		db:bind_int(insert_stmt_ix, 1, id)
		db:bind_text(insert_stmt_ix, 2, name)
		db:step(insert_stmt_ix)
	end
	
	local select_stmt_ix = db:prepare("select * from mytable")
	function insert_stmt(id, name)
		db:reset(insert_stmt_ix)
		db:bind_int(insert_stmt_ix, 1, id)
		db:bind_text(insert_stmt_ix, 2, name)
		db:step(insert_stmt_ix)
	end
	
	sql = nil
	collectgarbage("collect")
end

function test_sqlite()
	local sq = sqlite3()
	sqlite3_open("hoge.db", ref(sq))
	sqlite3_exec(sq, "drop table if exists mytable", NULL(), NULL(), NULL())
	sqlite3_exec(sq, "create table mytable (id integer primary key, name text)", NULL(), NULL(), NULL())
	sqlite3_exec(sq, "insert int mytable(name) values('hoge')", 0, 0, 0)
	sqlite3_exec(sq, "insert int mytable(name) values('bar')", 0, 0, 0)
	sqlite3_exec(sq, "insert int mytable(name) values('foo')", 0, 0, 0)
	sqlite3_close()
end

function test_flie()
	open("file.dat", "wb+")
--	open(10000)
	local stream, prev = open(__stream_path__)
	
	tbyte("data", 100, prev);
	swap(prev)
	seek(0)
	swap(stream)
	tbyte("data", 100, prev);
	swap(prev)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
	rbyte("data", 10)
end

function test_flie()
	fstr("10 ", true)
	rfstr("ff 40", true)
end

--test_flie()
--test_sqlite()
--test_sql()
--test_fifo()
--dofile(__streamdef_dir__.."bmp.lua")
--dofile(__streamdef_dir__.."jpg.lua")
--dofile(__streamdef_dir__.."ts.lua")
dofile(__streamdef_dir__.."h265.lua")




