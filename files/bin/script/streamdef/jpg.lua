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
		print("-------------------Exif-------------------")
		rbyte("0000",                2)
		exif(get("Length") - 8)
	elseif get("Identifier") == "http" then
		print("-------------------Http-------------------")
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
	
	
--	elseif t == 0       then return "GPSVersionID"                ,"GPS�^�O�̃o�[�W����                   :"
--	elseif t == 1       then return "GPSLatitudeRef"              ,"�ܓx�̓�k                            :"
--	elseif t == 2       then return "GPSLatitude"                 ,"�ܓx�i�x�A���A�b�j                    :"
--	elseif t == 3       then return "GPSLongitudeRef"             ,"�o�x�̓���                            :"
--	elseif t == 4       then return "GPSLongitude"                ,"�o�x�i�x�A���A�b�j                    :"
--	elseif t == 5       then return "GPSAltitudeRef"              ,"���x�̊                            :"
--	elseif t == 6       then return "GPSAltitude"                 ,"���x�im�j                             :"
--	elseif t == 7       then return "GPSTimeStamp"                ,"GPS�̎��ԁi���q���v�j                 :"
--	elseif t == 8       then return "GPSSatellites"               ,"���ʂɎg�p����GPS�q��                 :"
--	elseif t == 9       then return "GPSStatus"                   ,"GPS��M�@�̏��                       :"
--	elseif t == 10      then return "GPSMeasureMode"              ,"GPS�̑��ʃ��[�h                       :"
--	elseif t == 11      then return "GPSDOP"                      ,"���ʂ̐M����                          :"
--	elseif t == 12      then return "GPSSpeedRef"                 ,"���x�̒P��                            :"
--	elseif t == 13      then return "GPSSpeed"                    ,"���x                                  :"
--	elseif t == 14      then return "GPSTrackRef"                 ,"�i�s�����̊                        :"
--	elseif t == 15      then return "GPSTrack"                    ,"�i�s�����i�x�j                        :"
--	elseif t == 16      then return "GPSImgDirectionRef"          ,"�B�e�����̊                        :"
--	elseif t == 17      then return "GPSImgDirection"             ,"�B�e�����i�x�j                        :"
--	elseif t == 18      then return "GPSMapDatum"                 ,"���ʂɗp�����n�}�f�[�^                :"
--	elseif t == 19      then return "GPSDestLatitudeRef"          ,"�ړI�n�̈ܓx�̓�k                    :"
--	elseif t == 20      then return "GPSDestLatitude"             ,"�ړI�n�̈ܓx�i�x�A���A�b�j            :"
--	elseif t == 21      then return "GPSDestLongitudeRef"         ,"�ړI�n�̌o�x�̓���                    :"
--	elseif t == 22      then return "GPSDestLongitude"            ,"�ړI�n�̌o�x�i�x�A���A�b�j            :"
--	elseif t == 23      then return "GPSBearingRef"               ,"�ړI�n�̕��p�̊                    :"
--	elseif t == 24      then return "GPSBearing"                  ,"�ړI�n�̕��p�i�x�j                    :"
--	elseif t == 25      then return "GPSDestDistanceRef"          ,"�ړI�n�ւ̋����̒P��                  :"
--	elseif t == 26      then return "GPSDestDistance"             ,"�ړI�n�ւ̋���                        :"
--	elseif t == 256     then return "ImageWidth"                  ,"�摜�̕��i�s�N�Z���j                  :"
--	elseif t == 257     then return "ImageLength"                 ,"�摜�̍����i�s�N�Z���j                :"
--	elseif t == 258     then return "BitsPerSample"               ,"��f�̃r�b�g�̐[���i�r�b�g�j          :"
--	elseif t == 259     then return "Compression"                 ,"���k�̎��                            :"
--	elseif t == 262     then return "PhotometricInterpretation"   ,"��f�������̎��                      :"
--	elseif t == 274     then return "Orientation"                 ,"��f�̕���                            :"
--	elseif t == 277     then return "SamplesPerPixel"             ,"�s�N�Z�����̃R���|�[�l���g��          :"
--	elseif t == 284     then return "PlanarConfiguration"         ,"��f�f�[�^�̕���                      :"
--	elseif t == 530     then return "YCbCrSubSampling"            ,"��f�̔䗦������                      :"
--	elseif t == 531     then return "YCbCrPositioning"            ,"��f�̈ʒu������                      :"
--	elseif t == 282     then return "XResolution"                 ,"�摜�̕������̉𑜓x�idpi�j           :"
--	elseif t == 283     then return "YResolution"                 ,"�摜�̍��������̉𑜓x�idpi�j         :"
--	elseif t == 296     then return "ResolutionUnit"              ,"�𑜓x�̒P��                          :"
--	elseif t == 273     then return "StripOffsets"                ,"�C���[�W�f�[�^�ւ̃I�t�Z�b�g          :"
--	elseif t == 278     then return "RowsPerStrip"                ,"�P�X�g���b�v������̍s��              :"
--	elseif t == 279     then return "StripByteCounts"             ,"�e�X�g���b�v�̃T�C�Y�i�o�C�g�j        :"
--	elseif t == 513     then return "JPEGInterchangeFormat"       ,"JPEG�T���l�C����SOI�ւ̃I�t�Z�b�g     :"
--	elseif t == 514     then return "JPEGInterchangeFormatLength" ,"JPEG�T���l�C���f�[�^�̃T�C�Y�i�o�C�g�j:"
--	elseif t == 301     then return "TransferFunction"            ,"�~���J�[�u����                        :"
--	elseif t == 318     then return "WhitePoint"                  ,"�z���C�g�|�C���g�̐F���W�l            :"
--	elseif t == 319     then return "PrimaryChromaticities"       ,"���F�̐F���W�l                        :"
--	elseif t == 529     then return "YCbCrCoefficients"           ,"�F�ϊ��}�g���b�N�X�W��                :"
--	elseif t == 532     then return "ReferenceBlackWhite"         ,"���F�Ɣ��F�̒l                        :"
--	elseif t == 306     then return "DateTime"                    ,"�t�@�C���ύX����                      :"
--	elseif t == 270     then return "ImageDescription"            ,"�摜�^�C�g��                          :"
--	elseif t == 271     then return "Make"                        ,"���[�J�[                              :"
--	elseif t == 272     then return "Model"                       ,"���f��                                :"
--	elseif t == 305     then return "Software"                    ,"�g�p����Software                      :"
--	elseif t == 315     then return "Artist"                      ,"�B�e�Җ�                              :"
--	elseif t == 3432    then return "Copyright"                   ,"���쌠                                :"
--	elseif t == 34665   then return "ExifIFDPointer"              ,"Exif IFD�ւ̃|�C���^                  :"
--	elseif t == 34853   then return "GPSInfoIFDPointer"           ,"GPS���IFD�ւ̃|�C���^                :"
--	elseif t == 36864   then return "ExifVersion"                 ,"Exif�o�[�W����                        :"
--	elseif t == 40960   then return "FlashPixVersion"             ,"�Ή�FlashPix�̃o�[�W����              :"
--	elseif t == 40961   then return "ColorSpace"                  ,"�F��ԏ��                            :"
--	elseif t == 37121   then return "ComponentsConfiguration"     ,"�R���|�[�l���g�̈Ӗ�                  :"
--	elseif t == 37122   then return "CompressedBitsPerPixel"      ,"�摜���k���[�h�i�r�b�g�^�s�N�Z���j    :"
--	elseif t == 40962   then return "PixelXDimension"             ,"�L���ȉ摜�̕��i�s�N�Z���j            :"
--	elseif t == 40963   then return "PixelYDimension"             ,"�L���ȉ摜�̍����i�s�N�Z���j          :"
--	elseif t == 37500   then return "MakerNote"                   ,"���[�J�ŗL���                        :"
--	elseif t == 37510   then return "UserComment"                 ,"���[�U�R�����g                        :"
--	elseif t == 40964   then return "RelatedSoundFile"            ,"�֘A�����t�@�C����                    :"
--	elseif t == 36867   then return "DateTimeOriginal"            ,"�I���W�i���摜�̐�������              :"
--	elseif t == 36868   then return "DateTimeDigitized"           ,"�f�B�W�^���f�[�^�̐�������            :"
--	elseif t == 37520   then return "SubSecTime"                  ,"�t�@�C���ύX�����̕b�ȉ��̒l          :"
--	elseif t == 37521   then return "SubSecTimeOriginal"          ,"�摜���������̕b�ȉ��̒l              :"
--	elseif t == 37522   then return "SubSecTimeDigitized"         ,"�f�B�W�^���f�[�^���������̕b�ȉ��̒l  :"
--	elseif t == 33434   then return "ExposureTime"                ,"�I�o���ԁi�b�j                        :"
--	elseif t == 33437   then return "FNumber"                     ,"F�l                                   :"
--	elseif t == 34850   then return "ExposureProgram"             ,"�I�o�v���O����                        :"
--	elseif t == 34852   then return "SpectralSensitivity"         ,"�X�y�N�g�����x                        :"
--	elseif t == 34855   then return "ISOSpeedRatings"             ,"ISO�X�s�[�h���[�g                     :"
--	elseif t == 34856   then return "OECF"                        ,"���d�ϊ��֐�                          :"
--	elseif t == 37377   then return "ShutterSpeedValue"           ,"�V���b�^�[�X�s�[�h�iAPEX�j            :"
--	elseif t == 37378   then return "ApertureValue"               ,"�i��iAPEX�j                          :"
--	elseif t == 37379   then return "BrightnessValue"             ,"�P�x�iAPEX�j                          :"
--	elseif t == 37380   then return "ExposureBiasValue"           ,"�I�o�␳�iAPEX�j                      :"
--	elseif t == 37381   then return "MaxApertureValue"            ,"�����Y�̍ŏ�F�l�iAPEX�j               :"
--	elseif t == 37382   then return "SubjectDistance"             ,"��ʑ̋����im�j                       :"
--	elseif t == 37383   then return "MeteringMode"                ,"��������                              :"
--	elseif t == 37384   then return "LightSource"                 ,"����                                  :"
--	elseif t == 37385   then return "Flash"                       ,"�t���b�V��                            :"
--	elseif t == 37386   then return "FocalLength"                 ,"�����Y�̏œ_�����imm�j                :"
--	elseif t == 41483   then return "FlashEnergy"                 ,"�t���b�V���̃G�l���M�[�iBCPS�j        :"
--	elseif t == 41484   then return "SpatialFrequencyResponse"    ,"��Ԏ��g������                        :"
--	elseif t == 41486   then return "FocalPlaneXResolution"       ,"�œ_�ʂ̕������̉𑜓x�i�s�N�Z���j    :"
--	elseif t == 41487   then return "FocalPlaneYResolution"       ,"�œ_�ʂ̍��������̉𑜓x�i�s�N�Z���j  :"
--	elseif t == 41488   then return "FocalPlaneResolutionUnit"    ,"�œ_�ʂ̉𑜓x�̒P��                  :"
--	elseif t == 41492   then return "SubjectLocation"             ,"��ʑ̈ʒu                            :"
--	elseif t == 41493   then return "ExposureIndex"               ,"�I�o�C���f�b�N�X                      :"
--	elseif t == 41495   then return "SensingMethod"               ,"�摜�Z���T�̕���                      :"
--	elseif t == 41728   then return "FileSource"                  ,"�摜���͋@��̎��                    :"
--	elseif t == 41729   then return "SceneType"                   ,"�V�[���^�C�v                          :"
--	elseif t == 41730   then return "CFAPattern"                  ,"CFA�p�^�[��                           :"
--	elseif t == 40965   then return "InteroperabilityIFDPointer"  ,"�݊���IFD�ւ̃|�C���^                 :"   

	else                   return "UNDEFINED"                   ,"�s���ȃ^�O ("..t.."):"   

	end
end

function exif(size)
	local begin = cur()
	
	rstr ("ByteCode",            2)
	if get("ByteCode") == "MM" then
		little_endian(false)
	else
		little_endian(true)
	end
	
	cbyte("002A"  ,              2, 0x002A)
	rbyte("ifd_ofs",             4)
	ifd(begin, get("ifd_ofs"))
	
	seek(begin + size)
end

function ifd(origin, offset, indent)
	local indent = indent or 0
	local tab = string.rep("    ", indent)

	seek(origin + offset)
	rbyte("FieldCount",                                                     2)
	print(tab.."---------------IFD count:"..hexstr(get("FieldCount")).."-----------------")
	
	local count = get("FieldCount") -- �挈���邽�߂�local�ɕۑ�����
	for i=1, count do
		local begin = cur()
		rbyte("Tag",                                                        2)
		rbyte("Type",                                                       2)
		rbyte("Count",                                                      4)
		rbyte("ValueOffset",                                                4)
		
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
				local val = rbyte("Long",                           4)
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
	
	rbyte("NextIFD",                                                        4)
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
			fstr("ff d9", true)
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
enable_print(false)
jpg()
print_table(info)
print_status()