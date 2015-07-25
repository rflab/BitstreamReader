-- jpeg解析

-- 解析データ
local jpeg = {q = {}, huffman = {}, frame = {}, scan  = {}}

-- ビット読み込み
function RECEIVE(SSSS)
	return gbit(SSSS)
end

-- ±0の二値として扱う
function EXTEND(V, T)
	local Vt = 2^(T-1)
	if V < Vt then
		Vt = ((-1)<<T) + 1
		V = V+Vt
	end
	return V
end

-- ハフマン符号を一つデコード
function read_huffman(huffval, maxcode, mincode, valptr)
	local i=1
	local code = gbit(1) 
	while true do
		if maxcode[i] == nil then 
			print_table(maxcode)
			print(i, binstr(code))
		end
		if code > maxcode[i] then
			i = i + 1
			code = (code << 1) + gbit(1)
		else
			break
		end
	end
	local j = valptr[i]
	j = j + code - mincode[i]
	if huffval[j] == nil then
		assert(false)
	end
	return huffval[j]
end

-- ブロック0埋め
function init8x8(frame, block)
	for i=0, 63 do
		frame.macroblock[block][i] = 0
	end
end

-- DC成分ハフマンデコード
function dcdiff8x8(frame, block)
	local T = read_huffman(
		frame.dc_huffval, frame.dc_maxcode, frame.dc_mincode, frame.dc_valptr)
	sprint("d", T)
	local DIFF = EXTEND(RECEIVE(T), T)
	local val = frame.dc_prev_diff + DIFF
	frame.macroblock[block][0] = val
	frame.dc_prev_diff = val
end

-- AC成分ハフマンデコード
function ac8x8(frame, block)
	-- AC成分
	local K = 1
	while true do	
			sprint("a")
		local RS = read_huffman(
			frame.ac_huffval, frame.ac_maxcode, frame.ac_mincode, frame.ac_valptr)
		local RRRR = RS >> 4 -- 上位4bitは値の前のZeroRunLength SSSSRRRR=0はEOB
		local SSSS = RS % 16 -- 下位4bitは値のサイズ, 0の場合はRRRRによってZRL or EOB or 終端まで0
		local R = RRRR
		sprint("K=", K, "RRRR=", RRRR, "SSSS", SSSS)
		-- 0成分
		-- or 値
		if SSSS == 0 then
			if R == 15 then
				-- ZRL
				K = K + 16
				sprint("ZRL")
			else
				sprint("EOB")
				break
			end
		else
			K = K + R
			frame.macroblock[block][K] = RECEIVE(SSSS)
			frame.macroblock[block][K] = EXTEND(frame.macroblock[block][K], SSSS)
			if K >= 63 then
				sprint("BREAK")
				break
			else
				K=K+1
			end
		end
	end
end

-- ジグザグスキャン
local zigzag = {
	 0,  1,  8, 16,  9,  2,  3, 10,
	17, 24, 32, 25, 18, 11,  4,  5,
	12, 19, 26, 33, 40, 48, 41, 34,
	27, 20, 13,  6,  7, 14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36,
	29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46,
	53, 60, 61, 54, 47, 55, 62, 63
}
function zigzag8x8(frame, block)
	local ZZ = frame.macroblock[block]
	frame.macroblock[block] = {}
	for i=0, 63 do
		frame.macroblock[block][zigzag[i+1]] = ZZ[i]
	end
end

-- 逆量子化
local function iquontization8x8(frame, block)
	for i=0, 63 do
		frame.macroblock[block][i] = frame.macroblock[block][i] * frame.q[i]
	end
end

-- 行列の掛算(IDCTで使う)
function mul8x8(a, b)
	local ret = {}
	local ix
	for i=0, 7 do
		for j=0, 7 do
			ix = (i*8)+j 
			ret[ix] = 0
			for k=0, 7 do
				ret[ix] = ret[ix] + a[(i*8)+k] * b[(k*8)+j]
			end
		end
	end
	return ret
end

-- IDCT(高速化なし)
local dct_matrix = {}
local dct_matrix_t = {}
for i=0, 7 do
	dct_matrix[i] = 1/(2*(2^0.5))
	dct_matrix_t[i*8] = 1/(2*(2^0.5))
end
for i=1, 7 do
	for j=0, 7 do
		local v = 0.5 * math.cos(( i*(j+0.5) / 8) * math.pi)
		dct_matrix  [(i*8)+j] = v
		dct_matrix_t[(j*8)+i] = v
	end
end
function idct8x8(frame, block)
	frame.macroblock[block] = mul8x8(dct_matrix_t, frame.macroblock[block])
	frame.macroblock[block] = mul8x8(frame.macroblock[block], dct_matrix)
	for i=0, 63 do
		local v = math.ceil(frame.macroblock[block][i] + 128)
		if v < 0 then
			frame.macroblock[block][i] = 0
		elseif v > 255 then
			frame.macroblock[block][i] = 255
		else
			frame.macroblock[block][i] = v
		end
	end
end

-- 8x8ブロックをデバッグ表示
function dump8x8(t)
	for i = 1, 8 do
		for j = 1, 8  do
			io.write(string.format("%7.2f ", t[8*(i-1) + (j-1)]))
		end
		io.write("\n")
	end
end

-- Y16x16で4:2:0をビットマップに書き込み
local c420_indices = 
{
	 0, 0, 1, 1, 2, 2, 3, 3,
	 0, 0, 1, 1, 2, 2, 3, 3,
	 8, 8, 9, 9,10,10,11,11,
	 8, 8, 9, 9,10,10,11,11,
	16,16,17,17,18,18,19,19,
	16,16,17,17,18,18,19,19,
	24,24,25,25,26,26,27,27,
	24,24,25,25,26,26,27,27
}
function fill_block_420(bmp, x, y, Y, Cb, Cr)	
	local yix = 0
	local block = 1
	local cix = 0
	local coff = 0
	for bi = 0, 8, 8 do
		for bj = 0, 8, 8 do
			yix = 0
			for i=0, 7 do
				for j=0, 7 do
					bmp:putyuv(x+bj+j, y+bi+i,
						Y[block][yix],
						Cb[c420_indices[yix+1]+coff],
						Cr[c420_indices[yix+1]+coff])
					yix = yix + 1 
				end
			end
			block = block + 1
			coff = coff + 4
		end
		coff = coff + 24
	end
end

-- Y16x8で4:2:0をビットマップに書き込み
local c422_indices = 
{
	 0, 0, 1, 1, 2, 2, 3, 3,
	 8, 8, 9, 9,10,10,11,11,
	16,16,17,17,18,18,19,19,
	24,24,25,25,26,26,27,27,
	32,32,33,33,34,34,35,35,
	40,40,41,41,42,42,43,43,
	48,48,49,49,50,50,51,51,
	56,56,57,57,58,58,59,59
}
function fill_block_422(bmp, x, y, Y, Cb, Cr)	
	local yix = 0
	local block = 1
	local cix = 0
	local coff = 0
	for bj = 0, 8, 8 do
		yix = 0
		for i=0, 7 do
			for j=0, 7 do
				bmp:putyuv(x+bj+j, y+i,
					Y[block][yix],
					Cb[c422_indices[yix+1]+coff],
					Cr[c422_indices[yix+1]+coff])
				yix = yix + 1 
			end
		end
		block = block + 1
		coff = coff + 4
	end
end

-- Y8x8で4:4:4をビットマップに書き込み
function fill_block_444(bmp, x, y, Y, Cb, Cr)
	local yix = 0
	for bi=0, 7 do
		for bj=0, 7 do
			bmp:putyuv(x+bj, y+bi, Y[yix], Cb[yix], Cr[yix])
			yix = yix + 1 
		end
	end
end

