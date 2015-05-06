dofile("lib/mylib.lua")

s = BitStream.new()

s:open("test.wav") -- test.wavを解析
s:dump (0, 256) -- 先頭256バイトを表示


s:byte("hoge", 4, true)                   -- "hoge"のデータを４倍と読み込み、コンソール上に表示許可
local length = s:byte("length", 4, false) -- "length"のデータを４バイト読み込み変数に記憶
if length ~= 0 then
  s:byte("payload", 3, true)
  s:bit("foo[0-2]", 3, true)              -- ビット単位で読み込みこの行をコンソール上に表示
  s:bit("foo[3-7]", 5, true)              -- ビット単位で続けて読み込み
end

