-- jpeg���

-- ��̓f�[�^
local jpeg = {q = {}, huffman = {}, frame = {}, scan  = {}}

-- �r�b�g�ǂݍ���
function RECEIVE(SSSS)
	return gbit(SSSS)
end

-- �}0�̓�l�Ƃ��Ĉ���
function EXTEND(V, T)
	local Vt = 2^(T-1)
	if V < Vt then
		Vt = ((-1)<<T) + 1
		V = V+Vt
	end
	return V
end

-- �n�t�}����������f�R�[�h
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

-- �u���b�N0����
function init8x8(frame, block)
	for i=0, 63 do
		frame.macroblock[block][i] = 0
	end
end

-- DC�����n�t�}���f�R�[�h
function dcdiff8x8(frame, block)
	local T = read_huffman(
		frame.dc_huffval, frame.dc_maxcode, frame.dc_mincode, frame.dc_valptr)
	sprint("d", T)
	local DIFF = EXTEND(RECEIVE(T), T)
	local val = frame.dc_prev_diff + DIFF
	frame.macroblock[block][0] = val
	frame.dc_prev_diff = val
end

-- AC�����n�t�}���f�R�[�h
function ac8x8(frame, block)
	-- AC����
	local K = 1
	while true do	
			sprint("a")
		local RS = read_huffman(
			frame.ac_huffval, frame.ac_maxcode, frame.ac_mincode, frame.ac_valptr)
		local RRRR = RS >> 4 -- ���4bit�͒l�̑O��ZeroRunLength SSSSRRRR=0��EOB
		local SSSS = RS % 16 -- ����4bit�͒l�̃T�C�Y, 0�̏ꍇ��RRRR�ɂ����ZRL or EOB or �I�[�܂�0
		local R = RRRR
		sprint("K=", K, "RRRR=", RRRR, "SSSS", SSSS)
		-- 0����
		-- or �l
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

-- �W�O�U�O�X�L����
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

-- �t�ʎq��
local function iquontization8x8(frame, block)
	for i=0, 63 do
		frame.macroblock[block][i] = frame.macroblock[block][i] * frame.q[i]
	end
end

-- �s��̊|�Z(IDCT�Ŏg��)
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

-- IDCT(�������Ȃ�)
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

-- 8x8�u���b�N���f�o�b�O�\��
function dump8x8(t)
	for i = 1, 8 do
		for j = 1, 8  do
			io.write(string.format("%7.2f ", t[8*(i-1) + (j-1)]))
		end
		io.write("\n")
	end
end

-- Y16x16��4:2:0���r�b�g�}�b�v�ɏ�������
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

-- Y16x8��4:2:0���r�b�g�}�b�v�ɏ�������
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

-- Y8x8��4:4:4���r�b�g�}�b�v�ɏ�������
function fill_block_444(bmp, x, y, Y, Cb, Cr)
	local yix = 0
	for bi=0, 7 do
		for bj=0, 7 do
			bmp:putyuv(x+bj, y+bi, Y[yix], Cb[yix], Cr[yix])
			yix = yix + 1 
		end
	end
end

