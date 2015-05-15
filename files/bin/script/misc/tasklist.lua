--[=======================================[

               LUAスクリプト

hrk. All Right Reserves.


更新履歴
2009/3/10：作成
2009/3/13：こいつはおそらく派生しないけど、一応変数名に_つけた

--]=======================================]


C_Class("TaskList")({
	__tostring = function()	
		return("TaskList")
	end,
})

-- コンストラクタ
function TaskList:_Ctor()
	self._tasks = {}		-- スケジュール対象アクターリスト
	self._addedtasks = {}	-- スケジュール中に追加されたタスク
	self._deletedtasks = {}	-- スケジュール中に削除されたタスク
	self._deltmp = {}		-- 削除用テーブル
	--self._draw = {}
end

function TaskList:_Dtor()
end

function TaskList:_DeleteAll()
	local cnt = 0
	for i, v in pairs(self._tasks) do
		if v ~= false then
            self:_DelTask(v)
			cnt = cnt + 1
		end
	end
	
	--タスクによってAdd、delされたものを反映
	self:_ListAdd()
	self:_ListDel()
	print("delete all lua tasks!!>>", cnt)
end

-- 全てのアクターをスケジュール処理
function TaskList:_Move()

	-- 手動でAdd、delされたものを反映
	self:_ListAdd()
	self:_ListDel()
	
	--collectgarbage(stop)
	--"stop" 		--- ガベージコレクタを停止する。 
	--"restart" 	--- ガベージコレクタを再開する。 
	--"collect" 	--- フルガベージコレクションサイクルを実行する。 
	--"count" 		--- Luaが使っているメモリの合計を(キロバイトで)返す。 
	--"step"		--- ガベージコレクションステップひとつを実行する。 ステップの「サイズ」は arg で制御する。 大きな値は大きなステップを意味するが、具体的には定まっていない。 ステップサイズを制御したければ、 arg の値を実験的に調整しなければならない。 このステップでコレクションサイクルが終わった場合は true を返す。 
	--"steppause" 	--- コレクタの停止値 (2.10 を参照) の新しい値を arg÷100に設定する。 
	--"setstepmul" 	--- コレクタの ステップ係数 の新しい値を arg÷100に設定する (2.10 を参照)。

	--local cnt = 0
	local routine 
	for i, v in ipairs(self._tasks) do
		if v ~= false and self._deletedtasks[v] == nil then --continue..
			routine = v._routine
			if routine ~= nil and routine._co ~= nil then
				if false == routine:_Resume(v) then
					self:_DelTask(v)
				end
			end
			--self:_AMove(v)
			--cnt = cnt + 1
		end
	end
	--print("moved tasks cnt:", cnt)
	
	--タスクの追加が_addedtasks[task] = true or false だと、描画順に狂いが生じるため↓↓に変更
	--ついでに言うと、追加中に追加なんてありえないないだろ？
	--	-- 処理中に追加されたタスクをマージ
	--	while true do
	--		local added = self._addedtasks
	--		self._addedtasks = {}
	--		for k, v in pairs(added) do
	--			-- 削除リストに登録されていれば追加中止
	--			if k._isdead then
	--                added[k] = false
	--			end
	--		end
	--		self:_ListAdd(added)
	--		self:_ListDel()
	--		
	--		--新たに追加されていなければ終了
	--		if next(self._addedtasks) == nil then
	--			break
	--		end
	--	end

	--タスクによってAdd、delされたものを反映
	self:_ListAdd()
	self:_ListDel()
end

--タスクを追加予約。
function TaskList:_AddTask(task)
	--↓のようにするとタスクの追加順序が狂い、描画の順番が入れ替わる
	--self._addedtasks[task] = true
	--そのため、連番でタスクを追加しておく
	--実際の追加処理の際にはtask
	table.insert(self._addedtasks, task)
end

function TaskList:_DelTask(task)
	task._isdead = true
	self._deletedtasks[task] = true
	
	--for i,v in ipairs(self._tasks) do
	--	if v == task then
	--		self._tasks[i] = false
	--	end
	--end
	--local funcs = task.coroutine_funcs
	--if task.on_destroy ~= nil then
	--	-- この中で他のtaskがdeleteされる可能性がある
	--	task:on_destroy(task.routine)
	--end
	--task:delete_internal()
end