-- ピクチャデータをスキャン・デコード
function start_scan()
	-- データを転送
	local scan, prev = open()
	enable_print(false)
	swap(prev)
	while true do
		local ofs = fbyte(0xff, false)
		tbyte("scan", ofs+1, scan, true)
		local segment = lbyte(1)
		if segment == 0xd0
		or segment == 0xd1
		or segment == 0xd2
		or segment == 0xd3
		or segment == 0xd4
		or segment == 0xd5
		or segment == 0xd6
		or segment == 0xd7 then
			-- reset
			tbyte("RST", 1, scan, true)
		elseif segment ~= 0 then
			break
		else
			cbyte("dummy", 1, 0)
			-- print("continue scan")
		end
	end
	swap(scan)
	
	repeat
		-- スキャン用のテーブルを用意
		local hi
		local vi
		for i=1, jpeg.num_frame do
			jpeg.frame[i].q = jpeg.q[jpeg.frame[i].Qi]
			jpeg.frame[i].dc_huffval  = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].dc_huffman][0].huffval
			jpeg.frame[i].dc_huffcode = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].dc_huffman][0].huffcode
			jpeg.frame[i].dc_mincode  = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].dc_huffman][0].mincode 
			jpeg.frame[i].dc_maxcode  = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].dc_huffman][0].maxcode 
			jpeg.frame[i].dc_valptr   = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].dc_huffman][0].valptr  
		
			jpeg.frame[i].ac_huffval  = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].dc_huffman][1].huffval
			jpeg.frame[i].ac_huffcode = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].ac_huffman][1].huffcode
			jpeg.frame[i].ac_mincode  = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].ac_huffman][1].mincode 
			jpeg.frame[i].ac_maxcode  = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].ac_huffman][1].maxcode 
			jpeg.frame[i].ac_valptr   = jpeg.huffman[jpeg.scan[jpeg.frame[i].Ci].ac_huffman][1].valptr

			jpeg.frame[i].dc_prev_diff = 0
			jpeg.frame[i].macroblock = {{}, {}, {}, {}}
			
			if jpeg.frame[i].Ci == 1 then
				hi = jpeg.frame[i].Hi
				vi = jpeg.frame[i].Vi
			end
		end
		
		if hi == 2 and vi == 2 then
		elseif hi == 2 and vi == 1 then
		elseif hi == 1 and vi == 1 then
			-- supported
		else
			print("unsupported color format")
			break
		end
		
		-- デコード
		local x = 0
		local y = 0
		local macroblocksize_x = hi*8
		local macroblocksize_y = vi*8 
		local buf_width  = math.ceil(jpeg.width / macroblocksize_x) * macroblocksize_x
		local buf_height = math.ceil(jpeg.height / macroblocksize_y) * macroblocksize_y
		local reset_count = 0
		local RST
		local bmp = bitmap:new(jpeg.width, jpeg.height, buf_width, buf_height)
		print("W  = "..jpeg.width)
		print("H = "..jpeg.height)
		print("Start Decode ..")
		while y < buf_height do
			while x < buf_width do
				check_progress(false)
				
				-- リセット処理
				if jpeg.restert_interval and reset_count >= jpeg.restert_interval then
					if select(2, cur()) ~= 0 then
						rbit("stuffing_bit", 8 - select(2, cur()))
					end
					RST = rbyte("RST", 2)
					if  RST ~= 0xffd0
					and RST ~= 0xffd1
					and RST ~= 0xffd2
					and RST ~= 0xffd3
					and RST ~= 0xffd4
					and RST ~= 0xffd5
					and RST ~= 0xffd6
					and RST ~= 0xffd7 then
						assert(false, "failed reset.")
					else
						print("reset marker", hexstr(RST))
						for i, v in ipairs(jpeg.frame) do
							v.dc_prev_diff = 0
						end
					end
					reset_count = 1
				else
					reset_count = reset_count + 1
				end
				
				-- マクロブロックデコード
				for ci, v in ipairs(jpeg.frame) do
					local block = 1
					for i = 0, v.Vi-1 do
						for j = 0, v.Hi-1 do
							-- 8x8をデコード
							sprint("8x8", ci, i, j)
							init8x8(v, block)
							dcdiff8x8(v, block)
							ac8x8(v, block)
							iquontization8x8(v, block)
							zigzag8x8(v, block)
							idct8x8(v, block)
							block = block + 1
						end
					end
				end
				
				-- bitmapに書き込み
				if hi == 2 and vi == 2 then
					fill_block_420(bmp, x, y,
						jpeg.frame[1].macroblock,
						jpeg.frame[2].macroblock[1],
						jpeg.frame[3].macroblock[1])	
				elseif hi == 2 and vi == 1 then
					fill_block_422(bmp, x, y,
						jpeg.frame[1].macroblock,
						jpeg.frame[2].macroblock[1],
						jpeg.frame[3].macroblock[1])
				else
					fill_block_444(bmp, x, y,
						jpeg.frame[1].macroblock[1],
						jpeg.frame[2].macroblock[1],
						jpeg.frame[3].macroblock[1])
				end				
				x = x + macroblocksize_x
			end
			x = 0
			y = y + macroblocksize_y
		end
		print("Done")
		
		-- ファイル・コンソール出力
		bmp:write(__stream_dir__.."out.bmp")
		local sb = bmp:create_scaled_bmp(120, nil)
		sb:print_ascii(120, nil)
	until true

	swap(prev)
end

-- 知らないセグメント読み飛ばし
function segment()
	local length = rbit("L", 16)
	seekoff(length - 2)
end

-- 以下JPEG規格通り

function app0()
	local begin = cur()
	print("-------------------JFIF-------------------")
	rbyte("L" ,         2)
	cstr ("identifier", 5, "4A 46 49 46 00")
	rbyte("version",    2)
	rbyte("units",      1)
	rbyte("Xdensity",   2)
	rbyte("Ydensity",   2)
	rbyte("Xthumbnail", 1)
	rbyte("Ythumbnail", 1)
	rbyte("(RGB)",      3 * get("Xthumbnail")*get("Ythumbnail"))

	seekoff(get("L") - (cur() - begin))
end

function app1()
	local begin = cur()
	rbyte("L",               2)
	rstr ("Identifier",      4)

	if get("Identifier") == "Exif" then
		print("-------------------Exif-------------------")
		rbyte("0000",                2)
		exif(get("L") - 8)
	elseif get("Identifier") == "http" then
		print("-------------------Http-------------------")
		rstr("http",             256)
		seek(get("L") + begin)
	end
end

function dqt()
print("Quantization table")
	local begin = cur()

	rbit("Lq", 16)
	
	repeat
		rbit("Pq", 4)
		rbit("Tq", 4)

		local precision = get("Pq") == 0 and 8 or 16
		local Q = {}
		for i=0, 63 do
			Q[i] = rbit("Qk", precision)
		end
		
		jpeg.q[get("Tq")] = Q
	until get("Lq") <= cur()-begin
end

function dri()
print("Define restert interbal ")
	local begin = cur()
	rbit("Lr", 16)
	rbit("Ri", 16) -- リスタートインターバル

	jpeg.restert_interval = get("Ri")  

	skip(get("Lr"), begin)
end

function dht()
print("Huffman table")

	local begin = cur()
	rbit("Lh", 16)

	repeat
		rbit("Tc", 4) -- このテーブルを使うのがDCかACか
		rbit("Th", 4) -- このテーブルのID

		local BITS = {}
		local V = {}
		for i=1, 16 do
			BITS[i] = rbit("Li",        8)
		end
		local k = 0
		for i=1, 16 do
			sprint("V["..i.."]")
			for j=1, BITS[i] do
				V[k] = rbit("Vij",      8)
				k = k + 1
			end
		end

		-- huffsize
		local k = 0
		local huffsize = {}
		for i=1, 16 do
			for j = 1, BITS[i] do
				huffsize[k] = i
				k = k + 1
			end
		end
		huffsize[k] = 0
		
		-- huffcode
		k = 0
		local code = 0
		local si = huffsize[0]
		local huffcode = {}
		while true do
			while huffsize[k] == si do
				huffcode[k] = code
				-- printf("%10s, %-16s %-32s", k, "val="..V[k], "huff=="..binstr(code, si))
				code = code + 1
				k = k + 1
			end

			if huffsize[k] == 0 then
				break
			end

			while huffsize[k] ~= si do
				code = code << 1 -- 11111 の状態から左シフト
				si = si + 1
			end
		end
		
		-- max min valptr
		local maxcode = {} -- 同じbit数のハフマンコードの最大値
		local mincode = {} -- 同じbit数のハフマンコードの最大値
		local valptr = {}  -- mincodeのindex
		local j = 0
		for i = 1, 16 do
			if BITS[i] == 0 then
				maxcode[i] = -1
			else
				valptr[i] = j
				mincode[i] = huffcode[j]
				j = j + BITS[i] - 1
				maxcode[i] = huffcode[j]
				j = j + 1
			end
		end
		
		jpeg.huffman[get("Th")] = jpeg.huffman[get("Th")] or {}
		jpeg.huffman[get("Th")][get("Tc")] = {}
		jpeg.huffman[get("Th")][get("Tc")].huffval  = V
		jpeg.huffman[get("Th")][get("Tc")].huffcode = huffcode
		jpeg.huffman[get("Th")][get("Tc")].mincode  = mincode
		jpeg.huffman[get("Th")][get("Tc")].maxcode  = maxcode
		jpeg.huffman[get("Th")][get("Tc")].valptr   = valptr

	until get("Lh") <= cur()-begin
end

function sof0()
print("Frame header")

	local begin = cur()
	rbit("Lf", 16)
	rbit("P",  8)
	rbit("Y",  16)
	rbit("X",  16)
	rbit("Nf", 8)
	
	printf("w=%d h=%d", get("X"), get("Y"))
	jpeg.width = get("X")
	jpeg.height = get("Y")
	jpeg.num_frame = get("Nf")

	for i=1, get("Nf") do
		local ci =
		rbit("Ci",  8) -- Component(Y, Cb, Cr or etc)
		rbit("Hi",  4) -- factor h
		rbit("Vi",  4) -- factor v
		rbit("Tqi", 8) -- table

		local ci = get("Ci")
		if     ci == 1 then printf("# Y  h=%d v=%d", get("Hi"), get("Vi"))
		elseif ci == 2 then printf("# Cb h=%d v=%d", get("Hi"), get("Vi"))
		elseif ci == 3 then printf("# Cr h=%d v=%d", get("Hi"), get("Vi"))
		elseif ci == 4 then printf("# I  h=%d v=%d", get("Hi"), get("Vi"))
		elseif ci == 5 then printf("# Q  h=%d v=%d", get("Hi"), get("Vi"))
		else assert(false, "unknown Ci") end

		jpeg.frame[i] = {}
		jpeg.frame[i].Qi = get("Tqi")
		jpeg.frame[i].Hi = get("Hi")
		jpeg.frame[i].Vi = get("Vi")
		jpeg.frame[i].Ci = get("Ci")
	end

	skip(get("Lf"), begin)
