-- mp4解析

data = {}
cur_trak = nil

function boxheader()
	-- print("BOX")
	rbyte("boxsize",                     4, data)
	rstr ("boxheader",                   4, data)
	return data["boxsize"].val, data["boxheader"].val
end

function ftyp(size)
	rbyte("MajorBrand",                   4)
	rbyte("MinorVersion",                 4)
	rstr ("CompatibleBrands",             size - 8)
end

function pdin(size)
	rbyte("pdin", size)
end

function afra(size)
	rbyte("afra", size)
end

function abst(size)
	rbyte("abst", size)
end

function asrt(size)
	rbyte("asrt", size)
end

function afrt(size)
	rbyte("afrt", size)
end

function moov(size)
	local total_size = 0;
	while total_size < size do
		local box_size, header = boxheader()
		
		if header == "mvhd" then
			mvhd(box_size-8)
		elseif header == "trak" then
			trak(box_size-8)
		elseif header == "mvex" then
			mvex(box_size-8)
		elseif header == "udta" then
			udta(box_size-8)
		elseif header == "auth" then
			auth(box_size-8)
		else
			print("# unknown box", header)
			rbyte("payload", box_size-8)
		end
		
		total_size = total_size + box_size
	end
end

function mvhd(size)
	rbyte("Version",                      1, data)
	local x = data["Version"].val+1
	
	rbyte("Flags",                      3)
	rbyte("CreationTime",               4 * x)
	rbyte("ModificationTime",           4 * x)
	rbyte("TimeScale",                  4, data)
	rbyte("Duration",                   4 * x)
	rbyte("Rate (fixed16.16)",          4)
	rbyte("Volume (fixed8.8)",          2)
	cbyte("Reserved",                   2, 0)
	rbyte("Reserved",                   4*2)
	rbyte("Matrix(SI32[9])",            4*9)
	rbyte("Reserved",                   4*6)
	rbyte("NextTrackID",                4)
end

function trak(size, header)
	cur_trak = {}
	table.insert(data, cur_trak)

	local total_size = 0;
	while total_size < size do
		local box_size, header = boxheader()
		
		if header == "mdia" then
			mdia(box_size-8)
		elseif header == "edts" then
			edts(box_size-8)
		else
			print("# unknown box", header)
			rbyte("payload", box_size-8)
		end
		
		total_size = total_size + box_size
	end
	
	convert_and_store_timestamp(cur_trak)
end

function tkhd(size)
	rbyte("tkhd", size)
end

function edts(size)
	local box_size, header = boxheader()
	elst(box_size)
end

function elst(size)
	rbyte("Version",                      1, data)
	local x = data["Version"].val+1
	rbyte("Flags",                        3)
	rbyte("EntryCount",                   4, data)
	
	-- ELSTRECORD
	for i=1, data["EntryCount"].val do
		rbyte("SegmentDuration",              4 * x)
		rbyte("MediaTime",                    4 * x, cur_trak)
		rbyte("MediaRateInteger",             2)
		rbyte("MediaRateFraction",            2)
	end
end

function mdia(size)
	local total_size = 0;
	while total_size < size do
		local box_size, header = boxheader()
		
		if header == "mdhd" then
			mdhd(box_size-8)
		elseif header == "minf" then
			minf(box_size-8)
		else
			print("# unknown box", header)
			rbyte("payload", box_size-8)
		end
		
		total_size = total_size + box_size
	end
end

function mdhd(size)
	rbyte("Version",                   1, data)
	rbyte("Flags",                     3)

	local x = data["Version"].val          + 1
	rbyte("CreationTime",              4 * x)
	rbyte("ModificationTime",          4 * x)
	rbyte("TimeScale",                 4, cur_trak)
	rbyte("Duration",                  4 * x)
	rbit("Pad",                        1)
	rbit("Language",                   15)
	rbyte("Reserved",                  2)
end

function hdlr(size)
	rbyte("hdlr", size)
end

function minf(size)
	local total_size = 0;
	while total_size < size do
		local box_size, header = boxheader()
		
		if header == "stbl" then
			stbl(box_size-8)
		else
			print("# unknown box", header)
			rbyte("payload", box_size-8)
		end
		
		total_size = total_size + box_size
	end
