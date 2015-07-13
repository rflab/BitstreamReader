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
enable_print(__default_enable_print__)
bmp()
print_table(info)

