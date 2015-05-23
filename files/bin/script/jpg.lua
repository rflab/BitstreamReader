-- bmp解析
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
	if     tag == 0     then return "GPSVersionID"                ,"GPSタグのバージョン                   :"
	elseif tag == 1     then return "GPSLatitudeRef"              ,"緯度の南北                            :"
	elseif tag == 2     then return "GPSLatitude"                 ,"緯度（度、分、秒）                    :"
	elseif tag == 3     then return "GPSLongitudeRef"             ,"経度の東西                            :"
	elseif tag == 4     then return "GPSLongitude"                ,"経度（度、分、秒）                    :"
	elseif tag == 5     then return "GPSAltitudeRef"              ,"高度の基準                            :"
	elseif tag == 6     then return "GPSAltitude"                 ,"高度（m）                             :"
	elseif tag == 7     then return "GPSTimeStamp"                ,"GPSの時間（原子時計）                 :"
	elseif tag == 8     then return "GPSSatellites"               ,"測位に使用したGPS衛星                 :"
	elseif tag == 9     then return "GPSStatus"                   ,"GPS受信機の状態                       :"
	elseif tag == 10    then return "GPSMeasureMode"              ,"GPSの測位モード                       :"
	elseif tag == 11    then return "GPSDOP"                      ,"測位の信頼性                          :"
	elseif tag == 12    then return "GPSSpeedRef"                 ,"速度の単位                            :"
	elseif tag == 13    then return "GPSSpeed"                    ,"速度                                  :"
	elseif tag == 14    then return "GPSTrackRef"                 ,"進行方向の基準                        :"
	elseif tag == 15    then return "GPSTrack"                    ,"進行方向（度）                        :"
	elseif tag == 16    then return "GPSImgDirectionRef"          ,"撮影方向の基準                        :"
	elseif tag == 17    then return "GPSImgDirection"             ,"撮影方向（度）                        :"
	elseif tag == 18    then return "GPSMapDatum"                 ,"測位に用いた地図データ                :"
	elseif tag == 19    then return "GPSDestLatitudeRef"          ,"目的地の緯度の南北                    :"
	elseif tag == 20    then return "GPSDestLatitude"             ,"目的地の緯度（度、分、秒）            :"
	elseif tag == 21    then return "GPSDestLongitudeRef"         ,"目的地の経度の東西                    :"
	elseif tag == 22    then return "GPSDestLongitude"            ,"目的地の経度（度、分、秒）            :"
	elseif tag == 23    then return "GPSBearingRef"               ,"目的地の方角の基準                    :"
	elseif tag == 24    then return "GPSBearing"                  ,"目的地の方角（度）                    :"
	elseif tag == 25    then return "GPSDestDistanceRef"          ,"目的地への距離の単位                  :"
	elseif tag == 26    then return "GPSDestDistance"             ,"目的地への距離                        :"
	elseif tag == 256   then return "ImageWidth"                  ,"画像の幅（ピクセル）                  :"
	elseif tag == 257   then return "ImageLength"                 ,"画像の高さ（ピクセル）                :"
	elseif tag == 258   then return "BitsPerSample"               ,"画素のビットの深さ（ビット）          :"
	elseif tag == 259   then return "Compression"                 ,"圧縮の種類                            :"
	elseif tag == 262   then return "PhotometricInterpretation"   ,"画素こう成の種類                      :"
	elseif tag == 274   then return "Orientation"                 ,"画素の並び                            :"
	elseif tag == 277   then return "SamplesPerPixel"             ,"ピクセル毎のコンポーネント数          :"
	elseif tag == 284   then return "PlanarConfiguration"         ,"画素データの並び                      :"
	elseif tag == 530   then return "YCbCrSubSampling"            ,"画素の比率こう成                      :"
	elseif tag == 531   then return "YCbCrPositioning"            ,"画素の位置こう成                      :"
	elseif tag == 282   then return "XResolution"                 ,"画像の幅方向の解像度（dpi）           :"
	elseif tag == 283   then return "YResolution"                 ,"画像の高さ方向の解像度（dpi）         :"
	elseif tag == 296   then return "ResolutionUnit"              ,"解像度の単位                          :"
	elseif tag == 273   then return "StripOffsets"                ,"イメージデータへのオフセット          :"
	elseif tag == 278   then return "RowsPerStrip"                ,"１ストリップあたりの行数              :"
	elseif tag == 279   then return "StripByteCounts"             ,"各ストリップのサイズ（バイト）        :"
	elseif tag == 513   then return "JPEGInterchangeFormat"       ,"JPEGサムネイルのSOIへのオフセット     :"
	elseif tag == 514   then return "JPEGInterchangeFormatLength" ,"JPEGサムネイルデータのサイズ（バイト）:"
	elseif tag == 301   then return "TransferFunction"            ,"諧調カーブ特性                        :"
	elseif tag == 318   then return "WhitePoint"                  ,"ホワイトポイントの色座標値            :"
	elseif tag == 319   then return "PrimaryChromaticities"       ,"原色の色座標値                        :"
	elseif tag == 529   then return "YCbCrCoefficients"           ,"色変換マトリックス係数                :"
	elseif tag == 532   then return "ReferenceBlackWhite"         ,"黒色と白色の値                        :"
	elseif tag == 306   then return "DateTime"                    ,"ファイル変更日時                      :"
	elseif tag == 270   then return "ImageDescription"            ,"画像タイトル                          :"
	elseif tag == 271   then return "Make"                        ,"メーカー                              :"
	elseif tag == 272   then return "Model"                       ,"モデル                                :"
	elseif tag == 305   then return "Software"                    ,"使用したSoftware                      :"
	elseif tag == 315   then return "Artist"                      ,"撮影者名                              :"
	elseif tag == 3432  then return "Copyright"                   ,"著作権                                :"
	elseif tag == 34665 then return "ExifIFDPointer"              ,"Exif IFDへのポインタ                  :"
	elseif tag == 34853 then return "GPSInfoIFDPointer"           ,"GPS情報IFDへのポインタ                :"
	elseif tag == 36864 then return "ExifVersion"                 ,"Exifバージョン                        :"
	elseif tag == 40960 then return "FlashPixVersion"             ,"対応FlashPixのバージョン              :"
	elseif tag == 40961 then return "ColorSpace"                  ,"色空間情報                            :"
	elseif tag == 37121 then return "ComponentsConfiguration"     ,"コンポーネントの意味                  :"
	elseif tag == 37122 then return "CompressedBitsPerPixel"      ,"画像圧縮モード（ビット／ピクセル）    :"
	elseif tag == 40962 then return "PixelXDimension"             ,"有効な画像の幅（ピクセル）            :"
	elseif tag == 40963 then return "PixelYDimension"             ,"有効な画像の高さ（ピクセル）          :"
	elseif tag == 37500 then return "MakerNote"                   ,"メーカ固有情報                        :"
	elseif tag == 37510 then return "UserComment"                 ,"ユーザコメント                        :"
	elseif tag == 40964 then return "RelatedSoundFile"            ,"関連音声ファイル名                    :"
	elseif tag == 36867 then return "DateTimeOriginal"            ,"オリジナル画像の生成日時              :"
	elseif tag == 36868 then return "DateTimeDigitized"           ,"ディジタルデータの生成日時            :"
	elseif tag == 37520 then return "SubSecTime"                  ,"ファイル変更日時の秒以下の値          :"
	elseif tag == 37521 then return "SubSecTimeOriginal"          ,"画像生成日時の秒以下の値              :"
	elseif tag == 37522 then return "SubSecTimeDigitized"         ,"ディジタルデータ生成日時の秒以下の値  :"
	elseif tag == 33434 then return "ExposureTime"                ,"露出時間（秒）                        :"
	elseif tag == 33437 then return "FNumber"                     ,"F値                                   :"
	elseif tag == 34850 then return "ExposureProgram"             ,"露出プログラム                        :"
	elseif tag == 34852 then return "SpectralSensitivity"         ,"スペクトル感度                        :"
	elseif tag == 34855 then return "ISOSpeedRatings"             ,"ISOスピードレート                     :"
	elseif tag == 34856 then return "OECF"                        ,"光電変換関数                          :"
	elseif tag == 37377 then return "ShutterSpeedValue"           ,"シャッタースピード（APEX）            :"
	elseif tag == 37378 then return "ApertureValue"               ,"絞り（APEX）                          :"
	elseif tag == 37379 then return "BrightnessValue"             ,"輝度（APEX）                          :"
	elseif tag == 37380 then return "ExposureBiasValue"           ,"露出補正（APEX）                      :"
	elseif tag == 37381 then return "MaxApertureValue"            ,"レンズの最小F値（APEX）               :"
	elseif tag == 37382 then return "SubjectDistance"             ,"被写体距離（m）                       :"
	elseif tag == 37383 then return "MeteringMode"                ,"測光方式                              :"
	elseif tag == 37384 then return "LightSource"                 ,"光源                                  :"
	elseif tag == 37385 then return "Flash"                       ,"フラッシュ                            :"
	elseif tag == 37386 then return "FocalLength"                 ,"レンズの焦点距離（mm）                :"
	elseif tag == 41483 then return "FlashEnergy"                 ,"フラッシュのエネルギー（BCPS）        :"
	elseif tag == 41484 then return "SpatialFrequencyResponse"    ,"空間周波数応答                        :"
	elseif tag == 41486 then return "FocalPlaneXResolution"       ,"焦点面の幅方向の解像度（ピクセル）    :"
	elseif tag == 41487 then return "FocalPlaneYResolution"       ,"焦点面の高さ方向の解像度（ピクセル）  :"
	elseif tag == 41488 then return "FocalPlaneResolutionUnit"    ,"焦点面の解像度の単位                  :"
	elseif tag == 41492 then return "SubjectLocation"             ,"被写体位置                            :"
	elseif tag == 41493 then return "ExposureIndex"               ,"露出インデックス                      :"
	elseif tag == 41495 then return "SensingMethod"               ,"画像センサの方式                      :"
	elseif tag == 41728 then return "FileSource"                  ,"画像入力機器の種類                    :"
	elseif tag == 41729 then return "SceneType"                   ,"シーンタイプ                          :"
	elseif tag == 41730 then return "CFAPattern"                  ,"CFAパターン                           :"
	elseif tag == 40965 then return "InteroperabilityIFDPointer"  ,"互換性IFDへのポインタ                 :"       
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
