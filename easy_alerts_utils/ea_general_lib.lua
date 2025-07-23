-- Library files should not have GetInfo(), causes crash by caller lua


function Debugger(...)
    Spring.Echo(...)
end

function TableToString(tbl, indent)
  if (type(tbl) == "table" and tbl.isPrototype) or (type(indent) == "table" and indent.isPrototype) then
    return "DON'T SEND PROTOs TO TableToString FUNCTION. IT WILL CRASH THE GAME!"
  end
  indent = indent or 4
  local str = ""
  str = str .. string.rep(".", indent) .. "{\n" -- Add indentation for nested tables
  if type(tbl) ~= "table" then -- Iterate through table elements
    str = str .. type(tbl) .. "=" .. tostring(tbl) -- If not a table, return its string representation
  else
    for k, v in pairs(tbl) do
      if (type(k) == "table" and k.isPrototype) or (type(v) == "table" and v.isPrototype) then
        return "DON'T SEND PROTOs TO TableToString FUNCTION. IT WILL CRASH!"
      end
      str = str .. string.rep(".", indent + 1)
      if type(k) == "string" then -- Format key
        str = str .. k .. " = "
      else
        str = str .. "[" .. tostring(k) .. "] = "
      end
      if type(v) == "table" then -- Handle different value types
        str = str .. TableToString(v, indent + 2) .. ",\n" -- Recursively call for nested tables
      elseif type(v) == "string"then
        str = str .. "\"" .. v .. "\",\n"
      else
        str = str .. tostring(v) .. ",\n"
      end
    end
  end
  str = str .. string.rep(".", indent) .. "}"
  return str
end

function SaveTable(tableName, tableData, filename)
    local file = io.open(filename, "w")
    if file then
        file:write("return " .. table.dump(tableData, tableName)) -- Assuming a table.dump function exists
        file:close()
        Debugger("Table saved successfully to", filename)
    else
        Debugger("Error: Could not open file for writing.")
    end
end

function table.dump(obj, name, indent)
    indent = indent or ""
    local str = ""
    if type(obj) == "table" then
        str = str .. "{\n"
        local nextIndent = indent .. "    "
        for k, v in pairs(obj) do
            str = str .. nextIndent .. tostring(k) .. " = " .. table.dump(v, nil, nextIndent) .. ",\n"
        end
        str = str .. indent .. "}"
    elseif type(obj) == "string" then
        str = string.format("%q", obj)
    else
        str = tostring(obj)
    end
    return str
end

local Node = {}
Node.__index = Node

function Node:new(value, alertRulesTbl, priority)
  return setmetatable({value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}, self)
end

local minPriorityQueue = {}
minPriorityQueue.__index = minPriorityQueue

function minPriorityQueue:new()
  return setmetatable({}, self)
end

function minPriorityQueue:binarySearchInsertIndex(table, priority) -- Binary search function to find the insertion point for a minimum priority queue
  local low, high = 1, #table
  local index = #table + 1 -- Default insertion at the end
  while low <= high do
    local mid = math.floor((low + high) / 2) -- Compare for minimum priority queue (ascending order)
    if priority < table[mid].priority then
      index = mid
      high = mid - 1
    else
      low = mid + 1
    end
  end
  return index
end

function minPriorityQueue:insert(value, alertRulesTbl, priority)
  if value == nil or type(priority) ~= "number" or priority < 0 or priority > 99999 then
    Debugger("priorityQueue:insert 1. ERROR. Invalid value or priority="..tostring(priority))
    return nil
  end
  local newNode = Node:new(value, alertRulesTbl, priority)
  local insertIndex = self:binarySearchInsertIndex(self, priority)
  table.insert(self, insertIndex, newNode)
end

function minPriorityQueue:pull(arrNum)
  arrNum = arrNum or 1
  if self:size() == 0 or type(arrNum) ~= "number" or (arrNum < 1 or arrNum > self:size()) then
    Debugger("priorityQueue:pull(). ERROR. Invalid arrNum=" .. tostring(arrNum))
    return nil
  end
  if self:size() == 0 then return nil, 0 end
  local elRemoved = table.remove(self, arrNum) -- Removes/Returns the requested element
  return elRemoved.value, elRemoved.alertRulesTbl, elRemoved.priority, elRemoved.queuedTime
