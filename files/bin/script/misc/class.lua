--[=======================================[

               LUAスクリプト

rf. All Right Reserves.


クラスを作成するときにはlocal class = CHoge:_New()等
_New()では_Ctor(...)を呼び出すので、これの実装が必要、
...には_Newの引数が渡される。





更新履歴
2009/3/1：作成

--]=======================================]

if rawget(_G, "global") == nil then
  global = function() end
end

local all = {} -- リロード用全インスタンス
setmetatable(all, {__mode = "kv"}) --key, valueともに弱参照


--reloadfunc 未対応 初めてクラスが定義されたときに呼ばれる関数を入れる
--クラス作成用クロージャ（C_Create）を返す関数
--これにメンバ変数を追加して呼び出すことでクラスが定義される
function C_Class(name_)--, reloadfunc)
	--reloadfunc = reloadfunc or C_DefReload
    return function(classTable_)
        C_Create(name_, nil, classTable_)--, reloadfunc)
    end
end

--スパークラスの__indexを引き継いだクラス作成
--C_Createにsuperが与えられるため、setmetatable(class, super)が呼べる≒継承
function C_SubClass(name_, super_)--, reloadfunc)
	--reloadfunc = reloadfunc	or C_DefReload
    return function(classTable_)
        C_Create(name_, super_, classTable_)--, reloadfunc)
    end
end


-- 派生クラスを作成
-- 前回作ったクラスがある場合はその中身だけ置き換える。
function C_Create(name_, super_, classTable_)--, reloadfunc)
	
	--クラス検索--見つかったらリロード
	local classTable = rawget(_G, name_)
	if classTable ~= nil then
		C_DefReloadAll(classTable, super_, classTable_)
		--if reloadfunc ~= nil then
		--	reloadfunc(class, super, classTable)
		--end
	else
		classTable = classTable_
		global(name_, classTable_) --グローバルに元になる連想配列作成
	end
	
	--クラス名で登録
	classTable._name = name_
	
	------------------------------------------------------------継承
	--クラステーブルに__indexを入れておけば、
	--このクラステーブルを元に作成したインスタンスは変数・関数をクラステーブルから探すことができる
	--これでは正しく継承できないので変更★
	--classTable.__index = classTable 
	--書き方が違うけどおなじ意味-->(classTable._super = super_)
			
	--★派生クラスに存在しないインデックスは親クラスから拾うようにする
	if super_ ~= nil then
		classTable._super = super_
		if rawget(super_, "__index") == super_ then
			--一回目の派生は基底クラスそのものをメタテーブルに加える
			setmetatable(classTable, super_)
		else
			--二度目に派生したときはテーブル追加
			setmetatable(classTable, {__index = super_})
		end
	end
	----------------------------------------------------------------

	--New関数追加
	--_Newによって返される関数は:で呼び出す関数にはならないので、selfを引数に入れることが必要？
	classTable._New = 
		function (self,...) --selfはclassTable_のこと
			local t = C_Instance(self)
			t:_Ctor(...)
			print("new instance-->", self._name)
			return t
		end
	classTable._Delete = 
		function (self) --selfはclassTable_のこと
			self:_Dtor()
			print("delete instance-->", self._name)
--			if self._super ~= nil then
--				rawget(self.._super, "_Dtor")()
--			end
		end				
--	classTable:_New = 
--		function (...)
--			local t = C_Instance(self)
--			t:_Ctor(...)
--			return t
--		end
	
--	setmetatable(class, {
--		__index    = class
--		__tostring = function(self) return(self._name) end,--初めにクラス名を登録しているので、クラスという認識があるならいらない
--		__gc       = function(self) print("gc", self) end
--	})
	
end