--------------------------------------------削除リストで削除
function TaskList:_ListDel()
	--テーブルループ削除
	while true do
	
		
		--もう削除するものがない
		if nil == next(self._deletedtasks) then
			break
		end
		
		--削除中にさらにself._deletedtasksに追加があると、削除できないものが発生するため、
		--削除リストは別の変数に移しておく
		for k, v in pairs(self._deletedtasks) do
	        self._deltmp[k] = v
	    end
		Clear(self._deletedtasks)

		--local cnt = 0
		for k, v in pairs(self._deltmp) do
			for i, v in ipairs(self._tasks) do
				if v == k then
					
					--ここでfalseにするとこのタスクを参照しているものがいなくなる,,,
					--はず（他に参照していなければの話。というか参照してた時点でバグorz）
					--ついでにテーブルに空きとして登録できる
					self._tasks[i] = false
					
					--死んだ後に何かを生成するタスクを作りたかった
					--シーンの破棄などというかほぼそれだけのため
					--ここを抜けると破棄されるはず
					if nil ~= v._After then
						v:_After()
					end
					v:_Delete(k) --内容の破棄
					
					--cnt = cnt + 1
					break
				end
			end
		end
		--if cnt > 0 then
		--	print("deleted tasks cnt:", cnt)
		--end
		
		Clear(self._deltmp)
	end
end



--------------------------------------------追加リストで追加
--テーブルの使いまわし
function TaskList:_ListAdd()

--	local task = nil
--	local val
--	--self._tasks内の空き
--	for i, v in ipairs(self._tasks) do
--		if v == false then
--			task, val = next(list, task)	--先に次の要素を見る
--			if task == nil then
--				return --空きはあるけど、追加するものがないとき
--			end
--            if val == true and not task._isdead then
--                self._tasks[i] = task
--            end
--		end
--	end
--	--self._tasksの終端
--	while true do
--		task, val = next(list, task)
--		if task == nil then
--			return --終端で終了
--		end
--        if val == true and not task._isdead then
--            table.insert(self._tasks, task)
--        end
--	end

	local ix = nil
	local val
	local list = self._addedtasks
	--追加中の追加なんてない。と思う
	--for k, v in pairs(self._addedtasks) do
    --    self._addtmp[k] = v
    --end
	--Clear(self._addedtasks)	
	--local list = self._addedtasks
	--self._addedtasks = {}
	
	--使用されていない領域にセット
	--self._tasksのfalseにセット
	for i, v in ipairs(self._tasks) do
		if v == false then--空き地見っけ！
			ix, val = next(list, ix)
			if ix == nil then
				--print("Clear inner", #self._addedtasks)
				Clear(self._addedtasks)
				return --空きはあるけど、追加するものがないとき
			end
            if not val._isdead then
                self._tasks[i] = val
            end
		end
	end
	
	--新しい要素として
	--self._tasksの終端
	while true do
		ix, val = next(list, ix)
		if ix == nil then
			--print("Clear outer", #self._addedtasks)
			Clear(self._addedtasks)
			return --終端で終了
		end
        if not val._isdead then
            table.insert(self._tasks, val)
        end
	end
	
end


--------------------------------------------タスク起動
--function TaskList:_AMove(task)
--	local rt = task._routine
--	if rt ~= nil and rt._co ~= nil then
--		if rt._wait > 0 then	
--			rt._wait = rt._wait-1
--			_isPaused
--		elseif rt._wait == 0 then	
--			local ret = rt:_Resume(task)
--            if ret == "exit" then
--                self:_DelTask(task)
--            elseif ret == false then
--				error("error:TaskList:Move ret -->", ret)
--            end
--		end
--	end
--end

--------------------------------------------ソート関数
--function TaskList:_Sort(l, r)
--	return l._id < r._id
--end
--
--function TaskList:_DrawSort()
--	print("<<draw task sort start>>")
--	table.sort(t1, TaskList._Sort)
--	print("<<draw task sort end>>")
--end


--------------------------------------------描画
--function TaskList:_Draw()
--	--local cnt = 0
--	for i, v in ipairs(self._tasks) do
--		if v ~= false then
--            --v:_Draw(i)
--            v:_Draw()
--		--	print("drawsucceeded")
--		--	--cnt = cnt + 1
--		--else
--		--	print("drawfalse")
--		end
--	end
--	--print("drawn tasks cnt:", cnt)
--end

--------------------------------------------タスク追加
--function TaskList:AddTask(task)
--	-- 配列に穴(false)があれば、そこに追加
--	for i,v in ipairs(self._tasks) do
--		if v == false then
--			self._tasks[i] = task
--			return
--		end
--	end
--	-- 末尾に追加
--	table.insert(self._tasks,task)
--end


--------------------------------------------削除
--機能が別れている必要はないのでは？ということで削除して_ListDelに埋め込んだ
--function TaskList:_Del()
--	--処理中に削除されたタスクを繰り返し削除
--	--新たに削除されていなければ終了
--	while true do
--		if next(self._deletedtasks) == nil then
--			break
--		end
--		self:_ListDel()
--	end
--end