end

function minPriorityQueue:peek(arrNum) -- Returns/Keeps the top/requested element, returning vars: value, alertRulesTbl, priority, queuedTime
  arrNum = arrNum or 1
  if self:isEmpty() or type(arrNum) ~= "number" or arrNum < 1 or arrNum > self:size() then
    Debugger("minPriorityQueue:peek(). ERROR. Invalid arrNum=" .. tostring(arrNum))
    return nil
  end
  return self[arrNum].value, self[arrNum].alertRulesTbl, self[arrNum].priority, self[arrNum].queuedTime
end

function minPriorityQueue:getSize() -- Returns the number of elements in the queue.
  return self:size()
end

function minPriorityQueue:isEmpty() -- Returns true if the queue is empty, false otherwise.
  return self:size() == 0
end

function minPriorityQueue:size()
  return #self
end
AlertQueue2 = minPriorityQueue:new()
-- Example usage:
-- AlertQueue2:insert("Task A", {},5)
-- AlertQueue2:insert("Task B", {},2)
-- AlertQueue2:insert("Task C", {},8)
-- local value, tmpalertRulesTbl, priority = AlertQueue2:pull()
-- Debugger("Pulled:", tostring(value), "with priority:", tostring(priority)) -- Expect "Task B" (lowest priority)
-- value, tmpalertRulesTbl, priority = AlertQueue2:pull()
-- Debugger("Pulled:", tostring(value), "with priority:", tostring(priority)) -- Expect "Task A"
-- value, tmpalertRulesTbl, priority = AlertQueue2:pull()
-- Debugger("Pulled:", tostring(value), "with priority:", tostring(priority)) -- Expect "Task C"

local priorityQueue = {}
priorityQueue.__index = priorityQueue
function priorityQueue:new()
  local queue = {
    heap = {},
    size = 0
  }
  return setmetatable(queue, self)
