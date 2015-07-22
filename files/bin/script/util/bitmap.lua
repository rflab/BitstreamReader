-- bmp作成

local name = ...           -- 第一引数がモジュール名
local _m = {}              -- メンバ関数を補樹威するテーブル
local _meta = {__index=_m} 
local _v = {}              -- プライベート変数(selfをキーとするテーブル)
package.loaded[name] = _m  -- 二度目のrequire()はこれが返される
_G[name] = _m              -- グローバルに登録しておく

------------------------------------------------
-- private
------------------------------------------------

local function clamp(min, max, val)
	if val < min then
		return min
	elseif val > max then
		return max
	else
		return val
	end
end

------------------------------------------------
-- public
------------------------------------------------

function _m:new(pitch, height, buf_pitch, buf_height)
	assert(pitch)
	assert(height)
	buf_pitch = buf_pitch or pitch
	buf_height = buf_height or height

	local obj = {
		dip = {
			pitch = pitch,
			height = height,
			buf_pitch = buf_pitch,
			buf_height = buf_height,
			r = {},
			g = {},
			b = {}
		},
		default_color = 0x00ff00
	}

	setmetatable(obj, _meta)
	return obj
end

function _m:write(filename)
	local dip = self.dip
	local data_size = dip.pitch*dip.height*3
	local align=(dip.pitch)%4
	write(filename, "BM")
	write(filename, val2str(data_size + 40, 4, true))  -- "bfSize",           4)
	write(filename, "00 00")                           -- "bfReserved1",      2)
	write(filename, "00 00")                           -- "bfReserved2",      2)
	write(filename, "36 00 00 00")                     -- "bfOffBits",        4)
	write(filename, "28 00 00 00")                     -- "bcSize",           4)
	write(filename, val2str(dip.pitch, 4, true))       -- "biWidth",          4) word単位
	write(filename, val2str(dip.height, 4, true))      -- "biHeight",         4)
	write(filename, "01 00")                           -- "biPlanes",         2)
	write(filename, "18 00")                           -- "biBitCount",       2)
	write(filename, "00 00 00 00")                     -- "biCompression",    4) RGB=0
	write(filename, val2str(
		data_size + align*dip.height, 4, true))        -- "biSizeImage",      4)
	write(filename, "00 00 00 00")                     -- "biXPixPerMeter",   4)
	write(filename, "00 00 00 00")                     -- "biYPixPerMeter",   4)
	write(filename, "00 00 00 00")                     -- "biClrUsed",        4)
	write(filename, "00 00 00 00")                     -- "biClrImporant",    4)
	
	local pos
	local numi=dip.height-1 
	local numj=dip.pitch-1
	for i=0, numi do
		for j=0, numj do
			pos = (dip.buf_pitch*(numi-i)) + j
			if dip.r[i] ~= nil then
				putchar(filename, clamp(0, 0xff, math.ceil(dip.r[pos])))
				putchar(filename, clamp(0, 0xff, math.ceil(dip.g[pos])))
				putchar(filename, clamp(0, 0xff, math.ceil(dip.b[pos])))
			else
				print("erro")
				write(filename, val2str(self.default_color, 3, true))
			end
		end
		-- 4バイト境界
		for j=1, align do
			putchar(filename, 0xff)
		end
	end
	close_file(filename)
end

function _m:ascii(x, y)
	local pos
	local dip = self.dip
	local numi=math.min(dip.height-1, x-1)
	local numj=math.min(dip.pitch-1, y-1)
	local c = {"  ", "..", "--", "++", "**", "##"}
	local cix
	for i=0, numi do
		for j=0, numj do
			pos = dip.buf_pitch*i + j
			cix = math.ceil(clamp(0, 255*3, (dip.r[pos] + dip.g[pos] +dip.b[pos])) / (255*3) * (#c-1)) + 1
			if dip.r[i] ~= nil then
				io.write(c[cix])
			else
				io.write(" ")
			end
		end
		io.write("\n")
	end
end

function _m:putrgb(x, y, r, g, b)
	if x > self.dip.buf_pitch
	or y > self.dip.buf_height then
		print("dip over")
		return
	end

	local pos = self.dip.buf_pitch * y + x
	self.dip.r[pos] = r
	self.dip.g[pos] = g
	self.dip.b[pos] = b
end

function _m:putyuv(x, y, Y, cb, cr)
	if x > self.dip.buf_pitch
	or y > self.dip.buf_height then
		print("dip over")
		return
	end
		local pos = self.dip.buf_pitch * y + x	
	--	print("ITU-R BT.601 / ITU-R BT.709 (1250/50/2:1)")
	self.dip.r[pos] = Y                     + 1.402*(cr-128)
	self.dip.g[pos] = Y - 0.344136*(cb-128) - 0.714136*(cr-128)
	self.dip.b[pos] = Y + 1.772*(cb-128)
	--	print("ITU-R BT.709 (1125/60/2:1)")
	--	dip.r[pos] = Y              +  1.5748*(cr-128)
	--	dip.g[pos] = Y - 0.187324*(cb-128) - 0.468124 *(cr-128)
	--	dip.b[pos] = Y + 1.8556*(cb-128)
end