end

function vmhd(size)
	rbyte("vmhd", size)
end

function smhd(size)
	rbyte("smhd", size)
end

function hmhd(size)
	rbyte("hmhd", size)
end

function nmhd(size)
	rbyte("nmhd", size)
end

function dinf(size)
	rbyte("dinf", size)
end

function dref(size)
	rbyte("dref", size)
end

function url (size)
	rbyte("url ", size)
end

function stbl(size)
	local total_size = 0;
	while total_size < size do
		local box_size, header = boxheader()
		
		if header == "stsd" then
			stsd(box_size-8)
		elseif header == "stts" then
			stts(box_size-8)
		elseif header == "stsc" then
			stsc(box_size-8)
		elseif header == "stsz" then
			stsz(box_size-8)
		elseif header == "stco" then
			stco(box_size-8)
		elseif header == "ctts" then
			ctts(box_size-8)
		else
			print("# unknown box", header)
			rbyte("payload", box_size-8)
		end
		
		total_size = total_size + box_size
	end
end

function VisualSampleEntryBox(header, size)
	rbyte("Reserved",           6)
	rbyte("DataReferenceIndex", 2)
	rbyte("Predefined",         2)
	rbyte("Reserved",           2)
	rbyte("Predefined",         4)
	rbyte("Width",              2)
	rbyte("Height",             2)
	rbyte("HorizResolution",    4)
	rbyte("VertResolution",     4)
	rbyte("Reserved",           4)
	rbyte("FrameCount",         2)
	rstr ("CompressorName",     32)
	rbyte("Depth",              2)
	rbyte("Predefined",         2)
end

function DESCRIPTIONRECORD(count)
	for i=1, count do
		local begin = cur()
		local box_size, header = boxheader()
		
		print("#"..header)
		cur_trak.descriotir = header
		
		if header == "avc1"
		or header == "avcC"
		or header == "m4ds"
		or header == "btrt" then
			VisualSampleEntryBox(header, box_size-8)
		elseif header == "mp4a" then
		    --
		else
			print("# unknown box", header)
			VisualSampleEntryBox(box_size-8)
		end

		rbyte("#some data", box_size - (cur()-begin))
	end
end

function stsd(size)
	rbyte("Version",      1)
	rbyte("Flags",        3)
	rbyte("Count",        4, data)
	DESCRIPTIONRECORD(data["Count"].val)
end

function rtmp(size)
	rbyte("rtmp", size)
end

function amhp(size)
	rbyte("amhp", size)
end

function amto(size)
	rbyte("amto", size)
end

function encv(size)
	rbyte("encv", size)
end

function enca(size)
	rbyte("enca", size)
end

function encr(size)
	rbyte("encr", size)
end

function sinf(size)
	rbyte("sinf", size)
end

function frma(size)
	rbyte("frma", size)
end

function schm(size)
	rbyte("schm", size)
end

function schi(size)
	rbyte("schi", size)
end

function adkm(size)
	rbyte("adkm", size)
end

function ahdr(size)
	rbyte("ahdr", size)
end

function aprm(size)
	rbyte("aprm", size)
end

function aeib(size)
	rbyte("aeib", size)
end

function akey(size)
	rbyte("akey", size)
end

function aps (size)
	rbyte("aps ", size)
end

function flxs(size)
	rbyte("flxs", size)
end

function asig(size)
	rbyte("asig", size)
end

function adaf(size)
	rbyte("adaf", size)
end

function stts(size)
	rbyte("Version",                              1)
	rbyte("Flags",                                3)
	rbyte("Count",                                4, data)
	
	for i=1, data["Count"].val do
		rbyte("SttsSampleCount",                  4, cur_trak)
		rbyte("SttsSampleDelta",                  4, cur_trak)
	end
end

function ctts(size)
	print("sdfd")
	rbyte("Version",              1)
	rbyte("Flags",                3)
	rbyte("Count",                4, data)
	for i=1, data["Count"].val do
		rbyte("CttsSampleCount",  4, cur_trak)
		rbyte("CttsSampleOffset", 4, cur_trak)
	end
end

function stsc(size)
	rbyte("stsc", size)
end

