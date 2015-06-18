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

--test_fifo()
--dofile(__exec_dir__.."script/bmp.lua")
--dofile(__exec_dir__.."script/jpg.lua")
dofile(__exec_dir__.."script/ts.lua")


