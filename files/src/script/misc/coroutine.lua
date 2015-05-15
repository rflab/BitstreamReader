--[=======================================[

               LUAスクリプト

hrk. All Right Reserves.


更新履歴
2009/3/10：作成.

--]=======================================]


local Dummy = function(task, rt) end
local COSTATUS = coroutine.status
local CORESUME = coroutine.resume
local COYIELD = coroutine.yield
local COCREATE = coroutine.create

C_Class("Routine")({
	__tostring = function(self)
		return("routine:"..self._name)
	end
})

-- コンストラクタ
function Routine:_Ctor()
	self._wait = 0
	self._isPaused = false
	self._co = nil		--コルーチン
	self._func = nil
    self._task = nil
	--ルーチンプールが確認に使用する変数"end"のときは、RoutinPoolがこのインスタンスを所有する	
	--"run" --> タスクが所有
	--"end" --> ルーチンプールが所有
	self._state = "stop"
	self._pool = nil
end

function Routine:_Dtor()
end

function Routine:_PauseOn()
	self._isPaused = true
end

function Routine:_PauseOff()
	self._isPaused = false
end

--コルーチンをYield状態でスタートしておく
--Routineクラス作成時に一回だけ呼ばれる
function Routine:_Start()
--	if self._state == "stop" then
--		return true
--	end

	--後でfuncを取り替えられるように、関数をかませる
	--yieldはcallerで呼ばれるfunc内と、caller自身から呼ばれるcaller自身から呼び出した場合は_funcの入れ替えができるに "run" funcからreturn すると"stop"担ってここでも外で
	local function caller(rt)
		local ret = "init"
		local label
		while true do
			if self._func == nil then
				error("attemt to coroutine.resume empty Routine : ret :"..tostring(ret)..","..tostring(label).." task class:"..tostring(self._task._name) )
			end
			
			--ここでstatusを変更するのはそれほど意味はない気がする
			--多分_funcを関数で変更する前提で
			self._state = "run"
			ret, label = self._func(self._task, rt) --このfuncを入れ替えればいい
			self._state = "stop"
			
			-- restartの場合はnilにできない
			--if ret ~= "restart" then
			--	self._func = nil
			--end　
			COYIELD(ret, label) --このyieldでとまっている間は_funcの外部なので_funcを入れ替えることが可能、そのためself._stateを見て関数を入れ替える
		end
	end

	--終了状態でコルーチン作成
	self._co = COCREATE(caller)
	
	return true
end

function Routine:_ChangeFunc(f)
	if "function" ~= type(f) then
		error("Routine:_ChangeFunc() not function", type(f))
	end
	
	if "stop" ~= self._state then
		print("Routine:_ChangeFunc() coroutine now running !!")
		return
		--error("Routine:_ChangeFunc() coroutine now running !!", self._task._name)
	end
	
	self._func = f
end


--Yield状態のコルーチンをResume
--暫定的に毎回コルーチンとタスクを結びつける
function Routine:_Resume(task)
	self._task = task
	if self._isPaused == true then
		return true
	elseif self._wait > 0 then	
		self._wait = self._wait-1
		return true
	elseif self._wait ~= 0 then	
		error("_wait is negative!?")
	end
	
	--ルーチンの組み換えがあった場合にはそのルーチンを続けて実行する
	--最大10回まで
	for i=0, 10 do
		if not self._co then --ルーチンがない？？
			return true
		end
		
		if COSTATUS(self._co) == "dead" then --ルーチンは終了している
			return true
		end
		
		--resはコルーチンの成功失敗
		--yieldかreturnによって戻ってくる
		local resCo, val, val2 = CORESUME(self._co, self)
		
		if not resCo then
			--errorを呼ぶとC側でもスタックとレースバック出力されるけど一応
			local stacktrace = debug.traceback()
			C_AnalizeDetail(task)
			error("Routine:Coroutine _Resume() error: \n"..task._name..tostring(val)..tostring(val2)..stacktrace)
		end
		---------------------------------------------------------------------------------------
		--Yieldとreturnで適切な引数とともに戻ってこなければならない
		--以下の場合わけに合致していない場合は未定義
		----------------------------------------------Yieldで戻ってきた
		if val == "wait" then
			if val2 == "pause" then
				self:PauseOn()
			elseif type(val2) == "number" then
				self._wait = val2
			else
				print("self'.'_Wait()?? error")
				error("Routine wait(n) error: n is not number. type:"..type(val2).." task:"..tostring(task)..task._name)
			end
			return true
		
		----------------------------------------------returnで戻ってきた
		elseif val == "exit" then
			return false
--		elseif val == "refresh" then
--			self:_Start()
		elseif val == "goto" then
			self:_ChangeFunc(val2)
		else
			C_AnalizeDetail(task)
			print("ret err --> ", task._name, resCo, val, val2)
			error("ret err --> ", val, val2)
		end
		---------------------------------------------------------------------------------------

	end

	print("Routine:_Resume() : too many loop on task :", task)
	return false
end


--ひつようなだけRoutinクラスのインスタンスを作成する
--プールしているコルーチンオブジェクトが足りなくなった場合だけ新たに作成
C_Class("RoutinePool") {
}

-- コンストラクタ
function RoutinePool:_Ctor(max)
	self._pool = {}
    for i=1,max do
        table.insert(self._pool, self:_NewRoutine())
    end
end

function RoutinePool:_Dtor()
end

--新しいルーチンを作成
function RoutinePool:_NewRoutine()
    local rt = Routine:_New()
	rt:_ChangeFunc(Dummy)
	rt:_Start()
    return rt
end

--ルーチンをプールに返す
function RoutinePool:_Back(rt)

	--delete all ですでに消されている場合とか。
	--ひどい実装だけど暫定で
	if rt == nil then 
		print("RoutinePool:_Back already done!")
		return;
	end
	
	print("RoutinePool:_Back", rt._task._name)
	rt._task = nil
    rt:_ChangeFunc(Dummy)
    
  	--保管庫適当にあいてるところを探す
	for i,v in ipairs(self._pool) do
		if v == false then
			self._pool[i] = rt
			return
		end
	end
	
	--保管庫が埋まってる
    table.insert(self._pool,rt)
end

--線形探索してルーチンを１つ借りる
--poolのうちfalseでないところが未使用のコルーチン
--本当はfalseで埋めたりするのじゃなくて、erase、insertのほうが早くない？
function RoutinePool:_Get()
    for i, rt in ipairs(self._pool) do
        if rt ~= false then
            self._pool[i] = false --プールはfalseにしておく
 
			--間違ってreturn coroutine.yield("goto", func) とかやっちゃった状態。
			if rt._func ~= Dummy then
				error("return \"wait\" ?? use yield(\"wait\", ...)")
			end
			
			--間違ってreturn "wait" とかやっちゃった状態。
			--どこからも実行されずwaitしている状態であると思われるので、
			--そのコルーチン自体は参照先をなくして、削除する
			--新規にコルーチンを作成
			if "stop" ~= rt._state then
				error("return \"wait\" ?? use yield(\"wait\", ...)")
				rt:_Start()
				return rt
			end
			
			print("recycle coroutine")
            return rt
        end
    end
    
    --もうないならコルーチン作り直す
    return self:_NewRoutine()
end
