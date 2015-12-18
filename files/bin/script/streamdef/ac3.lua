function ac3_bitstream(size)
	while cur() < size do
		ac3_syncframe()
	end
end

function ac3_sequence(size)
	-- enable_print(true)
	while cur() < size do
		check_progress(false)
		if lbit(12) == syncword then
			nest_call("ac3_frame", ac3_frame)
		else
			byte_alignment()
			seekoff(1)
			fbyte(0xff)
		end
	end
end


function ac3_syncframe()
	syncinfo()
	bsi()
	-- for blk = 0, 6-1 do
	-- 	audblk()
	-- end
	-- auxdata()
	-- errorcheck()
end

function syncinfo()
	cbit("syncword", 16, 0x0b77)
	rbit("crc1", 16)
	rbit("fscod", 2)
	rbit("frmsizecod", 6)
end

function bsi()
	rbit("strmtyp", 2)
	rbit("substreamid", 3)
	rbit("frmsiz", 11)
	rbit("fscod", 2)
	if (get("fscod") == 0x3) then
		rbit("fscod2", 2)
		set("numblkscod", 0x3) -- /* six blocks per frame */
	else
		rbit("numblkscod", 2)
	end
	rbit("acmod", 3)
	rbit("lfeon", 1)
	rbit("bsid", 5)
	rbit("dialnorm", 5)
	rbit("compre", 1)
	if get("compre") ~= 0 then
		rbit("compr", 8)
	end
	
	-- langcode 1
	-- if (langcode) {langcod} 8
	-- audprodie 1
	-- if (audprodie)
	-- {
	-- mixlevel 5
	-- roomtyp 2
	-- }
	-- if (acmod == 0) /* if 1+1 mode (dual mono, so some items need a second value) */
	-- {
	-- dialnorm2 5
	-- compr2e 1
	-- if (compr2e) {compr2} 8
	-- langcod2e 1
	-- if (langcod2e) {langcod2} 8
	-- audprodi2e 1
	-- if (audprodi2e)
	-- {
	-- Advanced Television Systems Committee, Inc. Document A/52:2010
	-- 32
	-- 5.3.3 audioblk: Audio Block
	-- mixlevel2 5
	-- roomtyp2 2
	-- }
	-- }
	-- copyrightb 1
	-- origbs 1
	-- timecod1e 1
	-- if (timecod1e) {timecod1} 14
	-- timecod2e 1
	-- if (timecod2e) {timecod2} 14
	-- addbsie 1
	-- if (addbsie)
	-- {
	-- addbsil 6
	-- addbsi (addbsil+1)~8
	-- }
	-- } /* end of bsi
end

function audblk()
end

function auxdata()
end

function errorcheck()
end
