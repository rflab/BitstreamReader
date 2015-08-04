-- ライブラリロード
package.path = __exec_dir__.."script/util/?.lua"
require("profiler")
require("stream")
require("wavfile")
require("bitmap")
require("csv")
require("explicit_globals")
require("util")
require("cmd")
use_explicit_globals(true)

