-- ライブラリロード
package.path = __exec_dir__.."script/util/?.lua"
require("profiler")
require("stream")
require("csv")
require("explicit_globals")
require("util")
require("cmd")
require("check_stream")
use_explicit_globals(true)

