-- CSV�t�@�C���o�̓X�g���[��

local name = ...           -- �����������W���[����
local _m = {}              -- �����o�֐������Ђ���e�[�u��
local _meta = {__index=_m} 
local _v = {}              -- �v���C�x�[�g�ϐ�(self���L�[�Ƃ���e�[�u��)
package.loaded[name] = _m  -- ��x�ڂ�require()�͂��ꂪ�Ԃ����
_G[name] = _m              -- �O���[�o���ɓo�^���Ă���

------------------------------------------------
-- private
------------------------------------------------

------------------------------------------------
-- public
------------------------------------------------

function _m:new ()
	obj = {}
	--_v[obj] = {}
	setmetatable(obj, _meta)
	return obj
end

function _m:enter(name)
	self[name] = self[name] or {total_time=0, prev_time=0, count=0}
	self[name].prev_time = os.clock()
	self[name].count = self[name].count + 1
end

function _m:leave(name)
	self[name].total_time = 
		self[name].total_time + (os.clock() - self[name].prev_time)
end

function _m:print()
	for k, v in pairs(self) do
		print(k, "total:"..v.total_time, 
			"count:"..v.count, "average:"..v.total_time/v.count)
	end
end
