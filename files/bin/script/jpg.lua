-- bmp���
local __stream_path__ = argv[1] or "test.jpg"
local info = {}

function segment(maker)
	rbyte("Length",              2)
	rbyte("Payload",             get("Length")-2)	
end

function app0()
	rbyte("Length",              2)
	rstr ("JFIF",                get("Length")-2)	
end

function app1()
	local begin = cur()
	rbyte("Length",              2)
	rstr ("Identifier",          4)
	
	if get("Identifier") == "Exif" then
		rbyte("0000",                2)
		tiff(get("Length") - 8)
	elseif get("Identifier") == "http" then
		rstr("http",             256)
	end
		
	seek(get("Length") + begin)
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

function get_type(ty)
	if     ty == 1   then return 1
	elseif ty == 2   then return "string"
	elseif ty == 3   then return 2
	elseif ty == 4   then return 4
	elseif ty == 5   then return 8 -- 4:4
	elseif ty == 7   then return "undefined"
	elseif ty == 9   then return 4
	elseif ty == 10  then return 8 -- 4:4
	end
end

function get_tag(tag)
	if     tag == 0     then return "GPSVersionID"                ,"GPS�^�O�̃o�[�W����                   :"
	elseif tag == 1     then return "GPSLatitudeRef"              ,"�ܓx�̓�k                            :"
	elseif tag == 2     then return "GPSLatitude"                 ,"�ܓx�i�x�A���A�b�j                    :"
	elseif tag == 3     then return "GPSLongitudeRef"             ,"�o�x�̓���                            :"
	elseif tag == 4     then return "GPSLongitude"                ,"�o�x�i�x�A���A�b�j                    :"
	elseif tag == 5     then return "GPSAltitudeRef"              ,"���x�̊                            :"
	elseif tag == 6     then return "GPSAltitude"                 ,"���x�im�j                             :"
	elseif tag == 7     then return "GPSTimeStamp"                ,"GPS�̎��ԁi���q���v�j                 :"
	elseif tag == 8     then return "GPSSatellites"               ,"���ʂɎg�p����GPS�q��                 :"
	elseif tag == 9     then return "GPSStatus"                   ,"GPS��M�@�̏��                       :"
	elseif tag == 10    then return "GPSMeasureMode"              ,"GPS�̑��ʃ��[�h                       :"
	elseif tag == 11    then return "GPSDOP"                      ,"���ʂ̐M����                          :"
	elseif tag == 12    then return "GPSSpeedRef"                 ,"���x�̒P��                            :"
	elseif tag == 13    then return "GPSSpeed"                    ,"���x                                  :"
	elseif tag == 14    then return "GPSTrackRef"                 ,"�i�s�����̊                        :"
	elseif tag == 15    then return "GPSTrack"                    ,"�i�s�����i�x�j                        :"
	elseif tag == 16    then return "GPSImgDirectionRef"          ,"�B�e�����̊                        :"
	elseif tag == 17    then return "GPSImgDirection"             ,"�B�e�����i�x�j                        :"
	elseif tag == 18    then return "GPSMapDatum"                 ,"���ʂɗp�����n�}�f�[�^                :"
	elseif tag == 19    then return "GPSDestLatitudeRef"          ,"�ړI�n�̈ܓx�̓�k                    :"
	elseif tag == 20    then return "GPSDestLatitude"             ,"�ړI�n�̈ܓx�i�x�A���A�b�j            :"
	elseif tag == 21    then return "GPSDestLongitudeRef"         ,"�ړI�n�̌o�x�̓���                    :"
	elseif tag == 22    then return "GPSDestLongitude"            ,"�ړI�n�̌o�x�i�x�A���A�b�j            :"
	elseif tag == 23    then return "GPSBearingRef"               ,"�ړI�n�̕��p�̊                    :"
	elseif tag == 24    then return "GPSBearing"                  ,"�ړI�n�̕��p�i�x�j                    :"
	elseif tag == 25    then return "GPSDestDistanceRef"          ,"�ړI�n�ւ̋����̒P��                  :"
	elseif tag == 26    then return "GPSDestDistance"             ,"�ړI�n�ւ̋���                        :"
	elseif tag == 256   then return "ImageWidth"                  ,"�摜�̕��i�s�N�Z���j                  :"
	elseif tag == 257   then return "ImageLength"                 ,"�摜�̍����i�s�N�Z���j                :"
	elseif tag == 258   then return "BitsPerSample"               ,"��f�̃r�b�g�̐[���i�r�b�g�j          :"
	elseif tag == 259   then return "Compression"                 ,"���k�̎��                            :"
	elseif tag == 262   then return "PhotometricInterpretation"   ,"��f�������̎��                      :"
	elseif tag == 274   then return "Orientation"                 ,"��f�̕���                            :"
	elseif tag == 277   then return "SamplesPerPixel"             ,"�s�N�Z�����̃R���|�[�l���g��          :"
	elseif tag == 284   then return "PlanarConfiguration"         ,"��f�f�[�^�̕���                      :"
	elseif tag == 530   then return "YCbCrSubSampling"            ,"��f�̔䗦������                      :"
	elseif tag == 531   then return "YCbCrPositioning"            ,"��f�̈ʒu������                      :"
	elseif tag == 282   then return "XResolution"                 ,"�摜�̕������̉𑜓x�idpi�j           :"
	elseif tag == 283   then return "YResolution"                 ,"�摜�̍��������̉𑜓x�idpi�j         :"
	elseif tag == 296   then return "ResolutionUnit"              ,"�𑜓x�̒P��                          :"
	elseif tag == 273   then return "StripOffsets"                ,"�C���[�W�f�[�^�ւ̃I�t�Z�b�g          :"
	elseif tag == 278   then return "RowsPerStrip"                ,"�P�X�g���b�v������̍s��              :"
	elseif tag == 279   then return "StripByteCounts"             ,"�e�X�g���b�v�̃T�C�Y�i�o�C�g�j        :"
	elseif tag == 513   then return "JPEGInterchangeFormat"       ,"JPEG�T���l�C����SOI�ւ̃I�t�Z�b�g     :"
	elseif tag == 514   then return "JPEGInterchangeFormatLength" ,"JPEG�T���l�C���f�[�^�̃T�C�Y�i�o�C�g�j:"
	elseif tag == 301   then return "TransferFunction"            ,"�~���J�[�u����                        :"
	elseif tag == 318   then return "WhitePoint"                  ,"�z���C�g�|�C���g�̐F���W�l            :"
	elseif tag == 319   then return "PrimaryChromaticities"       ,"���F�̐F���W�l                        :"
	elseif tag == 529   then return "YCbCrCoefficients"           ,"�F�ϊ��}�g���b�N�X�W��                :"
	elseif tag == 532   then return "ReferenceBlackWhite"         ,"���F�Ɣ��F�̒l                        :"
	elseif tag == 306   then return "DateTime"                    ,"�t�@�C���ύX����                      :"
	elseif tag == 270   then return "ImageDescription"            ,"�摜�^�C�g��                          :"
	elseif tag == 271   then return "Make"                        ,"���[�J�[                              :"
	elseif tag == 272   then return "Model"                       ,"���f��                                :"
	elseif tag == 305   then return "Software"                    ,"�g�p����Software                      :"
	elseif tag == 315   then return "Artist"                      ,"�B�e�Җ�                              :"
	elseif tag == 3432  then return "Copyright"                   ,"���쌠                                :"
	elseif tag == 34665 then return "ExifIFDPointer"              ,"Exif IFD�ւ̃|�C���^                  :"
	elseif tag == 34853 then return "GPSInfoIFDPointer"           ,"GPS���IFD�ւ̃|�C���^                :"
	elseif tag == 36864 then return "ExifVersion"                 ,"Exif�o�[�W����                        :"
	elseif tag == 40960 then return "FlashPixVersion"             ,"�Ή�FlashPix�̃o�[�W����              :"
	elseif tag == 40961 then return "ColorSpace"                  ,"�F��ԏ��                            :"
	elseif tag == 37121 then return "ComponentsConfiguration"     ,"�R���|�[�l���g�̈Ӗ�                  :"
	elseif tag == 37122 then return "CompressedBitsPerPixel"      ,"�摜���k���[�h�i�r�b�g�^�s�N�Z���j    :"
	elseif tag == 40962 then return "PixelXDimension"             ,"�L���ȉ摜�̕��i�s�N�Z���j            :"
	elseif tag == 40963 then return "PixelYDimension"             ,"�L���ȉ摜�̍����i�s�N�Z���j          :"
	elseif tag == 37500 then return "MakerNote"                   ,"���[�J�ŗL���                        :"
	elseif tag == 37510 then return "UserComment"                 ,"���[�U�R�����g                        :"
	elseif tag == 40964 then return "RelatedSoundFile"            ,"�֘A�����t�@�C����                    :"
	elseif tag == 36867 then return "DateTimeOriginal"            ,"�I���W�i���摜�̐�������              :"
	elseif tag == 36868 then return "DateTimeDigitized"           ,"�f�B�W�^���f�[�^�̐�������            :"
	elseif tag == 37520 then return "SubSecTime"                  ,"�t�@�C���ύX�����̕b�ȉ��̒l          :"
	elseif tag == 37521 then return "SubSecTimeOriginal"          ,"�摜���������̕b�ȉ��̒l              :"
	elseif tag == 37522 then return "SubSecTimeDigitized"         ,"�f�B�W�^���f�[�^���������̕b�ȉ��̒l  :"
	elseif tag == 33434 then return "ExposureTime"                ,"�I�o���ԁi�b�j                        :"
	elseif tag == 33437 then return "FNumber"                     ,"F�l                                   :"
	elseif tag == 34850 then return "ExposureProgram"             ,"�I�o�v���O����                        :"
	elseif tag == 34852 then return "SpectralSensitivity"         ,"�X�y�N�g�����x                        :"
	elseif tag == 34855 then return "ISOSpeedRatings"             ,"ISO�X�s�[�h���[�g                     :"
	elseif tag == 34856 then return "OECF"                        ,"���d�ϊ��֐�                          :"
	elseif tag == 37377 then return "ShutterSpeedValue"           ,"�V���b�^�[�X�s�[�h�iAPEX�j            :"
	elseif tag == 37378 then return "ApertureValue"               ,"�i��iAPEX�j                          :"
	elseif tag == 37379 then return "BrightnessValue"             ,"�P�x�iAPEX�j                          :"
	elseif tag == 37380 then return "ExposureBiasValue"           ,"�I�o�␳�iAPEX�j                      :"
	elseif tag == 37381 then return "MaxApertureValue"            ,"�����Y�̍ŏ�F�l�iAPEX�j               :"
	elseif tag == 37382 then return "SubjectDistance"             ,"��ʑ̋����im�j                       :"
	elseif tag == 37383 then return "MeteringMode"                ,"��������                              :"
	elseif tag == 37384 then return "LightSource"                 ,"����                                  :"
	elseif tag == 37385 then return "Flash"                       ,"�t���b�V��                            :"
	elseif tag == 37386 then return "FocalLength"                 ,"�����Y�̏œ_�����imm�j                :"
	elseif tag == 41483 then return "FlashEnergy"                 ,"�t���b�V���̃G�l���M�[�iBCPS�j        :"
	elseif tag == 41484 then return "SpatialFrequencyResponse"    ,"��Ԏ��g������                        :"
	elseif tag == 41486 then return "FocalPlaneXResolution"       ,"�œ_�ʂ̕������̉𑜓x�i�s�N�Z���j    :"
	elseif tag == 41487 then return "FocalPlaneYResolution"       ,"�œ_�ʂ̍��������̉𑜓x�i�s�N�Z���j  :"
	elseif tag == 41488 then return "FocalPlaneResolutionUnit"    ,"�œ_�ʂ̉𑜓x�̒P��                  :"
	elseif tag == 41492 then return "SubjectLocation"             ,"��ʑ̈ʒu                            :"
	elseif tag == 41493 then return "ExposureIndex"               ,"�I�o�C���f�b�N�X                      :"
	elseif tag == 41495 then return "SensingMethod"               ,"�摜�Z���T�̕���                      :"
	elseif tag == 41728 then return "FileSource"                  ,"�摜���͋@��̎��                    :"
	elseif tag == 41729 then return "SceneType"                   ,"�V�[���^�C�v                          :"
	elseif tag == 41730 then return "CFAPattern"                  ,"CFA�p�^�[��                           :"
	elseif tag == 40965 then return "InteroperabilityIFDPointer"  ,"�݊���IFD�ւ̃|�C���^                 :"       
	end
