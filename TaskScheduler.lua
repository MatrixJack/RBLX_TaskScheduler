local runService = game:GetService("RunService")

local queue = {}
local queueInternal = {}

local taskScheduler = {}
local taskSchedulerInternal = {}

local waitMethod

if runService:IsServer() then waitMethod = runService.Heartbeat else waitMethod = runService.RenderStepped end

--<<------------------------------------------------------------->>--

queueInternal.__index = queueInternal

function queueInternal:length()
	return #self.queue
end

function queueInternal:getNext()
	self.calls = self.calls + 1
	
	return rawget(self.queue, 1)
end

function queueInternal:shiftQueue()
	self.removed = self.removed + 1
	
	table.remove(self.queue, 1)
end

function queueInternal:setTask(task)
	self.queue[#self.queue + 1] = task
end

function queue.new()
	local self = {}
	
	self.removed = 0
	self.calls = 0
	self.queue = {}
	
	return setmetatable(self, queueInternal)
end

--<<------------------------------------------------------------->>--

taskSchedulerInternal.__index = taskSchedulerInternal

function taskSchedulerInternal:newTask(routine, ...)
	local task = {}
	
	task.coroutine = coroutine.create(routine)
	task.arguments = {...}
	
	function task:execute()
		local success, errCode = coroutine.resume(task.coroutine, unpack(task.arguments))
		
		if not success then
			warn(errCode)
			print(debug.traceback(task.coroutine))
		end
	end
	
	self.queue:setTask(task)
end

function taskSchedulerInternal:setSleep(value)
	self.sleep = value
end

function taskSchedulerInternal:createCoroutine()
	return coroutine.create(function()
		while true do
			if self.sleep then waitMethod:Wait() end
			
			if self.queue:length() > 0 then
				local task = self.queue:getNext()
				
				task:execute()
				
				self.queue:shiftQueue()
			else
				waitMethod:Wait()
			end
		end
	end)
end

function taskScheduler.new()
	local self = {}
	
	self.queue = queue.new()
	self.status = "Idle"
	self.sleep = false
	
	local self = setmetatable(self, taskSchedulerInternal)
	
	coroutine.resume(self:createCoroutine())
	self.createCoroutine = nil
	
	return self
end

--<<------------------------------------------------------------->>--

local taskSchedulerProxy = newproxy(true)
local taskSchedulerMetatable = getmetatable(taskSchedulerProxy)

taskSchedulerMetatable.__index = taskScheduler
taskSchedulerMetatable.__tostring = function() return "taskScheduler" end
taskSchedulerMetatable.__metatable = "The metatable is locked"

return taskSchedulerProxy