end

function sos()
print("Scan header")
	local begin = cur()
	
	rbit("Ls", 16)
	rbit("Ns", 8)

	for i=1, get("Ns") do
		rbit("Csj", 8) -- 成分ID
		rbit("Tdj", 4) -- ＤＣ成分ハフマンテーブル番号
		rbit("Taj", 4) -- ＡＣ成分ハフマンテーブル番号

		jpeg.scan[get("Csj")] = {}
		jpeg.scan[get("Csj")].dc_huffman = get("Tdj") 
		jpeg.scan[get("Csj")].ac_huffman = get("Taj") 
	end

	rbit("Ss", 8)
	rbit("Se", 8)
	rbit("Ah", 4)
	rbit("AL", 4)

	skip(get("Ls"), begin)
	
	--スキャンデコード開始
	start_scan()
end

function get_type(t)
	if     t == 1   then return 1, "byte"
	elseif t == 2   then return 1, "ascii"
	elseif t == 3   then return 2, "short"
	elseif t == 4   then return 4, "long"
	elseif t == 5   then return 8, "rational"
	elseif t == 7   then return 1, "undefined"
	elseif t == 9   then return 4, "slong"
	elseif t == 10  then return 8, "srational"
	end
end

-- Exif情報領域名取得
function get_tag(t)
	if     t == 0       then return "GPSVersionID"                ,"GPSタグのバージョン                   :"
	elseif t == 1       then return "GPSLatitudeRef"              ,"緯度の南北                            :"
	elseif t == 2       then return "GPSLatitude"                 ,"緯度（度、分、秒）                    :"
	elseif t == 3       then return "GPSLongitudeRef"             ,"経度の東西                            :"
	elseif t == 4       then return "GPSLongitude"                ,"経度（度、分、秒）                    :"
	elseif t == 5       then return "GPSAltitudeRef"              ,"高度の基準                            :"
	elseif t == 6       then return "GPSAltitude"                 ,"高度（m）                             :"
	elseif t == 7       then return "GPSTimeStamp"                ,"GPSの時間（原子時計）                 :"
	elseif t == 8       then return "GPSSatellites"               ,"測位に使用したGPS衛星                 :"
	elseif t == 9       then return "GPSStatus"                   ,"GPS受信機の状態                       :"
	elseif t == 10      then return "GPSMeasureMode"              ,"GPSの測位モード                       :"
	elseif t == 11      then return "GPSDOP"                      ,"測位の信頼性                          :"
	elseif t == 12      then return "GPSSpeedRef"                 ,"速度の単位                            :"
	elseif t == 13      then return "GPSSpeed"                    ,"速度                                  :"
	elseif t == 14      then return "GPSTrackRef"                 ,"進行方向の基準                        :"
	elseif t == 15      then return "GPSTrack"                    ,"進行方向（度）                        :"
	elseif t == 16      then return "GPSImgDirectionRef"          ,"撮影方向の基準                        :"
	elseif t == 17      then return "GPSImgDirection"             ,"撮影方向（度）                        :"
	elseif t == 18      then return "GPSMapDatum"                 ,"測位に用いた地図データ                :"
	elseif t == 19      then return "GPSDestLatitudeRef"          ,"目的地の緯度の南北                    :"
	elseif t == 20      then return "GPSDestLatitude"             ,"目的地の緯度（度、分、秒）            :"
	elseif t == 21      then return "GPSDestLongitudeRef"         ,"目的地の経度の東西                    :"
	elseif t == 22      then return "GPSDestLongitude"            ,"目的地の経度（度、分、秒）            :"
	elseif t == 23      then return "GPSBearingRef"               ,"目的地の方角の基準                    :"
	elseif t == 24      then return "GPSBearing"                  ,"目的地の方角（度）                    :"
	elseif t == 25      then return "GPSDestDistanceRef"          ,"目的地への距離の単位                  :"
	elseif t == 26      then return "GPSDestDistance"             ,"目的地への距離                        :"
	elseif t == 256     then return "ImageWidth"                  ,"画像の幅                              :"
	elseif t == 257     then return "ImageLength"                 ,"画像の高さ                            :"
	elseif t == 258     then return "BitsPerSample"               ,"画像のビットの深さ                    :"
	elseif t == 259     then return "Compression圧縮の種類"       ,"Compression scheme                    :"
	elseif t == 262     then return "PhotometricInterpretation"   ,"画像こう成                            :"
	elseif t == 270     then return "ImageDescription"            ,"画像タイトル                          :"
	elseif t == 271     then return "Make"                        ,"画像入力機器のメーカー名              :"
	elseif t == 272     then return "Model"                       ,"画像入力機器のモデル名                :"
	elseif t == 273     then return "StripOffsets"                ,"画像データのロケーション              :"
	elseif t == 274     then return "Orientation"                 ,"画像方向                              :"
	elseif t == 277     then return "SamplesPerPixel"             ,"コンポーネント数                      :"
	elseif t == 278     then return "RowsPerStrip"                ,"ストリップ中のライン数                :"
	elseif t == 279     then return "StripByteCounts"             ,"ストリップのデータ量                  :"
	elseif t == 282     then return "XResolution"                 ,"画像の幅の解像度                      :"
	elseif t == 283     then return "YResolution"                 ,"画像の高さの解像度                    :"
	elseif t == 284     then return "PlanarConfiguration"         ,"画像データの並び                      :"
	elseif t == 296     then return "ResolutionUnit"              ,"画像の幅と高さの解像度の単位          :"
	elseif t == 301     then return "TransferFunction"            ,"再生階調カーブ特性                    :"
	elseif t == 305     then return "CreatorTool"                 ,"使用Software名                        :"
	elseif t == 306     then return "ModifyDate"                  ,"ファイル変更日時                      :"
	elseif t == 315     then return "Artist"                      ,"作者名                                :"
	elseif t == 318     then return "WhitePoint"                  ,"参照白色点の色度座標値                :"
	elseif t == 319     then return "PrimaryChromaticities"       ,"原色の色度座標値                      :"
	elseif t == 513     then return "JPEGInterchangeFormat"       ,"JPEG の SOI へのオフセット            :"
	elseif t == 514     then return "JPEGInterchangeFormatLength" ,"JPEG データのバイト数                 :"
	elseif t == 529     then return "YCbCrCoefficients"           ,"色変換マトリクス係数                  :"
	elseif t == 530     then return "YCbCrSubSampling"            ,"YCC の画素こう成 (Cの間引き率)        :"
	elseif t == 531     then return "YCbCrPositioning"            ,"YCC の画素こう成 (Y と C の位置)      :"
	elseif t == 532     then return "ReferenceBlackWhite"         ,"参照黒色点値と参照白色点値            :"
	elseif t == 33432   then return "Copyright"                   ,"撮影著作権者/編集著作権者             :"
	elseif t == 33434   then return "ExposureTime"                ,"露出時間                              :"
	elseif t == 33437   then return "FNumber"                     ,"F値                                   :"
	elseif t == 34665   then return "ExifIFDPointer"              ,"Exif タグ                             :"
	elseif t == 34850   then return "ExposureProgram"             ,"露出プログラム                        :"
	elseif t == 34852   then return "SpectralSensitivity"         ,"スペクトル感度                        :"
	elseif t == 34853   then return "GPSInfoIFDPointer"           ,"GPS タグ                              :"
	elseif t == 34855   then return "ISOSpeedRatings"             ,"ISO スピードレート/撮影感度           :"
	elseif t == 34856   then return "OECF"                        ,"光電交換関数                          :"
	elseif t == 36864   then return "ExifVersion"                 ,"Exif バージョン                       :"
	elseif t == 36867   then return "DateTimeOriginal"            ,"原画像データの生成日時                :"
	elseif t == 36868   then return "MetadataDate"                ,"デジタルデータの生成日時              :"
	elseif t == 37121   then return "ComponentsConfiguration"     ,"各コンポーネントの意味                :"
	elseif t == 37122   then return "CompressedBitsPerPixel"      ,"画像圧縮モード                        :"
	elseif t == 37377   then return "ShutterSpeedValue"           ,"シャッタースピード                    :"
	elseif t == 37378   then return "ApertureValue"               ,"絞り値                                :"
	elseif t == 37379   then return "BrightnessValue"             ,"輝度値                                :"
	elseif t == 37380   then return "ExposureBiasValue"           ,"露出補正値                            :"
	elseif t == 37381   then return "MaxApertureValue"            ,"レンズ最小 F 値                       :"
	elseif t == 37382   then return "SubjectDistance"             ,"被写体距離                            :"
	elseif t == 37383   then return "MeteringMode"                ,"測光方式                              :"
	elseif t == 37384   then return "LightSource"                 ,"光源                                  :"
	elseif t == 37385   then return "Flash"                       ,"フラッシュ                            :"
	elseif t == 37386   then return "FocalLength"                 ,"レンズ焦点距離                        :"
	elseif t == 37396   then return "SubjectArea"                 ,"Subject area                          :"
	elseif t == 37500   then return "MakerNote"                   ,"メーカーノート                        :"
	elseif t == 37510   then return "UserComment"                 ,"ユーザーコメント                      :"
	elseif t == 37520   then return "SubSecTime"                  ,"Date Time のサブセック                :"
	elseif t == 37521   then return "SubSecTimeOriginal"          ,"Date Time Original のサブセック       :"
	elseif t == 37522   then return "SubSecTimeDegitized"         ,"Date Time Digitized のサブセック      :"
	elseif t == 40960   then return "FlashpixVersion"             ,"対応フラッシュピックスバージョン      :"
	elseif t == 40961   then return "ColorSpace"                  ,"色空間情報                            :"
	elseif t == 40962   then return "PixelXDimension"             ,"実効画像幅                            :"
	elseif t == 40963   then return "PixelYDimension"             ,"実効画像高さ                          :"
	elseif t == 40964   then return "RelatedSoundFile"            ,"関連音声ファイル                      :"
	elseif t == 40965   then return "InteroperabilityIFDPointer"  ,"互換性 IFD へのポインタ               :"
	elseif t == 41483   then return "FlashEnergy"                 ,"フラッシュ強度                        :"
	elseif t == 41484   then return "SpatialFrequencyResponse"    ,"空間周波数応答                        :"
	elseif t == 41486   then return "FocalPlaneXResolution"       ,"焦点面の幅の解像度                    :"
	elseif t == 41487   then return "FocalPlaneYResolution"       ,"焦点面の高さの解像度                  :"
	elseif t == 41488   then return "FocalPlaneResolutionUnit"    ,"焦点面解像度単位                      :"
	elseif t == 41492   then return "SubjectLocation"             ,"被写体位置                            :"
	elseif t == 41493   then return "ExposureIndex"               ,"露出インデックス                      :"
	elseif t == 41495   then return "SensingMethod"               ,"センサー方式                          :"
	elseif t == 41728   then return "FileSource"                  ,"FileSource                            :"
	elseif t == 41729   then return "SceneType"                   ,"シーンタイプ                          :"
	elseif t == 41730   then return "CFAPattern"                  ,"CFA パターン                          :"
	elseif t == 41985   then return "CustomRendered"              ,"カスタムイメージプロセッシング        :"
	elseif t == 41986   then return "ExposureMode"                ,"露出モード                            :"
	elseif t == 41987   then return "WhiteBalance"                ,"ホワイトバランス                      :"
	elseif t == 41988   then return "DigitalZoomRatio"            ,"デジタルズーム比率                    :"
	elseif t == 41989   then return "FocalLengthIn35mmFilm"       ,"35mm 換算焦点距離                     :"
	elseif t == 41990   then return "SceneCaptureType"            ,"シーン撮影タイプ                      :"
	elseif t == 41991   then return "GainControl"                 ,"ゲインコントロール                    :"
	elseif t == 41992   then return "Contrast"                    ,"コントラスト                          :"
	elseif t == 41993   then return "Saturation"                  ,"彩度                                  :"
	elseif t == 41994   then return "Sharpness"                   ,"シャープネス                          :"
	elseif t == 41995   then return "DeviceSettingDescription"    ,"デバイス設定                          :"
	elseif t == 41996   then return "SubjectDistanceRange"        ,"被写体距離範囲                        :"
	elseif t == 42016   then return "0xa420"                      ,"ユニーク画像 ID                       :"
	elseif t == 42240   then return "0xa500"                      ,"ガンマ値                              :"
	elseif t == 50706   then return "DNGVersion"                  ,"DNG バージョン                        :"
	elseif t == 50707   then return "DNGBackwardVersion"          ,"DNG backward version                  :"
	elseif t == 50708   then return "DNGUniqueCameraModel"        ,"カメラ機種名                          :"
	elseif t == 50709   then return "DNGLocalizedCameraModel"     ,"カメラ機種名                          :"
	elseif t == 50710   then return "DNGCFAPlaneColor"            ,"CFA plane color                       :"
	elseif t == 50711   then return "DNGCFALayout"                ,"CFA レイアウト                        :"
	elseif t == 50712   then return "DNGLinearizationTable"       ,"Linearization table                   :"
	elseif t == 50713   then return "DNGBlackLevelRepeatDim"      ,"Black level repeat dim                :"
	elseif t == 50714   then return "DNGBlackLevel"               ,"Black level                           :"
	elseif t == 50715   then return "DNGBlackLevelDeltaH"         ,"Black level delta H                   :"
	elseif t == 50716   then return "DNGBlackLevelDeltaV"         ,"Black level delta V                   :"
	elseif t == 50717   then return "DNGWhiteLevel"               ,"White level                           :"
	elseif t == 50718   then return "DNGDefaultscale"             ,"Default scale                         :"
	elseif t == 50719   then return "DNGDefaultCropOrigin"        ,"Default crop origin                   :"
	elseif t == 50720   then return "DNGDefaultCropSize"          ,"Default crop size                     :"
	elseif t == 50721   then return "DNGColorMatrix1"             ,"Color matrix1                         :"
	elseif t == 50722   then return "DNGColorMatrix2"             ,"Color matrix2                         :"
	elseif t == 50723   then return "DNGCameraCalibration1"       ,"Camera calibration1                   :"
	elseif t == 50724   then return "DNGCameraCalibration2"       ,"Camera calibration2                   :"
	elseif t == 50725   then return "DNGReductionMatrix1"         ,"Reduction matrix1                     :"
	elseif t == 50726   then return "DNGReductionMatrix2"         ,"Reduction matrix2                     :"
	elseif t == 50727   then return "DNGAnalogBalance"            ,"Analog balance                        :"
	elseif t == 50728   then return "DNGAsShotNeutral"            ,"As shot neutral                       :"
	elseif t == 50729   then return "DNGAsShotWhiteXY"            ,"As shot white XY                      :"
	elseif t == 50730   then return "DNGBaselineExposure"         ,"Baseline exposure                     :"
	elseif t == 50731   then return "DNGBaselineNoise"            ,"Baseline noise                        :"
	elseif t == 50732   then return "DNGBaselineSharpness"        ,"Baseline sharpness                    :"
	elseif t == 50733   then return "DNGBayerGreenSplit"          ,"Bayer green split                     :"
	elseif t == 50734   then return "DNGLinearResponseLimit"      ,"Linear response limit                 :"
	elseif t == 50735   then return "DNGCameraSerialNumber"       ,"シリアルナンバー                      :"
	elseif t == 50736   then return "DNGLensInfo"                 ,"レンズ情報                            :"
	elseif t == 50737   then return "DNGChromaBlurRadius"         ,"Chroma blur radius                    :"
	elseif t == 50738   then return "DNGAntiAliasStrength"        ,"Anti-alias strength                   :"
	elseif t == 50739   then return "DNGShadowScale"              ,"Shadow scale                          :"
	elseif t == 50740   then return "DNGPrivateData"              ,"プライベートデータ                    :"
	elseif t == 50741   then return "DNGMakerNoteSafety"          ,"MakerNote safety                      :"
	elseif t == 50778   then return "DNGCalibrationIlluminant1"   ,"Calibration illuminant1               :"
	elseif t == 50779   then return "DNGCalibrationIlluminant2"   ,"Calibration illuminant2               :"
	elseif t == 50780   then return "DNGBestQualityScale"         ,"Best quality scale                    :"
	elseif t == 50781   then return "DNGRawDataUniqueID"          ,"Raw data unique ID                    :"
	elseif t == 50827   then return "DNGOriginalRawFileName"      ,"オリジナル RAW ファイル名             :"
	elseif t == 50828   then return "DNGOriginalRawFileData"      ,"オリジナル RAW ファイルデータ         :"
	elseif t == 50829   then return "DNGActiveArea"               ,"Active area                           :"
	elseif t == 50830   then return "DNGMaskedArea"               ,"Masked area                           :"
	elseif t == 50831   then return "DNGAsShotICCProfile"         ,"As shot ICC profile                   :"
	elseif t == 50832   then return "DNGAsShotPreProfileMatrix"   ,"As shot pre-profile matrix            :"
	elseif t == 50833   then return "DNGCurrentICCProfile"        ,"Current ICC profile                   :"
	elseif t == 50834   then return "DNGCurrentPreProfileMatrix"  ,"Current pre-profile matrix            :"
	elseif t == 1000000 then return "GPSVersionID"                ,"GPS タグのバージョン                  :"
	elseif t == 1000001 then return "GPSLatitudeRef"              ,"北緯(N) or 南緯(S)                    :"
	elseif t == 1000002 then return "GPSLatitude"                 ,"緯度 (数値)                           :"
	elseif t == 1000003 then return "GPSLongitudeRef"             ,"東経(E) or 西経(W)                    :"
	elseif t == 1000004 then return "GPSLongitude"                ,"経度 (数値)                           :"
	elseif t == 1000005 then return "GPSAltitudeRef"              ,"高度の単位                            :"
	elseif t == 1000006 then return "GPSAltitude"                 ,"高度 (数値)                           :"
	elseif t == 1000007 then return "GPSTimeStamp"                ,"GPS 時間 (原子時計の時間)             :"
	elseif t == 1000008 then return "GPSSatellites"               ,"測位に使った衛星信号                  :"
	elseif t == 1000009 then return "GPSStatus"                   ,"GPS 受信機の状態                      :"
	elseif t == 1000010 then return "GPSMessureMode"              ,"GPS 測位方法                          :"
	elseif t == 1000011 then return "GPSDOP"                      ,"測位の信頼性                          :"
	elseif t == 1000012 then return "GPSSpeedRef"                 ,"速度の単位                            :"
	elseif t == 1000013 then return "GPSSpeed"                    ,"速度 (数値)                           :"
	elseif t == 1000014 then return "GPSTrackRef"                 ,"進行方向の単位                        :"
	elseif t == 1000015 then return "GPSTrack"                    ,"進行方向 (数値)                       :"
	elseif t == 1000016 then return "GPSImgDirectionRef"          ,"撮影した画像の方向の単位              :"
	elseif t == 1000017 then return "GPSImgDirection"             ,"撮影した画像の方向 (数値)             :"
	elseif t == 1000018 then return "GPSMapDatum"                 ,"測位用いた地図データ                  :"
	elseif t == 1000019 then return "GPSDestLatitudeRef"          ,"目的地の北緯(N) or 南緯(S)            :"
	elseif t == 1000020 then return "GPSDestLatitude"             ,"目的地の緯度 (数値)                   :"
	elseif t == 1000021 then return "GPSDestLongitudeRef"         ,"目的地の東経(E) or 西経(W)            :"
	elseif t == 1000022 then return "GPSDestLongitude"            ,"目的地の経度 (数値)                   :"
	elseif t == 1000023 then return "GPSDestBearingRef"           ,"目的地の方角の単位                    :"
	elseif t == 1000024 then return "GPSDestBearing"              ,"目的地の方角 (数値)                   :"
	elseif t == 1000025 then return "GPSDestDistanceRef"          ,"目的地までの距離の単位                :"
	elseif t == 1000026 then return "GPSDestDistance"             ,"目的地までの距離 (数値)               :"
	elseif t == 1000027 then return "GPSProcessingMethod"         ,"Name of GPS processing method         :"
	elseif t == 1000028 then return "GPSAreaInformation"          ,"Name of GPS area                      :"
	elseif t == 1000029 then return "GPSDateStamp"                ,"GPS date                              :"
	elseif t == 1000030 then return "GPSDifferential"             ,"GPS differential correction           :"
	elseif t == 2000000 then return "InteroperabilityIndex"       ,"互換性識別子                          :"
	elseif t == 3000001 then return "CRSRawFileName"              ,"Raw ファイル名                        :"
	elseif t == 3000002 then return "CRSVersion"                  ,"バージョン                            :"
	elseif t == 3000003 then return "CRSWhiteBalance"             ,"ホワイトバランス                      :"
	elseif t == 3000004 then return "CRSTemperature"              ,"色温度                                :"
	elseif t == 3000005 then return "CRSTint"                     ,"色合い                                :"
	elseif t == 3000006 then return "CRSShadowTint"               ,"ShadowTint                            :"
	elseif t == 3000007 then return "CRSExposure"                 ,"露光量                                :"
	elseif t == 3000008 then return "CRSShadows"                  ,"シャドウ                              :"
	elseif t == 3000009 then return "CRSBrightness"               ,"明るさ                                :"
	elseif t == 3000010 then return "CRSContrast"                 ,"コントラスト                          :"
	elseif t == 3000011 then return "CRSSaturation"               ,"彩度                                  :"
	elseif t == 3000012 then return "CRSRedSaturation"            ,"彩度(赤)                              :"
	elseif t == 3000013 then return "CRSGreenSaturation"          ,"彩度(緑)                              :"
	elseif t == 3000014 then return "CRSBlueSaturation"           ,"彩度(青)                              :"
	elseif t == 3000015 then return "CRSSharpness"                ,"シャープ                              :"
	elseif t == 3000016 then return "CRSLuminanceSmoothing"       ,"LuminanceSmoothing                    :"
	elseif t == 3000017 then return "CRSRedHue"                   ,"RedHue                                :"
	elseif t == 3000018 then return "CRSGreenHue"                 ,"GreenHue                              :"
	elseif t == 3000019 then return "CRSBlueHue"                  ,"BlueHue                               :"
	elseif t == 3000020 then return "CRSColorNoiseReduction"      ,"ColorNoiseReduction                   :"
	elseif t == 3000021 then return "CRSChromaticAberration"      ,"RChromaticAberration                  :"
	elseif t == 3000022 then return "CRSChromaticAberration"      ,"BChromaticAberration                  :"
	elseif t == 3000023 then return "CRSVignette"                 ,"AmountVignette                        :"
	elseif t == 3000024 then return "CRSLens"                     ,"レンズ                                :"
	elseif t == 3000025 then return "CRSSerialNumber"             ,"シリアルナンバー                      :"
	elseif t == 3000026 then return "CRSAutoBrightness"           ,"明るさ自動設定                        :"
	elseif t == 3000027 then return "CRSAutoShadows"              ,"シャドウ自動設定                      :"
	elseif t == 3000028 then return "CRSAutoContrast"             ,"コントラスト自動設定                  :"
	elseif t == 3000029 then return "CRSAutoExposure"             ,"露光量自動設定                        :"
	elseif t == 3100512 then return "OLSpecialMode"               ,"撮影モード                            :"
	elseif t == 3100513 then return "OLJpegQuality"               ,"撮影品質                              :"
	elseif t == 3100514 then return "OLMacro"                     ,"マクロ                                :"
	elseif t == 3100516 then return "OLDigitalZoom"               ,"デジタルズーム                        :"
	elseif t == 3100519 then return "OLSoftwareRelease"           ,"ファームウェア                        :"
	elseif t == 3100520 then return "OLpictInfo"                  ,"画像情報                              :"
	elseif t == 3100521 then return "OLCameraID"                  ,"カメラ ID                             :"
	elseif t == 3103840 then return "OLDataDump.unknown"          ,"Data dump                             :"
	elseif t == 3104100 then return "OLFlashMode"                 ,"フラッシュモード                      :"
	elseif t == 3104102 then return "OLExposureBias"              ,"露出補正値                            :"
	elseif t == 3104107 then return "OLFocusMode"                 ,"フォーカスモード                      :"
	elseif t == 3104108 then return "OLFocusDistance"             ,"焦点距離                              :"
	elseif t == 3104109 then return "OLZoom"                      ,"ズーム                                :"
	elseif t == 3104110 then return "OLMacroFocus"                ,"マクロ                                :"
	elseif t == 3104111 then return "OLSharpness"                 ,"シャープネス                          :"
	elseif t == 3104113 then return "OLColourMatrix"              ,"カラーマトリックス                    :"
	elseif t == 3104114 then return "OLBlackLevel"                ,"黒レベル                              :"
	elseif t == 3104117 then return "OLWhiteBalance"              ,"ホワイトバランス                      :"
	elseif t == 3104119 then return "OLRedBias"                   ,"バイアス(赤)                          :"
	elseif t == 3104120 then return "OLBlueBias"                  ,"バイアス(青)                          :"
	elseif t == 3104122 then return "OLSerialNumber"              ,"シリアルナンバー                      :"
	elseif t == 3104131 then return "OLFlashBias"                 ,"フラッシュバイアス                    :"
	elseif t == 3104137 then return "OLContrast"                  ,"コントラスト                          :"
	elseif t == 3104138 then return "OLSharpnessFactor"           ,"Sharpness Factor                      :"
	elseif t == 3104139 then return "OLColourControl"             ,"カラーコントロール                    :"
	elseif t == 3104140 then return "OLValidBits"                 ,"有効ビット                            :"
	elseif t == 3104141 then return "OLCoringFilter"              ,"Coring Filter                         :"
	elseif t == 3104142 then return "OLImageWidth"                ,"画像の幅                              :"
	elseif t == 3104143 then return "OLImageHeight"               ,"画像の高さ                            :"
	elseif t == 3104148 then return "OLCompressionRatio"          ,"圧縮比                                :"
	elseif t == 3200018 then return "PXExposureTime"              ,"露出時間                              :"
	elseif t == 3200019 then return "PXFNumber"                   ,"F値                                   :"
	elseif t == 3200020 then return "PXISOSpeed"                  ,"ISO 値                                :"
	elseif t == 3200022 then return "PXExposureBias"              ,"露出補正値E                           :"
	elseif t == 3200025 then return "PXWhiteBalance"              ,"ホワイトバランス                      :"
	elseif t == 3200063 then return "PXLensID"                    ,"レンズ情報                            :"
	elseif t == 3200079 then return "PXImageTone"                 ,"画像仕上げ                            :"
	elseif t == 3300002 then return "EXThumbInfo"                 ,"サムネイルの大きさ                    :"
	elseif t == 3300003 then return "EXThumbSize"                 ,"サムネイルのサイズ                    :"
	elseif t == 3300004 then return "EXThumbOffset"               ,"サムネイルへのオフセット              :"
	elseif t == 3300008 then return "EXQualityMode"               ,"撮影品質                              :"
	elseif t == 3300009 then return "EXImageSize"                 ,"画像サイズ                            :"
	elseif t == 3300020 then return "EXISOSensitivity"            ,"ISO 感度                              :"
	elseif t == 3300025 then return "EXWhiteBalance"              ,"ホワイトバランス                      :"
	elseif t == 3300029 then return "EXFocalLength"               ,"焦点距離                              :"
	elseif t == 3300031 then return "EXSaturation"                ,"彩度                                  :"
	elseif t == 3300032 then return "EXContrast"                  ,"コントラスト                          :"
	elseif t == 3300033 then return "EXSharpness"                 ,"シャープネス                          :"
	elseif t == 3303584 then return "EXPIM"                       ,"unknown                               :"
	elseif t == 3308192 then return "EXThumbnail"                 ,"unknown                               :"
	elseif t == 3308209 then return "EXWBBias"                    ,"ホワイトバランスバイアス              :"
	elseif t == 3308210 then return "EXFlash"                     ,"unknown                               :"
	elseif t == 3308226 then return "EXObjectDistance"            ,"対象物の距離                          :"
	elseif t == 3308244 then return "EXFlashDistance"             ,"フラッシュの距離                      :"
	elseif t == 3312288 then return "EXRecordMode"                ,"unknown                               :"
	elseif t == 3312289 then return "EXSelfTimer"                 ,"unknown                               :"
	elseif t == 3312290 then return "EXQuality"                   ,"品質                                  :"
	elseif t == 3312291 then return "EXFocusMode"                 ,"フォーカスモード                      :"
	elseif t == 3312294 then return "EXTimeZone"                  ,"タイムゾーン                          :"
	elseif t == 3312295 then return "EXBestshotMode"              ,"unknown                               :"
	elseif t == 3312308 then return "EXCCDSensitivity"            ,"CCD感度                               :"
	elseif t == 3312309 then return "EXColorMode"                 ,"カラーモード                          :"
	elseif t == 3312310 then return "EXColorEnhance"              ,"色強調                                :"
	elseif t == 3312311 then return "EXFilter"                    ,"フィルター                            :"
	elseif t == 3400001 then return "PXOCaptureMode"              ,"撮影モード                            :"
	elseif t == 3400002 then return "PXOQualityLevel"             ,"撮影品質                              :"
	elseif t == 3400003 then return "PXOFocusMode"                ,"フォーカスモード                      :"
	elseif t == 3400004 then return "PXOFlashMode"                ,"フラッシュ                            :"
	elseif t == 3400007 then return "PXOWhiteBalance"             ,"ホワイトバランス                      :"
	elseif t == 3400010 then return "PXODigitalZoom"              ,"デジタルズーム                        :"
	elseif t == 3400011 then return "PXOSharpness"                ,"シャープネス                          :"
	elseif t == 3400012 then return "PXOContrast"                 ,"コントラスト                          :"
	elseif t == 3400013 then return "PXOSaturation"               ,"彩度                                  :"
	elseif t == 3400020 then return "PXOISOSpeed"                 ,"ISO 感度                              :"
	elseif t == 3400023 then return "PXOColorMode"                ,"カラー                                :"
	elseif t == 3404096 then return "PXOTimeZone"                 ,"タイムゾーン                          :"
	elseif t == 3404097 then return "PXODaylightSavings"          ,"Daylight savings                      :"
	elseif t == 3500002 then return "NKISOSetting"                ,"ISO 感度                              :"
	elseif t == 3500003 then return "NKColorMode"                 ,"カラーモード                          :"
	elseif t == 3500004 then return "NKQuality"                   ,"撮影品質                              :"
	elseif t == 3500005 then return "NKWhitebalance"              ,"ホワイトバランス                      :"
	elseif t == 3500006 then return "NKSharpness"                 ,"シャープネス                          :"
	elseif t == 3500007 then return "NKFocusMode"                 ,"フォーカスモード                      :"
	elseif t == 3500008 then return "NKFlashSetting"              ,"シンクロモード                        :"
	elseif t == 3500009 then return "NKFlashMode"                 ,"フラッシュモード                      :"
	elseif t == 3500011 then return "NKWhiteBalanceOffset"        ,"ホワイトバランス補正量                :"
	elseif t == 3500015 then return "NKISOselection"              ,"ISO 感度の選択                        :"
	elseif t == 3500017 then return "NKThumbnailIFDOffset"        ,"unknown                               :"
	elseif t == 3500128 then return "NKImageAdjustment"           ,"画像モード                            :"
	elseif t == 3500129 then return "NKContrastSetting"           ,"階調補正                              :"
	elseif t == 3500130 then return "NKAdapter"                   ,"アダプター                            :"
	elseif t == 3500131 then return "NKLensSetting"               ,"unknown                               :"
	elseif t == 3500132 then return "NKLensInfo"                  ,"レンズ情報                            :"
	elseif t == 3500133 then return "NKManualFocusDistance"       ,"マニュアルフォーカス距離              :"
	elseif t == 3500134 then return "NKDigitalZoom"               ,"デジタルズーム比率                    :"
	elseif t == 3500136 then return "NKAFFocusPoint"              ,"フォーカスエリア                      :"
	elseif t == 3500137 then return "NKShutterMode"               ,"動作モード                            :"
	elseif t == 3500141 then return "NKColorSpace"                ,"色空間情報                            :"
	elseif t == 3500146 then return "NKColorOffset"               ,"色相補正値                            :"
	elseif t == 3500149 then return "NKNoiseReduction"            ,"ノイズリダクション                    :"
	elseif t == 3500152 then return "NKLendID"                    ,"レンズ ID                             :"
	elseif t == 3500167 then return "NKShotCount"                 ,"撮影回数                              :"
	elseif t == 3500169 then return "NKFinishSetting"             ,"仕上がり設定                          :"
	elseif t == 3500171 then return "NKDigitalImgProg"            ,"デジタルイメージプログラム            :"
	elseif t == 3600003 then return "NKEQuality"                  ,"撮影モード                            :"
	elseif t == 3600004 then return "NKEColorMode"                ,"カラーモード                          :"
	elseif t == 3600005 then return "NKEImageAdjustment"          ,"撮影設定                              :"
	elseif t == 3600006 then return "NKECCDSensitivity"           ,"CCD 感度                              :"
	elseif t == 3600007 then return "NKEWhiteBalance"             ,"ホワイトバランス                      :"
	elseif t == 3600008 then return "NKEFocus"                    ,"unknown                               :"
	elseif t == 3600010 then return "NKEDigitalZoom"              ,"デジタルズーム比率                    :"
	elseif t == 3600011 then return "NKEConverter"                ,"コンバータ                            :"
	elseif t == 3700000 then return "MLTMakerNoteVersion"         ,"バージョン                            :"
	elseif t == 3700001 then return "MLTCameraSettingsOld"        ,"unknown                               :"
	elseif t == 3700003 then return "MLTExposureMode"             ,"露出モード                            :"
	elseif t == 3700003 then return "MLTFlashMode"                ,"フラッシュ                            :"
	elseif t == 3700003 then return "MLTWhiteBalance"             ,"ホワイトバランス                      :"
	elseif t == 3700003 then return "MLTImageSize"                ,"画像サイズ                            :"
	elseif t == 3700003 then return "MLTImageQuality"             ,"画像品質                              :"
	elseif t == 3700003 then return "MLTDriveMode"                ,"ドライブモード                        :"
	elseif t == 3700003 then return "MLTMeteringMode"             ,"測光方式                              :"
	elseif t == 3700003 then return "MLTFilmSpeed"                ,"ISO スピードレード                    :"
	elseif t == 3700003 then return "MLTShutterSpeed"             ,"シャッター速度                        :"
	elseif t == 3700003 then return "MLTAperture"                 ,"Aperture                              :"
	elseif t == 3700003 then return "MLTMacroMode"                ,"マクロモード                          :"
	elseif t == 3700003 then return "MLTDigitalZoom"              ,"デジタルズーム                        :"
	elseif t == 3700003 then return "MLTExposureCompensation"     ,"露出補正                              :"
	elseif t == 3700003 then return "MLTBracketStep"              ,"Bracket step                          :"
	elseif t == 3700003 then return "MLTunknown16"                ,"unknown                               :"
	elseif t == 3700003 then return "MLTIntervalLength"           ,"時間間隔 (分)                         :"
	elseif t == 3700003 then return "MLTIntervalNumber"           ,"間隔数                                :"
	elseif t == 3700003 then return "MLTFocalLength"              ,"焦点距離 (35mm 換算)                  :"
	elseif t == 3700003 then return "MLTFocusDistance"            ,"Focus distance                        :"
	elseif t == 3700003 then return "MLTFlashFired"               ,"フラッシュ                            :"
	elseif t == 3700003 then return "MLTDate"                     ,"日                                    :"
	elseif t == 3700003 then return "MLTTime"                     ,"時                                    :"
	elseif t == 3700003 then return "MLTMaxAperture"              ,"Max Aperture                          :"
	elseif t == 3700003 then return "MLTFileNumberMemory"         ,"File number memory                    :"
	elseif t == 3700003 then return "MLTLastFileNumber"           ,"Last file number                      :"
	elseif t == 3700003 then return "MLTWhiteBalanceRed"          ,"ホワイトバランス(赤)                  :"
	elseif t == 3700003 then return "MLTWhiteBalanceGreen"        ,"ホワイトバランス(緑)                  :"
	elseif t == 3700003 then return "MLTWhiteBalanceBlue"         ,"ホワイトバランス(青)                  :"
	elseif t == 3700003 then return "MLTSaturation"               ,"彩度                                  :"
	elseif t == 3700003 then return "MLTContrast"                 ,"コントラスト                          :"
	elseif t == 3700003 then return "MLTSharpness"                ,"シャープネス                          :"
	elseif t == 3700003 then return "MLTSubjectProgram"           ,"露出プログラム                        :"
	elseif t == 3700003 then return "MLTFlashCompensation"        ,"フラッシュ補正                        :"
	elseif t == 3700003 then return "MLTISOSetting"               ,"ISO 値                                :"
	elseif t == 3700003 then return "MLTCameraModel"              ,"モデル                                :"
	elseif t == 3700003 then return "MLTIntervalMode"             ,"Interval mode                         :"
	elseif t == 3700003 then return "MLTFolderName"               ,"Folder name                           :"
	elseif t == 3700003 then return "MLTColorMode"                ,"カラーモード                          :"
	elseif t == 3700003 then return "MLTColorFilter"              ,"カラーフィルター                      :"
	elseif t == 3700003 then return "MLTBWFilter"                 ,"白黒フィルター                        :"
	elseif t == 3700003 then return "MLTInternalFlash"            ,"内蔵フラッシュ                        :"
	elseif t == 3700003 then return "MLTBrightnessValue"          ,"輝度値                                :"
	elseif t == 3700003 then return "MLTSpotFocusPointX"          ,"焦点位置(X)                           :"
	elseif t == 3700003 then return "MLTSpotFocusPointY"          ,"焦点位置(Y)                           :"
	elseif t == 3700003 then return "MLTWideFocusZone"            ,"Wide focus zone                       :"
	elseif t == 3700003 then return "MLTFocusMode"                ,"フォーカスモード                      :"
	elseif t == 3700003 then return "MLTFocusArea"                ,"フォーカス範囲                        :"
	elseif t == 3700003 then return "MLTDECPosition"              ,"DEC position                          :"
	elseif t == 3700064 then return "MLTComppressImageSize"       ,"画像サイズ                            :"
	elseif t == 3700129 then return "MLTThumbnail"                ,"unknown                               :"
	elseif t == 3700136 then return "MLTThumbnailOffset"          ,"unknown                               :"
	elseif t == 3700137 then return "MLTThumbnailLength"          ,"サムネイルのサイズ                    :"
	elseif t == 3700268 then return "MLTLensID"                   ,"レンズ情報                            :"
	elseif t == 3703584 then return "MLTPIMInformation"           ,"Print IM 情報                         :"
	elseif t == 3703840 then return "MLTCameraSettings"           ,"unknown                               :"
	elseif t == 3800002 then return "SGSerialID"                  ,"シリアルナンバー                      :"
	elseif t == 3800003 then return "SGDriveMode"                 ,"ドライブモード                        :"
	elseif t == 3800004 then return "SGImageSize"                 ,"記録画素数                            :"
	elseif t == 3800005 then return "SGAFMode"                    ,"AF モード                             :"
	elseif t == 3800006 then return "SGFocusMode"                 ,"フォーカスモード                      :"
	elseif t == 3800007 then return "SGWhiteBalance"              ,"ホワイトバランス                      :"
	elseif t == 3800008 then return "SGExposureMode"              ,"露出モード                            :"
	elseif t == 3800009 then return "SGMeteringMode"              ,"測光モード                            :"
	elseif t == 3800010 then return "SGFocalLength"               ,"焦点距離                              :"
	elseif t == 3800011 then return "SGColorSpace"                ,"色空間                                :"
	elseif t == 3800012 then return "SGExposure"                  ,"露出補正                              :"
	elseif t == 3800013 then return "SGContrast"                  ,"コントラスト                          :"
	elseif t == 3800014 then return "SGShadow"                    ,"シャドウ                              :"
	elseif t == 3800015 then return "SGHighlight"                 ,"ハイライト                            :"
	elseif t == 3800016 then return "SGSaturation"                ,"彩度補正                              :"
	elseif t == 3800017 then return "SGSharpness"                 ,"シャープネス補正                      :"
	elseif t == 3800018 then return "SGX3FillLight"               ,"X3 Fill Light                         :"
	elseif t == 3800020 then return "SGColorCoordination"         ,"カラー調整                            :"
	elseif t == 3800021 then return "SGCustomSettingMode"         ,"調整設定                              :"
	elseif t == 3800022 then return "SGJpegQuality"               ,"JPEG 品質                             :"
	elseif t == 3800023 then return "SGFirmware"                  ,"ファームウェア                        :"
	elseif t == 3800024 then return "SGSoftware"                  ,"Software                              :"
	elseif t == 3800025 then return "SGAutoBlacket"               ,"オートブラケット                      :"
	elseif t == 4000001 then return "CNMacroMode"                 ,"撮影モード                            :"
	elseif t == 4000001 then return "CNSelfTimer"                 ,"セルフタイマー                        :"
	elseif t == 4000001 then return "CNFlash"                     ,"フラッシュ                            :"
	elseif t == 4000001 then return "CNDriveMode"                 ,"ドライブモード                        :"
	elseif t == 4000001 then return "CNFocusMode"                 ,"フォーカスモード                      :"
	elseif t == 4000001 then return "CNImageSize"                 ,"画像サイズ                            :"
	elseif t == 4000001 then return "CNImageSelect"               ,"イメージセレクト                      :"
	elseif t == 4000001 then return "CNDigitalZoom"               ,"デジタルズーム                        :"
	elseif t == 4000001 then return "CNContrast"                  ,"コントラスト                          :"
	elseif t == 4000001 then return "CNSaturation"                ,"彩度                                  :"
	elseif t == 4000001 then return "CNSharpness"                 ,"シャープネス                          :"
	elseif t == 4000001 then return "CNISOSensitive"              ,"ISO 感度                              :"
	elseif t == 4000001 then return "CNMeteringMode"              ,"測光方式                              :"
	elseif t == 4000001 then return "CNFocusType"                 ,"フォーカスタイプ                      :"
	elseif t == 4000001 then return "CNAFPoint"                   ,"unknown                               :"
	elseif t == 4000001 then return "CNExposurePorgram"           ,"露出プログラム                        :"
	elseif t == 4000001 then return "CNLensID"                    ,"レンズ情報                            :"
	elseif t == 4000001 then return "CNLensMaximum"               ,"最大焦点距離                          :"
	elseif t == 4000001 then return "CNLensMinimum"               ,"最小焦点距離                          :"
	elseif t == 4000001 then return "CNLensUnit"                  ,"焦点距離単位(mm)                      :"
	elseif t == 4000001 then return "CNFlashDetailed"             ,"unknown                               :"
	elseif t == 4000001 then return "CNFocusSetting"              ,"フォーカス設定                        :"
	elseif t == 4000001 then return "CNImageStabilization"        ,"手ぶれ補正                            :"
	elseif t == 4000001 then return "CNImageEffect"               ,"色効果                                :"
	elseif t == 4000001 then return "CNHueBias"                   ,"色合い補正値                          :"
	elseif t == 4000004 then return "CNWhitebalance"              ,"ホワイトバランス                      :"
	elseif t == 4000004 then return "CNImageNumber"               ,"unknown                               :"
	elseif t == 4000004 then return "CNAFPointUsed"               ,"unknown                               :"
	elseif t == 4000004 then return "CNFlashBias"                 ,"フラッシュ補正強度                    :"
	elseif t == 4000004 then return "CNAperture"                  ,"絞り                                  :"
	elseif t == 4000004 then return "CNExposure"                  ,"露出時間                              :"
	elseif t == 4000004 then return "CNNDFilter"                  ,"ND フィルター                         :"
	elseif t == 4000006 then return "CNImageType"                 ,"イメージの種類                        :"
	elseif t == 4000007 then return "CNFirmware"                  ,"ファームウェア                        :"
	elseif t == 4000009 then return "CNUser"                      ,"所有者名                              :"
	elseif t == 4000012 then return "CNSerial"                    ,"シリアルナンバー                      :"
	elseif t == 4000015 then return "CNNoiseReduction"            ,"ノイズリダクション                    :"
	elseif t == 4000015 then return "CNButtunFunction"            ,"シャッター/AEロックボタン             :"
	elseif t == 4000015 then return "CNMirrorLockUp"              ,"ミラーロックアップ                    :"
	elseif t == 4000015 then return "CNShutterStep"               ,"シャッター/絞りの露出設定             :"
	elseif t == 4000015 then return "CNAFSupliment"               ,"AF 補助光                             :"
	elseif t == 4000015 then return "CNApexPriority"              ,"絞り優先モード時のシャッター速度      :"
	elseif t == 4000015 then return "CNAEFunction"                ,"AEブラケット順序とキャンセル機のう    :"
	elseif t == 4000015 then return "CNShutterSynchro"            ,"シャッター幕シンクロ                  :"
	elseif t == 4000015 then return "CNAFStopButton"              ,"レンズ AF ストップボタン              :"
	elseif t == 4000015 then return "CNFlashMemLimit"             ,"自動フラッシュ充電量制限              :"
	elseif t == 4000015 then return "CNMenuPosition"              ,"メニューボタン復帰位置                :"
	elseif t == 4000015 then return "CNSETFunction"               ,"SET ボタン機のう                      :"
	elseif t == 4000015 then return "CNSensorCleaning"            ,"センサークリーニング                  :"
	elseif t == 4000160 then return "CNColorTemp"                 ,"色温度                                :"
	elseif t == 4000180 then return "CNColorSpace"                ,"色空間                                :"
	elseif t == 4600000 then return "FJVersion"                   ,"unknown                               :"
	elseif t == 4604096 then return "FJQuality"                   ,"画像品質                              :"
	elseif t == 4604097 then return "FJSharpness"                 ,"シャープネス                          :"
	elseif t == 4604098 then return "FJWhiteBalance"              ,"ホワイトバランス                      :"
	elseif t == 4604099 then return "FJColor"                     ,"色の濃さ                              :"
	elseif t == 4604112 then return "FJFlashMode"                 ,"フラッシュ                            :"
	elseif t == 4604113 then return "FJFlashStrength"             ,"フラッシュ補正                        :"
	elseif t == 4604128 then return "FJMacro"                     ,"マクロ                                :"
	elseif t == 4604129 then return "FJFocusMode"                 ,"フォーカスモード                      :"
	elseif t == 4604144 then return "FJSlowSync"                  ,"スローシンクロ                        :"
	elseif t == 4604145 then return "FJPictureMode"               ,"撮影モード                            :"
	elseif t == 4604352 then return "FJContBlacket"               ,"連写/自動ブラケット                   :"
	elseif t == 4604864 then return "FJBlurWarning"               ,"手ぶれ警告                            :"
	elseif t == 4604865 then return "FJFocusWarning"              ,"オートフォーカスの状態                :"
	elseif t == 4604866 then return "FJAEWarning"                 ,"自動露出の状態                        :"
	elseif t == 9900001 then return "KCMode"                      ,"撮影モード                            :"

    -- バージョン 2.2 以降
	elseif t == 27	    then return ""                            ,"測位方式の名称                        :"
	elseif t == 28	    then return ""                            ,"測位地点の名称                        :"
	elseif t == 29	    then return ""                            ,"GPS 日付                              :"
	elseif t == 30	    then return ""                            ,"GPS 補正測位                          :"
	elseif t == 31	    then return ""                            ,"水平方向測位誤差                      :"

	-- バージョン 2.3 以降
	elseif t == 34864	then return ""                            ,"感度種別                              :"
	elseif t == 34865	then return ""                            ,"標準出力感度                          :"
	elseif t == 34866	then return ""                            ,"推奨露光指数                          :"
	elseif t == 34867	then return ""                            ,"ISO スピード                          :"
	elseif t == 34868	then return ""                            ,"ISO スピードラティチュード yyy        :"
	elseif t == 34869	then return ""                            ,"ISO スピードラティチュード zzz        :"
	elseif t == 42032   then return ""                            ,"カメラ所有者名                        :"
	elseif t == 42033   then return ""                            ,"カメラシリアル番号                    :"
	elseif t == 42034   then return ""                            ,"レンズの仕様情報                      :"
	elseif t == 42035   then return ""                            ,"レンズメーカー名                      :"
	elseif t == 42036   then return ""                            ,"レンズのモデル名                      :"
	elseif t == 42037   then return ""                            ,"レンズシリアル番号                    :"
	elseif t == 42240   then return ""                            ,"再生ガンマ                            :"

	elseif t == 59932   then return "Padding"                     ,"Padding                               :"
	elseif t == 59933   then return "EXIF OffsetSchema"           ,"EXIF OffsetSchema                     :"

	-- Exiv?
	elseif t == 18246   then return "Rating"                      ,"Rating                                :"
	elseif t == 18249   then return "RatingPercent"               ,"RatingPercent                         :"
	elseif t == 40093   then return "XPAuthor"                    ,"XPAuthor                              :"
	else                     return "UNDEFINED"                   ,"不明なタグ ("..t.."):"

	end
