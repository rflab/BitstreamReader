--[=======================================[

               LUAスクリプト

hrk. All Right Reserves.


タスク_Initを呼び出さないといけない
	local cfg = {dir = cfg_.dir, file = cfg_.file}
	self.loader = BMELoader:_New()
	self.loader:_Init(cfg)

更新履歴
2009/3/1 ：作成
2009/3/13：名前がぶつかるので、変数名に_つけた

--]=======================================]

--------------------------------------------------
---何度も呼ばれる関数をローカルで
local COYIELD = coroutine.yield

--------------------------------------------------
C_Class("Task")({
	__tostring = function(self)
		return(self._name) 
	end,
	
	--ユーザーデータのみに有効なメタメソッド
	--クラスがユーザーデータを持てば、GCが呼び出すようになる
	--したがって、ここに書く意味はない?
	__gc = function(self)
		print("gc", self)
	end,
	
	_all = {},	--すべてのタスク、コレ自体は弱参照-このテーブルに参照されていてもGCに回収される
	_id_cnt = 1,
})

--------------------------------------------------
---__mode、
---'k' が含まれていたら、テーブルのキーが弱参照となる。
--- もし __mode フィールドが'v' を含んでいたら、テーブルの値が弱参照となる。
setmetatable(Task._all, {__mode = "kv"})

--------------------------------------------------
---コンストラクタ
--実体ごとに必ず一回呼ばれる
function Task:_Ctor()
	self._routine = nil 					--ルーチン
	self._routinepool = GS.routinepool		--グローバルだけど一応保持
	
	--ルーチンで実行中の関数
	self._state = nil
	
	--死んでたら動かない
	self._isdead = false

	--なんとなくID登録
	local id = Task._id_cnt + 1				
	self._id = id
	Task._id_cnt = id
	Task._all[self._id] = self

	--デストラクタ設定
	--newproxy非公式Lua関数、
	self._ud = newproxy(true)
	getmetatable(self._ud).__gc = function(s)
		self:_OnGC()
	end
	
	--_Entry関数があればタスクとして登録
	--なければダミーが登録されているはず
	if self._Entry ~= nil then
		self._routine = self._routinepool:_Get()
		self._routine:_ChangeFunc(self._Entry)
	end

	--コルーチンがなければコルーチンがResumeされない
	GS.tasklist:_AddTask(self)
	
	print("new task --> id", self._id)
end

--------------------------------------------------
---GCされる状態に戻す
---子タスクも消す
function Task:_Dtor()
	self._routinepool:_Back(self._routine)
	self._routine = nil

	--親タスクから外れる
print("w")
   -- Rm(self._children, task) --コレしないと親が生きている限り削除されない。。重そう
    
    --子タスクを消す
	if self._children ~= nil then
		for i,v in pairs(self._children) do
			GS.tasklist:_DelTask(v)
		end
	end
	self._children = nil
end

--------------------------------------------------
function Task:_AddChild(obj)
	self._children = self._children or {}

	table.insert(self._children, obj)
	print("_AddChild", self._name, "children-->", self._children)
	for i , v in pairs(self._children) do
		print(v._name)
	end
	
end

--------------------------------------------------
function Task:_AddChildren(t)
	self._children = self._children or {}
	
	for i, v in pairs(t) do
	--	self:_AddChild(v)
		table.insert(self._children, v)
	end
end

--------------------------------------------------
function Task:_SetChildren(t)
	self._children = t
end

--------------------------------------------------
function Task:_OnGC()
	print("gc -->", self)
end

--------------------------------------------------
---コルーチン内から呼ぶ関数
---数値でその数値だけ待つ
---"pause"でずっと待つ
---外部からpauseがかけられた場合はwaitのカウントもとまるはず
function Task:_Wait(val)
	COYIELD("wait", val)
    --self._time = self._time + cnt + 1
end

--------------------------------------------------
function Task:_OnPause(on_, off_)
	self.onpauseon = on_
	self.onpauseoff = off_
end

--------------------------------------------------
function Task:_PauseOn()
	self._routine:_PauseOn()
	if nil ~= self.onpauseon then
		self.onpauseon()
	end
