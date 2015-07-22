-- bmp作成

-- Windows Bitmap
function write_bmp(filename, dip)
	write(filename, "BM")
	write(filename, val2str(dip.pitch*dip.height*3 +40, 4, true)) -- "bfSize",           4)
	write(filename, "00 00")                                      -- "bfReserved1",      2)
	write(filename, "00 00")                                      -- "bfReserved2",      2)
	write(filename, "36 00 00 00")                                -- "bfOffBits",        4)
	write(filename, "28 00 00 00")                                -- "bcSize",           4)
	write(filename, val2str(dip.pitch, 4, true))                  -- "biWidth",          4)
	write(filename, val2str(dip.height, 4, true))                 -- "biHeight",         4)
	write(filename, "01 00")                                      -- "biPlanes",         2)
	write(filename, "18 00")                                      -- "biBitCount",       2)
	write(filename, "00 00 00 00")                                -- "biCompression",    4)
	write(filename, val2str(dip.pitch*dip.height*3, 4, true))     -- "biSizeImage",      4)
	write(filename, "00 00 00 00")                                -- "biXPixPerMeter",   4)
	write(filename, "00 00 00 00")                                -- "biYPixPerMeter",   4)
	write(filename, "00 00 00 00")                                -- "biClrUsed",        4)
	write(filename, "00 00 00 00")                                -- "biClrImporant",    4)

	local num = dip.pitch*dip.height
	for i=0, num-1 do
		putchar(filename, math.ceil(dip.r[i]))
		putchar(filename, math.ceil(dip.g[i]))
		putchar(filename, math.ceil(dip.b[i]))
	end
	close_file(filename)
end

function init_dip(pitch, height)
	local dip = {}
	dip.pitch = pitch
	dip.height = height
	dip.r = {}
	dip.g = {}
	dip.b = {}
	return dip
end

function putrgb(dip, x, y, r, g, b)
	if x > dip.pitch
	or y > dip.height then
		print("dip over")
		return
	end

	local pos = (dip.pitch*(dip.height-y-1)) + x
	dip.r[pos] = r
	dip.g[pos] = g
	dip.b[pos] = b
end

function putyuv(dip, x, y, Y, cb, cr)
	if x > dip.pitch
	or y > dip.height then
		print("dip over")
		return
	end

	local pos = (dip.pitch*(dip.height-y-1)) + x
	--dip.r[pos] = Y                     +  1.402*(cr-128)
	--dip.g[pos] = Y - 0.344136*(cb-128) - 0.714136*(cr-128)
	--dip.b[pos] = Y + 1.772*(cb-128)
	dip.r[pos] = Y              +  1.5748*(cr-128)
	dip.g[pos] = Y - 0.187324*(cb-128) - 0.468124 *(cr-128)
	dip.b[pos] = Y + 1.8556*(cb-128)
	
	--print("-----------------------")
	--print(Y, cb, cr)
	--print(Y, dip.r[pos])
	--print(cb, dip.g[pos])
	--print(cr, dip.b[pos])

	if dip.r[pos] < 0 then
		print(dip.r[pos])
		dip.r[pos] = 0;
	end
	if dip.g[pos] < 0 then
		print(dip.g[pos])
		dip.g[pos] = 0;
	end
	if dip.b[pos] < 0 then
		print(dip.b[pos])
		dip.b[pos] = 0;
	end
	if dip.r[pos] > 255 then
		print(dip.r[pos])
		dip.r[pos] = 255;
	end
	if dip.g[pos] > 255 then
		print(dip.g[pos])
		dip.g[pos] = 255;
	end
	if dip.b[pos] > 255 then
		print(dip.b[pos])
		dip.b[pos] = 255;
	end

end

-- Windows Bitmap
function old_write_bmp(filename, dip)
	write(filename, "BM")
	write(filename, val2str(dip.pitch*dip.height*3 +40, 4, true)) -- "bfSize",           4)
	write(filename, "00 00")                                      -- "bfReserved1",      2)
	write(filename, "00 00")                                      -- "bfReserved2",      2)
	write(filename, "36 00 00 00")                                -- "bfOffBits",        4)
	write(filename, "28 00 00 00")                                -- "bcSize",           4)
	write(filename, val2str(dip.pitch, 4, true))                  -- "biWidth",          4)
	write(filename, val2str(dip.height, 4, true))                  -- "biHeight",         4)
	write(filename, "01 00")                                      -- "biPlanes",         2)
	write(filename, "18 00")                                      -- "biBitCount",       2)
	write(filename, "00 00 00 00")                                -- "biCompression",    4)
	write(filename, val2str(dip.pitch*dip.height*3, 4, true))     -- "biSizeImage",      4)
	write(filename, "00 00 00 00")                                -- "biXPixPerMeter",   4)
	write(filename, "00 00 00 00")                                -- "biYPixPerMeter",   4)
	write(filename, "00 00 00 00")                                -- "biClrUsed",        4)
	write(filename, "00 00 00 00")                                -- "biClrImporant",    4)
	dip.buf:seek(0)
	dip.buf:tbyte("dip", dip.buf:get_size(), filename, true)
end

function old_init_dip(pitch, height)
	local dip = {}
	dip.pitch = pitch
	dip.height = height
	dip.buf = stream:new()
	
	for i=1, pitch*height do
		dip.buf:write("00 00 ff")
	end
	print("hoge", dip.buf:get_size(), dip.buf:cur())
	return dip
end

function old_putrgb(dip, x, y, r, g, b)
	local pos = (dip.pitch*(dip.height-1-y) + x) * 3
	
	dip.buf:seek(pos)
	dip.buf:write(string.char(r)..string.char(g)..string.char(b))
end

function test_pattern()
	-- テストパターン作成

	print("init dip")
	local width = 720
	local height = 480
	local r, g, b
	local dip = init_dip(width, height)

	print("fill grad")
	for i=0, 80-1 do
		for j=0, width-1 do
			r = putrgb.floor(j/width*255)
			putcolor(dip, j, i, r, r, r)
		end
	end

	print("color bar")
	for i=80, height-1 do
		for j=0, width-1 do
			if     j/width*7 < 1 then r=255; g=255; b=255 
			elseif j/width*7 < 2 then r=0;   g=0;   b=255   
			elseif j/width*7 < 3 then r=0;   g=255; b=0   
			elseif j/width*7 < 4 then r=255; g=0;   b=0 
			elseif j/width*7 < 5 then r=255; g=255; b=0   
			elseif j/width*7 < 6 then r=255; g=0;   b=255 
			else                      r=0;   g=255; b=255 end
			putrgb(dip, j, i, b, g, r)
		end
	end

	write_bmp(__out_dir__.."out.bmp", dip)
	print("done")
end