end
function priorityQueue:insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
  if value == nil or type(priority) ~= "number" or priority < 0 or priority > 99999 then
    Debugger("priorityQueue:insert 1. ERROR. Invalid value or priority="..tostring(priority))
    return nil
  end
  self.size = self.size + 1
  self.heap[self.size] = {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
  self:_swim(self.size)
end

function priorityQueue:pull(heapNum) -- Returns/Removes the highest priority with vars: value, alertRulesTbl, priority, queuedTime
  if self:isEmpty() or heapNum > self.size then
    return nil, nil
  end
  heapNum = heapNum or 1
  local top = self.heap[heapNum]
  if self.size > 1 then
    self.heap[heapNum] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1
    if heapNum < self.size then
      self:_sink(1)
    end
  else
    self.heap[1] = nil
    self.size = 0
  end
  return top.value, top.alertRulesTbl, top.priority, top.queuedTime
end

function priorityQueue:peek(heapNum) -- Returns/Keeps the top/requested element, returning vars: value, alertRulesTbl, priority, queuedTime
  if self:isEmpty() or type(heapNum) ~= "number" or heapNum < 1 or heapNum > self.size then
    Debugger("priorityQueue:peek(). ERROR. Invalid heapNum=" .. tostring(heapNum))
    return nil, nil, nil, nil
  end
  heapNum = heapNum or 1
  return self.heap[heapNum].value, self.heap[heapNum].alertRulesTbl, self.heap[heapNum].priority, self.heap[heapNum].queuedTime
end

function priorityQueue:getSize() -- Returns the number of elements in the queue.
  return self.size
end

function priorityQueue:isEmpty() -- Returns true if the queue is empty, false otherwise.
  return self.size == 0
end

function priorityQueue:__lessThan(i, j) -- Helper functions for heap operations (min-heap)
  return self.heap[i].priority < self.heap[j].priority
end
function priorityQueue:_swap(i, j)
  self.heap[i], self.heap[j] = self.heap[j], self.heap[i]
end
function priorityQueue:_swim(k)
  while k > 1 and self:__lessThan(k, math.floor(k / 2)) do
    self:_swap(k, math.floor(k / 2))
    k = math.floor(k / 2)
  end
end
function priorityQueue:_sink(k)
  while 2 * k <= self.size do
    local j = 2 * k
    if j < self.size and self:__lessThan(j + 1, j) then
      j = j + 1
    end
    if not self:__lessThan(j, k) then
      break
    end
    self:_swap(k, j)
    k = j
  end
end
AlertQueue = priorityQueue:new()

local function clone( base_object, clone_object )
  if type( base_object ) ~= "table" then
    return clone_object or base_object 
  end
  clone_object = clone_object or {}
  clone_object.__index = base_object
  return setmetatable(clone_object, clone_object)
end

local function isa( clone_object, base_object )
  local clone_object_type = type(clone_object)
  local base_object_type = type(base_object)
  if clone_object_type ~= "table" and base_object_type ~= table then
    return clone_object_type == base_object_type
  end
  local index = clone_object.__index
  local _isa = index == base_object
  while not _isa and index ~= nil do
    index = index.__index
    _isa = index == base_object
  end
  return _isa
end
ProtoObject = clone( table, { clone = clone, isa = isa } )
ProtoObject.isPrototype = true
-- var = protoObject:clone()

function AlertPointer(x, y, z, pointerText, localOnly)
  if debug then Debugger("alertPointer 1. coords="..tostring(x)..", "..tostring(y)..", "..tostring(z)..", pointerText="..tostring(pointerText)..", localOnly="..tostring(localOnly)) end
  if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or x < 0 then
    Debugger("alertPointer 2. ERROR. Invalid coordinates=" .. tostring(x) .. ", " .. tostring(y))
    return false
  end
  pointerText = type(pointerText) == "string" and pointerText or ""
  localOnly = type(localOnly) == "boolean" and localOnly or true
  Spring.MarkerAddPoint( x, y, z, pointerText, localOnly) -- localOnly = mark (only you see)
  return true
end

function AlertSound(soundPath, volume)
  volume = volume or 1.0
  if debug then Debugger("alertSound 1. soundPath=" .. tostring(soundPath)..", volume="..tostring(volume)) end
  if type(soundPath) ~= "string" or volume ~= nil and (type(volume) ~= "number" or volume < 0 or volume > 1) then
    Debugger("alert 2. ERROR. Invalid volume or soundPath=" .. tostring(soundPath)..", volume="..tostring(volume))
    return nil
  end
    Spring.PlaySoundFile(soundPath, volume, 'ui')
  return true
end

function AlertMessage(message, toWhom) -- string message, ["me" | "all" | "allies" | "spectators"]
  if debug then Debugger("alertMessage 1. alertMessage=" .. tostring(message)..", toWhom="..tostring(toWhom)) end
  toWhom = toWhom or "me"
  if type(message) ~= "string" or message == "" or (type(toWhom) ~= "string" and toWhom ~= nil) or (toWhom ~= "me" and toWhom ~= "all" and toWhom ~= "allies" and toWhom ~= "spectators") then
    Debugger("alertMessage 2. ERROR. Invalid toWhom or message=" .. tostring(message)..", toWhom="..tostring(toWhom))
    return nil
  end
  local isSpectator = Spring.GetSpectatingState()
  if not toWhom == "me" and not toWhom == "all" and not toWhom == "allies" and not toWhom == "spectators"  then
    Debugger("alertMessage 3. ERROR. toWhom must be: me, all, allies, or spectators." .. tostring(message)..", toWhom="..tostring(toWhom))
  elseif toWhom == "me" then
    Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), message) -- "me" myPlayerID
  elseif not isSpectator and toWhom == "all" then
    Spring.SendMessage(message) -- "all"
  elseif not isSpectator and toWhom == "allies" then
    Spring.SendMessageToAllyTeam(Spring.GetMyAllyTeamID(), message) -- "allies" teamsManager.myArmyManager.allianceID
  elseif toWhom == "spectators" then
    Spring.SendMessageToSpectators(message) -- "spectators"
  else
    Debugger("alertMessage 4. ERROR. Spectators should not talk to players!" .. tostring(message)..", toWhom="..tostring(toWhom))
  end
  return true
end


-- return {
--   Debugger = Debugger
-- }