end


--------------------------------------------------
function Task:_PauseOff()
	self._routine:_PauseOff()
	if nil ~= self.onpauseoff then
		self.onpauseoff()
	end
end

--------------------------------------------------
function Task:_PauseOnAll()
	print("pause on all", self._name, "children -->", self._children)
	self:_PauseOn()
	
	if self._children ~= nil then
		for i,v in pairs(self._children) do
			v:_PauseOnAll()
		end
	end
end
--------------------------------------------------
function Task:_PauseOffAll()
	self:_PauseOff()
	
	if self._children ~= nil then
		for i,v in pairs(self._children) do
			v:_PauseOffAll()
		end
	end
end

--------------------------------------------------
--機能を活かす
function Task:_On()
	--error("no On() override")
end

--------------------------------------------------
--子も含めてすべての絵を隠す
function Task:_OnAll()

	--if true then
	--	return
	--end

	self:_On()
	
	if self._children == nil then
		return
	end
	
	for i, v in pairs(self._children) do
		v:_OnAll()
	end
end

--------------------------------------------------
--機能を殺す
function Task:_Off()
	--error("no Off() override")
end

--------------------------------------------------
--子も含めてすべての絵を隠す
function Task:_OffAll()
	self:_Off()
	
	if self._children == nil then
		return
	end
	
	for i, v in pairs(self._children) do
		v:_OffAll()
	end
end

--------------------------------------------------
function Task:_Priority(priority_)
	--error("no _Priority() override", self._name, priority_)
end

--------------------------------------------------
---現在の状態名（＝状態関数名）を取得
function Task:_GetState()
	return self._state
end

--------------------------------------------------
function Task:NextID()
	local next = Task._id_cnt
	
	return next
end

--------------------------------------------------
---（クラス関数）すべての存在するTaskの中からIDで探す
function Task:_GetTask(id)
	return Task._all[id]
end

--------------------------------------------------
---（クラス関数）すべての存在するTaskの中からIDで探す
function Task:_RequestDelete()
	self.deleted = true
end

--------------------------------------------------
-----子タスク
--function Task:_SetChild(task)
--	if task._parent ~= nil then
--		task:_Independence()		--すでに親がいるなら引き離す
--	end
--	self._children = self._children or {} --初めての子供？
--	table.insert(self._children, task)	--子を持つ
--	task._parent = self					--親として認識させる
--end

--------------------------------------------------
-----子タスクを捨てる
-----task用にrmをラッピング
--function Task:_Abandon(task)
--	if self._children ~= nil then
--	    Rm(self._children, task)
--	end
--end

--------------------------------------------------
-----親タスクから切り離す
-----というか、親に捨ててもらう
--function Task:_Independence()
--	if self._parent ~= nil then
--		self._parent:_Abandon(self)
--		self._parent = nil
--	end
--end

--------------------------------------------------
--drawsys table 使うと重たいので、タスク追加時にプライオリティ指定して、タスクが捨てられると同時描画もされなくなるようにする
---描画システムに登録
--function Task:_DrawSys(ds)
--    self._ds = ds
--    ds:_Add(self)
--end

--	if self._ds ~= nil then				--DrawSystemからはずす
--		Rm(self._ds, self)
--		self._ds = nil
--	end

--------------------------------------------------
---taskの切り替え
--function Task:_ChangeState(state)
--	local f = self[state]
--	if nil == f then
--		print("ChangeFunc Error!", self, state)
--		return false
--	elseif "function" ~= type(f) then
--		print("type ~= function -->", self, state)
--		return false
--	end
--	print("_ChangeState", self, state)
--	self._routine:_ChangeFunc(f)
--	--???なんで。。self._routine:_Restart()
--	self._state = state
--	return true
--end

--------------------------------------------------
---Draw Interface
--function Task:_Draw()
--end

--------------------------------------------------
-----_GoTo
--function Task:_GoTo(label)
--	COYIELD("goto", label)
--end

--------------------------------------------------
-----_Exit
--function Task:_Exit()
--	COYIELD("exit", nil)
--end

--------------------------------------------------