end

function exif(size)
	local begin = cur()

	rstr ("ByteCode", 2)
	if get("ByteCode") == "MM" then
		little_endian(false)
	else
		little_endian(true)
	end

	cbyte("002A"  ,  2, 0x002A)
	rbyte("ifd_ofs", 4)
	ifd(begin, get("ifd_ofs"))

	seek(begin + size)
end

function ifd(origin, offset, indent)
	local indent = indent or 0
	local tab = string.rep("    ", indent)

	seek(origin + offset)
	rbyte("FieldCount", 2)
	print(tab.."---------------IFD count:"..hexstr(get("FieldCount")).."-----------------")

	local count = get("FieldCount")
	for i=1, count do
		local begin = cur()
		rbyte("Tag",         2)
		rbyte("Type",        2)
		rbyte("Count",       4)
		rbyte("ValueOffset", 4)

		local sz, ty = get_type(get("Type"))
		if get("Count") * sz > 4 then
			seek(get("ValueOffset")+origin)
		else
			seek(cur() - 4)
		end

		if ty == "byte" then
			for j=1, get("Count") do
				local val = rbyte("Byte",                     1)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
		elseif ty == "ascii" then
			local val = rstr("Ascii",                         get("Count"))
			print(tab..(select(2, get_tag(get("Tag")))), val)
		elseif ty == "short" then
			for j=1, get("Count") do
				local val = rbyte("Short",                    2)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
		elseif ty == "long" then
			for j=1, get("Count") do
				local val = rbyte("Long",                     4)
				print(tab..(select(2, get_tag(get("Tag")))), val)

				-- 次の階層
				if get_tag(get("Tag")) == "ExifIFDPointer"
				or get_tag(get("Tag")) == "GPSInfoIFDPointer"
				or get_tag(get("Tag")) == "InteroperabilityIFDPointer" then
					local begin = cur()
					ifd(origin, val, indent+1)
					seek(begin)
				end
			end
		elseif ty == "rational" then
			for j=1, get("Count") do
				local num = rbyte("Number",                   4)
				local den = rbyte("Denom",                    4)
				print(tab..(select(2, get_tag(get("Tag")))),  num/den)
			end
		elseif ty == "undefined" then
			local val = rbyte("Undefined",                    get("Count"))
			print(tab..(select(2, get_tag(get("Tag")))), val)
		elseif ty == "slong" then
			for j=1, get("Count") do
				local val = rbyte("Slong",                    4)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
		elseif ty == "srational" then
			for j=1, get("Count") do
				local num = rbyte("SNumber",                  4)
				local den = rbyte("SDenom",                   4)
				print(tab..(select(2, get_tag(get("Tag")))), num/den)
			end
		end

		seek(begin + 12)
	end

	rbyte("NextIFD", 4)
	if get("NextIFD") == 0 then
		return
	else
		local begin = cur()
		ifd(origin, get("NextIFD"), indent)
		seek(begin)
	end
end

function jpg()
	cbyte("SOI",           2, 0xffd8)

	while cur() + 4 < get_size() do
		local maker = rbyte("Markar",        2)
		if maker == 0xffd9 then -- EOI
			break;
		elseif maker == 0xffe0 then
			app0()
		elseif maker == 0xffe1 then
			app1()
		elseif maker == 0xffdb then
			dqt()
		elseif maker == 0xffdd then
			dri()
		elseif maker == 0xffc4 then
			dht()
		elseif maker == 0xffc0 then
			-- ベースライン
			sof0()
		elseif maker == 0xffda then
			sos()
		elseif maker == 0xffd0
		or     maker == 0xffd1
		or     maker == 0xffd2
		or     maker == 0xffd3
		or     maker == 0xffd4
		or     maker == 0xffd5
		or     maker == 0xffd6
		or     maker == 0xffd7 then
			-- restartはスキャンついでに行う
			assert(false, "RST found")
		else
			print("#unknown maker=", hexstr(maker))
			segment()
		end
	end
end

open(__stream_path__)
enable_print(false)
jpg()