end

function tiff(size)
	info.tiff_begin = cur()
	info.tiff = sub_stream(size)
	info.tiff:enable_print(true)
	
	rstr ("ByteCode",            2)

	if get("ByteCode") == "MM" then
		little_endian(false)
		info.little_endian = false
		info.tiff:little_endian(false)
	else
		little_endian(true)
		info.little_endian = true
		info.tiff:little_endian(true)
	end
	
	cbyte("002A"  ,              2, 0x002A)
	rbyte("_0th_IFD",            4)
	
	seek(info.tiff_begin + get("_0th_IFD"))
	ifd()
end

function ifd(offset)
	rbyte("Count",                    2)
	
	for i=1, get("Count") do
		rbyte("ValueTag",             2)
		rbyte("ValueType",            2)
		rbyte("ValueCount",           4)
		rbyte("Value",                4)

		local ty = get_type(get("ValueType"))
		local val
		if ty == "string" then
			if get("ValueCount") > 4 then
				info.tiff:seek(get("Value"))
				val = info.tiff:read_string("String", get("ValueCount"))
			else
				val = val2str(get("Value"))
			end
			print((select(2, get_tag(get("ValueTag")))), val)
		elseif ty == "undefined" then
			print("undefined info")
		elseif get("ValueCount")*ty > 4 then
			info.tiff:seek(get("Value"))
			val = info.tiff:read_byte("Value", get("ValueCount")*ty)
			print((select(2, get_tag(get("ValueTag")))), val)
		else
			val = get("Value")
			print((select(2, get_tag(get("ValueTag")))), val)
		end
	end
	
	rbyte("Next",                     4)
end

function jpg()
	cbyte("SOI",           2, 0xffd8)
	
	-- while true do
	-- 	sbyte(0xff)
	-- 	rbyte("id", 2)
	-- end

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
