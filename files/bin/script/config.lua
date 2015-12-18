-- グローバル変数
local ep, __, en, ee = split_file_name(argv[0])
local sp, sd, sn, se = split_file_name(argv[1])
global("__streamdef_dir__",   __exec_dir__.."script/streamdef/")
global("__exec_path__",       ep)
global("__exec_name__",       en)
global("__exec_ext__",        ee)
global("__stream_path__",     sp)
global("__stream_dir__",      sd)
global("__stream_name__",     sn)
global("__stream_ext__",      se)
global("__out_dir__",         __exec_dir__.."out/")
global("__database_dir__",    __out_dir__)
global("__payload_dir__",     __out_dir__)
global("__error_info_path__", __out_dir__.."err.txt")
global("__text_editor__",     "C:\\Program Files (x86)\\sakura\\sakura.exe")
global("__hex_editor__",      "C:\\Program Files (x86)\\BzEditor\\Bz.exe")

-- windowsの場合はディレクトリ名を/→\に置換する
if windows then
	__streamdef_dir__   = __streamdef_dir__:gsub("(/)", "\\")
	__exec_path__       = __exec_path__:gsub("(/)", "\\")
	__exec_name__       = __exec_name__:gsub("(/)", "\\")
	__exec_ext__        = __exec_ext__:gsub("(/)", "\\")
	__stream_path__     = __stream_path__:gsub("(/)", "\\")
	__stream_dir__      = __stream_dir__:gsub("(/)", "\\")
	__stream_name__     = __stream_name__:gsub("(/)", "\\")
	__stream_ext__      = __stream_ext__:gsub("(/)", "\\")
	__out_dir__         = __out_dir__:gsub("(/)", "\\")
	__database_dir__    = __database_dir__:gsub("(/)", "\\")
	__payload_dir__     = __payload_dir__:gsub("(/)", "\\")
	__error_info_path__ = __error_info_path__:gsub("(/)", "\\")
	__exec_dir__        = __exec_dir__:gsub("(/)", "\\")
	__error_info_path__ = __error_info_path__:gsub("(/)", "\\")
end

-- __out_dir__を作成する
if windows then
	os.execute("mkdir \""..__out_dir__.."\"")
else
	os.execute("mkdir -p \""..__out_dir__.."\"")
end


