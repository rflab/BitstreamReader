-- bmp解析
local __stream_path__ = argv[1] or "test.jpg"
local info = {}

function segment(maker)
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function app0()
	rbyte("Length",              2)
	rstr ("Payload",             get("Length")-2)	
end

function dqt()
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function dht()
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function sof0()
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function sos()
	rbyte("Length",              2) -- SOSの場合これはあてにならない
	rbyte("Ns",                  1)
	
	for i=1, get("Ns") do
		rbyte("Cs_id",           1) -- 成分ID
		rbit ("DC_DHT",          4) -- ＤＣ成分ハフマンテーブル番号
		rbit ("AC_DHT",          4) -- ＡＣ成分ハフマンテーブル番号
	end
	
	rbyte("Ss",                  1)
	rbyte("Se",                  1)
	rbit ("Ah",                  4)
	rbit ("AL",                  4)
end

function jpg()
	cbyte("SOI",           2, 0xffd8)
	
	-- while true do
	-- 	sbyte(0xff)
	-- 	rbyte("id", 2)
	-- end

	while true do
		rbyte("Markar",        2)
		if get("Markar") == 0xffd9 then -- EOI
			break;
		elseif get("Markar") == 0xffe0 then
			app0()
		elseif get("Markar") == 0xffdb then
			dqt()
		elseif get("Markar") == 0xffc4 then
			dht()
		elseif get("Markar") == 0xffc0 then
			sof0()
		elseif get("Markar") == 0xffda then
			sos()
			sstr("ff d9")
		elseif get("Markar") == 0xffd0
		or     get("Markar") == 0xffd1
		or     get("Markar") == 0xffd2
		or     get("Markar") == 0xffd3
		or     get("Markar") == 0xffd4
		or     get("Markar") == 0xffd5
		or     get("Markar") == 0xffd6
		or     get("Markar") == 0xffd7 then
			-- restart
		else
			segment(get("Markar"))
		end 
	end
end

open(__stream_path__)
little_endian(false)
enable_print(true)
jpg()
print_table(info)
print_status()
