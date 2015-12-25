-- mp4解析
local cur_trak = nil
local trak_no = 0
local trak_data = {}
local nal_offset = {}
local nal_size = {}
local box_tree = {}

function push_box()
	seekoff(4)
	local box_name = gstr(4)
	table.insert(box_tree, box_name)
	push(box_name)
	seekoff(-8)
end

function pop_box()
	pop(box_tree[#box_tree])
	table.remove(box_tree)
end

local tree_depth = 1
function child_boxes(list, size)
	local begin = cur()
	local total_size = 0
	while total_size < size do
		local child_begin = cur()
	
		-- boxをプッシュ
		seekoff(4)
		local box_name = gstr(4)
		seekoff(-8)
		push(box_name)
		tree_depth = tree_depth + 1
		
		-- boxを解析
		local box_begin = cur()
		local header, box_size, header_size = BOXHEADER()
		printf("adr=0x%08x, siz=0x%08x "..string.rep("     ", tree_depth).."%s", box_begin, get("boxsize"), get("BOXHEADER"))
		if list[header] ~= nil then
			list[header](box_size-header_size)
		else
			unsupported_box(header, box_size, header_size)
		end

		-- たまにサイズが合わないけどよくわからない
		unknown_data(box_size, child_begin, header)

		-- boxをポップ
		pop(header)
		tree_depth = tree_depth - 1

		total_size = total_size + box_size
	end

	-- サイズチェック
	if cur() - begin ~= size then
		assert(false, "box size error")
	end
end

function BOXHEADER()
	rbyte("boxsize",                     4)
	rstr ("BOXHEADER",                   4)

	if get("boxsize") == 1 then
		rbyte("boxsize_upper32bit",      4)
		rbyte("boxsize",                 4)
		return get("BOXHEADER"), get("boxsize"), 16
	else
		return get("BOXHEADER"), get("boxsize"), 8
	end
end

function unknown_data(size, begin, str)
	local remain = size - (cur() - begin)
	if remain ~= 0 then
		print("#unknown data at"..hexstr(cur()), "size="..hexstr(remain), "\""..str.."\"")
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
	child_boxes({mvhd=mvhd, trak=trak, mvex=mvex, udta=udta, auth=auth, titl=titl, dscp=dscp, cprt=cprt}, size)
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

	child_boxes({mdia=mdia, tref=tref, tkhd=tkhd, edts=edts}, size)

	analyse_trak(cur_trak)
end

function tkhd(size)
	print(" --> unsupported")
	rbyte("tkhd", size)
end

function tref(size)
	print(" --> unsupported")
	rbyte("tkhd", size)
end

function edts(size)
	child_boxes({elst=elst}, size)
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
	child_boxes({mdhd=mdhd, minf=minf, hdlr=hdlr}, size)
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
	print(" --> unsupported")
	rbyte("hdlr", size)
end

function minf(size)
	child_boxes({stbl=stbl, vmhd=vmhd, smhd=smhd, hmhd=hmhd, nmhd=nmhd, dinf=dinf}, size)
end

function vmhd(size)
	print(" --> unsupported")
	rbyte("vmhd", size)
end

function smhd(size)
	print(" --> unsupported")
	rbyte("smhd", size)
end

function hmhd(size)
	print(" --> unsupported")
	rbyte("hmhd", size)
end

function nmhd(size)
	print(" --> unsupported")
	rbyte("nmhd", size)
end

function dinf(size)
	print(" --> unsupported")
	rbyte("dinf", size)
	-- child_boxes({dref=dref}, size)
end

function dref(size)
	child_boxes({url=url}, size)
end

function url (size)
	print(" --> unsupported")
	rbyte("url ", size)
end

function stbl(size)
	child_boxes({stsd=stsd, stts=stts, stsc=stsc, stsz=stsz, stco=stco, stss=stss, ctts=ctts}, size)
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

	child_boxes({
		m4ds=MPEG4ExtensionDescriptorsBox,
		hvcC=HEVCDecoderConfigurationRecord,
		btrt=MPEG4BitRateBox},
		size - (cur() - begin))
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

	child_boxes({
		m4ds=MPEG4ExtensionDescriptorsBox,
		avcC=AVCConfigurationBox,
		btrt=MPEG4BitRateBox},
		size - (cur() - begin))
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
	push_box()
	local header, box_size, header_size = BOXHEADER()

	cur_trak.descriptor = header

	if header == "avc1" then
		AVCSampleEntry(box_size - header_size)
	elseif header == "hvc1"
	or     header == "hev1"
	or     header == "hvcC" then
		HEVCSampleEntry(box_size - header_size)
	elseif header == "mp4a" then
		rbyte("some data", box_size - header_size)
	else
		unsupported_box(header, box_size, header_size)
	end
	pop_box()
end

function stsd(size)
	local begin = cur()

	rbyte("Version",      1)
	rbyte("Flags",        3)
	rbyte("Count",        4)
	for i=1, get("Count") do
		DESCRIPTIONRECORD()
	end

	--sample entry boxes
	child_boxes({rtmp=rtmp, rtmp=rtmp, encv=encv, enca=enca, encr=encr}, size - (cur() - begin))
	unknown_data(size, begin, "stsd")
end

function rtmp(size)
	child_boxes({amhp=amhp, amto=amto}, size)
end

function amhp(size)
	print(" --> unsupported")
	rbyte("amhp", size)
end

function amto(size)
	print(" --> unsupported")
	rbyte("amto", size)
end

function encv(size)
	print(" --> unsupported")
	rbyte("encv", size)
end

function enca(size)
	print(" --> unsupported")
	rbyte("enca", size)
end

function encr(size)
	child_boxes({sinf=sinf}, size)
end

function sinf(size)
	child_boxes({frma=frma, schm=schm, schi=schi}, size)
end

function frma(size)
	print(" --> unsupported")
	rbyte("frma", size)
end

function schm(size)
	print(" --> unsupported")
	rbyte("schm", size)
end

function schi(size)
	child_boxes({adkm=adkm}, size)
end

function adkm(size)
	print(" --> unsupported")
	rbyte("adkm", size)
end

function ahdr(size)
	print(" --> unsupported")
	rbyte("ahdr", size)
end

function aprm(size)
	print(" --> unsupported")
	rbyte("aprm", size)
end

function aeib(size)
	print(" --> unsupported")
	rbyte("aeib", size)
end

function akey(size)
	print(" --> unsupported")
	rbyte("akey", size)
end

function aps (size)
	print(" --> unsupported")
	rbyte("aps ", size)
end

function flxs(size)
	print(" --> unsupported")
	rbyte("flxs", size)
end

function asig(size)
	print(" --> unsupported")
	rbyte("asig", size)
end

function adaf(size)
	print(" --> unsupported")
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
		nest_call("STSCRECORD", STSCRECORD)
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
	assert(false, "unsupported size")
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
	child_boxes({mehd=mehd, trex=trex}, size)
end

function mehd(size)
	print(" --> unsupported")
	rbyte("mehd", size)
end

function trex(size)
	print(" --> unsupported")
	rbyte("trex", size)
end

function auth(size)
	print(" --> unsupported")
	rbyte("auth", size)
end

function titl(size)
	print(" --> unsupported")
	rbyte("titl", size)
end

function dscp(size)
	print(" --> unsupported")
	rbyte("dscp", size)
end

function cprt(size)
	print(" --> unsupported")
	rbyte("cprt", size)
end

function udta(size)
	print(" --> unsupported")
	rbyte("udta", size)
end

function uuid(size)
	print(" --> unsupported")
	rbyte("uuid", size)
end

function moof(size)
	child_boxes({mfhd=mfhd, traf=traf}, size)
end

function mfhd(size)
	rbyte("Version",                      1)
	rbyte("Flags",                        3)
	rbyte("SequenceNumber",               4)
end

function traf(size)
	--enable_print(true)
	child_boxes({tfhd=tfhd, trun=trun, tfdt=tfdt}, size)
end

local SampleDependOn
function SAMPLEFLAGS()
	rbit("Reserved", 6)
	SampleDependOn = rbit("SampleDependsOn", 2)
	rbit("SampleIsDependedOn", 2)
	rbit("SampleHasRedundancy", 2)
	rbit("SamplePaddingValue", 3)
	rbit("SampleIsDifferenceSample", 1)
	rbit("SampleDegradationPriority", 16)
end

local DefaultSampleDependOn
local DefaultBaseDataOffset
local DefaultSampleSize
local DefaultSampleDuration
function tfhd(size)
	rbyte("Version",                      1)
	rbyte("Flags",                        3)
	rbyte("TrackID",                      4)
	if get("Flags") & 0x000001 ~= 0 then
		rbyte("BaseDataOffset",           8)
	end
	if get("Flags") & 0x000002 ~= 0 then
		rbyte("SampleDescriptionIndex",   4)
	end
	if get("Flags") & 0x000008 ~= 0 then
		DefaultSampleDuration = rbyte("DefaultSampleDuration",    4)
	end
	if get("Flags") & 0x000010 ~= 0 then
		DefaultSampleSize = rbyte("DefaultSampleSize",        4)
	end
	if get("Flags") & 0x000020 ~= 0 then
		nest_call("DefaultSampleFlags", SAMPLEFLAGS)
		DefaultSampleDependOn = get("SampleDependsOn")
	end
end

local SampleDuration
local SampleSize
local SampleCompositionTimeOffset
function SampleInformationStructure(Flags)
	if Flags & 0x000100 ~= 0 then
		SampleDuration = rbyte("SampleDuration", 4)
	end
	if Flags & 0x000200 ~= 0 then
		SampleSize = rbyte("SampleSize", 4)
	end
	if Flags & 0x000400 ~= 0 then
		nest_call("SampleFlags", SAMPLEFLAGS)
	end
	if Flags & 0x000800 ~= 0 then
		SampleCompositionTimeOffset = rbyte("SampleCompositionTimeOffset", 4)
	end
end

local FirstSampleDependOn
local FirstDataOffset
local sample_count = 0
local current_tick = 0
function trun(size)
	rbyte("Version", 1)
	local flags = rbyte("Flags", 3)
	local count = rbyte("SampleCount", 4)

	if flags & 0x000001 ~= 0 then
		rbyte("DataOffset",                       4)
	end
	if flags & 0x000004 ~= 0 then
		nest_call("FirstSampleFlags", SAMPLEFLAGS)
		FirstSampleDependOn = get("SampleDependsOn")
	end
	for i=1, count do
		SampleDependOn = DefaultSampleDependOn
		SampleDuration = DefaultSampleDuration
		SampleCompositionTimeOffset = 0
		if i==1 then
			SampleDependOn = FirstSampleDependOn or SampleDependOn
		end

		nest_call("SampleInformation", SampleInformationStructure, flags)
		
		if cur_trak.descriptor == "avcC"
		or cur_trak.descriptor == "avc1"
		or cur_trak.descriptor == "hvc1" then
			if SampleDependOn == 1 then
				io.write("x")
			elseif SampleDependOn == 2 then 
				io.write("I")
			else
				io.write("?")
			end
				
			if i%50 == 0 then
				io.write("\n")
			end
		end
			
		sample_count = sample_count + 1
		current_tick = current_tick + SampleDuration
		if SampleCompositionTimeOffset then
			set("PTS[ms]", decstr((current_tick + SampleCompositionTimeOffset) / get("TimeScale")*1000))
			set("DTS[ms]", decstr(current_tick / get("TimeScale")*1000))
		else
			set("PTS[ms]", decstr((current_tick + SampleCompositionTimeOffset) / get("TimeScale")*1000))
		end
	end
	io.write("\n")
end

function tfdt(size)
	local version = rbyte("Version", 1)
	rbyte("Flags", 3)

	if version==1 then
		rbyte("baseMediaDecodeTime", 8)
	else
		rbyte("baseMediaDecodeTime", 4)
	end
end

function mdat(size)
	-- print(" data only")
	rbyte("mdat", size)
end

function meta(size)
	print(" --> unsupported")
	rbyte("meta", size)
end

function ilst(size)
	print(" --> unsupported")
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
	print(" --> unsupported")
	rbyte("skip", size)
end

function mfra(size)
	print(" --> unsupported")
	rbyte("mfra", size)
end

function tfra(size)
	print(" --> unsupported")
	rbyte("tfra", size)
end

function mfro(size)
	print(" --> unsupported")
	rbyte("mfro", size)
end

function mp4(size)
	child_boxes({ftyp=ftyp, free=free, moov=moov, moof=moof, mdat=mdat}, size)
end

----------------------------------------
-- 解析用util
----------------------------------------
function analyse_trak(trak)
	if get("SizeCount") == 0 then
		print("no stsc, maybe fragmented.", trak.descriptor)
		return
	end
	
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
		set(trak.descriptor.."_DTS[ms]", decstr(DTS_in_tick[i]/time_scale*1000))
		set(trak.descriptor.."_DTS[90kHz]", hexstr(math.ceil(DTS_in_tick[i]/time_scale*90000)))
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
			set(trak.descriptor.."_PTS[ms]", decstr(PTS_in_tick[i]/time_scale*1000))
			set(trak.descriptor.."_PTS[90kHz]", hexstr(math.ceil(PTS_in_tick[i]/time_scale*90000)))
		end
		store(trak.descriptor.."PTS", PTS)
	else
		print("no PTS in ", cur_trak.descriptor)
	end

	-- ES書き出し
	print("================================")
	print("trak.descriptor = \""..cur_trak.descriptor.."\"")

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
	
	-- ES解析
	if trak.descriptor == "avc1" then
		print("analyze H.264? [y/n (default:n)]")
		if io.read() == "y" then
			dofile(__streamdef_dir__.."h264.lua")
			local stream, prev = open(out_file_name)
			length_stream(get("lengthSizeMinusOne")+1)
			swap(prev)
		end
	elseif trak.descriptor == "hvc1"
	or     trak.descriptor == "hev1" then
		print("analyze H.265? [y/n (default:n)]")
		if io.read() == "y" then
			dofile(__streamdef_dir__.."h265.lua")
			local stream, prev = open(out_file_name)
			length_stream(get("lengthSizeMinusOne")+1)
			swap(prev)
		end
	elseif trak.descriptor == "mp4a" then
		print("analyze ADTS? [y/n (default:n)]")
		if io.read() == "y" then
			dofile(__streamdef_dir__.."aac.lua")
			local stream, prev = open(out_file_name)
			adts_sequence(get_size())
			swap(prev)
		end
	else
		print("unsupported es type ".. trak.descriptor)
	end

	print("================================")
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
analyse_mp4()

