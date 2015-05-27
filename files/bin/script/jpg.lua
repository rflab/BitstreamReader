-- bmp���
local __stream_path__ = argv[1] or "test.jpg"
local info = {}

function segment(maker)
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function app0()
	local begin = cur()
	print("-------------------JFIF-------------------")
	rbyte("Length",              2)
	rstr ("JFIF",                get("Length")-2)
	seek(get("Length") + begin)
end

function app1()
	local begin = cur()
	rbyte("Length",              2)
	rstr ("Identifier",          4)
	
	if get("Identifier") == "Exif" then
		rbyte("0000",                2)
		exif(get("Length") - 8)
	elseif get("Identifier") == "http" then
		rstr("http",             256)
		seek(get("Length") + begin)
	end
		
end


function dqt()
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function dht()
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function sof0()
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function sos()
	rbyte("Length",              2) -- SOS�̏ꍇ����͂��ĂɂȂ�Ȃ�
	rbyte("Ns",                  1)
	
	for i=1, get("Ns") do
		rbyte("Cs_id",           1) -- ����ID
		rbit ("DC_DHT",          4) -- �c�b�����n�t�}���e�[�u���ԍ�
		rbit ("AC_DHT",          4) -- �`�b�����n�t�}���e�[�u���ԍ�
	end
	
	rbyte("Ss",                  1)
	rbyte("Se",                  1)
	rbit ("Ah",                  4)
	rbit ("AL",                  4)
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
function get_tag(t)
	if     t == 0     then return "GPSVersionID"                ,"GPS�^�O�̃o�[�W����                   :"
	elseif t == 1     then return "GPSLatitudeRef"              ,"�ܓx�̓�k                            :"
	elseif t == 2     then return "GPSLatitude"                 ,"�ܓx�i�x�A���A�b�j                    :"
	elseif t == 3     then return "GPSLongitudeRef"             ,"�o�x�̓���                            :"
	elseif t == 4     then return "GPSLongitude"                ,"�o�x�i�x�A���A�b�j                    :"
	elseif t == 5     then return "GPSAltitudeRef"              ,"���x�̊                            :"
	elseif t == 6     then return "GPSAltitude"                 ,"���x�im�j                             :"
	elseif t == 7     then return "GPSTimeStamp"                ,"GPS�̎��ԁi���q���v�j                 :"
	elseif t == 8     then return "GPSSatellites"               ,"���ʂɎg�p����GPS�q��                 :"
	elseif t == 9     then return "GPSStatus"                   ,"GPS��M�@�̏��                       :"
	elseif t == 10    then return "GPSMeasureMode"              ,"GPS�̑��ʃ��[�h                       :"
	elseif t == 11    then return "GPSDOP"                      ,"���ʂ̐M����                          :"
	elseif t == 12    then return "GPSSpeedRef"                 ,"���x�̒P��                            :"
	elseif t == 13    then return "GPSSpeed"                    ,"���x                                  :"
	elseif t == 14    then return "GPSTrackRef"                 ,"�i�s�����̊                        :"
	elseif t == 15    then return "GPSTrack"                    ,"�i�s�����i�x�j                        :"
	elseif t == 16    then return "GPSImgDirectionRef"          ,"�B�e�����̊                        :"
	elseif t == 17    then return "GPSImgDirection"             ,"�B�e�����i�x�j                        :"
	elseif t == 18    then return "GPSMapDatum"                 ,"���ʂɗp�����n�}�f�[�^                :"
	elseif t == 19    then return "GPSDestLatitudeRef"          ,"�ړI�n�̈ܓx�̓�k                    :"
	elseif t == 20    then return "GPSDestLatitude"             ,"�ړI�n�̈ܓx�i�x�A���A�b�j            :"
	elseif t == 21    then return "GPSDestLongitudeRef"         ,"�ړI�n�̌o�x�̓���                    :"
	elseif t == 22    then return "GPSDestLongitude"            ,"�ړI�n�̌o�x�i�x�A���A�b�j            :"
	elseif t == 23    then return "GPSBearingRef"               ,"�ړI�n�̕��p�̊                    :"
	elseif t == 24    then return "GPSBearing"                  ,"�ړI�n�̕��p�i�x�j                    :"
	elseif t == 25    then return "GPSDestDistanceRef"          ,"�ړI�n�ւ̋����̒P��                  :"
	elseif t == 26    then return "GPSDestDistance"             ,"�ړI�n�ւ̋���                        :"
	elseif t == 256   then return "ImageWidth"                  ,"�摜�̕��i�s�N�Z���j                  :"
	elseif t == 257   then return "ImageLength"                 ,"�摜�̍����i�s�N�Z���j                :"
	elseif t == 258   then return "BitsPerSample"               ,"��f�̃r�b�g�̐[���i�r�b�g�j          :"
	elseif t == 259   then return "Compression"                 ,"���k�̎��                            :"
	elseif t == 262   then return "PhotometricInterpretation"   ,"��f�������̎��                      :"
	elseif t == 274   then return "Orientation"                 ,"��f�̕���                            :"
	elseif t == 277   then return "SamplesPerPixel"             ,"�s�N�Z�����̃R���|�[�l���g��          :"
	elseif t == 284   then return "PlanarConfiguration"         ,"��f�f�[�^�̕���                      :"
	elseif t == 530   then return "YCbCrSubSampling"            ,"��f�̔䗦������                      :"
	elseif t == 531   then return "YCbCrPositioning"            ,"��f�̈ʒu������                      :"
	elseif t == 282   then return "XResolution"                 ,"�摜�̕������̉𑜓x�idpi�j           :"
	elseif t == 283   then return "YResolution"                 ,"�摜�̍��������̉𑜓x�idpi�j         :"
	elseif t == 296   then return "ResolutionUnit"              ,"�𑜓x�̒P��                          :"
	elseif t == 273   then return "StripOffsets"                ,"�C���[�W�f�[�^�ւ̃I�t�Z�b�g          :"
	elseif t == 278   then return "RowsPerStrip"                ,"�P�X�g���b�v������̍s��              :"
	elseif t == 279   then return "StripByteCounts"             ,"�e�X�g���b�v�̃T�C�Y�i�o�C�g�j        :"
	elseif t == 513   then return "JPEGInterchangeFormat"       ,"JPEG�T���l�C����SOI�ւ̃I�t�Z�b�g     :"
	elseif t == 514   then return "JPEGInterchangeFormatLength" ,"JPEG�T���l�C���f�[�^�̃T�C�Y�i�o�C�g�j:"
	elseif t == 301   then return "TransferFunction"            ,"�~���J�[�u����                        :"
	elseif t == 318   then return "WhitePoint"                  ,"�z���C�g�|�C���g�̐F���W�l            :"
	elseif t == 319   then return "PrimaryChromaticities"       ,"���F�̐F���W�l                        :"
	elseif t == 529   then return "YCbCrCoefficients"           ,"�F�ϊ��}�g���b�N�X�W��                :"
	elseif t == 532   then return "ReferenceBlackWhite"         ,"���F�Ɣ��F�̒l                        :"
	elseif t == 306   then return "DateTime"                    ,"�t�@�C���ύX����                      :"
	elseif t == 270   then return "ImageDescription"            ,"�摜�^�C�g��                          :"
	elseif t == 271   then return "Make"                        ,"���[�J�[                              :"
	elseif t == 272   then return "Model"                       ,"���f��                                :"
	elseif t == 305   then return "Software"                    ,"�g�p����Software                      :"
	elseif t == 315   then return "Artist"                      ,"�B�e�Җ�                              :"
	elseif t == 3432  then return "Copyright"                   ,"���쌠                                :"
	elseif t == 34665 then return "ExifIFDPointer"              ,"Exif IFD�ւ̃|�C���^                  :"
	elseif t == 34853 then return "GPSInfoIFDPointer"           ,"GPS���IFD�ւ̃|�C���^                :"
	elseif t == 36864 then return "ExifVersion"                 ,"Exif�o�[�W����                        :"
	elseif t == 40960 then return "FlashPixVersion"             ,"�Ή�FlashPix�̃o�[�W����              :"
	elseif t == 40961 then return "ColorSpace"                  ,"�F��ԏ��                            :"
	elseif t == 37121 then return "ComponentsConfiguration"     ,"�R���|�[�l���g�̈Ӗ�                  :"
	elseif t == 37122 then return "CompressedBitsPerPixel"      ,"�摜���k���[�h�i�r�b�g�^�s�N�Z���j    :"
	elseif t == 40962 then return "PixelXDimension"             ,"�L���ȉ摜�̕��i�s�N�Z���j            :"
	elseif t == 40963 then return "PixelYDimension"             ,"�L���ȉ摜�̍����i�s�N�Z���j          :"
	elseif t == 37500 then return "MakerNote"                   ,"���[�J�ŗL���                        :"
	elseif t == 37510 then return "UserComment"                 ,"���[�U�R�����g                        :"
	elseif t == 40964 then return "RelatedSoundFile"            ,"�֘A�����t�@�C����                    :"
	elseif t == 36867 then return "DateTimeOriginal"            ,"�I���W�i���摜�̐�������              :"
	elseif t == 36868 then return "DateTimeDigitized"           ,"�f�B�W�^���f�[�^�̐�������            :"
	elseif t == 37520 then return "SubSecTime"                  ,"�t�@�C���ύX�����̕b�ȉ��̒l          :"
	elseif t == 37521 then return "SubSecTimeOriginal"          ,"�摜���������̕b�ȉ��̒l              :"
	elseif t == 37522 then return "SubSecTimeDigitized"         ,"�f�B�W�^���f�[�^���������̕b�ȉ��̒l  :"
	elseif t == 33434 then return "ExposureTime"                ,"�I�o���ԁi�b�j                        :"
	elseif t == 33437 then return "FNumber"                     ,"F�l                                   :"
	elseif t == 34850 then return "ExposureProgram"             ,"�I�o�v���O����                        :"
	elseif t == 34852 then return "SpectralSensitivity"         ,"�X�y�N�g�����x                        :"
	elseif t == 34855 then return "ISOSpeedRatings"             ,"ISO�X�s�[�h���[�g                     :"
	elseif t == 34856 then return "OECF"                        ,"���d�ϊ��֐�                          :"
	elseif t == 37377 then return "ShutterSpeedValue"           ,"�V���b�^�[�X�s�[�h�iAPEX�j            :"
	elseif t == 37378 then return "ApertureValue"               ,"�i��iAPEX�j                          :"
	elseif t == 37379 then return "BrightnessValue"             ,"�P�x�iAPEX�j                          :"
	elseif t == 37380 then return "ExposureBiasValue"           ,"�I�o�␳�iAPEX�j                      :"
	elseif t == 37381 then return "MaxApertureValue"            ,"�����Y�̍ŏ�F�l�iAPEX�j               :"
	elseif t == 37382 then return "SubjectDistance"             ,"��ʑ̋����im�j                       :"
	elseif t == 37383 then return "MeteringMode"                ,"��������                              :"
	elseif t == 37384 then return "LightSource"                 ,"����                                  :"
	elseif t == 37385 then return "Flash"                       ,"�t���b�V��                            :"
	elseif t == 37386 then return "FocalLength"                 ,"�����Y�̏œ_�����imm�j                :"
	elseif t == 41483 then return "FlashEnergy"                 ,"�t���b�V���̃G�l���M�[�iBCPS�j        :"
	elseif t == 41484 then return "SpatialFrequencyResponse"    ,"��Ԏ��g������                        :"
	elseif t == 41486 then return "FocalPlaneXResolution"       ,"�œ_�ʂ̕������̉𑜓x�i�s�N�Z���j    :"
	elseif t == 41487 then return "FocalPlaneYResolution"       ,"�œ_�ʂ̍��������̉𑜓x�i�s�N�Z���j  :"
	elseif t == 41488 then return "FocalPlaneResolutionUnit"    ,"�œ_�ʂ̉𑜓x�̒P��                  :"
	elseif t == 41492 then return "SubjectLocation"             ,"��ʑ̈ʒu                            :"
	elseif t == 41493 then return "ExposureIndex"               ,"�I�o�C���f�b�N�X                      :"
	elseif t == 41495 then return "SensingMethod"               ,"�摜�Z���T�̕���                      :"
	elseif t == 41728 then return "FileSource"                  ,"�摜���͋@��̎��                    :"
	elseif t == 41729 then return "SceneType"                   ,"�V�[���^�C�v                          :"
	elseif t == 41730 then return "CFAPattern"                  ,"CFA�p�^�[��                           :"
	elseif t == 40965 then return "InteroperabilityIFDPointer"  ,"�݊���IFD�ւ̃|�C���^                 :"   
	else                   return "UNDEFINED"                   ,"�s���ȃ^�O ("..t.."):"   
	end
end

function exif(size)
	info.exif_begin = cur()
	info.exif = sub_stream("Exif", size)
	info.exif:enable_print(false)
	
	rstr ("ByteCode",            2)

	if get("ByteCode") == "MM" then
		little_endian(false)
		info.exif:little_endian(false)
	else
		little_endian(true)
		info.exif:little_endian(true)
	end
	
	cbyte("002A"  ,              2, 0x002A)
	rbyte("_0th_IFD",            4)
	
	ifd(get("_0th_IFD"))
	
	seek(info.exif_begin + size)
end

function ifd(offset, indent)
	local indent = indent or 0
	tab = string.rep("    ", indent)
	seek(info.exif_begin + offset)

	rbyte("FieldCount",                                                     2)
	print(tab.."---------------".."IFD count:"..get("FieldCount").."-----------------")
	
	local count = get("FieldCount") -- �挈���邽�߂�local�ɕۑ�����
	for i=1, count do
		rbyte("Tag",                                                        2)
		rbyte("Type",                                                       2)
		rbyte("Count",                                                      4)
		rbyte("ValueOffset",                                                4)
		
		local sz, ty = get_type(get("Type"))
		
		if get("Count") * sz > 4 then
			info.exif:seek_byte(get("ValueOffset"))
		else
			info.exif:seek_byte(cur() - info.exif_begin - 4)
		end
		
		if ty == "byte" then
			for j=1, get("Count") do
				local val = info.exif:read_byte("Byte",                     1)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
		elseif ty == "ascii" then
			local val = info.exif:read_string("Ascii",                     get("Count"))
			print(tab..(select(2, get_tag(get("Tag")))), val)
		elseif ty == "short" then
			for j=1, get("Count") do
				local val = info.exif:read_byte("Short",                    2)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
		elseif ty == "long" then
			local val
			for j=1, get("Count") do
				val = info.exif:read_byte("Long",                           4)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
			
			-- ���̊K�w
			if get_tag(get("Tag")) == "ExifIFDPointer"
			or get_tag(get("Tag")) == "GPSInfoIFDPointer"
			or get_tag(get("Tag")) == "InteroperabilityIFDPointer" then
				local cur_offset = cur()
				ifd(val, indent+1)
				seek(cur_offset)
			end
			
		elseif ty == "rational" then
			for j=1, get("Count") do
				local num = info.exif:read_byte("Number",                   4)
				local den = info.exif:read_byte("Denom",                    4)
				print(tab..(select(2, get_tag(get("Tag")))), num/den)
			end
		elseif ty == "undefined" then
			local val = info.exif:read_byte("Undefined",                    get("Count"))
			print(tab..(select(2, get_tag(get("Tag")))), val)
		elseif ty == "slong" then
			for j=1, get("Count") do
				local val = info.exif:read_byte("Slong",                    4)
				print(tab..(select(2, get_tag(get("Tag")))), val)
			end
		elseif ty == "srational" then
			for j=1, get("Count") do
				local num = info.exif:read_byte("SNumber",                  4)
				local den = info.exif:read_byte("SDenom",                   4)
				print(tab..(select(2, get_tag(get("Tag")))), num/den)
			end
		end
	end
	
	rbyte("NextIFD",                                                        4)
	if get("NextIFD") == 0 then
		return
	else
		local cur_offset = cur()
		ifd(get("NextIFD"))
		seek(cur_offset)
	end
end

function jpg()
	cbyte("SOI",           2, 0xffd8)
	
	while true do
		rbyte("Markar",        2)
		if get("Markar") == 0xffd9 then -- EOI
			break;
		elseif get("Markar") == 0xffe0 then
			app0()
		elseif get("Markar") == 0xffe1 then
			app1()
		elseif get("Markar") == 0xffdb then
			dqt()
		elseif get("Markar") == 0xffc4 then
			dht()
		elseif get("Markar") == 0xffc0 then
			sof0()
		elseif get("Markar") == 0xffda then
			sos()
			sstr("ff d9")
		elseif get("Markar") == 0xffd0
		or     get("Markar") == 0xffd1
		or     get("Markar") == 0xffd2
		or     get("Markar") == 0xffd3
		or     get("Markar") == 0xffd4
		or     get("Markar") == 0xffd5
		or     get("Markar") == 0xffd6
		or     get("Markar") == 0xffd7 then
			-- restart
		else
			segment(get("Markar"))
		end 
	end
end


open(__stream_path__)
little_endian(false)
enable_print(true)
jpg()
print_table(info)
print_status()
