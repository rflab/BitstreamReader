-- bmp解析
local __stream_path__ = argv[1] or "test.tobmp"

-- Windows Bitmap
function create_bmp(filename, dip)
	write(filename, "BM")
	write(filename, hex2str(dip.pitch*dip.hight*3 +40, 4, true)) -- "bfSize",           4)
	write(filename, "00 00")                                     -- "bfReserved1",      2)
	write(filename, "00 00")                                     -- "bfReserved2",      2)
	write(filename, "36 00 00 00")                               -- "bfOffBits",        4)
	write(filename, "28 00 00 00")                               -- "bcSize",           4)
	write(filename, hex2str(dip.pitch, 4, true))                 -- "biWidth",          4)
	write(filename, hex2str(dip.hight, 4, true))                 -- "biHeight",         4)
	write(filename, "01 00")                                     -- "biPlanes",         2)
	write(filename, "18 00")                                     -- "biBitCount",       2)
	write(filename, "00 00 00 00")                               -- "biCompression",    4)
	write(filename, hex2str(dip.pitch*dip.hight*3, 4, true))     -- "biSizeImage",      4)
	write(filename, "00 00 00 00")                               -- "biXPixPerMeter",   4)
	write(filename, "00 00 00 00")                               -- "biYPixPerMeter",   4)
	write(filename, "00 00 00 00")                               -- "biClrUsed",        4)
	write(filename, "00 00 00 00")                               -- "biClrImporant",    4)
	dip.buf:seek(0)
	dip.buf:tbyte("dip", dip.buf:size(), true, filename)
end

function init_dip(pitch, hight)
	local dip = {}
	dip.pitch = pitch
	dip.hight = hight
	dip.buf = stream:new()
	
	for i=1, pitch*hight do
		dip.buf:write("00 00 ff")
	end
	return dip
end

function putcolor(dip, x, y, r, g, b)
	local pos = (dip.pitch*y + x) * 3
	dip.buf:seek(pos)
	dip.buf:write(string.char(r)..string.char(g)..string.char(b))
end

function test_pattern()
	-- テストパターン作成

	print("init dip")
	local width = 720
	local hight = 480
	local r, g, b
	local dip = init_dip(width, hight)

	print("fill grad")
	for i=0, 80-1 do
		for j=0, width-1 do
			r = math.floor(j/width*255)
			putcolor(dip, j, i, r, r, r)
		end
	end

	print("color bar")
	for i=80, hight-1 do
		for j=0, width-1 do
			if     j/width*7 < 1 then r=255; g=255; b=255 
			elseif j/width*7 < 2 then r=0;   g=0;   b=255   
			elseif j/width*7 < 3 then r=0;   g=255; b=0   
			elseif j/width*7 < 4 then r=255; g=0;   b=0 
			elseif j/width*7 < 5 then r=255; g=255; b=0   
			elseif j/width*7 < 6 then r=255; g=0;   b=255 
			else                      r=0;   g=255; b=255 end
			putcolor(dip, j, i, b, g, r)
		end
	end

	create_bmp(__out_dir__.."out.bmp", dip)
	print("done")
end