function stsz(size)
	rbyte("Version",                        1)
	rbyte("Flags",                          3)
	rbyte("ConstantSize",                   4)
	rbyte("SizeCount",                      4, data)
	for i=1, data["SizeCount"].val do
		rbyte("SizeTable",                  4, cur_trak)
	end
end

function stco(size)
	rbyte("Version",                     1)
	rbyte("Flags",                       3)
	rbyte("OffsetCount",                 4, data)
	for i=1, data["OffsetCount"].val do
		rbyte("StcoOffsets",             4, cur_trak)
	end
end

function co64(size)
	rbyte("Version",                     4)
	rbyte("Flags",                       4)
	rbyte("OffsetCount",                 4, data)
	for i=1, data["OffsetCount"].val do
		rbyte("StcoOffsets",             8, cur_trak)
	end
end

function stss(size)
	rbyte("stss", size)
end

function sdtp(size)
	rbyte("sdtp", size)
end

function mvex(size)
	rbyte("mvex", size)
end

function mehd(size)
	rbyte("mehd", size)
end

function trex(size)
	rbyte("trex", size)
end

function auth(size)
	rbyte("auth", size)
end

function titl(size)
	rbyte("titl", size)
end

function dscp(size)
	rbyte("dscp", size)
end

function cprt(size)
	rbyte("cprt", size)
end

function udta(size)
	rbyte("udta", size)
end

function uuid(size)
	rbyte("uuid", size)
end

function moof(size)
	rbyte("moof", size)
end

function mfhd(size)
	rbyte("mfhd", size)
end

function traf(size)
	rbyte("traf", size)
end

function tfhd(size)
	rbyte("tfhd", size)
end

function trun(size)
	rbyte("trun", size)
end

function mdat(size)
	rbyte("mdat", size)
end

function meta(size)
	rbyte("meta", size)
end

function ilst(size)
	rbyte("ilst", size)
end

function free(size)
	rbyte("free", size)
end

function skip(size)
	rbyte("skip", size)
end

function mfra(size)
	rbyte("mfra", size)
end

function tfra(size)
	rbyte("tfra", size)
end

function mfro(size)
	rbyte("mfro", size)
end

function mp4(size)
	local total_size = 0
	while total_size < size do
		local box_size, header = boxheader()

		if header == "ftyp" then
			ftyp(box_size-8)
		elseif header == "moov" then
			moov(box_size-8)
		elseif header == "mdat" then
			mdat(box_size-8)
		else
			print("# unknown box", header)
			rbyte("payload", box_size-8)
		end
		
		total_size = total_size + box_size
	end
	return size, header
end

----------------------------------------
-- 解析用util
----------------------------------------

function convert_and_store_timestamp(trak)	
	local time_scale = trak.TimeScale.val

	-- tick単位のDTS
	local DTS_in_tick = {}
	local total_tick = 0
	for i=1, #(trak.SttsSampleCount.tbl) do
		local count = trak.SttsSampleCount.tbl[i]
		local delta = trak.SttsSampleDelta.tbl[i]
		for i=1, count do
			table.insert(DTS_in_tick, total_tick)
			total_tick = total_tick + delta
		end
	end

	-- 秒単位に変換保管
	local DTS = {}
	for i=1, #DTS_in_tick do
		table.insert(DTS, DTS_in_tick[i]/time_scale)
	end

	-- テーブルに保管
	trak.DTS = DTS

	if trak.CttsSampleCount and next(trak.CttsSampleCount.tbl) then
		-- tick単位のPTS
		local PTS_in_tick = {}
		local ix = 1
		for i=1, #(trak.CttsSampleCount.tbl) do
			local count  = trak.CttsSampleCount.tbl[i]
			local offset = trak.CttsSampleOffset.tbl[i]
			for i=1, count do
				table.insert(PTS_in_tick, DTS_in_tick[ix]+offset)
				ix = ix + 1
			end
		end
		
		local PTS = {}
		for i=1, #PTS_in_tick do
			table.insert(PTS, PTS_in_tick[i]/time_scale)
		end
		
		-- テーブルに保管
		trak.PTS = PTS
	else
		print("no PTS")
	end
end

stream = open_stream(__stream_name__)
stdout_to_file(false)
print_on(false)

mp4(file_size())

print_status()
save_as_csv("data.csv", data)

