-- sql�N���X

------------------------------------------------
-- class
------------------------------------------------
local name = ...           -- �����������W���[����
local _m = {}              -- �����o�֐������Ђ���e�[�u��
local _meta = {__index=_m} -- ���^�e�[�u��
local _v = {}              -- �v���C�x�[�g�ϐ�(self���L�[�Ƃ���e�[�u��)
package.loaded[name] = _m  -- ��x�ڂ�require()�͂��ꂪ�Ԃ����
_G[name] = _m              -- �O���[�o���ɓo�^���Ă���

------------------------------------------------
-- public
------------------------------------------------
function _m:new()
	obj = {tbl={}}
	setmetatable(obj, _meta )
	return obj
end

function _m:begin()
	gs_sql:exec("begin");
end

function _m:commit()
	gs_sql:exec("commit");
end

function _m:rollback()
	gs_sql:exec("rollback");
end




