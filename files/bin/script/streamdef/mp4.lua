-- mp4解析
local cur_trak = nil
local trak_no = 0
local trak_data = {}
local nal_offset = {}
local nal_size = {}

function BOXHEADER()
	rbyte("boxsize",                     4)
	rstr ("BOXHEADER",                   4)

	if get("boxsize") == 1 then
		rbyte("boxsize_upper32bit",      4)
		rbyte("boxsize",                 4)
		printf("adr=0x%08x, siz=0x%08x      %s", cur(), get("boxsize"), get("BOXHEADER"))
		return get("BOXHEADER"), get("boxsize"), 16
	else
		printf("adr=0x%08x, siz=0x%08x      %s", cur(), get("boxsize"), get("BOXHEADER"))
		return get("BOXHEADER"), get("boxsize"), 8
	end
end

function unknown_data(size, begin)
	local remain = size - (cur() - begin)
	if remain ~= 0 then
		print("#unknown data at"..hexstr(cur()), "size="..hexstr(remain))
		rbyte("#unknown data", remain)
	end
end

function unsupported_box(header, box_size, header_size)
	print("# unsupported box", header)
	rbyte("payload", box_size-header_size)
end

function ftyp(size)
	rstr ("MajorBrand",                   4)
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
		local header, box_size, header_size = BOXHEADER()

		if header == "mvhd" then
			mvhd(box_size-header_size)
		elseif header == "trak" then
			trak(box_size-header_size)
		elseif header == "mvex" then
			mvex(box_size-header_size)
		elseif header == "udta" then
			udta(box_size-header_size)
		elseif header == "auth" then
			auth(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end
end

function mvhd(size)
	rbyte("Version",                      1)
	local x = get("Version")+1

	rbyte("Flags",                        3)
	rbyte("CreationTime",                 4 * x)
	rbyte("ModificationTime",             4 * x)
	rbyte("TimeScale",                    4)
	rbyte("Duration",                     4 * x)
	rbyte("Rate (fixed16.16)",            4)
	rbyte("Volume (fixed8.8)",            2)
	cbyte("Reserved",                     2, 0)
	rbyte("Reserved",                     4*2)
	rbyte("Matrix(SI32[9])",              4*9)
	rbyte("Reserved",                     4*6)
	rbyte("NextTrackID",                  4)
end

function trak(size, header)
	cur_trak = {}

	local total_size = 0;
	while total_size < size do
		local header, box_size, header_size = BOXHEADER()

		if header == "mdia" then
			mdia(box_size-header_size)
		elseif header == "edts" then
			edts(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end

	analyse_trak(cur_trak)
end

function tkhd(size)
	rbyte("tkhd", size)
end

function edts(size)
	local header, box_size, header_size = BOXHEADER()
	elst(box_size)
end

function elst(size)
	rbyte("Version",                 1)
	local x = get("Version")+1
	rbyte("Flags",                   3)
	rbyte("EntryCount",              4)

	-- ELSTRECORD
	for i=1, get("EntryCount") do
		rbyte("SegmentDuration",     4 * x)
		rbyte("MediaTime",           4 * x)
		rbyte("MediaRateInteger",    2)
		rbyte("MediaRateFraction",   2)

	end
end

function mdia(size)
	local total_size = 0;
	while total_size < size do
		local header, box_size, header_size = BOXHEADER()

		if header == "mdhd" then
			mdhd(box_size-header_size)
		elseif header == "minf" then
			minf(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end
end

function mdhd(size)
	rbyte("Version",                   1)
	rbyte("Flags",                     3)

	local x = get("Version") + 1
	rbyte("CreationTime",              4 * x)
	rbyte("ModificationTime",          4 * x)
	rbyte("TimeScale",                 4)
	rbyte("Duration",                  4 * x)
	rbit ("Pad",                       1)
	rbit ("Language",                  15)
	rbyte("Reserved",                  2)
end

function hdlr(size)
	rbyte("hdlr", size)
end

function minf(size)
	local total_size = 0;
	while total_size < size do
		local header, box_size, header_size = BOXHEADER()

		if header == "stbl" then
			stbl(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
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
	rbyte("dinf", 0)
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
		local header, box_size, header_size = BOXHEADER()

		if header == "stsd" then
			stsd(box_size-header_size)
		elseif header == "stts" then
			stts(box_size-header_size)
		elseif header == "stsc" then
			stsc(box_size-header_size)
		elseif header == "stsz" then
			stsz(box_size-header_size)
		elseif header == "stco" then
			stco(box_size-header_size)
		elseif header == "stss" then
			stss(box_size-header_size)
		elseif header == "ctts" then
			ctts(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end
end

function HEVCDecoderConfigurationRecord()
	rbit("configurationVersion",              8, 1)
	rbit("profile_space",                     2)
	rbit("tier_flag",                         1)
	rbit("profile_idc",                       5)
	rbit("profile_compatibility_flags",       32)
	rbit("constraint_indicator_flags",        48)
	rbit("level_idc",                         8)
	cbit("reserved",                          4, 0xf)
	rbit("min_spatial_segmentation_idc",      12)
	cbit("reserved",                          6, 0x3f)
	rbit("parallelismType",                   2)
	cbit("reserved",                          6, 0x3f)
	rbit("chromaFormat",                      2)
	cbit("reserved",                          5, 0x1f)
	rbit("bitDepthLumaMinus8",                3)
	cbit("reserved",                          5, 0x1f)
	rbit("bitDepthChromaMinus8",              3)
	rbit("avgFrameRate",                      16)
	rbit("constantFrameRate",                 2)
	rbit("numTemporalLayers",                 3)
	rbit("temporalIdNested",                  1)
	rbit("lengthSizeMinusOne",                2)
	rbit("numOfArrays",                       8)
	for j=0, get("numOfArrays")-1 do
		rbit("array_completeness",            1)
		rbit("reserved",                      1, 0)
		local NAL_unit_type =
		rbit("NAL_unit_type",                 6)
		rbit("numNalus",                      16)
		for i=0, get("numNalus")-1 do
			local nalUnitLength =
			rbit("nalUnitLength",             16)
			table.insert(nal_offset, (cur()))
			table.insert(nal_size, nalUnitLength)
			rbit("nalUnit",                   8*get("nalUnitLength"))
		end
	end
end

function HEVCSampleEntry(size)
	local begin = cur()
	local hvcC_exists = false
	VisualSampleEntryBox()

	local total_size = cur() - begin;
	while total_size < size do
		local header, box_size, header_size = BOXHEADER()

		if header == "m4ds" then
			MPEG4ExtensionDescriptorsBox(box_size - header_size)
		elseif header == "hvcC" then
			HEVCDecoderConfigurationRecord()
			hvcC_exists = true
		elseif header == "btrt" then
			MPEG4BitRateBox()
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end

	assert(hvcC_exists, "hvcC not exists")
end

function MPEG4BitRateBox()
	rbit("bufferSizeDB",         32) -- unsigned int(32)
	rbit("maxBitrate",           32) -- unsigned int(32)
	rbit("avgBitrate",           32) -- unsigned int(32)
end

function MPEG4ExtensionDescriptorsBox(size)
	rstr("Descriptor", size)
end

function AVCSampleEntry(size)
	local begin = cur()

	VisualSampleEntryBox()

	local total_size = cur() - begin;
	while total_size < size do
		local begin = cur()
		local header, box_size, header_size = BOXHEADER()

		if header == "m4ds" then
			MPEG4ExtensionDescriptorsBox(box_size - header_size)
		elseif header == "avcC" then
			AVCConfigurationBox()
		elseif header == "btrt" then
			MPEG4BitRateBox()
		else
			unsupported_box(header, box_size, header_size)
		end
	
		unknown_data(box_size, begin)

		total_size = total_size + box_size
	end
end


function AVCConfigurationBox()
	AVCDecoderConfigurationRecord()
end

function VisualSampleEntryBox()
	rbyte("Reserved",                    6)
	rbyte("DataReferenceIndex",          2)
	rbyte("Predefined",                  2)
	rbyte("Reserved",                    2)
	rbyte("Predefined[3]",               4*3)
	rbyte("Width",                       2)
	rbyte("Height",                      2)
	rbyte("HorizResolution",             4)
	rbyte("VertResolution",              4)
	rbyte("Reserved",                    4)
	rbyte("FrameCount",                  2)
	rstr ("CompressorName",              32)
	rbyte("Depth",                       2)
	rbyte("Predefined",                  2)
end

function AVCDecoderConfigurationRecord()
	cbit("configurationVersion",            8, 1) -- unsigned int(8)
	rbit("AVCProfileIndication",            8) -- unsigned int(8)
	rbit("profile_compatibility",           8) -- unsigned int(8)
	rbit("AVCLevelIndication",              8) -- unsigned int(8)
	cbit("reserved",                        6, 0x3f)
	rbit("lengthSizeMinusOne",              2) -- unsigned int(2)
	cbit("reserved",                        3, 0x7)
	rbit("numOfSequenceParameterSets",      5) -- unsigned int(5)
	for i=0, get("numOfSequenceParameterSets") - 1 do
		rbit("sequenceParameterSetLength",  16) -- unsigned int(16)
		table.insert(nal_offset, (cur()))
		table.insert(nal_size, get("sequenceParameterSetLength"))
		rbit("sequenceParameterSetNALUnit", 8*get("sequenceParameterSetLength"))
	end
	rbit("numOfPictureParameterSets",       8) -- unsigned int(8)
	for i=0, get("numOfPictureParameterSets") - 1 do
		rbit("pictureParameterSetLength",   16) -- unsigned int(16)
		table.insert(nal_offset, (cur()))
		table.insert(nal_size, get("sequenceParameterSetLength"))
		rbit("pictureParameterSetNALUnit",  8*get("pictureParameterSetLength"))
	end
end

function DESCRIPTIONRECORD()
	local header, box_size, header_size = BOXHEADER()

	cur_trak.descriptor = header

	if header == "avc1" then
		AVCSampleEntry(box_size - header_size)
	elseif header == "hvc1" then
		HEVCSampleEntry(box_size - header_size)
	elseif header == "mp4a" then
		rbyte("some data", box_size - header_size)
	else
		unsupported_box(header, box_size, header_size)
	end
end

function stsd(size)
	local begin = cur()

	rbyte("Version",      1)
	rbyte("Flags",        3)
	rbyte("Count",        4)
	for i=1, get("Count") do
		DESCRIPTIONRECORD()
	end

	unknown_data(size, begin)
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
	rbyte("Version",                                        1)
	rbyte("Flags",                                          3)
	store_to_table(cur_trak, "Count", rbyte("Count",                 4))

	for i=1, get("Count") do
		store_to_table(cur_trak, "SttsSampleCount", rbyte("SttsSampleCount",   4))
		store_to_table(cur_trak, "SttsSampleDelta", rbyte("SttsSampleDelta",   4))
	end
end

function ctts(size)
	rbyte("Version",                                        1)
	rbyte("Flags",                                          3)
	rbyte("Count",                                          4)
	for i=1, get("Count") do
		store_to_table(cur_trak, "CttsSampleCount",  rbyte("CttsSampleCount",   4))
		store_to_table(cur_trak, "CttsSampleOffset", rbyte("CttsSampleOffset",  4))
	end
end

function STSCRECORD()
	store_to_table(cur_trak, "FirstChunk",      rbyte("FirstChunk",            4))
	store_to_table(cur_trak, "SamplesPerChunk", rbyte("SamplesPerChunk",       4))
	store_to_table(cur_trak, "SampleDescIndex", rbyte("SampleDescIndex",       4))
end

function stsc(size)
	rbyte("Version",                                        1)
	rbyte("Flags",                                          3)
	rbyte("Count",                                          4)
	for i=1, get("Count") do
		STSCRECORD()
	end
end

function stsz(size)
	rbyte("Version",                                        1)
	rbyte("Flags",                                          3)
	rbyte("ConstantSize",                                   4)
	rbyte("SizeCount",                                      4)
	if get("ConstantSize") == 0 then
		for i=1, get("SizeCount") do
			store_to_table(cur_trak, "SizeTable", rbyte("SizeTable",         4))
		end
	else
		for i=1, get("SizeCount") do
			store_to_table(cur_trak, "SizeTable", get("ConstantSize"))
		end
	end
end

function stco(size)
	rbyte("Version",                                        1)
	rbyte("Flags",                                          3)
	rbyte("OffsetCount",                                    4)
	for i=1, get("OffsetCount") do
		store_to_table(cur_trak, "StcoOffsets", rbyte("StcoOffsets",       4))
	end
end

function co64(size)
	assert("unsupported size")
	rbyte("Version",                                        4)
	rbyte("Flags",                                          4)
	rbyte("OffsetCount",                                    4)
	for i=1, get("OffsetCount") do
		store_to_table(cur_trak, "StcoOffsets", rbyte("StcoOffsets",       8))
	end
end

function stss(size)
	rbyte("Version",                                        1)
	rbyte("Flags",                                          3)
	rbyte("SyncCount",                                      4)
	for i=1, get("SyncCount") do
		store_to_table(cur_trak, "SyncTable", rbyte("SyncTable",         4))
	end
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
	local total_size = 0;
	while total_size < size do
		local header, box_size, header_size = BOXHEADER()

		if header == "mfhd" then
			mfhd(box_size-header_size)
		elseif header == "traf" then
			traf(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end
end

function mfhd(size)
	rbyte("mfhd", size)
end

function traf(size)
	local total_size = 0;
	while total_size < size do
		local header, box_size, header_size = BOXHEADER()

		if header == "mfhd" then
			mfhd(box_size-header_size)
		elseif header == "traf" then
			traf(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end
end

function SAMPLEFLAGS()
	rbit("Reserved",                  6)
	rbit("SampleDependsOn",           2)
	rbit("SampleIsDependedOn",        2)
	rbit("SampleHasRedundancy",       2)
	rbit("SamplePaddingValue",        3)
	rbit("SampleIsDifferenceSample",  1)
	rbit("SampleDegradationPriority", 16)
end

function tfhd(size)
	rbyte("Version",                      1)
	rbyte("Flags",                        3)
	rbyte("TrackID",                      4)
	if get("Flags") & 0x000001 then
		rbyte("BaseDataOffset",           8)
	end
	if get("Flags") & 0x000002 then
		rbyte("SampleDescriptionIndex",   4)
	end
	if get("Flags") & 0x000008 then
		rbyte("DefaultSampleDuration",    4)
	end
	if get("Flags") & 0x000010 then
		rbyte("DefaultSampleSize",        4)
	end
	if get("Flags") & 0x000020 then
		-- DefaultSampleFlags
		SAMPLEFLAGS()
	end
end

function SampleInformationStructure(Flags)
	-- SampleInformation
	if Flags & 0x000100 then
		rbyte("SampleDuration",               4)
	end
	if Flags & 0x000200 then
		rbyte("SampleSize",                   4)
	end
	if Flags & 0x000400 then
		-- SampleFlags
		SAMPLEFLAGS()
	end
	if Flags & 0x000800 then
		rbyte("SampleCompositionTimeOffset",  4)
	end
end

function trun(size)
	rbyte("Version",                              1)
	rbyte("Flags",                                3)
	rbyte("SampleCount",                          4)
	if get("Flags") & 0x000001 then
		rbyte("DataOffset",                       4)
	end
	if get("Flags") & 0x000004 then
		-- SampleFlags
		SAMPLEFLAGS()
	end
	local Flags = get("Flags")
	for i=1, get("SampleCount") do
		-- SampleInformation
		SampleInformationStructure(Flags)
	end
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
	-- local total_size = 0
	-- while total_size < size do
	-- 	local header, box_size, header_size = BOXHEADER()
	-- 	rbyte("payload", box_size-header_size)
	-- 	total_size = total_size + box_size
	-- end
	-- return size, header
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
		local header, box_size, header_size = BOXHEADER()

		if header == "ftyp" then
			ftyp(box_size-header_size)
		elseif header == "free" then
			free(box_size-header_size)
		elseif header == "moov" then
			moov(box_size-header_size)
		elseif header == "moof" then
			moof(box_size-header_size)
		elseif header == "mdat" then
			mdat(box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		total_size = total_size + box_size
	end
	return total_size
end

----------------------------------------
-- 解析用util
----------------------------------------
function analyse_trak(trak)
	local result = {}

	local time_scale = get("TimeScale")

	-- samples
	local chunk_no = 1
	local sample_in_chunk = 1
	local stsc_no = 1
	local samples_per_chunk = trak.SamplesPerChunk.tbl[stsc_no]
	local next_stsc = trak.FirstChunk.tbl[stsc_no]
	local sample_size = 0
	local size_in_chunk = 0
	local No = {}
	local Size = {}
	local Chunk = {}
	local Offset = {}
	for sample_no = 1, get("SizeCount") do

		-- sample to chunk更新
		if chunk_no == next_stsc then
			samples_per_chunk = trak.SamplesPerChunk.tbl[stsc_no] or samples_per_chunk
			next_stsc = trak.FirstChunk.tbl[stsc_no + 1] or get("SizeCount") -- とりあえず
			stsc_no = stsc_no + 1
		end

		-- サンプルサイズ
		sample_size = trak.SizeTable.tbl[sample_no]

		-- 各種値を保存
		table.insert(No, sample_no)
		table.insert(Size, sample_size)
		table.insert(Chunk, chunk_no)
		table.insert(Offset, trak.StcoOffsets.tbl[chunk_no] + size_in_chunk)

		-- chunk or sampleのカウントアップ
		if sample_in_chunk == samples_per_chunk then
			sample_in_chunk = 1
			chunk_no = chunk_no + 1
			size_in_chunk = 0
		else
			sample_in_chunk = sample_in_chunk + 1
			size_in_chunk = size_in_chunk + sample_size
		end
	end
	store(trak.descriptor.."No.", No)
	store(trak.descriptor.."Size", Size)
	store(trak.descriptor.."Chunk", Chunk)
	store(trak.descriptor.."Offset", Offset)

	-- DTS
	local DTS = {}
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
	for i=1, #DTS_in_tick do
		table.insert(DTS, DTS_in_tick[i]/time_scale)
	end
	store(trak.descriptor.."DTS", DTS)

	-- PTS
	local PTS = {}
	if trak.CttsSampleCount and next(trak.CttsSampleCount.tbl) then
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
		for i=1, #PTS_in_tick do
			table.insert(PTS, PTS_in_tick[i]/time_scale)
		end
		store(trak.descriptor.."PTS", PTS)
	else
		print("no PTS in ", cur_trak.descriptor)
	end

	-- ES書き出し
	-- Videoであれば解析
	print(cur_trak.descriptor)
	local prev = cur()
	local out_file_name = __out_dir__..trak.descriptor..".es"
	if trak.descriptor == "avc1"
	or trak.descriptor == "hvc1" then
		for i, v in ipairs(nal_offset) do
			seek(nal_offset[i])
			write(out_file_name, val2str(nal_size[i], get("lengthSizeMinusOne")+1))
			tbyte("nal", nal_size[i], out_file_name)
		end
	end
	for i = 1, #Offset do
		seek(Offset[i])
		tbyte("es", Size[i], out_file_name)
	end
	
	
	
	
	
	
	print("analyze es?")
	if io.read() == "y" then
		if trak.descriptor == "avc1" then
			dofile(__streamdef_dir__.."h264.lua")
			local stream, prev = open(out_file_name)
			length_stream(get("lengthSizeMinusOne")+1)
			swap(prev)
		elseif trak.descriptor == "hvc1" then
			dofile(__streamdef_dir__.."h265.lua")
			local stream, prev = open(out_file_name)
			length_stream(get("lengthSizeMinusOne")+1)
			swap(prev)
		end
	end
	seek(prev)
	
	
	
	
	

	-- タイムスタンプ書き出し用
	trak_no = trak_no + 1
	trak_data[trak_no] = {}
	trak_data[trak_no].i = 1
	trak_data[trak_no].descriptor = cur_trak.descriptor
	trak_data[trak_no].PTS = PTS
	trak_data[trak_no].DTS = DTS
	trak_data[trak_no].Offset = Offset
	table.insert(trak_data[trak_no].Offset, false) -- 番兵
end

function analyse_mp4()
	local c = csv:new()
	local min_ofs = 0x7fffffff
	local min_i
	local end_count = 0
	while true do
		min_i = 1
		min_ofs = 0x7fffffff
		end_count = 0

	    -- Offsetの一番近いtrakを調べる、出力済みならカウントアップ
		for i, v in ipairs(trak_data) do
			if v.Offset[v.i] == false then
				end_count = end_count+1
			else
				if v.Offset[v.i] < min_ofs then
					min_ofs = v.Offset[v.i]
					min_i = i
				end
			end
		end

	    -- 全部出力済みで終了
		if end_count == #trak_data then
			c:save(__out_dir__.."/timestamp.csv")
			break
		end

	    -- CSVに保存、offsetがまだのtrakはfalseを書き込みcsv上で空欄にする
		c:insert("Offset", min_ofs)
		for i, v in ipairs(trak_data) do

			if v.Offset[v.i] ~= false then
				if min_i == i then
					c:insert(v.descriptor.." DTS", v.DTS[v.i])
					v.i = v.i + 1
				else
					c:insert(v.descriptor.." DTS", "")
				end
			else
				c:insert(v.descriptor.." DTS", "")
			end
		end
	end
end

--reset("lengthSizeMinusOne", 3)

--open(__stream_path__)
enable_print(false)
mp4(get_size())
save_as_csv(__out_dir__.."mp4.csv")
analyse_mp4()

