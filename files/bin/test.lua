dofile("lib/mylib.lua")

s = BitStream.new()

s:open("test.wav") -- test.wav�����
s:dump (0, 256) -- �擪256�o�C�g��\��


s:byte("hoge", 4, true)                   -- "hoge"�̃f�[�^���S�{�Ɠǂݍ��݁A�R���\�[����ɕ\������
local length = s:byte("length", 4, false) -- "length"�̃f�[�^���S�o�C�g�ǂݍ��ݕϐ��ɋL��
if length ~= 0 then
  s:byte("payload", 3, true)
  s:bit("foo[0-2]", 3, true)              -- �r�b�g�P�ʂœǂݍ��݂��̍s���R���\�[����ɕ\��
  s:bit("foo[3-7]", 5, true)              -- �r�b�g�P�ʂő����ēǂݍ���
end

