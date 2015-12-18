-- "%w+" match →バイナリに変換

local file = io.open(__stream_path__, "rb")
for pattern in file:lines("*l") do
	write(__stream_dir__..__stream_name__..".dat", pattern)
end

-- ファイルストリームとして読み込み
open(__stream_dir__..__stream_name__..".dat")
dump()