-- �s�N�`���f�[�^���X�L�����E�f�R�[�h
function start_scan()
	-- �f�[�^��]��
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
		-- �X�L�����p�̃e�[�u����p��
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
		
		-- �f�R�[�h
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
				
				-- ���Z�b�g����
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
				
				-- �}�N���u���b�N�f�R�[�h
				for ci, v in ipairs(jpeg.frame) do
					local block = 1
					for i = 0, v.Vi-1 do
						for j = 0, v.Hi-1 do
							-- 8x8���f�R�[�h
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
				
				-- bitmap�ɏ�������
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
		
		-- �t�@�C���E�R���\�[���o��
		bmp:write(__stream_dir__.."out.bmp")
		local sb = bmp:create_scaled_bmp(120, nil)
		sb:print_ascii(120, nil)
	until true

	swap(prev)
end

-- �m��Ȃ��Z�O�����g�ǂݔ�΂�
function segment()
	local length = rbit("L", 16)
	seekoff(length - 2)
end

-- �ȉ�JPEG�K�i�ʂ�

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
	rbit("Ri", 16) -- ���X�^�[�g�C���^�[�o��

	jpeg.restert_interval = get("Ri")  

	skip(get("Lr"), begin)
end

function dht()
print("Huffman table")

	local begin = cur()
	rbit("Lh", 16)

	repeat
		rbit("Tc", 4) -- ���̃e�[�u�����g���̂�DC��AC��
		rbit("Th", 4) -- ���̃e�[�u����ID

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
				code = code << 1 -- 11111 �̏�Ԃ��獶�V�t�g
				si = si + 1
			end
		end
		
		-- max min valptr
		local maxcode = {} -- ����bit���̃n�t�}���R�[�h�̍ő�l
		local mincode = {} -- ����bit���̃n�t�}���R�[�h�̍ő�l
		local valptr = {}  -- mincode��index
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
		rbit("Csj", 8) -- ����ID
		rbit("Tdj", 4) -- �c�b�����n�t�}���e�[�u���ԍ�
		rbit("Taj", 4) -- �`�b�����n�t�}���e�[�u���ԍ�

		jpeg.scan[get("Csj")] = {}
		jpeg.scan[get("Csj")].dc_huffman = get("Tdj") 
		jpeg.scan[get("Csj")].ac_huffman = get("Taj") 
	end

	rbit("Ss", 8)
	rbit("Se", 8)
	rbit("Ah", 4)
	rbit("AL", 4)

	skip(get("Ls"), begin)
	
	--�X�L�����f�R�[�h�J�n
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

-- Exif���̈於�擾
function get_tag(t)
	if     t == 0       then return "GPSVersionID"                ,"GPS�^�O�̃o�[�W����                   :"
	elseif t == 1       then return "GPSLatitudeRef"              ,"�ܓx�̓�k                            :"
	elseif t == 2       then return "GPSLatitude"                 ,"�ܓx�i�x�A���A�b�j                    :"
	elseif t == 3       then return "GPSLongitudeRef"             ,"�o�x�̓���                            :"
	elseif t == 4       then return "GPSLongitude"                ,"�o�x�i�x�A���A�b�j                    :"
	elseif t == 5       then return "GPSAltitudeRef"              ,"���x�̊                            :"
	elseif t == 6       then return "GPSAltitude"                 ,"���x�im�j                             :"
	elseif t == 7       then return "GPSTimeStamp"                ,"GPS�̎��ԁi���q���v�j                 :"
	elseif t == 8       then return "GPSSatellites"               ,"���ʂɎg�p����GPS�q��                 :"
	elseif t == 9       then return "GPSStatus"                   ,"GPS��M�@�̏��                       :"
	elseif t == 10      then return "GPSMeasureMode"              ,"GPS�̑��ʃ��[�h                       :"
	elseif t == 11      then return "GPSDOP"                      ,"���ʂ̐M����                          :"
	elseif t == 12      then return "GPSSpeedRef"                 ,"���x�̒P��                            :"
	elseif t == 13      then return "GPSSpeed"                    ,"���x                                  :"
	elseif t == 14      then return "GPSTrackRef"                 ,"�i�s�����̊                        :"
	elseif t == 15      then return "GPSTrack"                    ,"�i�s�����i�x�j                        :"
	elseif t == 16      then return "GPSImgDirectionRef"          ,"�B�e�����̊                        :"
	elseif t == 17      then return "GPSImgDirection"             ,"�B�e�����i�x�j                        :"
	elseif t == 18      then return "GPSMapDatum"                 ,"���ʂɗp�����n�}�f�[�^                :"
	elseif t == 19      then return "GPSDestLatitudeRef"          ,"�ړI�n�̈ܓx�̓�k                    :"
	elseif t == 20      then return "GPSDestLatitude"             ,"�ړI�n�̈ܓx�i�x�A���A�b�j            :"
	elseif t == 21      then return "GPSDestLongitudeRef"         ,"�ړI�n�̌o�x�̓���                    :"
	elseif t == 22      then return "GPSDestLongitude"            ,"�ړI�n�̌o�x�i�x�A���A�b�j            :"
	elseif t == 23      then return "GPSBearingRef"               ,"�ړI�n�̕��p�̊                    :"
	elseif t == 24      then return "GPSBearing"                  ,"�ړI�n�̕��p�i�x�j                    :"
	elseif t == 25      then return "GPSDestDistanceRef"          ,"�ړI�n�ւ̋����̒P��                  :"
	elseif t == 26      then return "GPSDestDistance"             ,"�ړI�n�ւ̋���                        :"
	elseif t == 256     then return "ImageWidth"                  ,"�摜�̕�                              :"
	elseif t == 257     then return "ImageLength"                 ,"�摜�̍���                            :"
	elseif t == 258     then return "BitsPerSample"               ,"�摜�̃r�b�g�̐[��                    :"
	elseif t == 259     then return "Compression���k�̎��"       ,"Compression scheme                    :"
	elseif t == 262     then return "PhotometricInterpretation"   ,"�摜������                            :"
	elseif t == 270     then return "ImageDescription"            ,"�摜�^�C�g��                          :"
	elseif t == 271     then return "Make"                        ,"�摜���͋@��̃��[�J�[��              :"
	elseif t == 272     then return "Model"                       ,"�摜���͋@��̃��f����                :"
	elseif t == 273     then return "StripOffsets"                ,"�摜�f�[�^�̃��P�[�V����              :"
	elseif t == 274     then return "Orientation"                 ,"�摜����                              :"
	elseif t == 277     then return "SamplesPerPixel"             ,"�R���|�[�l���g��                      :"
	elseif t == 278     then return "RowsPerStrip"                ,"�X�g���b�v���̃��C����                :"
	elseif t == 279     then return "StripByteCounts"             ,"�X�g���b�v�̃f�[�^��                  :"
	elseif t == 282     then return "XResolution"                 ,"�摜�̕��̉𑜓x                      :"
	elseif t == 283     then return "YResolution"                 ,"�摜�̍����̉𑜓x                    :"
	elseif t == 284     then return "PlanarConfiguration"         ,"�摜�f�[�^�̕���                      :"
	elseif t == 296     then return "ResolutionUnit"              ,"�摜�̕��ƍ����̉𑜓x�̒P��          :"
	elseif t == 301     then return "TransferFunction"            ,"�Đ��K���J�[�u����                    :"
	elseif t == 305     then return "CreatorTool"                 ,"�g�pSoftware��                        :"
	elseif t == 306     then return "ModifyDate"                  ,"�t�@�C���ύX����                      :"
	elseif t == 315     then return "Artist"                      ,"��Җ�                                :"
	elseif t == 318     then return "WhitePoint"                  ,"�Q�Ɣ��F�_�̐F�x���W�l                :"
	elseif t == 319     then return "PrimaryChromaticities"       ,"���F�̐F�x���W�l                      :"
	elseif t == 513     then return "JPEGInterchangeFormat"       ,"JPEG �� SOI �ւ̃I�t�Z�b�g            :"
	elseif t == 514     then return "JPEGInterchangeFormatLength" ,"JPEG �f�[�^�̃o�C�g��                 :"
	elseif t == 529     then return "YCbCrCoefficients"           ,"�F�ϊ��}�g���N�X�W��                  :"
	elseif t == 530     then return "YCbCrSubSampling"            ,"YCC �̉�f������ (C�̊Ԉ�����)        :"
	elseif t == 531     then return "YCbCrPositioning"            ,"YCC �̉�f������ (Y �� C �̈ʒu)      :"
	elseif t == 532     then return "ReferenceBlackWhite"         ,"�Q�ƍ��F�_�l�ƎQ�Ɣ��F�_�l            :"
	elseif t == 33432   then return "Copyright"                   ,"�B�e���쌠��/�ҏW���쌠��             :"
	elseif t == 33434   then return "ExposureTime"                ,"�I�o����                              :"
	elseif t == 33437   then return "FNumber"                     ,"F�l                                   :"
	elseif t == 34665   then return "ExifIFDPointer"              ,"Exif �^�O                             :"
	elseif t == 34850   then return "ExposureProgram"             ,"�I�o�v���O����                        :"
	elseif t == 34852   then return "SpectralSensitivity"         ,"�X�y�N�g�����x                        :"
	elseif t == 34853   then return "GPSInfoIFDPointer"           ,"GPS �^�O                              :"
	elseif t == 34855   then return "ISOSpeedRatings"             ,"ISO �X�s�[�h���[�g/�B�e���x           :"
	elseif t == 34856   then return "OECF"                        ,"���d�����֐�                          :"
	elseif t == 36864   then return "ExifVersion"                 ,"Exif �o�[�W����                       :"
	elseif t == 36867   then return "DateTimeOriginal"            ,"���摜�f�[�^�̐�������                :"
	elseif t == 36868   then return "MetadataDate"                ,"�f�W�^���f�[�^�̐�������              :"
	elseif t == 37121   then return "ComponentsConfiguration"     ,"�e�R���|�[�l���g�̈Ӗ�                :"
	elseif t == 37122   then return "CompressedBitsPerPixel"      ,"�摜���k���[�h                        :"
	elseif t == 37377   then return "ShutterSpeedValue"           ,"�V���b�^�[�X�s�[�h                    :"
	elseif t == 37378   then return "ApertureValue"               ,"�i��l                                :"
	elseif t == 37379   then return "BrightnessValue"             ,"�P�x�l                                :"
	elseif t == 37380   then return "ExposureBiasValue"           ,"�I�o�␳�l                            :"
	elseif t == 37381   then return "MaxApertureValue"            ,"�����Y�ŏ� F �l                       :"
	elseif t == 37382   then return "SubjectDistance"             ,"��ʑ̋���                            :"
	elseif t == 37383   then return "MeteringMode"                ,"��������                              :"
	elseif t == 37384   then return "LightSource"                 ,"����                                  :"
	elseif t == 37385   then return "Flash"                       ,"�t���b�V��                            :"
	elseif t == 37386   then return "FocalLength"                 ,"�����Y�œ_����                        :"
	elseif t == 37396   then return "SubjectArea"                 ,"Subject area                          :"
	elseif t == 37500   then return "MakerNote"                   ,"���[�J�[�m�[�g                        :"
	elseif t == 37510   then return "UserComment"                 ,"���[�U�[�R�����g                      :"
	elseif t == 37520   then return "SubSecTime"                  ,"Date Time �̃T�u�Z�b�N                :"
	elseif t == 37521   then return "SubSecTimeOriginal"          ,"Date Time Original �̃T�u�Z�b�N       :"
	elseif t == 37522   then return "SubSecTimeDegitized"         ,"Date Time Digitized �̃T�u�Z�b�N      :"
	elseif t == 40960   then return "FlashpixVersion"             ,"�Ή��t���b�V���s�b�N�X�o�[�W����      :"
	elseif t == 40961   then return "ColorSpace"                  ,"�F��ԏ��                            :"
	elseif t == 40962   then return "PixelXDimension"             ,"�����摜��                            :"
	elseif t == 40963   then return "PixelYDimension"             ,"�����摜����                          :"
	elseif t == 40964   then return "RelatedSoundFile"            ,"�֘A�����t�@�C��                      :"
	elseif t == 40965   then return "InteroperabilityIFDPointer"  ,"�݊��� IFD �ւ̃|�C���^               :"
	elseif t == 41483   then return "FlashEnergy"                 ,"�t���b�V�����x                        :"
	elseif t == 41484   then return "SpatialFrequencyResponse"    ,"��Ԏ��g������                        :"
	elseif t == 41486   then return "FocalPlaneXResolution"       ,"�œ_�ʂ̕��̉𑜓x                    :"
	elseif t == 41487   then return "FocalPlaneYResolution"       ,"�œ_�ʂ̍����̉𑜓x                  :"
	elseif t == 41488   then return "FocalPlaneResolutionUnit"    ,"�œ_�ʉ𑜓x�P��                      :"
	elseif t == 41492   then return "SubjectLocation"             ,"��ʑ̈ʒu                            :"
	elseif t == 41493   then return "ExposureIndex"               ,"�I�o�C���f�b�N�X                      :"
	elseif t == 41495   then return "SensingMethod"               ,"�Z���T�[����                          :"
	elseif t == 41728   then return "FileSource"                  ,"FileSource                            :"
	elseif t == 41729   then return "SceneType"                   ,"�V�[���^�C�v                          :"
	elseif t == 41730   then return "CFAPattern"                  ,"CFA �p�^�[��                          :"
	elseif t == 41985   then return "CustomRendered"              ,"�J�X�^���C���[�W�v���Z�b�V���O        :"
	elseif t == 41986   then return "ExposureMode"                ,"�I�o���[�h                            :"
	elseif t == 41987   then return "WhiteBalance"                ,"�z���C�g�o�����X                      :"
	elseif t == 41988   then return "DigitalZoomRatio"            ,"�f�W�^���Y�[���䗦                    :"
	elseif t == 41989   then return "FocalLengthIn35mmFilm"       ,"35mm ���Z�œ_����                     :"
	elseif t == 41990   then return "SceneCaptureType"            ,"�V�[���B�e�^�C�v                      :"
	elseif t == 41991   then return "GainControl"                 ,"�Q�C���R���g���[��                    :"
	elseif t == 41992   then return "Contrast"                    ,"�R���g���X�g                          :"
	elseif t == 41993   then return "Saturation"                  ,"�ʓx                                  :"
	elseif t == 41994   then return "Sharpness"                   ,"�V���[�v�l�X                          :"
	elseif t == 41995   then return "DeviceSettingDescription"    ,"�f�o�C�X�ݒ�                          :"
	elseif t == 41996   then return "SubjectDistanceRange"        ,"��ʑ̋����͈�                        :"
	elseif t == 42016   then return "0xa420"                      ,"���j�[�N�摜 ID                       :"
	elseif t == 42240   then return "0xa500"                      ,"�K���}�l                              :"
	elseif t == 50706   then return "DNGVersion"                  ,"DNG �o�[�W����                        :"
	elseif t == 50707   then return "DNGBackwardVersion"          ,"DNG backward version                  :"
	elseif t == 50708   then return "DNGUniqueCameraModel"        ,"�J�����@�햼                          :"
	elseif t == 50709   then return "DNGLocalizedCameraModel"     ,"�J�����@�햼                          :"
	elseif t == 50710   then return "DNGCFAPlaneColor"            ,"CFA plane color                       :"
	elseif t == 50711   then return "DNGCFALayout"                ,"CFA ���C�A�E�g                        :"
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
	elseif t == 50735   then return "DNGCameraSerialNumber"       ,"�V���A���i���o�[                      :"
	elseif t == 50736   then return "DNGLensInfo"                 ,"�����Y���                            :"
	elseif t == 50737   then return "DNGChromaBlurRadius"         ,"Chroma blur radius                    :"
	elseif t == 50738   then return "DNGAntiAliasStrength"        ,"Anti-alias strength                   :"
	elseif t == 50739   then return "DNGShadowScale"              ,"Shadow scale                          :"
	elseif t == 50740   then return "DNGPrivateData"              ,"�v���C�x�[�g�f�[�^                    :"
	elseif t == 50741   then return "DNGMakerNoteSafety"          ,"MakerNote safety                      :"
	elseif t == 50778   then return "DNGCalibrationIlluminant1"   ,"Calibration illuminant1               :"
	elseif t == 50779   then return "DNGCalibrationIlluminant2"   ,"Calibration illuminant2               :"
	elseif t == 50780   then return "DNGBestQualityScale"         ,"Best quality scale                    :"
	elseif t == 50781   then return "DNGRawDataUniqueID"          ,"Raw data unique ID                    :"
	elseif t == 50827   then return "DNGOriginalRawFileName"      ,"�I���W�i�� RAW �t�@�C����             :"
	elseif t == 50828   then return "DNGOriginalRawFileData"      ,"�I���W�i�� RAW �t�@�C���f�[�^         :"
	elseif t == 50829   then return "DNGActiveArea"               ,"Active area                           :"
	elseif t == 50830   then return "DNGMaskedArea"               ,"Masked area                           :"
	elseif t == 50831   then return "DNGAsShotICCProfile"         ,"As shot ICC profile                   :"
	elseif t == 50832   then return "DNGAsShotPreProfileMatrix"   ,"As shot pre-profile matrix            :"
	elseif t == 50833   then return "DNGCurrentICCProfile"        ,"Current ICC profile                   :"
	elseif t == 50834   then return "DNGCurrentPreProfileMatrix"  ,"Current pre-profile matrix            :"
	elseif t == 1000000 then return "GPSVersionID"                ,"GPS �^�O�̃o�[�W����                  :"
	elseif t == 1000001 then return "GPSLatitudeRef"              ,"�k��(N) or ���(S)                    :"
	elseif t == 1000002 then return "GPSLatitude"                 ,"�ܓx (���l)                           :"
	elseif t == 1000003 then return "GPSLongitudeRef"             ,"���o(E) or ���o(W)                    :"
	elseif t == 1000004 then return "GPSLongitude"                ,"�o�x (���l)                           :"
	elseif t == 1000005 then return "GPSAltitudeRef"              ,"���x�̒P��                            :"
	elseif t == 1000006 then return "GPSAltitude"                 ,"���x (���l)                           :"
	elseif t == 1000007 then return "GPSTimeStamp"                ,"GPS ���� (���q���v�̎���)             :"
	elseif t == 1000008 then return "GPSSatellites"               ,"���ʂɎg�����q���M��                  :"
	elseif t == 1000009 then return "GPSStatus"                   ,"GPS ��M�@�̏��                      :"
	elseif t == 1000010 then return "GPSMessureMode"              ,"GPS ���ʕ��@                          :"
	elseif t == 1000011 then return "GPSDOP"                      ,"���ʂ̐M����                          :"
	elseif t == 1000012 then return "GPSSpeedRef"                 ,"���x�̒P��                            :"
	elseif t == 1000013 then return "GPSSpeed"                    ,"���x (���l)                           :"
	elseif t == 1000014 then return "GPSTrackRef"                 ,"�i�s�����̒P��                        :"
	elseif t == 1000015 then return "GPSTrack"                    ,"�i�s���� (���l)                       :"
	elseif t == 1000016 then return "GPSImgDirectionRef"          ,"�B�e�����摜�̕����̒P��              :"
	elseif t == 1000017 then return "GPSImgDirection"             ,"�B�e�����摜�̕��� (���l)             :"
	elseif t == 1000018 then return "GPSMapDatum"                 ,"���ʗp�����n�}�f�[�^                  :"
	elseif t == 1000019 then return "GPSDestLatitudeRef"          ,"�ړI�n�̖k��(N) or ���(S)            :"
	elseif t == 1000020 then return "GPSDestLatitude"             ,"�ړI�n�̈ܓx (���l)                   :"
	elseif t == 1000021 then return "GPSDestLongitudeRef"         ,"�ړI�n�̓��o(E) or ���o(W)            :"
	elseif t == 1000022 then return "GPSDestLongitude"            ,"�ړI�n�̌o�x (���l)                   :"
	elseif t == 1000023 then return "GPSDestBearingRef"           ,"�ړI�n�̕��p�̒P��                    :"
	elseif t == 1000024 then return "GPSDestBearing"              ,"�ړI�n�̕��p (���l)                   :"
	elseif t == 1000025 then return "GPSDestDistanceRef"          ,"�ړI�n�܂ł̋����̒P��                :"
	elseif t == 1000026 then return "GPSDestDistance"             ,"�ړI�n�܂ł̋��� (���l)               :"
	elseif t == 1000027 then return "GPSProcessingMethod"         ,"Name of GPS processing method         :"
	elseif t == 1000028 then return "GPSAreaInformation"          ,"Name of GPS area                      :"
	elseif t == 1000029 then return "GPSDateStamp"                ,"GPS date                              :"
	elseif t == 1000030 then return "GPSDifferential"             ,"GPS differential correction           :"
	elseif t == 2000000 then return "InteroperabilityIndex"       ,"�݊������ʎq                          :"
	elseif t == 3000001 then return "CRSRawFileName"              ,"Raw �t�@�C����                        :"
	elseif t == 3000002 then return "CRSVersion"                  ,"�o�[�W����                            :"
	elseif t == 3000003 then return "CRSWhiteBalance"             ,"�z���C�g�o�����X                      :"
	elseif t == 3000004 then return "CRSTemperature"              ,"�F���x                                :"
	elseif t == 3000005 then return "CRSTint"                     ,"�F����                                :"
	elseif t == 3000006 then return "CRSShadowTint"               ,"ShadowTint                            :"
	elseif t == 3000007 then return "CRSExposure"                 ,"�I����                                :"
	elseif t == 3000008 then return "CRSShadows"                  ,"�V���h�E                              :"
	elseif t == 3000009 then return "CRSBrightness"               ,"���邳                                :"
	elseif t == 3000010 then return "CRSContrast"                 ,"�R���g���X�g                          :"
	elseif t == 3000011 then return "CRSSaturation"               ,"�ʓx                                  :"
	elseif t == 3000012 then return "CRSRedSaturation"            ,"�ʓx(��)                              :"
	elseif t == 3000013 then return "CRSGreenSaturation"          ,"�ʓx(��)                              :"
	elseif t == 3000014 then return "CRSBlueSaturation"           ,"�ʓx(��)                              :"
	elseif t == 3000015 then return "CRSSharpness"                ,"�V���[�v                              :"
	elseif t == 3000016 then return "CRSLuminanceSmoothing"       ,"LuminanceSmoothing                    :"
	elseif t == 3000017 then return "CRSRedHue"                   ,"RedHue                                :"
	elseif t == 3000018 then return "CRSGreenHue"                 ,"GreenHue                              :"
	elseif t == 3000019 then return "CRSBlueHue"                  ,"BlueHue                               :"
	elseif t == 3000020 then return "CRSColorNoiseReduction"      ,"ColorNoiseReduction                   :"
	elseif t == 3000021 then return "CRSChromaticAberration"      ,"RChromaticAberration                  :"
	elseif t == 3000022 then return "CRSChromaticAberration"      ,"BChromaticAberration                  :"
	elseif t == 3000023 then return "CRSVignette"                 ,"AmountVignette                        :"
	elseif t == 3000024 then return "CRSLens"                     ,"�����Y                                :"
	elseif t == 3000025 then return "CRSSerialNumber"             ,"�V���A���i���o�[                      :"
	elseif t == 3000026 then return "CRSAutoBrightness"           ,"���邳�����ݒ�                        :"
	elseif t == 3000027 then return "CRSAutoShadows"              ,"�V���h�E�����ݒ�                      :"
	elseif t == 3000028 then return "CRSAutoContrast"             ,"�R���g���X�g�����ݒ�                  :"
	elseif t == 3000029 then return "CRSAutoExposure"             ,"�I���ʎ����ݒ�                        :"
	elseif t == 3100512 then return "OLSpecialMode"               ,"�B�e���[�h                            :"
	elseif t == 3100513 then return "OLJpegQuality"               ,"�B�e�i��                              :"
	elseif t == 3100514 then return "OLMacro"                     ,"�}�N��                                :"
	elseif t == 3100516 then return "OLDigitalZoom"               ,"�f�W�^���Y�[��                        :"
	elseif t == 3100519 then return "OLSoftwareRelease"           ,"�t�@�[���E�F�A                        :"
	elseif t == 3100520 then return "OLpictInfo"                  ,"�摜���                              :"
	elseif t == 3100521 then return "OLCameraID"                  ,"�J���� ID                             :"
	elseif t == 3103840 then return "OLDataDump.unknown"          ,"Data dump                             :"
	elseif t == 3104100 then return "OLFlashMode"                 ,"�t���b�V�����[�h                      :"
	elseif t == 3104102 then return "OLExposureBias"              ,"�I�o�␳�l                            :"
	elseif t == 3104107 then return "OLFocusMode"                 ,"�t�H�[�J�X���[�h                      :"
	elseif t == 3104108 then return "OLFocusDistance"             ,"�œ_����                              :"
	elseif t == 3104109 then return "OLZoom"                      ,"�Y�[��                                :"
	elseif t == 3104110 then return "OLMacroFocus"                ,"�}�N��                                :"
	elseif t == 3104111 then return "OLSharpness"                 ,"�V���[�v�l�X                          :"
	elseif t == 3104113 then return "OLColourMatrix"              ,"�J���[�}�g���b�N�X                    :"
	elseif t == 3104114 then return "OLBlackLevel"                ,"�����x��                              :"
	elseif t == 3104117 then return "OLWhiteBalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 3104119 then return "OLRedBias"                   ,"�o�C�A�X(��)                          :"
	elseif t == 3104120 then return "OLBlueBias"                  ,"�o�C�A�X(��)                          :"
	elseif t == 3104122 then return "OLSerialNumber"              ,"�V���A���i���o�[                      :"
	elseif t == 3104131 then return "OLFlashBias"                 ,"�t���b�V���o�C�A�X                    :"
	elseif t == 3104137 then return "OLContrast"                  ,"�R���g���X�g                          :"
	elseif t == 3104138 then return "OLSharpnessFactor"           ,"Sharpness Factor                      :"
	elseif t == 3104139 then return "OLColourControl"             ,"�J���[�R���g���[��                    :"
	elseif t == 3104140 then return "OLValidBits"                 ,"�L���r�b�g                            :"
	elseif t == 3104141 then return "OLCoringFilter"              ,"Coring Filter                         :"
	elseif t == 3104142 then return "OLImageWidth"                ,"�摜�̕�                              :"
	elseif t == 3104143 then return "OLImageHeight"               ,"�摜�̍���                            :"
	elseif t == 3104148 then return "OLCompressionRatio"          ,"���k��                                :"
	elseif t == 3200018 then return "PXExposureTime"              ,"�I�o����                              :"
	elseif t == 3200019 then return "PXFNumber"                   ,"F�l                                   :"
	elseif t == 3200020 then return "PXISOSpeed"                  ,"ISO �l                                :"
	elseif t == 3200022 then return "PXExposureBias"              ,"�I�o�␳�lE                           :"
	elseif t == 3200025 then return "PXWhiteBalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 3200063 then return "PXLensID"                    ,"�����Y���                            :"
	elseif t == 3200079 then return "PXImageTone"                 ,"�摜�d�グ                            :"
	elseif t == 3300002 then return "EXThumbInfo"                 ,"�T���l�C���̑傫��                    :"
	elseif t == 3300003 then return "EXThumbSize"                 ,"�T���l�C���̃T�C�Y                    :"
	elseif t == 3300004 then return "EXThumbOffset"               ,"�T���l�C���ւ̃I�t�Z�b�g              :"
	elseif t == 3300008 then return "EXQualityMode"               ,"�B�e�i��                              :"
	elseif t == 3300009 then return "EXImageSize"                 ,"�摜�T�C�Y                            :"
	elseif t == 3300020 then return "EXISOSensitivity"            ,"ISO ���x                              :"
	elseif t == 3300025 then return "EXWhiteBalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 3300029 then return "EXFocalLength"               ,"�œ_����                              :"
	elseif t == 3300031 then return "EXSaturation"                ,"�ʓx                                  :"
	elseif t == 3300032 then return "EXContrast"                  ,"�R���g���X�g                          :"
	elseif t == 3300033 then return "EXSharpness"                 ,"�V���[�v�l�X                          :"
	elseif t == 3303584 then return "EXPIM"                       ,"unknown                               :"
	elseif t == 3308192 then return "EXThumbnail"                 ,"unknown                               :"
	elseif t == 3308209 then return "EXWBBias"                    ,"�z���C�g�o�����X�o�C�A�X              :"
	elseif t == 3308210 then return "EXFlash"                     ,"unknown                               :"
	elseif t == 3308226 then return "EXObjectDistance"            ,"�Ώە��̋���                          :"
	elseif t == 3308244 then return "EXFlashDistance"             ,"�t���b�V���̋���                      :"
	elseif t == 3312288 then return "EXRecordMode"                ,"unknown                               :"
	elseif t == 3312289 then return "EXSelfTimer"                 ,"unknown                               :"
	elseif t == 3312290 then return "EXQuality"                   ,"�i��                                  :"
	elseif t == 3312291 then return "EXFocusMode"                 ,"�t�H�[�J�X���[�h                      :"
	elseif t == 3312294 then return "EXTimeZone"                  ,"�^�C���]�[��                          :"
	elseif t == 3312295 then return "EXBestshotMode"              ,"unknown                               :"
	elseif t == 3312308 then return "EXCCDSensitivity"            ,"CCD���x                               :"
	elseif t == 3312309 then return "EXColorMode"                 ,"�J���[���[�h                          :"
	elseif t == 3312310 then return "EXColorEnhance"              ,"�F����                                :"
	elseif t == 3312311 then return "EXFilter"                    ,"�t�B���^�[                            :"
	elseif t == 3400001 then return "PXOCaptureMode"              ,"�B�e���[�h                            :"
	elseif t == 3400002 then return "PXOQualityLevel"             ,"�B�e�i��                              :"
	elseif t == 3400003 then return "PXOFocusMode"                ,"�t�H�[�J�X���[�h                      :"
	elseif t == 3400004 then return "PXOFlashMode"                ,"�t���b�V��                            :"
	elseif t == 3400007 then return "PXOWhiteBalance"             ,"�z���C�g�o�����X                      :"
	elseif t == 3400010 then return "PXODigitalZoom"              ,"�f�W�^���Y�[��                        :"
	elseif t == 3400011 then return "PXOSharpness"                ,"�V���[�v�l�X                          :"
	elseif t == 3400012 then return "PXOContrast"                 ,"�R���g���X�g                          :"
	elseif t == 3400013 then return "PXOSaturation"               ,"�ʓx                                  :"
	elseif t == 3400020 then return "PXOISOSpeed"                 ,"ISO ���x                              :"
	elseif t == 3400023 then return "PXOColorMode"                ,"�J���[                                :"
	elseif t == 3404096 then return "PXOTimeZone"                 ,"�^�C���]�[��                          :"
	elseif t == 3404097 then return "PXODaylightSavings"          ,"Daylight savings                      :"
	elseif t == 3500002 then return "NKISOSetting"                ,"ISO ���x                              :"
	elseif t == 3500003 then return "NKColorMode"                 ,"�J���[���[�h                          :"
	elseif t == 3500004 then return "NKQuality"                   ,"�B�e�i��                              :"
	elseif t == 3500005 then return "NKWhitebalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 3500006 then return "NKSharpness"                 ,"�V���[�v�l�X                          :"
	elseif t == 3500007 then return "NKFocusMode"                 ,"�t�H�[�J�X���[�h                      :"
	elseif t == 3500008 then return "NKFlashSetting"              ,"�V���N�����[�h                        :"
	elseif t == 3500009 then return "NKFlashMode"                 ,"�t���b�V�����[�h                      :"
	elseif t == 3500011 then return "NKWhiteBalanceOffset"        ,"�z���C�g�o�����X�␳��                :"
	elseif t == 3500015 then return "NKISOselection"              ,"ISO ���x�̑I��                        :"
	elseif t == 3500017 then return "NKThumbnailIFDOffset"        ,"unknown                               :"
	elseif t == 3500128 then return "NKImageAdjustment"           ,"�摜���[�h                            :"
	elseif t == 3500129 then return "NKContrastSetting"           ,"�K���␳                              :"
	elseif t == 3500130 then return "NKAdapter"                   ,"�A�_�v�^�[                            :"
	elseif t == 3500131 then return "NKLensSetting"               ,"unknown                               :"
	elseif t == 3500132 then return "NKLensInfo"                  ,"�����Y���                            :"
	elseif t == 3500133 then return "NKManualFocusDistance"       ,"�}�j���A���t�H�[�J�X����              :"
	elseif t == 3500134 then return "NKDigitalZoom"               ,"�f�W�^���Y�[���䗦                    :"
	elseif t == 3500136 then return "NKAFFocusPoint"              ,"�t�H�[�J�X�G���A                      :"
	elseif t == 3500137 then return "NKShutterMode"               ,"���샂�[�h                            :"
	elseif t == 3500141 then return "NKColorSpace"                ,"�F��ԏ��                            :"
	elseif t == 3500146 then return "NKColorOffset"               ,"�F���␳�l                            :"
	elseif t == 3500149 then return "NKNoiseReduction"            ,"�m�C�Y���_�N�V����                    :"
	elseif t == 3500152 then return "NKLendID"                    ,"�����Y ID                             :"
	elseif t == 3500167 then return "NKShotCount"                 ,"�B�e��                              :"
	elseif t == 3500169 then return "NKFinishSetting"             ,"�d�オ��ݒ�                          :"
	elseif t == 3500171 then return "NKDigitalImgProg"            ,"�f�W�^���C���[�W�v���O����            :"
	elseif t == 3600003 then return "NKEQuality"                  ,"�B�e���[�h                            :"
	elseif t == 3600004 then return "NKEColorMode"                ,"�J���[���[�h                          :"
	elseif t == 3600005 then return "NKEImageAdjustment"          ,"�B�e�ݒ�                              :"
	elseif t == 3600006 then return "NKECCDSensitivity"           ,"CCD ���x                              :"
	elseif t == 3600007 then return "NKEWhiteBalance"             ,"�z���C�g�o�����X                      :"
	elseif t == 3600008 then return "NKEFocus"                    ,"unknown                               :"
	elseif t == 3600010 then return "NKEDigitalZoom"              ,"�f�W�^���Y�[���䗦                    :"
	elseif t == 3600011 then return "NKEConverter"                ,"�R���o�[�^                            :"
	elseif t == 3700000 then return "MLTMakerNoteVersion"         ,"�o�[�W����                            :"
	elseif t == 3700001 then return "MLTCameraSettingsOld"        ,"unknown                               :"
	elseif t == 3700003 then return "MLTExposureMode"             ,"�I�o���[�h                            :"
	elseif t == 3700003 then return "MLTFlashMode"                ,"�t���b�V��                            :"
	elseif t == 3700003 then return "MLTWhiteBalance"             ,"�z���C�g�o�����X                      :"
	elseif t == 3700003 then return "MLTImageSize"                ,"�摜�T�C�Y                            :"
	elseif t == 3700003 then return "MLTImageQuality"             ,"�摜�i��                              :"
	elseif t == 3700003 then return "MLTDriveMode"                ,"�h���C�u���[�h                        :"
	elseif t == 3700003 then return "MLTMeteringMode"             ,"��������                              :"
	elseif t == 3700003 then return "MLTFilmSpeed"                ,"ISO �X�s�[�h���[�h                    :"
	elseif t == 3700003 then return "MLTShutterSpeed"             ,"�V���b�^�[���x                        :"
	elseif t == 3700003 then return "MLTAperture"                 ,"Aperture                              :"
	elseif t == 3700003 then return "MLTMacroMode"                ,"�}�N�����[�h                          :"
	elseif t == 3700003 then return "MLTDigitalZoom"              ,"�f�W�^���Y�[��                        :"
	elseif t == 3700003 then return "MLTExposureCompensation"     ,"�I�o�␳                              :"
	elseif t == 3700003 then return "MLTBracketStep"              ,"Bracket step                          :"
	elseif t == 3700003 then return "MLTunknown16"                ,"unknown                               :"
	elseif t == 3700003 then return "MLTIntervalLength"           ,"���ԊԊu (��)                         :"
	elseif t == 3700003 then return "MLTIntervalNumber"           ,"�Ԋu��                                :"
	elseif t == 3700003 then return "MLTFocalLength"              ,"�œ_���� (35mm ���Z)                  :"
	elseif t == 3700003 then return "MLTFocusDistance"            ,"Focus distance                        :"
	elseif t == 3700003 then return "MLTFlashFired"               ,"�t���b�V��                            :"
	elseif t == 3700003 then return "MLTDate"                     ,"��                                    :"
	elseif t == 3700003 then return "MLTTime"                     ,"��                                    :"
	elseif t == 3700003 then return "MLTMaxAperture"              ,"Max Aperture                          :"
	elseif t == 3700003 then return "MLTFileNumberMemory"         ,"File number memory                    :"
	elseif t == 3700003 then return "MLTLastFileNumber"           ,"Last file number                      :"
	elseif t == 3700003 then return "MLTWhiteBalanceRed"          ,"�z���C�g�o�����X(��)                  :"
	elseif t == 3700003 then return "MLTWhiteBalanceGreen"        ,"�z���C�g�o�����X(��)                  :"
	elseif t == 3700003 then return "MLTWhiteBalanceBlue"         ,"�z���C�g�o�����X(��)                  :"
	elseif t == 3700003 then return "MLTSaturation"               ,"�ʓx                                  :"
	elseif t == 3700003 then return "MLTContrast"                 ,"�R���g���X�g                          :"
	elseif t == 3700003 then return "MLTSharpness"                ,"�V���[�v�l�X                          :"
	elseif t == 3700003 then return "MLTSubjectProgram"           ,"�I�o�v���O����                        :"
	elseif t == 3700003 then return "MLTFlashCompensation"        ,"�t���b�V���␳                        :"
	elseif t == 3700003 then return "MLTISOSetting"               ,"ISO �l                                :"
	elseif t == 3700003 then return "MLTCameraModel"              ,"���f��                                :"
	elseif t == 3700003 then return "MLTIntervalMode"             ,"Interval mode                         :"
	elseif t == 3700003 then return "MLTFolderName"               ,"Folder name                           :"
	elseif t == 3700003 then return "MLTColorMode"                ,"�J���[���[�h                          :"
	elseif t == 3700003 then return "MLTColorFilter"              ,"�J���[�t�B���^�[                      :"
	elseif t == 3700003 then return "MLTBWFilter"                 ,"�����t�B���^�[                        :"
	elseif t == 3700003 then return "MLTInternalFlash"            ,"�����t���b�V��                        :"
	elseif t == 3700003 then return "MLTBrightnessValue"          ,"�P�x�l                                :"
	elseif t == 3700003 then return "MLTSpotFocusPointX"          ,"�œ_�ʒu(X)                           :"
	elseif t == 3700003 then return "MLTSpotFocusPointY"          ,"�œ_�ʒu(Y)                           :"
	elseif t == 3700003 then return "MLTWideFocusZone"            ,"Wide focus zone                       :"
	elseif t == 3700003 then return "MLTFocusMode"                ,"�t�H�[�J�X���[�h                      :"
	elseif t == 3700003 then return "MLTFocusArea"                ,"�t�H�[�J�X�͈�                        :"
	elseif t == 3700003 then return "MLTDECPosition"              ,"DEC position                          :"
	elseif t == 3700064 then return "MLTComppressImageSize"       ,"�摜�T�C�Y                            :"
	elseif t == 3700129 then return "MLTThumbnail"                ,"unknown                               :"
	elseif t == 3700136 then return "MLTThumbnailOffset"          ,"unknown                               :"
	elseif t == 3700137 then return "MLTThumbnailLength"          ,"�T���l�C���̃T�C�Y                    :"
	elseif t == 3700268 then return "MLTLensID"                   ,"�����Y���                            :"
	elseif t == 3703584 then return "MLTPIMInformation"           ,"Print IM ���                         :"
	elseif t == 3703840 then return "MLTCameraSettings"           ,"unknown                               :"
	elseif t == 3800002 then return "SGSerialID"                  ,"�V���A���i���o�[                      :"
	elseif t == 3800003 then return "SGDriveMode"                 ,"�h���C�u���[�h                        :"
	elseif t == 3800004 then return "SGImageSize"                 ,"�L�^��f��                            :"
	elseif t == 3800005 then return "SGAFMode"                    ,"AF ���[�h                             :"
	elseif t == 3800006 then return "SGFocusMode"                 ,"�t�H�[�J�X���[�h                      :"
	elseif t == 3800007 then return "SGWhiteBalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 3800008 then return "SGExposureMode"              ,"�I�o���[�h                            :"
	elseif t == 3800009 then return "SGMeteringMode"              ,"�������[�h                            :"
	elseif t == 3800010 then return "SGFocalLength"               ,"�œ_����                              :"
	elseif t == 3800011 then return "SGColorSpace"                ,"�F���                                :"
	elseif t == 3800012 then return "SGExposure"                  ,"�I�o�␳                              :"
	elseif t == 3800013 then return "SGContrast"                  ,"�R���g���X�g                          :"
	elseif t == 3800014 then return "SGShadow"                    ,"�V���h�E                              :"
	elseif t == 3800015 then return "SGHighlight"                 ,"�n�C���C�g                            :"
	elseif t == 3800016 then return "SGSaturation"                ,"�ʓx�␳                              :"
	elseif t == 3800017 then return "SGSharpness"                 ,"�V���[�v�l�X�␳                      :"
	elseif t == 3800018 then return "SGX3FillLight"               ,"X3 Fill Light                         :"
	elseif t == 3800020 then return "SGColorCoordination"         ,"�J���[����                            :"
	elseif t == 3800021 then return "SGCustomSettingMode"         ,"�����ݒ�                              :"
	elseif t == 3800022 then return "SGJpegQuality"               ,"JPEG �i��                             :"
	elseif t == 3800023 then return "SGFirmware"                  ,"�t�@�[���E�F�A                        :"
	elseif t == 3800024 then return "SGSoftware"                  ,"Software                              :"
	elseif t == 3800025 then return "SGAutoBlacket"               ,"�I�[�g�u���P�b�g                      :"
	elseif t == 4000001 then return "CNMacroMode"                 ,"�B�e���[�h                            :"
	elseif t == 4000001 then return "CNSelfTimer"                 ,"�Z���t�^�C�}�[                        :"
	elseif t == 4000001 then return "CNFlash"                     ,"�t���b�V��                            :"
	elseif t == 4000001 then return "CNDriveMode"                 ,"�h���C�u���[�h                        :"
	elseif t == 4000001 then return "CNFocusMode"                 ,"�t�H�[�J�X���[�h                      :"
	elseif t == 4000001 then return "CNImageSize"                 ,"�摜�T�C�Y                            :"
	elseif t == 4000001 then return "CNImageSelect"               ,"�C���[�W�Z���N�g                      :"
	elseif t == 4000001 then return "CNDigitalZoom"               ,"�f�W�^���Y�[��                        :"
	elseif t == 4000001 then return "CNContrast"                  ,"�R���g���X�g                          :"
	elseif t == 4000001 then return "CNSaturation"                ,"�ʓx                                  :"
	elseif t == 4000001 then return "CNSharpness"                 ,"�V���[�v�l�X                          :"
	elseif t == 4000001 then return "CNISOSensitive"              ,"ISO ���x                              :"
	elseif t == 4000001 then return "CNMeteringMode"              ,"��������                              :"
	elseif t == 4000001 then return "CNFocusType"                 ,"�t�H�[�J�X�^�C�v                      :"
	elseif t == 4000001 then return "CNAFPoint"                   ,"unknown                               :"
	elseif t == 4000001 then return "CNExposurePorgram"           ,"�I�o�v���O����                        :"
	elseif t == 4000001 then return "CNLensID"                    ,"�����Y���                            :"
	elseif t == 4000001 then return "CNLensMaximum"               ,"�ő�œ_����                          :"
	elseif t == 4000001 then return "CNLensMinimum"               ,"�ŏ��œ_����                          :"
	elseif t == 4000001 then return "CNLensUnit"                  ,"�œ_�����P��(mm)                      :"
	elseif t == 4000001 then return "CNFlashDetailed"             ,"unknown                               :"
	elseif t == 4000001 then return "CNFocusSetting"              ,"�t�H�[�J�X�ݒ�                        :"
	elseif t == 4000001 then return "CNImageStabilization"        ,"��Ԃ�␳                            :"
	elseif t == 4000001 then return "CNImageEffect"               ,"�F����                                :"
	elseif t == 4000001 then return "CNHueBias"                   ,"�F�����␳�l                          :"
	elseif t == 4000004 then return "CNWhitebalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 4000004 then return "CNImageNumber"               ,"unknown                               :"
	elseif t == 4000004 then return "CNAFPointUsed"               ,"unknown                               :"
	elseif t == 4000004 then return "CNFlashBias"                 ,"�t���b�V���␳���x                    :"
	elseif t == 4000004 then return "CNAperture"                  ,"�i��                                  :"
	elseif t == 4000004 then return "CNExposure"                  ,"�I�o����                              :"
	elseif t == 4000004 then return "CNNDFilter"                  ,"ND �t�B���^�[                         :"
	elseif t == 4000006 then return "CNImageType"                 ,"�C���[�W�̎��                        :"
	elseif t == 4000007 then return "CNFirmware"                  ,"�t�@�[���E�F�A                        :"
	elseif t == 4000009 then return "CNUser"                      ,"���L�Җ�                              :"
	elseif t == 4000012 then return "CNSerial"                    ,"�V���A���i���o�[                      :"
	elseif t == 4000015 then return "CNNoiseReduction"            ,"�m�C�Y���_�N�V����                    :"
	elseif t == 4000015 then return "CNButtunFunction"            ,"�V���b�^�[/AE���b�N�{�^��             :"
	elseif t == 4000015 then return "CNMirrorLockUp"              ,"�~���[���b�N�A�b�v                    :"
	elseif t == 4000015 then return "CNShutterStep"               ,"�V���b�^�[/�i��̘I�o�ݒ�             :"
	elseif t == 4000015 then return "CNAFSupliment"               ,"AF �⏕��                             :"
	elseif t == 4000015 then return "CNApexPriority"              ,"�i��D�惂�[�h���̃V���b�^�[���x      :"
	elseif t == 4000015 then return "CNAEFunction"                ,"AE�u���P�b�g�����ƃL�����Z���@�̂�    :"
	elseif t == 4000015 then return "CNShutterSynchro"            ,"�V���b�^�[���V���N��                  :"
	elseif t == 4000015 then return "CNAFStopButton"              ,"�����Y AF �X�g�b�v�{�^��              :"
	elseif t == 4000015 then return "CNFlashMemLimit"             ,"�����t���b�V���[�d�ʐ���              :"
	elseif t == 4000015 then return "CNMenuPosition"              ,"���j���[�{�^�����A�ʒu                :"
	elseif t == 4000015 then return "CNSETFunction"               ,"SET �{�^���@�̂�                      :"
	elseif t == 4000015 then return "CNSensorCleaning"            ,"�Z���T�[�N���[�j���O                  :"
	elseif t == 4000160 then return "CNColorTemp"                 ,"�F���x                                :"
	elseif t == 4000180 then return "CNColorSpace"                ,"�F���                                :"
	elseif t == 4600000 then return "FJVersion"                   ,"unknown                               :"
	elseif t == 4604096 then return "FJQuality"                   ,"�摜�i��                              :"
	elseif t == 4604097 then return "FJSharpness"                 ,"�V���[�v�l�X                          :"
	elseif t == 4604098 then return "FJWhiteBalance"              ,"�z���C�g�o�����X                      :"
	elseif t == 4604099 then return "FJColor"                     ,"�F�̔Z��                              :"
	elseif t == 4604112 then return "FJFlashMode"                 ,"�t���b�V��                            :"
	elseif t == 4604113 then return "FJFlashStrength"             ,"�t���b�V���␳                        :"
	elseif t == 4604128 then return "FJMacro"                     ,"�}�N��                                :"
	elseif t == 4604129 then return "FJFocusMode"                 ,"�t�H�[�J�X���[�h                      :"
	elseif t == 4604144 then return "FJSlowSync"                  ,"�X���[�V���N��                        :"
	elseif t == 4604145 then return "FJPictureMode"               ,"�B�e���[�h                            :"
	elseif t == 4604352 then return "FJContBlacket"               ,"�A��/�����u���P�b�g                   :"
	elseif t == 4604864 then return "FJBlurWarning"               ,"��Ԃ�x��                            :"
	elseif t == 4604865 then return "FJFocusWarning"              ,"�I�[�g�t�H�[�J�X�̏��                :"
	elseif t == 4604866 then return "FJAEWarning"                 ,"�����I�o�̏��                        :"
	elseif t == 9900001 then return "KCMode"                      ,"�B�e���[�h                            :"

    -- �o�[�W���� 2.2 �ȍ~
	elseif t == 27	    then return ""                            ,"���ʕ����̖���                        :"
	elseif t == 28	    then return ""                            ,"���ʒn�_�̖���                        :"
	elseif t == 29	    then return ""                            ,"GPS ���t                              :"
	elseif t == 30	    then return ""                            ,"GPS �␳����                          :"
	elseif t == 31	    then return ""                            ,"�����������ʌ덷                      :"

	-- �o�[�W���� 2.3 �ȍ~
	elseif t == 34864	then return ""                            ,"���x���                              :"
	elseif t == 34865	then return ""                            ,"�W���o�͊��x                          :"
	elseif t == 34866	then return ""                            ,"�����I���w��                          :"
	elseif t == 34867	then return ""                            ,"ISO �X�s�[�h                          :"
	elseif t == 34868	then return ""                            ,"ISO �X�s�[�h���e�B�`���[�h yyy        :"
	elseif t == 34869	then return ""                            ,"ISO �X�s�[�h���e�B�`���[�h zzz        :"
	elseif t == 42032   then return ""                            ,"�J�������L�Җ�                        :"
	elseif t == 42033   then return ""                            ,"�J�����V���A���ԍ�                    :"
	elseif t == 42034   then return ""                            ,"�����Y�̎d�l���                      :"
	elseif t == 42035   then return ""                            ,"�����Y���[�J�[��                      :"
	elseif t == 42036   then return ""                            ,"�����Y�̃��f����                      :"
	elseif t == 42037   then return ""                            ,"�����Y�V���A���ԍ�                    :"
	elseif t == 42240   then return ""                            ,"�Đ��K���}                            :"

	elseif t == 59932   then return "Padding"                     ,"Padding                               :"
	elseif t == 59933   then return "EXIF OffsetSchema"           ,"EXIF OffsetSchema                     :"

	-- Exiv?
	elseif t == 18246   then return "Rating"                      ,"Rating                                :"
	elseif t == 18249   then return "RatingPercent"               ,"RatingPercent                         :"
	elseif t == 40093   then return "XPAuthor"                    ,"XPAuthor                              :"
	else                     return "UNDEFINED"                   ,"�s���ȃ^�O ("..t.."):"

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

				-- ���̊K�w
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
			-- �x�[�X���C��
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
			-- restart�̓X�L�������łɍs��
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