--クラスからインスタンスを生成
--recycleにテーブルを渡せば、それをインスタンステーブルに使用する
--recycleがnilなら、内部で新たにインスタンステーブルを作成
--生成インスタンスをリターンする
function C_Instance(class, recycle)
	--{}でテーブル一個作成できる。これがインスタンス
	--localになっているが、この関数からリターンされた先で参照しておけば破棄されない
	--local t = {}
	local t = recycle or {}		
	
	--メタテーブルはテーブルとテーブルを結びつけるための用要素を含んだテーブル
	--このうち、__indexでテーブルを参照していると、
	--元のテーブルで参照したがそこに存在しない値を、__indexに登録したテーブルへ探しに行くようになる
	--C_Create内で、大本のテーブルに__indexを入れてあるため（class.__index = class）
	--インスタンスでは大本のテーブルをメタテーブルとしてしまうことができる、
	--大本のテーブルには__.*以外に、普通の値も保存できるので、メンバ関数とその継承、スタティック変数的なことが可能になる
	--妙技
	--★
	if rawget(class, "__index") == class then
		setmetatable(t, class)
	else
		setmetatable(t, {__index = class})
	end

	all[t] = true
	return t;
end

---クラスリロード
---メンバ変数のうち、
---ファイルを読み込んでも、もともとあった変数については継続する
--function C_DefReload(class, super, vars)
--	for k,v in pairs(vars) do
--		if rawget(class,k) == nil then
--			class[k] = v
--		end
--	end
--end

---- クラスリロードすべて上書き
function C_DefReloadAll(class, super, vars)
	for k,v in pairs(vars) do
		class[k] = v
	end
end


---- クラスリロード何もしない
--function C_DefReloaeNone(class, super, vars)
--end


----クラスのReload関数全部呼ぶ
--function C_Reload()
--	for i,v in pairs(all) do
--		if i.Reload ~= nil then
--			i:Reload()
--		end
--	end
--end

--メタテーブルがまさにスーパークラスにあたる
function C_GetSuper(t)
	local mt = getmetatable(t)
	return rawget(mt, "__index")
end

-- クラス名を取得
function C_GetName(t)
	return rawget(C_GetSuper(t), "_name")
end

---- 全クラスを取得
--function C_GetAll()
--	return all
--end
--
---- 全クラス巡回し、funcnameと同じ名前のメンバ関数をもっていたらそれを呼び出す
--function C_CallAll(funcname)
--	for k, v in pairs(all) do
--		if k[funcname] ~= nil then
--			k[funcname]()
--		end
--	end
--end

------------------------------------------------------------------------------以下、デバッグ用
function C_Anarize()
	print("--- analyze_instances --")
	print("<count>", "| <class>")
	local classes = {}
	for k, v in pairs(all) do
		local name = k._name
		if classes[name] == nil then
			classes[name] = {}
		end
		local stat = classes[name]
		stat.num = (stat.num or 0) + 1
	end

	for k, v in pairs(classes) do
		print(v.num.."| "..k)
	end
end

function C_AnalyzeFull()
    print("--- analyze_instances FULL!! --")
    for k, v in pairs(all) do
        local name = k._name
        print(k._name)
        for k, vv in pairs(k) do
        	print("", k, "", vv)
        end
    end
end

function C_AnalizeByName(name)
	print("--- analyze_instances's_detail --")
	local cnt = 0
	for k, v in pairs(all) do
		if name == k._name then
			print(k._name)
			for k, vv in pairs(k) do
				print("", k, "", vv)
			end
			cnt = cnt + 1
		end
	end
	if 0 == cnt then
		print("no such classes..")
	end 
end

function C_AnalizeDetail(c)
	print("--- analyze_instance_detail --")

	if nil == c then
		print("nil class..")
		return
	end
	
--    "nil" (という文字列。nil 値ではなく。)
--    "number"
--    "string"
--    "boolean"
--    "table"
--    "function"
--    "thread"
--    "userdata"
	
	print(c._name)
	for k, v in pairs(c) do
		if type(v) ~= "userdata" then
			print("", k, "", v)
		--elseif getmetatable(v) ~= nil then
		--	print("", k, "", v)
		--elseif getmetatable(v) ~= nil then
		else
			print("", k, "userdata")
		end
	end
end


