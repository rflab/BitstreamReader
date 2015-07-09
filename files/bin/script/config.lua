-- グローバル変数
local ep, __, en, ee = split_file_name(argv[0])
local sp, sd, sn, se = split_file_name(argv[1])
global("__exec_path__",     ep)
global("__exec_name__",     en)
global("__exec_ext__",      ee)
global("__stream_path__",   sp)
global("__stream_dir__",    sd)
global("__stream_name__",   sn)
global("__stream_ext__",    se)
global("__out_dir__",       __exec_dir__.."out/")
global("__streamdef_dir__", __exec_dir__.."script/streamdef/")

-- __out_dir__を作成しておく
if windows then
	os.execute("mkdir \""..__out_dir__.."\"")
else
	os.execute("mkdir -p \""..__out_dir__.."\"")
end
