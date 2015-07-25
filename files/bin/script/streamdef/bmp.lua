-- bmp解析
local __stream_path__ = argv[1] or "test.bmp"
local info = {} 

function BITMAPFILEHEADER()
	cstr ("bfType",           2, "BM")
	rbyte("bfSize",           4)
	rbyte("bfReserved1",      2)
	rbyte("bfReserved2",      2)
	rbyte("bfOffBits",        4)
	
	info.size = get("bfSize")
end

-- OS/2 bitmap
function BITMAPCOREHEADER()	
	rbyte("bcWidth",          2)
	rbyte("bcHeight",         2)
	rbyte("bcPlanes",         2)
	rbyte("bcBitCount",       2)

	info.width       = get("bcWidth")
	info.height      = get("bcHeight")
	info.depth       = get("bcBitCount")
	if     get("biCompression") == 0 then info.compression = "RGB"
	elseif get("biCompression") == 1 then assert(false, "unsupported RunLength8")
	elseif get("biCompression") == 2 then assert(false, "unsupported RunLength4")
	elseif get("biCompression") == 3 then assert(false, "unsupported Bitfields")
	end
	
	rbyte("data", get("bcWidth")*get("bcHeight")*get("bcBitCount"))
end

-- Windows Bitmap
function BITMAPINFOHEADER()	
	rbyte("biWidth",          4)
	rbyte("biHeight",         4)
	rbyte("biPlanes",         2)
	rbyte("biBitCount",       2)
	rbyte("biCompression",    4)
	rbyte("biSizeImage",      4)
	rbyte("biXPixPerMeter",   4)
	rbyte("biYPixPerMeter",   4)
	rbyte("biClrUsed",        4)
	rbyte("biClrImporant",    4)
	
	info.width  = get("biWidth")
	info.height = get("biHeight")
	info.depth  = get("biBitCount")
	if     get("biCompression") == 0 then info.compression = "RGB"
	elseif get("biCompression") == 1 then assert(false, "unsupported RunLength8")
	elseif get("biCompression") == 2 then assert(false, "unsupported RunLength4")
	elseif get("biCompression") == 3 then assert(false, "unsupported Bitfields")
	end
		
	enable_print(false)
	local begin = cur()
	local aligned_x = info.width + info.width%4
	local ascii_w = 120
	local ascii_h = math.floor(ascii_w*info.height/info.width)
	local intervalx = math.floor(aligned_x / ascii_w)
	local intervaly = math.floor(info.height / ascii_h)
	local bmp = bitmap:new(ascii_w, ascii_h)
	local r,g,b
	for y=0, ascii_h-1 do
		check_progress(false)
		for x=0, ascii_w-1 do
			b=gbyte(1)
			g=gbyte(1)
			r=gbyte(1)
			bmp:putrgb(x, ascii_h-1-y, r, g, b)
			seekoff(3*(intervalx)-3)
		end
		
		seek(begin+3*aligned_x*y*intervaly)
	end
	local sb = bmp:create_scaled_bmp(120, nil)
	sb:print_ascii(120, nil)
end

function bmp()
	BITMAPFILEHEADER()
	rbyte("bcSize",           4)

	if get("bcSize") == 14 then
		BITMAPCOREHEADER()
	elseif get("bcSize") == 40 then
		BITMAPINFOHEADER()
	else
		print("unsupported cbSize")
	end
	
end

open(__stream_path__)
little_endian(true)
enable_print(true)
bmp()
--print_table(info)

