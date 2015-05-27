-- bmp解析
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
	rbyte("Length",              2) -- SOSの場合これはあてにならない
	rbyte("Ns",                  1)
	
	for i=1, get("Ns") do
		rbyte("Cs_id",           1) -- 成分ID
		rbit ("DC_DHT",          4) -- ＤＣ成分ハフマンテーブル番号
		rbit ("AC_DHT",          4) -- ＡＣ成分ハフマンテーブル番号
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
	if     t == 0     then return "GPSVersionID"                ,"GPSタグのバージョン                   :"
	elseif t == 1     then return "GPSLatitudeRef"              ,"緯度の南北                            :"
	elseif t == 2     then return "GPSLatitude"                 ,"緯度（度、分、秒）                    :"
	elseif t == 3     then return "GPSLongitudeRef"             ,"経度の東西                            :"
	elseif t == 4     then return "GPSLongitude"                ,"経度（度、分、秒）                    :"
	elseif t == 5     then return "GPSAltitudeRef"              ,"高度の基準                            :"
	elseif t == 6     then return "GPSAltitude"                 ,"高度（m）                             :"
	elseif t == 7     then return "GPSTimeStamp"                ,"GPSの時間（原子時計）                 :"
	elseif t == 8     then return "GPSSatellites"               ,"測位に使用したGPS衛星                 :"
	elseif t == 9     then return "GPSStatus"                   ,"GPS受信機の状態                       :"
	elseif t == 10    then return "GPSMeasureMode"              ,"GPSの測位モード                       :"
	elseif t == 11    then return "GPSDOP"                      ,"測位の信頼性                          :"
	elseif t == 12    then return "GPSSpeedRef"                 ,"速度の単位                            :"
	elseif t == 13    then return "GPSSpeed"                    ,"速度                                  :"
	elseif t == 14    then return "GPSTrackRef"                 ,"進行方向の基準                        :"
	elseif t == 15    then return "GPSTrack"                    ,"進行方向（度）                        :"
	elseif t == 16    then return "GPSImgDirectionRef"          ,"撮影方向の基準                        :"
	elseif t == 17    then return "GPSImgDirection"             ,"撮影方向（度）                        :"
	elseif t == 18    then return "GPSMapDatum"                 ,"測位に用いた地図データ                :"
	elseif t == 19    then return "GPSDestLatitudeRef"          ,"目的地の緯度の南北                    :"
	elseif t == 20    then return "GPSDestLatitude"             ,"目的地の緯度（度、分、秒）            :"
	elseif t == 21    then return "GPSDestLongitudeRef"         ,"目的地の経度の東西                    :"
	elseif t == 22    then return "GPSDestLongitude"            ,"目的地の経度（度、分、秒）            :"
	elseif t == 23    then return "GPSBearingRef"               ,"目的地の方角の基準                    :"
	elseif t == 24    then return "GPSBearing"                  ,"目的地の方角（度）                    :"
	elseif t == 25    then return "GPSDestDistanceRef"          ,"目的地への距離の単位                  :"
	elseif t == 26    then return "GPSDestDistance"             ,"目的地への距離                        :"
	elseif t == 256   then return "ImageWidth"                  ,"画像の幅（ピクセル）                  :"
	elseif t == 257   then return "ImageLength"                 ,"画像の高さ（ピクセル）                :"
	elseif t == 258   then return "BitsPerSample"               ,"画素のビットの深さ（ビット）          :"
	elseif t == 259   then return "Compression"                 ,"圧縮の種類                            :"
	elseif t == 262   then return "PhotometricInterpretation"   ,"画素こう成の種類                      :"
	elseif t == 274   then return "Orientation"                 ,"画素の並び                            :"
	elseif t == 277   then return "SamplesPerPixel"             ,"ピクセル毎のコンポーネント数          :"
	elseif t == 284   then return "PlanarConfiguration"         ,"画素データの並び                      :"
	elseif t == 530   then return "YCbCrSubSampling"            ,"画素の比率こう成                      :"
	elseif t == 531   then return "YCbCrPositioning"            ,"画素の位置こう成                      :"
	elseif t == 282   then return "XResolution"                 ,"画像の幅方向の解像度（dpi）           :"
	elseif t == 283   then return "YResolution"                 ,"画像の高さ方向の解像度（dpi）         :"
	elseif t == 296   then return "ResolutionUnit"              ,"解像度の単位                          :"
	elseif t == 273   then return "StripOffsets"                ,"イメージデータへのオフセット          :"
	elseif t == 278   then return "RowsPerStrip"                ,"１ストリップあたりの行数              :"
	elseif t == 279   then return "StripByteCounts"             ,"各ストリップのサイズ（バイト）        :"
	elseif t == 513   then return "JPEGInterchangeFormat"       ,"JPEGサムネイルのSOIへのオフセット     :"
	elseif t == 514   then return "JPEGInterchangeFormatLength" ,"JPEGサムネイルデータのサイズ（バイト）:"
	elseif t == 301   then return "TransferFunction"            ,"諧調カーブ特性                        :"
	elseif t == 318   then return "WhitePoint"                  ,"ホワイトポイントの色座標値            :"
	elseif t == 319   then return "PrimaryChromaticities"       ,"原色の色座標値                        :"
	elseif t == 529   then return "YCbCrCoefficients"           ,"色変換マトリックス係数                :"
	elseif t == 532   then return "ReferenceBlackWhite"         ,"黒色と白色の値                        :"
	elseif t == 306   then return "DateTime"                    ,"ファイル変更日時                      :"
	elseif t == 270   then return "ImageDescription"            ,"画像タイトル                          :"
	elseif t == 271   then return "Make"                        ,"メーカー                              :"
	elseif t == 272   then return "Model"                       ,"モデル                                :"
	elseif t == 305   then return "Software"                    ,"使用したSoftware                      :"
	elseif t == 315   then return "Artist"                      ,"撮影者名                              :"
	elseif t == 3432  then return "Copyright"                   ,"著作権                                :"
	elseif t == 34665 then return "ExifIFDPointer"              ,"Exif IFDへのポインタ                  :"
	elseif t == 34853 then return "GPSInfoIFDPointer"           ,"GPS情報IFDへのポインタ                :"
	elseif t == 36864 then return "ExifVersion"                 ,"Exifバージョン                        :"
	elseif t == 40960 then return "FlashPixVersion"             ,"対応FlashPixのバージョン              :"
	elseif t == 40961 then return "ColorSpace"                  ,"色空間情報                            :"
	elseif t == 37121 then return "ComponentsConfiguration"     ,"コンポーネントの意味                  :"
	elseif t == 37122 then return "CompressedBitsPerPixel"      ,"画像圧縮モード（ビット／ピクセル）    :"
	elseif t == 40962 then return "PixelXDimension"             ,"有効な画像の幅（ピクセル）            :"
	elseif t == 40963 then return "PixelYDimension"             ,"有効な画像の高さ（ピクセル）          :"
	elseif t == 37500 then return "MakerNote"                   ,"メーカ固有情報                        :"
	elseif t == 37510 then return "UserComment"                 ,"ユーザコメント                        :"
	elseif t == 40964 then return "RelatedSoundFile"            ,"関連音声ファイル名                    :"
	elseif t == 36867 then return "DateTimeOriginal"            ,"オリジナル画像の生成日時              :"
	elseif t == 36868 then return "DateTimeDigitized"           ,"ディジタルデータの生成日時            :"
	elseif t == 37520 then return "SubSecTime"                  ,"ファイル変更日時の秒以下の値          :"
	elseif t == 37521 then return "SubSecTimeOriginal"          ,"画像生成日時の秒以下の値              :"
	elseif t == 37522 then return "SubSecTimeDigitized"         ,"ディジタルデータ生成日時の秒以下の値  :"
	elseif t == 33434 then return "ExposureTime"                ,"露出時間（秒）                        :"
	elseif t == 33437 then return "FNumber"                     ,"F値                                   :"
	elseif t == 34850 then return "ExposureProgram"             ,"露出プログラム                        :"
	elseif t == 34852 then return "SpectralSensitivity"         ,"スペクトル感度                        :"
	elseif t == 34855 then return "ISOSpeedRatings"             ,"ISOスピードレート                     :"
	elseif t == 34856 then return "OECF"                        ,"光電変換関数                          :"
	elseif t == 37377 then return "ShutterSpeedValue"           ,"シャッタースピード（APEX）            :"
	elseif t == 37378 then return "ApertureValue"               ,"絞り（APEX）                          :"
	elseif t == 37379 then return "BrightnessValue"             ,"輝度（APEX）                          :"
	elseif t == 37380 then return "ExposureBiasValue"           ,"露出補正（APEX）                      :"
	elseif t == 37381 then return "MaxApertureValue"            ,"レンズの最小F値（APEX）               :"
	elseif t == 37382 then return "SubjectDistance"             ,"被写体距離（m）                       :"
	elseif t == 37383 then return "MeteringMode"                ,"測光方式                              :"
	elseif t == 37384 then return "LightSource"                 ,"光源                                  :"
	elseif t == 37385 then return "Flash"                       ,"フラッシュ                            :"
	elseif t == 37386 then return "FocalLength"                 ,"レンズの焦点距離（mm）                :"
	elseif t == 41483 then return "FlashEnergy"                 ,"フラッシュのエネルギー（BCPS）        :"
	elseif t == 41484 then return "SpatialFrequencyResponse"    ,"空間周波数応答                        :"
	elseif t == 41486 then return "FocalPlaneXResolution"       ,"焦点面の幅方向の解像度（ピクセル）    :"
	elseif t == 41487 then return "FocalPlaneYResolution"       ,"焦点面の高さ方向の解像度（ピクセル）  :"
	elseif t == 41488 then return "FocalPlaneResolutionUnit"    ,"焦点面の解像度の単位                  :"
	elseif t == 41492 then return "SubjectLocation"             ,"被写体位置                            :"
	elseif t == 41493 then return "ExposureIndex"               ,"露出インデックス                      :"
	elseif t == 41495 then return "SensingMethod"               ,"画像センサの方式                      :"
	elseif t == 41728 then return "FileSource"                  ,"画像入力機器の種類                    :"
	elseif t == 41729 then return "SceneType"                   ,"シーンタイプ                          :"
	elseif t == 41730 then return "CFAPattern"                  ,"CFAパターン                           :"
	elseif t == 40965 then return "InteroperabilityIFDPointer"  ,"互換性IFDへのポインタ                 :"   
	else                   return "UNDEFINED"                   ,"不明なタグ ("..t.."):"   
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
	
	local count = get("FieldCount") -- 先決するためにlocalに保存する
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
			
			-- 次の階層
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
