-- wav作成
-- とりあえず2ch限定

local name = ...           -- 第一引数がモジュール名
local _m = {}              -- メンバ関数を補樹威するテーブル
local _meta = {__index=_m} 
local _v = {}              -- プライベート変数(selfをキーとするテーブル)
package.loaded[name] = _m  -- 二度目のrequire()はこれが返される
_G[name] = _m              -- グローバルに登録しておく

------------------------------------------------
-- private
------------------------------------------------

------------------------------------------------
-- public
------------------------------------------------

function _m:new(sampling_rate, channels)
	local obj = {
		sampling_rate = sampling_rate or 44100,
		channels = channels or 2,
		samples = {{}, {}}
	}

	setmetatable(obj, _meta)
	return obj
end

function _m:write(filename)
	local data_size = #self.samples[1] * self.channels * 2
	print("sampling rate:", self.sampling_rate)
	print("channels     :", self.channels)
	print("sample num   :", #self.samples[1])
	print("play time    :", #self.samples[1]/self.sampling_rate)
	
	write(filename, "RIFF")                           -- "RIFF",                        
	write(filename, val2str(
		data_size + 36, 4, true))                     -- "ckSize",                      
	write(filename, "WAVE")                           -- "WAVE",                        
	write(filename, "fmt ")                           -- "fmt ",                        
	write(filename, "10 00 00 00")                    -- "size",                        
	write(filename, "01 00")                          -- "format PCM=1",                      
	write(filename, "02 00")                          -- "channels",                    
	write(filename, val2str(
		self.sampling_rate, 4, true))                 -- "samplerate",                  
	write(filename, val2str(
		self.sampling_rate*self.channels*2, 4, true)) -- "bytepersec",                  
	write(filename, "04 00")                          -- "block_size(smaple_x_channel)",
	write(filename, "10 00")                          -- "bit_depth",                   
	write(filename, "data")                           -- "ckID",                        
	write(filename, val2str(
		data_size, 4, true))                           -- "ckSize",
	
	local l, r
	for i, v in pairs(self.samples[1]) do
		l = math.floor(self.samples[1][i]*0x7ffe)
		r = math.floor(self.samples[2][i]*0x7ffe)
		write(filename, val2str(l, 2, true))
		write(filename, val2str(r, 2, true))
	end
	close_file(filename)
end	

-- -1 ~ 1で指定
function _m:append_sample(l, r)
	table.insert(self.samples[1], l)
	table.insert(self.samples[2], r)
end

function _m:set_sample(index, l, r)
	self.samples[1][index] = l
	self.samples[2][index] = r
end

