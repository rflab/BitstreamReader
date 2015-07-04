-- sqlクラス

------------------------------------------------
-- class
------------------------------------------------
local name = ...           -- 第一引数がモジュール名
local _m = {}              -- メンバ関数を補樹威するテーブル
local _meta = {__index=_m} -- メタテーブル
local _v = {}              -- プライベート変数(selfをキーとするテーブル)
package.loaded[name] = _m  -- 二度目のrequire()はこれが返される
_G[name] = _m              -- グローバルに登録しておく

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




