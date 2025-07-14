local widgetName = "Easy_Alerts"
function widget:GetInfo()
	return {
		name = widgetName,
		desc = "Allows players and spectators to get customized unit-event alerts.",
		author = "Graushwein",
		date = "May 29, 2025",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end
-- ################################################# Config variables starts here #################################################
local soundVolume = 1.0 -- Set the volume between 0.0 and 1.0. NOT USED

local updateInterval = 30 -- 30 runs once per second, 1=30/sec, 60=1/2sec
local minReAlertSec = 3 -- to prevent a bunch at once
local deleteDestroyed = false -- For possible RAM concerns. Though, in the few small tests I tried it didn't seem to save more RAM

local alertAllTaken = false -- NOT TESTED YET
local alertAllTakenRules = {anyTaken = {["alertAllTaken"] = {sharedAlerts=true, reAlertSec=3, mark="Unit Taken"}}} -- KEEP "sharedAlerts=true", else this can SPAM
local alertAllGiven = false
local alertAllGivenRules = {anyGiven = {["alertAllGiven"] = {sharedAlerts=true, reAlertSec=3, mark="Unit Given"}}} -- KEEP "sharedAlerts=true", else this can SPAM

-- ######## ReadMe instructions: https://github.com/Graushwein/Widgets/blob/main/README.md

-- NOTICE: All text is case sensitive!
-- Unit Events = {"created","finished","idle","destroyed","los","thresholdHP","taken","given","damaged","loaded","stockpile"}
-- Event Rules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "alertDelay", "maxQueueTime", "alertSound", "mark", "ping","messageTo","messageTxt", "threshMinPerc"} -- TODO: , "threshMaxPerc" with economy

-- Premade Unit Types: commander,constructor,factory,factoryT1,factoryT2,factoryT3,rezBot,
  -- mex,mexT1,mexT2,energyGen,energyGenT1,energyGenT2,radar,nuke,antiNuke,allMobileUnits,unitsT1,unitsT2,unitsT3,
  -- hoverUnits,waterUnits,waterT1,waterT2,waterT3,groundUnits,groundT1,groundT2,groundT3,airUnits,airT1,airT2,airT3
-- {unitType = {event = {rules}}}
-- NOTICE: I recommend using "thresholdHP" instead of "damaged" events. "damaged" are disabled by default, for very late game performance concerns. (I haven't done any testing though.) To enable, go to "function widget:UnitDamaged(" and remove the "--" from all lines in the function block
local myCommanderRules = {thresholdHP = {reAlertSec=60, mark="Commander In Danger", alertSound="sounds/commands/cmd-selfd.wav", threshMinPerc=.6, priority=0}} -- damaged = {reAlertSec=30} Towards the end of games there's a lot of damage, so I recommend using "thresholdHP" for the few units you care about -- will sound alert when Commander idle/15 secs, (re)damaged once per 30 seconds (unlimited), and when damage causes HP to be under x%
local myConstructorRules = {idle = {sharedAlerts=true, reAlertSec=20, mark="Idle Con", alertDelay=.1}, destroyed = {mark="Con Lost"}, given = {mark="Con Given"}}
local myFactoryRules = {idle = {sharedAlerts=true, reAlertSec=20, mark="Idle Factory", alertDelay=.1}}
local myRezBotRules = {idle = {sharedAlerts=true, reAlertSec=20, alertDelay=.1, messageTo="me",messageTxt="RezBot Idle"}}
local myMexRules = {destroyed = {reAlertSec=5, mark="Mex Lost"}, taken = {mark="Mex Taken"}}
local myRadarRules = {destroyed = {mark="Radar Lost"}}
local myNukeRules = {stockpile = {messageTo="me", messageTxt="Nuke Ready", mark="Nuke Ready", alertSound="sounds/commands/cmd-selfd.wav"}}
-- More Unit Types:
local myEnergyGenT2Rules = {}; local myAntiNukeRules = {}; local myFactoryT1Rules = {}; local myFactoryT2Rules = {}; local myFactoryT3Rules = {}; local myMexT1Rules = {}; local myMexT2Rules = {}; local myEnergyGenRules = {}; local myEnergyGenT1Rules = {}; local myAllMobileUnitsRules = {}; local myUnitsT1Rules = {}; local myUnitsT2Rules = {}; local myUnitsT3Rules = {}; local myHoverUnitsRules = {}; local myWaterUnitsRules = {}; local myWaterT1Rules = {}; local myWaterT2Rules = {}; local myWaterT3Rules = {}; local myGroundUnitsRules = {}; local myGroundT1Rules = {}; local myGroundT2Rules = {}; local myGroundT3Rules = {}; local myAirUnitsRules = {}; local myAirT1Rules = {}; local myAirT2Rules = {}; local myAirT3Rules = {}
local trackMyTypesRules = {commander = myCommanderRules, constructor = myConstructorRules, factory = myFactoryRules, rezBot = myRezBotRules,	mex = myMexRules, energyGenT2 = myEnergyGenT2Rules,radar = myRadarRules, nuke = myNukeRules, antiNuke = myAntiNukeRules, factoryT1 = myFactoryT1Rules, factoryT2 = myFactoryT2Rules, factoryT3 = myFactoryT3Rules, mexT1 = myMexT1Rules, mexT2 = myMexT2Rules, energyGen = myEnergyGenRules, energyGenT1 = myEnergyGenT1Rules, allMobileUnits = myAllMobileUnitsRules, unitsT1 = myUnitsT1Rules, unitsT2 = myUnitsT2Rules, unitsT3 = myUnitsT3Rules, hoverUnits = myHoverUnitsRules, waterUnits = myWaterUnitsRules, waterT1 = myWaterT1Rules, waterT2 = myWaterT2Rules, waterT3 = myWaterT3Rules, groundUnits = myGroundUnitsRules, groundT1 = myGroundT1Rules, groundT2 = myGroundT2Rules, groundT3 = myGroundT3Rules, airUnits = myAirUnitsRules, airT1 = myAirT1Rules, airT2 = myAirT2Rules, airT3 = myAirT3Rules}

-- allyRules
local allyCommanderRules = {} -- Must have a rule to make it track the units. No alert means it only destroyed enemy mex will be tracked. To have it track alive mex, use "los"
local allyFactoryT2Rules = {finished = {sharedAlerts=true, maxAlerts=1, mark="T2 Ally Factory", alertDelay=30, messageTo="me", messageTxt="T2 Ally"}} -- So you can badger them for a T2 constructor ;)
local allyMexRules = {destroyed = {sharedAlerts=true, mark="Ally Mex Lost", alertDelay=30}}
local allyEnergyGenT2Rules = {destroyed = {sharedAlerts=true, mark="Ally Fusion Lost", alertDelay=30}}
local allyRadarRules = {destroyed = {sharedAlerts=true, mark="Ally Radar Lost", alertDelay=30}}
local allyNukeRules = {stockpile = {sharedAlerts=true, alertDelay=30, messageTo="me", messageTxt="Ally Nuke Ready", alertSound="sounds/commands/cmd-selfd.wav"}}

local allyRezBotRules = {}; local allyFactoryRules = {}; local allyConstructorRules = {}; local allyAntiNukeRules = {}; local allyFactoryT1Rules = {}; local allyFactoryT3Rules = {}; local allyMexT1Rules = {}; local allyMexT2Rules = {}; local allyEnergyGenRules = {}; local allyEnergyGenT1Rules = {}; local allyAllMobileUnitsRules = {}; local allyUnitsT1Rules = {}; local allyUnitsT2Rules = {}; local allyUnitsT3Rules = {}; local allyHoverUnitsRules = {}; local allyWaterUnitsRules = {}; local allyWaterT1Rules = {}; local allyWaterT2Rules = {}; local allyWaterT3Rules = {}; local allyGroundUnitsRules = {}; local allyGroundT1Rules = {}; local allyGroundT2Rules = {}; local allyGroundT3Rules = {}; local allyAirUnitsRules = {}; local allyAirT1Rules = {}; local allyAirT2Rules = {}; local allyAirT3Rules = {}
local trackAllyTypesRules = {commander = allyCommanderRules, constructor = allyConstructorRules, factory = allyFactoryRules, factoryT2 = allyFactoryT2Rules, rezBot = allyRezBotRules, mex = allyMexRules, energyGenT2 = allyEnergyGenT2Rules, radar = allyRadarRules, nuke = allyNukeRules, antiNuke = allyAntiNukeRules, factoryT1 = allyFactoryT1Rules, factoryT3 = allyFactoryT3Rules, mexT1 = allyMexT1Rules, mexT2 = allyMexT2Rules, energyGen = allyEnergyGenRules, energyGenT1 = allyEnergyGenT1Rules, allMobileUnits = allyAllMobileUnitsRules, unitsT1 = allyUnitsT1Rules, unitsT2 = allyUnitsT2Rules, unitsT3 = allyUnitsT3Rules, hoverUnits = allyHoverUnitsRules, waterUnits = allyWaterUnitsRules, waterT1 = allyWaterT1Rules, waterT2 = allyWaterT2Rules, waterT3 = allyWaterT3Rules, groundUnits = allyGroundUnitsRules, groundT1 = allyGroundT1Rules, groundT2 = allyGroundT2Rules, groundT3 = allyGroundT3Rules, airUnits = allyAirUnitsRules, airT1 = allyAirT1Rules, airT2 = allyAirT2Rules, airT3 = allyAirT3Rules}

-- enemyRules
local enemyCommanderRules = {los = {reAlertSec=60, mark="Commander", priority=0, messageTo="me",messageTxt="Get em!"} } -- will mark "Commander" at location when (re)enters LoS, once per 30 seconds (unlimited)
local enemyFactoryT2Rules = {los = {sharedAlerts=true, maxAlerts=1, mark="T2 enemy"}} -- Hope you're ready.
local enemyAntiNukeRules = {los = {sharedAlerts=true, maxAlerts=1, reAlertSec=1, mark="AntiNuke Spotted"}}
local enemyNukeRules = {los = {sharedAlerts=true, maxAlerts=1, reAlertSec=1, mark="Nuke Spotted"}}

local enemyConstructorRules = {}; local enemyRadarRules = {}; local enemyUnitsT2Rules = {}; local enemyUnitsT3Rules = {}; local enemyFactoryRules = {}; local enemyMexRules = {}; local enemyEnergyGenT2Rules = {}; local enemyRezBotRules = {}; local enemyFactoryT1Rules = {}; local enemyFactoryT3Rules = {}; local enemyMexT1Rules = {}; local enemyMexT2Rules = {}; local enemyEnergyGenRules = {}; local enemyEnergyGenT1Rules = {}; local enemyAllMobileUnitsRules = {}; local enemyUnitsT1Rules = {}; local enemyHoverUnitsRules = {}; local enemyWaterUnitsRules = {}; local enemyWaterT1Rules = {}; local enemyWaterT2Rules = {}; local enemyWaterT3Rules = {}; local enemyGroundUnitsRules = {}; local enemyGroundT1Rules = {}; local enemyGroundT2Rules = {}; local enemyGroundT3Rules = {}; local enemyAirUnitsRules = {}; local enemyAirT1Rules = {}; local enemyAirT2Rules = {}; local enemyAirT3Rules = {}
local trackEnemyTypesRules = {commander = enemyCommanderRules, constructor = enemyConstructorRules, rezBot = enemyRezBotRules, radar = enemyRadarRules, nuke = enemyNukeRules, antiNuke = enemyAntiNukeRules, factory = enemyFactoryRules, factoryT1 = enemyFactoryT1Rules, factoryT2 = enemyFactoryT2Rules, factoryT3 = enemyFactoryT3Rules, mex = enemyMexRules, mexT1 = enemyMexT1Rules, mexT2 = enemyMexT2Rules, energyGen = enemyEnergyGenRules, energyGenT1 = enemyEnergyGenT1Rules, energyGenT2 = enemyEnergyGenT2Rules, allMobileUnits = enemyAllMobileUnitsRules, unitsT1 = enemyUnitsT1Rules, unitsT2 = enemyUnitsT2Rules, unitsT3 = enemyUnitsT3Rules, hoverUnits = enemyHoverUnitsRules, waterUnits = enemyWaterUnitsRules, waterT1 = enemyWaterT1Rules, waterT2 = enemyWaterT2Rules, waterT3 = enemyWaterT3Rules, groundUnits = enemyGroundUnitsRules, groundT1 = enemyGroundT1Rules, groundT2 = enemyGroundT2Rules, groundT3 = enemyGroundT3Rules, airUnits = enemyAirUnitsRules, airT1 = enemyAirT1Rules, airT2 = enemyAirT2Rules, airT3 = enemyAirT3Rules}

-- spectatorRules
local spectatorCommanderRules = {thresholdHP = {reAlertSec=30, threshMinPerc=.6, mark="Commander In Danger", alertSound="sounds/commands/cmd-selfd.wav", priority=1}, loaded = {mark="Com-Drop", alertSound="sounds/commands/cmd-selfd.wav", priority=1}}
local spectatorConstructorRules = {} -- {idle = {sharedAlerts=true, reAlertSec=60, alertDelay=.1, mark="Idle Con"}, destroyed = {sharedAlerts=true, reAlertSec=30, mark="Con Destroyed"}}
local spectatorFactoryT2Rules = {created = {sharedAlerts=true, maxAlerts=3, mark="T2 Factory Started"}, finished = {sharedAlerts=true, maxAlerts=3, mark="T2 Factory Finished"}}
local spectatorFactoryT3Rules = {created = {sharedAlerts=true, maxAlerts=3, mark="T3 Factory Started", alertSound="sounds/commands/cmd-selfd.wav"}, finished = {sharedAlerts=true, maxAlerts=3, mark="T3 Factory Finished", alertSound="sounds/commands/cmd-selfd.wav"}}
local spectatorMexT2Rules = {created = {sharedAlerts=true, maxAlerts=1, reAlertSec=30, mark="MexT2 Started"}, thresholdHP = {sharedAlerts=true, threshMinPerc=.8, reAlertSec=60, mark="MexT2 Damaged"}}
local spectatorEnergyGenT2Rules = {created = {sharedAlerts=true, maxAlerts=3, mark="EnergyT2 Started"}, thresholdHP = {sharedAlerts=true, threshMinPerc=.8, reAlertSec=60, mark="EnergyGenT2 Damaged"}}
local spectatorRadarRules = {finished = {sharedAlerts=true, maxAlerts=5, reAlertSec=60, mark="Radar Finished"}}
local spectatorNukeRules = {stockpile = {sharedAlerts=true, maxAlerts=5, mark="Nuke Ready"}, created = {sharedAlerts=true, mark="Nuke Started", alertSound="sounds/commands/cmd-selfd.wav"}, finished = {reAlertSec=1, mark="Nuke Finished", alertSound="sounds/commands/cmd-selfd.wav"}}
local spectatorAntiNukeRules = {created = {sharedAlerts=true, maxAlerts=5, mark="Antinuke Started"}, finished = {sharedAlerts=true, maxAlerts=5, mark="AntiNuke Finished"}}

local spectatorFactoryRules = {}; local spectatorRezBotRules = {}; local spectatorMexRules = {}; local spectatorUnitsT2Rules = {}; local spectatorUnitsT3Rules = {}; local spectatorFactoryT1Rules = {}; local spectatorMexT1Rules = {}; local spectatorEnergyGenRules = {}; local spectatorEnergyGenT1Rules = {}; local spectatorAllMobileUnitsRules = {}; local spectatorUnitsT1Rules = {}; local spectatorHoverUnitsRules = {}; local spectatorWaterUnitsRules = {}; local spectatorWaterT1Rules = {}; local spectatorWaterT2Rules = {}; local spectatorWaterT3Rules = {}; local spectatorGroundUnitsRules = {}; local spectatorGroundT1Rules = {}; local spectatorGroundT2Rules = {}; local spectatorGroundT3Rules = {}; local spectatorAirUnitsRules = {}; local spectatorAirT1Rules = {}; local spectatorAirT2Rules = {}; local spectatorAirT3Rules = {}
local trackSpectatorTypesRules = {commander = spectatorCommanderRules, constructor = spectatorConstructorRules, rezBot = spectatorRezBotRules, radar = spectatorRadarRules, nuke = spectatorNukeRules, antiNuke = spectatorAntiNukeRules, factory = spectatorFactoryRules, factoryT1 = spectatorFactoryT1Rules, factoryT2 = spectatorFactoryT2Rules, factoryT3 = spectatorFactoryT3Rules, mex = spectatorMexRules, mexT1 = spectatorMexT1Rules, mexT2 = spectatorMexT2Rules, energyGen = spectatorEnergyGenRules, energyGenT1 = spectatorEnergyGenT1Rules, energyGenT2 = spectatorEnergyGenT2Rules, allMobileUnits = spectatorAllMobileUnitsRules, unitsT1 = spectatorUnitsT1Rules, unitsT2 = spectatorUnitsT2Rules, unitsT3 = spectatorUnitsT3Rules, hoverUnits = spectatorHoverUnitsRules, waterUnits = spectatorWaterUnitsRules, waterT1 = spectatorWaterT1Rules, waterT2 = spectatorWaterT2Rules, waterT3 = spectatorWaterT3Rules, groundUnits = spectatorGroundUnitsRules, groundT1 = spectatorGroundT1Rules, groundT2 = spectatorGroundT2Rules, groundT3 = spectatorGroundT3Rules, airUnits = spectatorAirUnitsRules, airT1 = spectatorAirT1Rules, airT2 = spectatorAirT2Rules, airT3 = spectatorAirT3Rules}

-- ################################################## Config variables ends here ##################################################
-- DONT change code below this if you are not sure what you are doing

-- Newly added event events/rules will need to be added here
-- most validEventRules are used in getEventRulesNotifyVars(typeEventRulesTbl, unitObj)
local validEvents = {"created","finished","idle","destroyed","los","thresholdHP","taken","given","damaged","loaded","stockpile"}
local validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "alertDelay", "maxQueueTime", "alertSound", "mark", "ping","messageTo","messageTxt", "threshMinPerc"} -- TODO: , "threshMaxPerc" with economy
local relevantMyUnitDefsRules = {} -- unitDefID (key), typeArray {commander,builder} Types match to types above --  -- {defID = {type = {event = {rules}}}}
local relevantAllyUnitDefsRules = {} -- unitDefs wanted in ally armyManagers
local relevantEnemyUnitDefsRules = {} -- unitDefs wanted in enemy armyManagers
local relevantSpectatorUnitDefsRules = {}
local lastAlertTime = 0
local isEnabledDamagedWidget = false -- This will toggle itself if widget:UnitDamaged is enabled. If performance is an issue, try commenting it out there.
local debug = false
local spGetUnitDefID= Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetCommandQueue = Spring.GetCommandQueue -- Deprecated: Getting the command count using GetUnitCommands/GetCommandQueue is deprecated. Please use Spring.GetUnitCommandCount instead.
local spGetFactoryCommands = Spring.GetFactoryCommands
local TestSound = 'sounds/commands/cmd-selfd.wav'

table.insert(validEventRules,"lastNotify") -- add system only rules
table.insert(validEventRules,"alertCount") -- add system only rules

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local isSpectator
local warnFrame = 0

local function debugger(...)
    Spring.Echo(...)
end

local function tableToString(tbl, indent)
  if (type(tbl) == "table" and tbl.isPrototype) or (type(indent) == "table" and indent.isPrototype) then
    return "DON'T SEND PROTOs TO tableToString FUNCTION. IT WILL CRASH THE GAME!"
  end
  indent = indent or 4
  local str = ""
  str = str .. string.rep(".", indent) .. "{\n" -- Add indentation for nested tables
  if type(tbl) ~= "table" then -- Iterate through table elements
    str = str .. type(tbl) .. "=" .. tostring(tbl) -- If not a table, return its string representation
  else
    for k, v in pairs(tbl) do
      if (type(k) == "table" and k.isPrototype) or (type(v) == "table" and v.isPrototype) then
        return "DON'T SEND PROTOs TO tableToString FUNCTION. IT WILL CRASH!"
      end
      str = str .. string.rep(".", indent + 1)
      if type(k) == "string" then -- Format key
        str = str .. k .. " = "
      else
        str = str .. "[" .. tostring(k) .. "] = "
      end
      if type(v) == "table" then -- Handle different value types
        str = str .. tableToString(v, indent + 2) .. ",\n" -- Recursively call for nested tables
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
--====================================================

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
local function binarySearchInsertIndex(table, priority) -- Binary search function to find the insertion point for a minimum priority queue
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
    debugger("priorityQueue:insert 1. ERROR. Invalid value or priority="..tostring(priority))
    return nil
  end
  local newNode = Node:new(value, alertRulesTbl, priority)
  local insertIndex = binarySearchInsertIndex(self, priority)
  table.insert(self, insertIndex, newNode)
end

function minPriorityQueue:pull(arrNum)
  if self:size() == 0 or type(arrNum) ~= "number" or arrNum < 1 or arrNum > self.size then
    debugger("priorityQueue:pull(). ERROR. Invalid arrNum=" .. tostring(arrNum))
    return nil
  end
  arrNum = arrNum or 1
  if self:size() == 0 then return nil, 0 end
  local elRemoved = table.remove(self, arrNum) -- Removes/Returns the requested element
  return elRemoved.value, elRemoved.alertRulesTbl, elRemoved.priority, elRemoved.queuedTime
end

function minPriorityQueue:peek(arrNum) -- Returns/Keeps the top/requested element, returning vars: value, alertRulesTbl, priority, queuedTime
  arrNum = arrNum or 1
  if self:isEmpty() or type(arrNum) ~= "number" or arrNum < 1 or arrNum > self.size then
    debugger("minPriorityQueue:peek(). ERROR. Invalid arrNum=" .. tostring(arrNum))
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
local alertQueue2 = minPriorityQueue:new()
-- Example usage:
-- min_pq:insert("Task A", 5)
-- min_pq:insert("Task B", 2)
-- min_pq:insert("Task C", 8)

-- local task, priority = min_pq:pull()
-- print("Pulled:", task, "with priority:", priority) -- Expect "Task B" (lowest priority)

-- task, priority = min_pq:pull()
-- print("Pulled:", task, "with priority:", priority) -- Expect "Task A"

-- task, priority = min_pq:pull()
-- print("Pulled:", task, "with priority:", priority) -- Expect "Task C"

--====================================================

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
    debugger("priorityQueue:insert 1. ERROR. Invalid value or priority="..tostring(priority))
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
    debugger("priorityQueue:peek(). ERROR. Invalid heapNum=" .. tostring(heapNum))
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
local alertQueue = priorityQueue:new()
-- ################################################# Prototypes starts here #################################################
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
local protoObject = clone( table, { clone = clone, isa = isa } )
protoObject.isPrototype = true

local teamsManager = protoObject:clone()
teamsManager.armies = {} -- armies key/value. Added with teamsManager[teamID] key = [armyManager].
teamsManager.myArmyManager = nil  -- will hold easy quick reference to main player's armyManager.
teamsManager.lastUpdate = nil
teamsManager.debug = false
teamsManager.defTypesEventsRules = {}

local pArmyManager = protoObject:clone()

pArmyManager.units = {} -- units key/value. Added with armyManager[unitID] = [unitObject]. Objects in multiple arrays/tables are the same object (memory efficient)
pArmyManager.unitsLost = {} -- key/value unitsLost[unitID] = [unitObject] of unit objects destroyed, taken, or given
pArmyManager.unitsReceived = {} -- key/value unitsReceived[unitID] = [unitObject] of unit objects given by an ally. Possibly used for notifications, but should remove after notified
pArmyManager.defTypesEventsRules = {} -- relevantMyUnitDefsRules is {defID = {type = {event = {rules}}}}

pArmyManager.playerIDsNames = {} -- key/value of playerIDsNames[playerID] = [playerName], usually only one, that can control the army's units. TODO: Could hold Player objects
pArmyManager.isMyTeam = nil
pArmyManager.allianceID = nil
pArmyManager.teamID = nil -- teamID of the armyManager 
pArmyManager.lastUpdate = nil -- Game seconds last update time of the armyManager (NOT IMPLEMENTED YET)
pArmyManager.isAI = nil
pArmyManager.isGaia = nil
pArmyManager.factories = {}
pArmyManager.resources = {metal = {}, energy = {}}
pArmyManager.debug = false  -- ############################ArmyManager debug mode enable################################################

local pUnit = protoObject:clone()

pUnit.parent = nil -- to get the unit's armyManager
pUnit.ID = nil -- unitID
pUnit.defID = nil -- unitDefID
-- unitObj.parent.teamID -- REMINDER: This is how to get the unit's teamID 
pUnit.isIdle = false -- Use the get/set-methods instead.
pUnit.lastSetIdle = nil -- uses GetGameFrame()
pUnit.created = nil -- gameSecs
pUnit.coords = {}
pUnit.lost = nil -- gameSecs
pUnit.isLost = false
pUnit.lastUpdate = nil -- Game seconds last update time of the unit (NOT used YET)
pUnit.typeRules = {}
pUnit.health = {} -- health of the unit
pUnit.debug = false

-- TODO: Add way for armies to change alliances -- FixedAllies ( ) return: nil | bool enabled. Teams can change sides...
-- ################################################## Basic Core TeamsManager methods start here #################################################
function teamsManager:makeAllArmies()
  if debug or self.debug then debugger("makeAllArmies 1.") end
  local gaiaTeamID = Spring.GetGaiaTeamID()  -- Game's Gaia (environment) compID, but not considered an AI
  local tmpTxt = "teamID/AllyID check\n"
  for _,teamID1 in pairs(Spring.GetTeamList()) do
    local teamID2,leaderNum,isDead,isAiTeam,strSide,allianceID = Spring.GetTeamInfo(teamID1)
    if teamID1 == gaiaTeamID then -- Game's Gaia (environment) actor 
      if debug or self.debug then tmpTxt = tmpTxt .. "Gaia Env is on teamID " ..tostring(teamID1) .. " in allianceID " .. tostring(allianceID) .. ", isDead=" .. tostring(isDead) .. "\n" end
      if debug or self.debug then debugger("makeAllArmies 2. Adding Gaia.") end
      self:newArmyManager(gaiaTeamID, allianceID)
    elseif isAiTeam then
      if debug or self.debug then tmpTxt = tmpTxt .. "AI is on teamID " ..tostring(teamID1) .. " in allianceID " .. tostring(allianceID) .. ", isDead=" .. tostring(isDead) .. "\n" end
      if debug or self.debug then debugger("makeAllArmies 3. Adding AI.") end
      self:newArmyManager(teamID1, allianceID)
    else -- compID is Human
      for _,playerID in pairs(Spring.GetPlayerList(teamID1)) do -- Get all players on the compID
        local playerName, isActive, isSpectatorTmp, teamIDTmp, allyTeamIDTmp, pingTime, cpuUsage, country, rank, customPlayerKeys = Spring.GetPlayerInfo(teamID1)
        if teamIDTmp == teamID1 then
          local tmpPlayerText = "playerID " .. tostring(playerID)
          if isActive then
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " is Active" end
          else
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " is Inactive" end
          end
          if isSpectatorTmp then
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " Spectator" end
          else
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " Participant" end
            local anArmy = self:getArmyManager(teamID1)
            if type(anArmy) == "nil" then
              if debug or self.debug then debugger("makeAllArmies 4. Adding newArmyManager. teamID=" .. tostring(teamID1) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
              anArmy = self:newArmyManager(teamID1, allianceID, playerID, playerName)
            else
              if debug or self.debug then debugger("makeAllArmies 5. Adding Player. playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
              anArmy:addPlayer(playerID, playerName)
            end
          end
          if debug or self.debug then tmpPlayerText = tmpPlayerText .. " with teamID " ..tostring(teamIDTmp) .. " in allianceID " .. tostring(allyTeamIDTmp) .. ", isDead=" .. tostring(isDead) .. "\n" end
          if debug or self.debug then tmpTxt = tmpTxt .. tmpPlayerText end
        end
      end
    end
  end
  if debug or self.debug then debugger(tmpTxt) end
  if isSpectator then
    teamsManager.defTypesEventsRules = relevantSpectatorUnitDefsRules
    for aDef,aTypesTbl in pairs(teamsManager.defTypesEventsRules) do
      for aType, eventsTbl in pairs(aTypesTbl) do
        for event,rulesTbl in pairs(eventsTbl) do
          if rulesTbl["sharedAlerts"] then
            local baseObj = teamsManager
            if type(baseObj["lastAlerts"]) ~= "table" then
              if debug then debugger("newteamsManager 6. Creating lastAlerts.")end
              baseObj["lastAlerts"] = {}
            end
            local lastAlerts = baseObj["lastAlerts"]
            if type(lastAlerts[aType]) ~= "table" then
              if debug then debugger("newteamsManager 7. Creating unitOrArmyObj["..tostring(aType).."]")end
              lastAlerts[aType] = {}
            end
            if type(lastAlerts[aType][event]) ~= "table" then
              if debug then debugger("newteamsManager 8. Creating unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]") end
              lastAlerts[aType][event] = {}
              lastAlerts[aType][event]["lastNotify"] = 0
              lastAlerts[aType][event]["alertCount"] = 0
              lastAlerts[aType][event]["isQueued"] = false
              if debug then debugger("newteamsManager 9. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", sharedAlerts="..tostring(rulesTbl["sharedAlerts"])) end
            end
          end
        end
      end
    end
  end
end

-- WARNING 1: If playerID not used, will assume is an AI
-- WARNING 2: Possible to add Spectators because it doesn't check
function teamsManager:newArmyManager(teamID, allianceID, playerID, playerName) -- Returns newArmyManager child object. playerID optional. Creates the requested new army with the basic IDs. Will return nil if already exists because a different method should be used.
  if debug or self.debug then debugger("newArmyManager 1. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID, true, allianceID, nil, nil) then debugger("newArmyManager 2. INVALID input. Returning nil.") return nil end
  local armyManager = self:getArmyManager(teamID)
  if type(armyManager) ~= "nil" then -- if an armyManager with teamID already exists, return nil
    debugger("newArmyManager 3. ERROR, shouldn't happen. ArmyManager ALREADY EXISTS. Returning nil. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID))
    return nil
  end
  armyManager = pArmyManager:clone()
  if type(armyManager) == "nil" then
    debugger("newArmyManager 4. ERROR ArmyManager NOT CREATED. Returning nil. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID))
    return nil
  end
  local gameSecs = Spring.GetGameSeconds()
  self.lastUpdate = gameSecs
  armyManager.lastUpdate = gameSecs -- Game seconds last update time of the armyManager
  armyManager.teamID = teamID
  armyManager.allianceID = allianceID
  armyManager.parent = self -- link the teamsManager new armyManager
  self.armies[teamID] = armyManager
  if debug or self.debug then debugger("newArmyManager 5. New Army created. armyManager Type=" .. type(armyManager) .. ", teamID=" .. tostring(armyManager.teamID) .. ", allianceID=" .. tostring(armyManager.allianceID) .. ", self.armies[teamID].teamID=" .. tostring(self.armies[teamID].teamID)) end
  if not isSpectator and teamID == myTeamID then
    armyManager.isMyTeam = true
    self.myArmyManager = armyManager
    armyManager.defTypesEventsRules = relevantMyUnitDefsRules
  elseif Spring.AreTeamsAllied(teamID, myTeamID) then
    armyManager.defTypesEventsRules = relevantAllyUnitDefsRules
  else
    armyManager.defTypesEventsRules = relevantEnemyUnitDefsRules
  end
  if isSpectator == false then
    for aDef,aTypesTbl in pairs(armyManager.defTypesEventsRules) do
      for aType, eventsTbl in pairs(aTypesTbl) do
        for event,rulesTbl in pairs(eventsTbl) do
          if rulesTbl["sharedAlerts"] then
            local baseObj = armyManager
            if isSpectator then
              baseObj = teamsManager
            end
            if type(baseObj["lastAlerts"]) ~= "table" then
              if debug then debugger("newArmyManager 6. Creating lastAlerts.")end
              baseObj["lastAlerts"] = {}
            end
            local lastAlerts = baseObj["lastAlerts"]
            if type(lastAlerts[aType]) ~= "table" then
              if debug then debugger("newArmyManager 7. Creating unitOrArmyObj["..tostring(aType).."]")end
              lastAlerts[aType] = {}
            end
            if type(lastAlerts[aType][event]) ~= "table" then
              if debug then debugger("newArmyManager 8. Creating unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]") end
              lastAlerts[aType][event] = {}
              lastAlerts[aType][event]["lastNotify"] = 0
              lastAlerts[aType][event]["alertCount"] = 0
              lastAlerts[aType][event]["isQueued"] = false
              if debug then debugger("newArmyManager 9. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", sharedAlerts="..tostring(rulesTbl["sharedAlerts"])) end
            end
          end
        end
      end
    end
  end
  if type(playerID) == "nil" then
    if teamID == Spring.GetGaiaTeamID() then
      armyManager.isGaia = true
      if debug or self.debug then debugger("newArmyManager 10. Gaia created. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", isGaia=" .. tostring(armyManager.isGaia)) end
    else
      armyManager.isAI = true
      if debug or self.debug then debugger("newArmyManager 11. AI created. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", isAI=" .. tostring(armyManager.isAI)) end
    end
    return armyManager
  end
  armyManager:addPlayer(playerID, playerName)
  if debug or self.debug then debugger("newArmyManager 12. Player created. armyManager Type=" .. type(armyManager) .. ", teamID=" .. tostring(armyManager.teamID) .. ", allianceID=" .. tostring(armyManager.allianceID) .. ", playerName=" .. tostring(armyManager.playerIDsNames[playerID])) end
  return armyManager
end

function teamsManager:getArmyManager(teamID) -- Returns existing ArmyManager (child object) or nil if doesn't exist
  if debug or self.debug then debugger("getArmyManager 1. teamID=" .. tostring(teamID)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID, nil, nil, nil, nil) then debugger("getArmyManager 2. INVALID input. Returning nil.") return nil end
  local anArmy = self.armies[teamID]
  if type(anArmy) == "nil" then
    if debug or self.debug then debugger("getArmyManager 3. ERROR, shouldn't happen. Returning (Nil because teamID=" .. tostring(teamID) .. " not found) anArmy Type=" .. type(anArmy)) end
    return nil
  end
  if debug or self.debug then debugger("getArmyManager 4. Found and returning anArmy Type=" .. type(anArmy) .. ", teamID=" .. tostring(self.armies[teamID].teamID)) end
  return anArmy
end

function teamsManager:getUnit(unitID, teamID)
  if debug or self.debug then debugger("teamsManager:getUnit 1. unitID=" .. tostring(unitID) .. ", teamID=" .. tostring(teamID)) end
  if not teamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then debugger("teamsManager:getUnit 2. INVALID input. Returning nil.") return nil end
  if type(teamID) == "nil" then
    if debug or self.debug then debugger("teamsManager:getUnit 3. Nil teamID. Trying Spring.GetUnitTeam(unitID). unitID=" .. tostring(unitID) .. ", teamID=" .. tostring(teamID)) end
    teamID = Spring.GetUnitTeam(unitID)
    if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID, nil, nil, nil, nil) then debugger("teamsManager:getUnit 4. INVALID input. Returning nil.") return nil end
  end
  local anArmy = self:getArmyManager(teamID)
  if type(anArmy) == "nil" then
    debugger("teamsManager:getUnit 5. ERROR. teamsManager:getArmyManager= nil. Army NOT FOUND, but should exist. Returning nil. unitID=" .. tostring(unitID) .. ", anArmy.teamID=" .. tostring(teamID))
      return nil
  else
    if debug or self.debug then debugger("teamsManager:getUnit 6. Found ArmyManager, Returning anArmy:getUnit(unitID). unitID=" .. tostring(unitID) .. ", anArmy.teamID=" .. tostring(anArmy.teamID)) end
      return anArmy:getUnit(unitID)
  end
end
-- this has two return types: nil if none found, or array of units if one or more found.
function teamsManager:getUnitsIfInitialized(unitID) -- This should only be used before creating an enemy unit, because they can be moved between teams while outside los.
  if debug or self.debug then debugger("teamsManager:getUnitsIfInitialized 1. unitID=" .. tostring(unitID)) end
  if not teamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then debugger("teamsManager:getUnitsIfInitialized 2. INVALID input. Returning nil.") return nil end
  local unitsFound = {}; local aUnit
  for teamID, anArmy in pairs(self.armies) do
    aUnit = anArmy.units[unitID]
    if aUnit ~= nil then
      table.insert(unitsFound,aUnit)
    end
  end
  if debug or self.debug then debugger("teamsManager:getUnitsIfInitialized 3. Total units found=" .. tostring(#unitsFound)) end
  if #unitsFound == 0 then
    return nil
  elseif #unitsFound == 1 then
    return table.remove(unitsFound,1)
  else
    debugger("teamsManager:getUnitsIfInitialized 4. ERROR. MULTIPLE units found=" .. tostring(#unitsFound))
    return unitsFound
  end
end

function teamsManager:createUnit(unitID, defID, teamID)
  if debug or self.debug then debugger("teamsManager:createUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", unitTeamID=" .. tostring(teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then debugger("teamsManager:createUnit 2. INVALID input. Returning nil.") return nil end
  local armyManager = self:getArmyManager(teamID)
  if type(armyManager) == "nil" then
    debugger("teamsManager:createUnit 3. ERROR. ArmyManager not found. unitTeamID=" .. tostring(teamID))
    return nil
  end
  return armyManager:createUnit(unitID, defID)
end

function teamsManager:isAllied(teamID1, teamID2)  -- If playing and teamID2 not given, assumes it is myTeamID 
  if debug or self.debug then debugger("isAllied 1. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID1, nil, nil, nil, nil) then debugger("isAllied 2. INVALID input. Returning nil.") return nil end
  local armyManager1 = self:getArmyManager(teamID1)
  if not armyManager1 then
    debugger("isAllied 3. ERROR. Army1 Obj not returned. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2))
    return nil
  end
  local armyManager2
  if not isSpectator and type(teamID2) == "nil" then
    teamID2 = self.myArmyManager.teamID
    armyManager2 = self.myArmyManager
    if debug or self.debug then debugger("isAllied 4. Using myTeamID for T2. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  elseif type(teamID2) == "number" then
    armyManager2 = self:getArmyManager(teamID2)
  else
    debugger("isAllied 5. ERROR. Need 2 teamIDs. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2) .. ", isSpectator=" .. tostring(isSpectator))
    return nil
  end
  if not armyManager2 then
    debugger("isAllied 5. ERROR. Army2 Obj not returned. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2))
    return nil
  end
  local isAllied = armyManager1.allianceID == armyManager2.allianceID
  local isSpringAllied = Spring.AreTeamsAllied(teamID1, teamID2)
  if isAllied == isSpringAllied then
    if debug or self.debug then debugger("isAllied 6. Spring agrees. isAllied=" .. tostring(isAllied) .. ", allianceID1=" .. tostring(armyManager1.allianceID) .. ", allianceID2=" .. tostring(armyManager2.allianceID)) end
    return isAllied
  else
    debugger("isAllied 7. ERROR. Spring DISAGREES. Spring=" .. tostring(isSpringAllied) .. ", isAllied=" .. tostring(isAllied) .. ", allianceID1=" .. tostring(armyManager1.allianceID) .. ", allianceID2=" .. tostring(armyManager2.allianceID))
    return nil
  end
end

function teamsManager:isEnemy(teamID1, teamID2)
  if debug or self.debug then debugger("isEnemy 1. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  return self:isAllied(teamID1, teamID2) == false
end

function teamsManager:moveUnit(unitID, defID, oldTeamID, newTeamID)
  if debug or self.debug then debugger("moveUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", oldTeamID=" .. tostring(oldTeamID) .. ", newTeamID=" .. tostring(newTeamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, true, oldTeamID, nil, nil, nil, nil) then debugger("teamsManager:moveUnit 2. INVALID input. Returning nil.") return nil end
  if not teamsManager:validIDs(nil, nil, nil, nil, true, newTeamID, nil, nil, nil, nil) then debugger("teamsManager:moveUnit 3. INVALID input. Returning nil.") return nil end
  local oldTeamArmy = self:getArmyManager(oldTeamID)
  local newTeamArmy = self:getArmyManager(newTeamID)
  if type(oldTeamArmy) == "nil" or type(newTeamArmy) == "nil" then
    debugger("moveUnit 4. ERROR. Either Army NOT found. oldTeamArmy=" .. type(oldTeamArmy) .. ", newTeamArmy" .. type(newTeamArmy))
    return nil
  end
  local aUnit = oldTeamArmy:getUnit(unitID)
  if type(aUnit) == "nil" then
    if debug or self.debug then debugger("moveUnit 5. OldUnit not found CREATING IT AUTOMATICALLY. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", oldTeamID=" .. type(oldTeamID) .. ", newTeamID=" .. type(newTeamID)) end
    aUnit = self:createUnit(unitID, defID, oldTeamID)
    if type(aUnit) == "nil" then
      debugger("moveUnit 6. ERROR. Failed to create/find new unit in oldTeamArmy. oldTeamArmy=" .. type(oldTeamArmy) .. ", newTeamArmy=" .. type(newTeamArmy))
      return nil
    end
  end
  -- Need to TEST
  if alertAllTaken or alertAllGiven then
    local takenType, takenEvntTbl = next(alertAllTakenRules)
    local givenType, givenEvntTbl = next(alertAllGivenRules)
    for aType, eventsTbl in pairs({[takenType]=takenEvntTbl , [givenType]=givenEvntTbl }) do
      for event,rulesTbl in pairs(eventsTbl) do
        if not rulesTbl["sharedAlerts"] then
          local lastAlerts = aUnit["lastAlerts"]
          if type(lastAlerts[aType]) ~= "table" then
            if debug then debugger("moveUnit 7. Setting givenTaken type. unitOrArmyObj["..tostring(aType).."]="..type(lastAlerts[aType])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
            lastAlerts[aType] = {}
          end
          if type(lastAlerts[aType][event]) ~= "table" then
            lastAlerts[aType][event] = {}
            lastAlerts[aType][event]["lastNotify"] = 0
            lastAlerts[aType][event]["alertCount"] = 0
            lastAlerts[aType][event]["isQueued"] = false
            if debug then debugger("moveUnit 8. Setting givenTaken event vars. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
          end
        end
      end
    end
  end
  local givenTaken
  if teamsManager:isAllied(newTeamID, oldTeamID) then
    givenTaken = "given"
    if debug or self.debug then debugger("moveUnit 9. Unit has been given. unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  else
    givenTaken = "taken"
    if debug or self.debug then debugger("moveUnit 9. Unit has been taken. unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  end
  if givenTaken == "taken" then
    if alertAllTaken then
      if debug or self.debug then debugger("moveUnit 10. Unit has rule to alert when taken, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      teamsManager:addUnitToAlertQueue(aUnit, alertAllTakenRules)
    else
      local takenEvent = aUnit:getTypesRulesForEvent(givenTaken, true, false)
      if takenEvent then
        if debug or self.debug then debugger("moveUnit 10. Unit has rule to alert when taken, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
        teamsManager:addUnitToAlertQueue(aUnit, takenEvent)
      end
    end
  end
  aUnit:setLost(false)
  aUnit.parent = newTeamArmy
  newTeamArmy.units[unitID] = aUnit -- set here because it is only set in createUnit(), and setLost() removed from other army
  aUnit:setTypes(aUnit.defID)
  newTeamArmy.unitsReceived[aUnit.ID] = aUnit
  -- Need to TEST
  if givenTaken == "given" then
    if alertAllGiven then
      if debug or self.debug then debugger("moveUnit 8. Unit has rule alertAllGiven, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      teamsManager:addUnitToAlertQueue(aUnit, alertAllGivenRules)
    else
      local givenEvent = aUnit:getTypesRulesForEvent(givenTaken, true, false)
      if givenEvent then
        if debug or self.debug then debugger("moveUnit 10. Unit has rule to alert when given, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
        teamsManager:addUnitToAlertQueue(aUnit, givenEvent)
      end
    end
  end

  self.lastUpdate = Spring.GetGameSeconds()
  return aUnit
end

function teamsManager:getOrCreateUnit(unitID, defID, teamID)
  if debug or self.debug then debugger("teamsManager:getOrCreateUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then debugger("teamsManager:getOrCreateUnit 2. INVALID input. Returning nil.") return nil end
  local anArmy = self:getArmyManager(teamID)
  if anArmy == nil then debugger("teamsManager:getOrCreateUnit 3. ERROR. Army NOT found. teamID=" .. tostring(teamID)) return nil end
  return anArmy:getOrCreateUnit(unitID, defID)
end

function teamsManager:validIDs(vUnit, unitID, vdef, defID, vtm, teamID, vAlli, allianceID, vplr, playerID) -- only "v" vars=true will be validated
if false then debugger("validIDs 1. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID)) end
  local allValid = true
  if vUnit and type(unitID) ~= "number" then
    debugger("validIDs 2. ERROR bad UnitID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vdef and type(defID) ~= "number" then
    debugger("validIDs 3. ERROR bad defID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vtm and type(teamID) ~= "number" then
    debugger("validIDs 4. ERROR bad teamID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vAlli and type(allianceID) ~= "number" then
    debugger("validIDs 5. ERROR bad allianceID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vplr and type(playerID) ~= "number" then
    debugger("validIDs 5. ERROR bad playerID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  return allValid
end

local function alertPointer(x, y, z, pointerText, localOnly)
  if debug then debugger("alertPointer 1. coords="..tostring(x)..", "..tostring(y)..", "..tostring(z)..", pointerText="..tostring(pointerText)..", localOnly="..tostring(localOnly)) end
  if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or x < 0 then
    debugger("alertPointer 2. ERROR. Invalid coordinates=" .. tostring(x) .. ", " .. tostring(y))
    return false
  end
  pointerText = type(pointerText) == "string" and pointerText or ""
  localOnly = type(localOnly) == "boolean" and localOnly or true
  Spring.MarkerAddPoint( x, y, z, pointerText, localOnly) -- localOnly = mark (only you see)
  return true
end

local function alertSound(soundPath, volume)
  volume = volume or 1
  if debug then debugger("alertSound 1. soundPath=" .. tostring(soundPath)..", volume="..tostring(volume)) end
  if type(soundPath) ~= "string" or volume ~= nil and (type(volume) ~= "number" or volume < 0 or volume > 1) then
    debugger("alert 2. ERROR. Invalid volume or soundPath=" .. tostring(soundPath)..", volume="..tostring(volume))
    return nil
  end
    Spring.PlaySoundFile(soundPath, 1.0, 'ui')
  return true
end

local function alertMessage(message, toWhom)
  if debug then debugger("alertMessage 1. alertMessage=" .. tostring(message)..", toWhom="..tostring(toWhom)) end
  toWhom = toWhom or "me"
  if type(message) ~= "string" or message == "" or (type(toWhom) ~= "string" and toWhom ~= nil) or (toWhom ~= "me" and toWhom ~= "all" and toWhom ~= "allies" and toWhom ~= "spectators") then
    debugger("alertMessage 2. ERROR. Invalid toWhom or message=" .. tostring(message)..", toWhom="..tostring(toWhom))
    return nil
  end
  if not toWhom == "me" and not toWhom == "all" and not toWhom == "allies" and not toWhom == "spectators"  then
    debugger("alertMessage 3. ERROR. toWhom must be: me, all, allies, or spectators." .. tostring(message)..", toWhom="..tostring(toWhom))
  elseif toWhom == "me" then
    Spring.SendMessageToPlayer(myPlayerID, message) -- "me" myPlayerID
  elseif not isSpectator and toWhom == "all" then
    Spring.SendMessage(message) -- "all"
  elseif not isSpectator and toWhom == "allies" then
    Spring.SendMessageToAllyTeam(teamsManager.myArmyManager.allianceID, message) -- "allies" teamsManager.myArmyManager.allianceID
  elseif toWhom == "spectators" then
    Spring.SendMessageToSpectators(message) -- "spectators"
  else
    debugger("alertMessage 4. ERROR. Spectators should not talk to players!" .. tostring(message)..", toWhom="..tostring(toWhom))
  end
  return true
end

function teamsManager:alert(unitObj, alertVarsTbl) -- nil input alerts from alertQueue. alertVarsTbl created by getEventRulesNotifyVars(unitObj,typeEventRulesTbl)
  if unitObj == nil and alertVarsTbl == nil then
    if debug or self.debug then debugger("alert 1. Alert called without parameters. will attempt to use queue.") end
  else
    if debug or self.debug then debugger("alert 1. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    if type(alertVarsTbl) ~= "table" then
      debugger("alert 2. ERROR. Not nil or bad parameters. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl))
      return nil
    end
  end
  local success = false
  if unitObj == nil and alertVarsTbl == nil then
    if debug or self.debug then debugger("alert 3. Going to getNextQueuedAlert.") end
    unitObj, alertVarsTbl, _ = self:getNextQueuedAlert()
    if alertVarsTbl == nil then
      if debug or self.debug then debugger("alert 4. No alerts returned, exiting.") end
      return false
    end
  end
  if type(alertVarsTbl["alertSound"]) == "string" then -- play audio found in alertSound rule
    if debug or self.debug then debugger("alert 5. About to play alertSound. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    alertSound(alertVarsTbl["alertSound"])
    success = true
    lastAlertTime = Spring.GetGameSeconds()
  end
  if type(alertVarsTbl["messageTxt"]) == "string" and type(alertVarsTbl["messageTo"]) == "string" then -- chat message and recipients
    if debug or self.debug then debugger("alert 6. Going to alertMessage. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    alertMessage(alertVarsTbl["messageTxt"], alertVarsTbl["messageTo"])
    success = true
    lastAlertTime = Spring.GetGameSeconds()
  end
  if type(unitObj) == "table" and type(unitObj.ID) == "number" and type(alertVarsTbl) == "table" then
    if debug or self.debug then debugger("alert 7. Starting mark/ping part. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    if (alertVarsTbl["mark"] == true or type(alertVarsTbl["mark"]) == "string") or (alertVarsTbl["ping"] == true or type(alertVarsTbl["ping"]) == "string") then -- not supposed to have both, but will be cautious and make localOnly the preference
      local localOnly = false
      local pointerText = alertVarsTbl["ping"] -- else will ping to other players with false
      if not pointerText or alertVarsTbl["mark"] == true or type(alertVarsTbl["mark"]) == "string" then
        localOnly = true
        pointerText = alertVarsTbl["mark"]
      end
      if pointerText == true then pointerText = "" end
      local x, y, z = unitObj:getCoords()
      if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        debugger("alert 8. ERROR. Invalid coordinates=" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z))
        success = false
      else
        alertPointer(x, y, z, pointerText, localOnly)
        if debug or self.debug then debugger("alert 9. Returning True. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
        success = true
      end
    end
  end
  if success then
    local alertBaseObj = unitObj
    if alertVarsTbl["sharedAlerts"] then
      alertBaseObj = unitObj.parent
      if isSpectator then
        alertBaseObj = teamsManager
      end
    end
    alertBaseObj = alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]
    local gameSec = Spring.GetGameSeconds()
    alertBaseObj["lastNotify"] = gameSec
    alertBaseObj["alertCount"] = (alertBaseObj["alertCount"] + 1)
    lastAlertTime = Spring.GetGameSeconds()
  end
  if debug or self.debug then debugger("alert 10. was="..tostring(success)..", unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
  return success
end

function teamsManager:addUnitToAlertQueue(unitObj, typeEventRulesTbl) -- Use [unit or armyMgr]:getTypesRulesForEvent() with topPriorityOnly = true. Must have one of each: type,event
  if debug or self.debug then debugger("addUnitToAlertQueue 1. ") end
  if type(unitObj) ~= "table" or type(unitObj.ID) ~= "number" or type(typeEventRulesTbl) ~= "table" then
    debugger("addUnitToAlertQueue 2. ERROR. Returning nil. Bad unit or rules table. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(typeEventRulesTbl))
    return nil
  end
  unitObj:getCoords() -- in case it dies before the alert happens
  local alertVarsTbl = self:getEventRulesNotifyVars(unitObj, typeEventRulesTbl)
  if type(alertVarsTbl) ~= "table" then -- all is verified by getEventRulesNotifyVars()
    debugger("addUnitToAlertQueue 3. ERROR. Returning nil. getEventRulesNotifyVars() returned nil. alertVarsTbl=" .. type(alertVarsTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if alertVarsTbl["sharedAlerts"] then
    alertBaseObj = unitObj.parent
    if isSpectator then
      alertBaseObj = teamsManager
    end
  end
  alertBaseObj = alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]
  local gameSecs = Spring.GetGameSeconds()
  if debug then debugger("addUnitToAlertQueue 4. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(alertVarsTbl["maxAlerts"])..", mark="..tostring(alertVarsTbl["mark"])..", ping="..tostring(alertVarsTbl["ping"])..", alertSound="..tostring(alertVarsTbl["alertSound"]) .. ", tableToString=" .. tableToString(alertVarsTbl)) end
  if ((type(alertVarsTbl["mark"]) ~= "string") and (type(alertVarsTbl["ping"]) ~= "string") and type(alertVarsTbl["alertSound"]) ~= "string") or alertBaseObj["isQueued"] or gameSecs < alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"] or (alertVarsTbl["maxAlerts"] ~= 0 and alertBaseObj["alertCount"] >= alertVarsTbl["maxAlerts"]) then
    if debug then debugger("addUnitToAlertQueue 4.1. Too soon or no alert rules. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(alertVarsTbl["maxAlerts"])..", mark="..tostring(alertVarsTbl["mark"])..", ping="..tostring(alertVarsTbl["ping"])..", alertSound="..tostring(alertVarsTbl["alertSound"]) .. ", tableToString=" .. tableToString(alertVarsTbl)) end
    return false
  end
  if alertVarsTbl["priority"] == 0 then
    if debug then debugger("addUnitToAlertQueue 5. SUCCESS. Priority 0 goes straight to alert(). priority=" .. tostring(alertVarsTbl["priority"])) end
    self:alert(unitObj, alertVarsTbl)
    return true
  end
  if not alertQueue:isEmpty() then -- ensure not adding duplicates and manage situations where an alert should be removed and/or replaced
    -- If already in queue for same event, vars used: teamID, unitType, event, sharedAlerts, priority, maxQueueTime, threshMinPerc, threshMaxPerc
    if debug then debugger("addUnitToAlertQueue 6. sharedAlerts=" .. tostring(alertVarsTbl["sharedAlerts"]) .. ". Starting checks to decide if this alert should be queued and/or others removed/replaced. alertVarsTbl=" .. tableToString(alertVarsTbl)) end
    local alertMatchesTbls
    if alertVarsTbl["sharedAlerts"] then
      alertMatchesTbls = self:getQueuedEvents(nil,alertVarsTbl.teamID,alertVarsTbl["unitType"],alertVarsTbl["event"],nil,nil)
      if alertMatchesTbls then -- if shared, and same type/event, then don't add the new one
        if debug then debugger("addUnitToAlertQueue 7. ERROR. Rejected because same shared type/event was present. Returning nil. alertVarsTbl=" .. tableToString(alertVarsTbl)) end
        return nil
      end
      if debug then debugger("addUnitToAlertQueue 8. SUCCESS. Added sharedAlert to queue.") end
      alertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
      return true
    else
      alertMatchesTbls = self:getQueuedEvents(unitObj,alertVarsTbl.teamID,nil,alertVarsTbl["event"],nil, nil)
    end
    if alertMatchesTbls then
      local useNewAlert = true
      local bestPriority = alertVarsTbl["priority"]
      local removeHeapNums = {}
      for heapNum,value in ipairs(alertMatchesTbls) do -- {heapNum = {value = unitObj, alertRulesTbl = {[rule] = [value]}, priority = priority, queuedTime = Spring.GetGameSeconds()}}
        if bestPriority < value["priority"] then -- Remove duplicate with worse priority -- self.heap[heapNum].value
          if debug then debugger("addUnitToAlertQueue 9. Will need to remove heap="..tostring(heapNum)) end -- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
          table.insert(removeHeapNums,heapNum)
        else
          bestPriority = value.alertRulesTbl["priority"]
          useNewAlert = false -- alertQueue already has same or better, no need to add the new one
        end
      end
      if #removeHeapNums > 0 then
        if #removeHeapNums > 1 then
          debugger("addUnitToAlertQueue 9. ERROR. This shouldn't happen, alertQueue had multiple matches and it is a pain to remove multiple at once. duplicates="..tostring(#removeHeapNums)..", removeHeapNums="..tableToString(removeHeapNums))
        end
        local k, rHN = next(removeHeapNums)
        if rHN then
          local removeObj = alertQueue.heap[rHN]
          if alertQueue.size > 1 then
            if alertQueue.size == rHN then
              alertQueue.heap[alertQueue.size] = nil
            else
              alertQueue.heap[rHN] = alertQueue.heap[alertQueue.size]
              alertQueue.heap[alertQueue.size] = nil
              alertQueue:_sink(1)
            end
              alertQueue.size = alertQueue.size - 1
          else
            alertQueue.heap[1] = nil
            alertQueue.size = 0
          end
          local unitOrArmyObj = removeObj.value
          if removeObj.alertRulesTbl["sharedAlerts"] then
            unitOrArmyObj = unitOrArmyObj.parent
            if isSpectator then
              unitOrArmyObj = teamsManager
            end
          end
          if debug then debugger("addUnitToAlertQueue 10. Removed a heap and setting isQueued false.") end
          unitOrArmyObj["lastAlerts"][removeObj.alertRulesTbl["unitType"]][removeObj.alertRulesTbl["event"]]["isQueued"] = false
        end
      end
      if useNewAlert and bestPriority == alertVarsTbl["priority"] then
        if debug then debugger("addUnitToAlertQueue 11. Adding requested alert after removing one with worse priority.") end
        alertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
        alertBaseObj["isQueued"] = true
        return true
      end
      if debug then debugger("addUnitToAlertQueue 12. alertQueue already has same or better, no need to add the new one.") end
      return false
    end
  end
  if debug then debugger("addUnitToAlertQueue 13. SUCCESS. There were no matches. Adding to queue.") end
  alertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
  alertBaseObj["isQueued"] = true
  return true
end

-- Returns single-level key/value table with everything needed for addUnitToAlertQueue
function teamsManager:getEventRulesNotifyVars(unitObj,typeEventRulesTbl ) -- validates and returns alertVarsTbl key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
  if debug then debugger("getEventRulesNotifyVars 1. unitObj=" .. type(unitObj) .. ", typeEventRulesTbl=" .. type(typeEventRulesTbl)) end
  local typeCount = 0
  local eventCount = 0
  local unitType
  local event
  local rulesTbl
  for aType, eventsTbl in pairs(typeEventRulesTbl) do
    typeCount = typeCount + 1
    unitType = aType
    for anEvent, aRulesTbl in pairs(eventsTbl) do
      eventCount = eventCount + 1
      event = anEvent
      rulesTbl = aRulesTbl
    end
  end
  if typeCount ~= 1 or eventCount ~= 1 then
    debugger("getEventRulesNotifyVars 3. ERROR. Returning nil. Bad typeEventRulesTbl or multiple events provided. typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if rulesTbl["sharedAlerts"] then
    alertBaseObj = unitObj.parent
    if isSpectator then
      alertBaseObj = teamsManager
    end
  end
  local lastNotify = alertBaseObj["lastAlerts"][unitType][event]["lastNotify"]
  local alertCount = alertBaseObj["lastAlerts"][unitType][event]["alertCount"]
  if type(lastNotify) ~= "number" or type(alertCount) ~= "number" then
    debugger("getEventRulesNotifyVars 5. ERROR. Returning nil. Bad alertCount or lastSharedNotify=" .. type(lastNotify) .. ", type(alertCount)=" .. type(alertCount) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
    return nil
  end
  return {["teamID"]=unitObj.parent.teamID, ["unitType"]=unitType, ["event"]=event, ["lastNotify"]=lastNotify, ["sharedAlerts"]=rulesTbl["sharedAlerts"], ["priority"]=rulesTbl["priority"], ["reAlertSec"]=rulesTbl["reAlertSec"], ["maxAlerts"]=rulesTbl["maxAlerts"], ["alertDelay"]=rulesTbl["alertDelay"], ["alertCount"]=alertCount, ["maxQueueTime"]=rulesTbl["maxQueueTime"], ["alertSound"]=rulesTbl["alertSound"], ["mark"]=rulesTbl["mark"], ["ping"]=rulesTbl["ping"], ["threshMinPerc"]=rulesTbl["threshMinPerc"], ["threshMaxPerc"]=rulesTbl["threshMaxPerc"]}
end

function teamsManager:getNextQueuedAlert()
  if debug then debugger("getNextQueuedAlert 1. queueSize="..tostring(alertQueue:getSize())) end
  if Spring.GetGameSeconds() < lastAlertTime + minReAlertSec then
    if debug then debugger("getNextQueuedAlert 1.1. Too soon due to minReAlertSec="..tostring(minReAlertSec)..", remainingSecs="..lastAlertTime + minReAlertSec - Spring.GetGameSeconds()) end
    return nil
  end
  local validFound = false; local unitObj, alertVarsTbl, priority, queuedSec; local gameSecs = Spring.GetGameSeconds(); local heapNum = 1
  while validFound == false and alertQueue:getSize() > 0 and heapNum <= alertQueue:getSize() do
    unitObj, alertVarsTbl, priority, queuedSec = alertQueue:peek(heapNum)
    if gameSecs <= queuedSec + alertVarsTbl["alertDelay"] then
      if debug then debugger("getNextQueuedAlert 2. Still waiting alertDelay="..queuedSec + alertVarsTbl["alertDelay"] - gameSecs..", queueSize="..tostring(alertQueue:getSize())) end
      heapNum = heapNum + 1
    else
      unitObj, alertVarsTbl, priority, queuedSec = alertQueue:pull(heapNum)
      if debug then debugger("getNextQueuedAlert 3. Pulled value=" .. type(unitObj) .. ", alertRulesTbl=" .. type(alertVarsTbl) .. ", priority=" .. tostring(priority) .. ", gameSecs=" .. tostring(gameSecs) .. ", unitName=" .. tostring(UnitDefs[unitObj.defID].translatedHumanName)) end
      if gameSecs <= queuedSec + alertVarsTbl["maxQueueTime"] then
        if debug then debugger("getNextQueuedAlert 4. Valid found with remaining time="..queuedSec + alertVarsTbl["maxQueueTime"] - gameSecs) end
        validFound = true
      end
      if alertVarsTbl["event"] == "idle" and (alertVarsTbl["teamID"] ~= unitObj.parent.teamID or unitObj.isLost or unitObj:getIdle() == false) then -- important: "NOT unitObj:getIdle()" used because it returns nil while waiting the 5 frames to ensure the idle isn't a false positive.
        if debug then debugger("getNextQueuedAlert 5. No longer idle.") end
        validFound = false
      end
      local alertBaseObj = unitObj
      if alertVarsTbl["sharedAlerts"] then
        alertBaseObj = unitObj.parent
        if isSpectator then
          alertBaseObj = teamsManager
        end
      end
      alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]["isQueued"] = false
    end
  end
  if validFound then
    if debug then debugger("getNextQueuedAlert 6. SUCCESS Valid found with remaining time="..queuedSec + alertVarsTbl["maxQueueTime"] - gameSecs) end
    return unitObj, alertVarsTbl, priority
  end
  if debug then debugger("getNextQueuedAlert 7. None found.") end
  return nil, nil, nil
end

-- Need to convert to use alertQueue2 because it is WAY easier to work with, and the heap system isn't warranted for such small queues
-- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
function teamsManager:getQueuedEvents(unitObj,teamID,unitType,event,priorityLessThan,sharedAlerts) -- leaves them in queue. 
  if debug then debugger("getQueuedEvents 1. Searching for unit teamID="..tostring(teamID)..", unitType="..tostring(unitType)..", event="..tostring(event)..", sharedAlerts="..tostring(sharedAlerts)..", priorityLessThan="..tostring(priorityLessThan)) end
  local matchedEvents = {}; local matches = 0; local size = alertQueue:getSize()
  if size > 0 then
    for heapNum,valPriTbl in ipairs(alertQueue.heap) do -- should probably replace alertQueue.heap[heapNum] with valPriTbl $$$$$$$$$$$$
      if debug then debugger("getQueuedEvents 2. Queued unit vars: heapNum=" .. tostring(heapNum) .. ", sharedAlert="..tostring(alertQueue.heap[heapNum].alertRulesTbl["sharedAlerts"]) .. ", priority="..tostring(alertQueue.heap[heapNum]["priority"]) .. ", queuedTime=" .. tostring(valPriTbl["queuedTime"]) .. ", teamID=" .. tostring(alertQueue.heap[heapNum].alertRulesTbl.teamID) .. ", unitType=" .. tostring(alertQueue.heap[heapNum].alertRulesTbl["unitType"]) .. ", event=" .. tostring(alertQueue.heap[heapNum].alertRulesTbl["event"]) .. ", unitName=" .. tostring(UnitDefs[alertQueue.heap[heapNum].value.defID].translatedHumanName)) end
      if (type(teamID) == "nil" or (type(teamID) == "number" and teamID == alertQueue.heap[heapNum].alertRulesTbl.teamID)) and
      (type(unitType) == "nil" or (type(unitType) == "string" and unitType == alertQueue.heap[heapNum].alertRulesTbl["unitType"])) and
      (type(event) == "nil" or (type(event) == "string" and event == alertQueue.heap[heapNum].alertRulesTbl["event"])) and
      (type(unitObj) == "nil" or (type(unitObj) == "table" and unitObj == alertQueue.heap[heapNum].value)) and
      (type(sharedAlerts) == "nil" or sharedAlerts == alertQueue.heap[heapNum].alertRulesTbl["sharedAlerts"]) and
      (type(priorityLessThan) == "nil" or (type(priorityLessThan) == "number" and alertQueue.heap[heapNum].priority < priorityLessThan )) then
        matchedEvents[heapNum] = alertQueue.heap[heapNum] -- {heapNum = {value = unitObj, alertRulesTbl = {[rule] = [value]}, priority = priority, queuedTime = Spring.GetGameSeconds()}}
        matches = matches +1
        if debug then debugger("getQueuedEvents 3. Match found in heap=" .. tostring(heapNum) .. ", unitName=" .. tostring(UnitDefs[alertQueue.heap[heapNum].value.defID].translatedHumanName)) end
      end
    end
  end
  if matches < 1 then
    if debug then debugger("getQueuedEvents 4. No matches found.") end
    return nil
  end
  if debug then debugger("getQueuedEvents 5. Matches being returned=" .. tostring(matches)) end
  return matchedEvents
end

function teamsManager:validTypeEventRulesTbls(typeTbl) --returns nil | true, typeCount, eventCount, ruleCount
  if debug then debugger("validTypeEventRulesTbls 1. event=" .. type(typeTbl)) end
  if type(typeTbl) ~= "table" then
    debugger("validTypeEventRulesTbls 2. ERROR. Returning False. Not eventTbl=" .. type(typeTbl))
    return nil
  end
  local typeCount = 0; local eventCount = 0; local ruleCount = 0; local emptyTypesToRemove = {}; local badValue = nil
  for aType,eventTbl in pairs(typeTbl) do
    if type(aType) ~= "string" then
      debugger("validTypeEventRulesTbls 3. ERROR. Returning Nil. NOT string aType=" .. type(aType))
      return nil
    end
    if type(eventTbl) ~= "table" then
      if debug then debugger("validTypeEventRulesTbls 3.1. Skipping this type because it could be a placeholder. Not eventTbl=" .. type(eventTbl) .. ", aType="..tostring(aType)) end
      table.insert(emptyTypesToRemove,aType)
    else
      typeCount = typeCount +1
      for anEvent,rulesTbl in pairs(eventTbl) do
        if type(anEvent) ~= "string" then
          debugger("validTypeEventRulesTbls 3.2. ERROR. Returning False. NOT string anEvent=" .. type(anEvent))
          return nil
        end
        rulesTbl["mark"] = type(rulesTbl["mark"]) == "string" and rulesTbl["mark"] or nil -- string or nil
        rulesTbl["ping"] = type(rulesTbl["ping"]) == "string" and rulesTbl["ping"] or nil -- string or nil
        rulesTbl["alertSound"] = type(rulesTbl["alertSound"]) == "string" and rulesTbl["alertSound"] or nil -- string or nil
        rulesTbl["sharedAlerts"] = rulesTbl["sharedAlerts"] == true and rulesTbl["sharedAlerts"] or false -- true or nil
        rulesTbl["maxQueueTime"] = type(rulesTbl["maxQueueTime"]) == "number" and rulesTbl["maxQueueTime"] or 120 -- number
        rulesTbl["maxAlerts"] = type(rulesTbl["maxAlerts"]) == "number" and rulesTbl["maxAlerts"] or 0
        rulesTbl["reAlertSec"] = type(rulesTbl["reAlertSec"]) == "number" and rulesTbl["reAlertSec"] or 15
        rulesTbl["priority"] = type(rulesTbl["priority"]) == "number" and rulesTbl["priority"] or 5
        rulesTbl["alertDelay"] = type(rulesTbl["alertDelay"]) == "number" and rulesTbl["alertDelay"] or 0
        rulesTbl["messageTxt"] = type(rulesTbl["messageTxt"]) == "string" and rulesTbl["messageTxt"] or nil -- string or nil  -- , messageTo="me",messageTxt="messageTxt"
        if type(rulesTbl["messageTxt"]) ~= "string" or rulesTbl["messageTxt"] == "" then
          rulesTbl["messageTo"] = nil
          rulesTbl["messageTxt"] = nil
        elseif type(rulesTbl["messageTo"]) ~= "string" or (rulesTbl["messageTo"] ~= "all" and rulesTbl["messageTo"] ~= "allies" and rulesTbl["messageTo"] ~= "spectators" ) then
          rulesTbl["messageTo"] = "me"
        end
        if anEvent == "thresholdHP" and type(rulesTbl["threshMinPerc"]) ~= "number" then
          debugger("validTypeEventRulesTbls 3.3. ERROR. Bad threshMinPerc or used without thresholdHP. Must be: 0 < threshMinPerc < 1. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
          return nil
        elseif type(rulesTbl["threshMinPerc"]) ~= "number" then
          rulesTbl["threshMinPerc"] = nil
        elseif rulesTbl["threshMinPerc"] == nil and anEvent == "thresholdHP" or rulesTbl["threshMinPerc"] and anEvent ~= "thresholdHP" or rulesTbl["threshMinPerc"] >= 1 or rulesTbl["threshMinPerc"] <= 0 then
          debugger("validTypeEventRulesTbls 3.3. ERROR. Bad threshMinPerc or used without thresholdHP. Must be: 0 < threshMinPerc < 1. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
          return nil
        end
        -- if type(rulesTbl["threshMaxPerc"]) ~= "number" then -- Not implemented yet. Bad logic, do similar to threshMinPerc
        --   rulesTbl["threshMaxPerc"] = nil
        -- elseif (rulesTbl["threshMinPerc"] and rulesTbl["threshMaxPerc"] <= rulesTbl["threshMinPerc"]) or rulesTbl["threshMaxPerc"] >= 1 or rulesTbl["threshMaxPerc"] <= 0 then
        --   debugger("validTypeEventRulesTbls 3.4. ERROR. Bad threshMaxPerc. Must be 0 < threshMinPerc < 1 and greater than threshMinPerc. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
        --   return nil
        -- end
        -- debugger("validTypeEventRulesTbls 4. TEST. threshMinPerc, threshMaxPerc, sharedAlerts, mark, ping, alertSound, maxAlerts, reAlertSec, priority, or event="..tostring(anEvent)..", priority=" .. tostring(rulesTbl["priority"]) .. ", reAlertSec=" .. tostring(rulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(rulesTbl["maxAlerts"]) .. ", maxQueueTime=" .. tostring(rulesTbl["maxQueueTime"]) .. ", threshMinPerc=" .. tostring(rulesTbl["threshMinPerc"]) .. ", threshMaxPerc=" .. tostring(rulesTbl["threshMaxPerc"]) .. ", tableToString=" .. tableToString(rulesTbl))
        if (rulesTbl["maxAlerts"]~= nil and type(rulesTbl["maxAlerts"]) ~= "number") or type(rulesTbl["reAlertSec"]) ~= "number" or type(rulesTbl["priority"]) ~= "number" or (rulesTbl["maxQueueTime"] ~= nil and rulesTbl["maxQueueTime"] ~= false and type(rulesTbl["maxQueueTime"]) ~= "number") or (type(rulesTbl["mark"]) ~= "string" and rulesTbl["mark"] ~= nil) or (type(rulesTbl["ping"]) ~= "string" and rulesTbl["ping"] ~= nil) or (type(rulesTbl["alertSound"]) ~= "string" and rulesTbl["alertSound"] ~= nil) or (type(rulesTbl["sharedAlerts"]) ~= "boolean" --[[ and rulesTbl["sharedAlerts"] ~= nil]]) or (rulesTbl["threshMinPerc"] ~= nil and type(rulesTbl["threshMinPerc"]) ~= "number" or (type(rulesTbl["threshMinPerc"]) == "number" and (rulesTbl["threshMinPerc"] <= 0 or rulesTbl["threshMinPerc"] >= 1))) or (rulesTbl["threshMaxPerc"] ~= nil and type(rulesTbl["threshMaxPerc"]) ~= "number" or ((type(rulesTbl["threshMaxPerc"]) == "number" and (rulesTbl["threshMaxPerc"] >= 1 or rulesTbl["threshMaxPerc"] <= 0)) or ((type(rulesTbl["threshMaxPerc"]) == "number" and rulesTbl["threshMinPerc"] == "number") and (rulesTbl["threshMaxPerc"] <= rulesTbl["threshMinPerc"])))) then
          debugger("validTypeEventRulesTbls 4. ERROR. Returning nil. Bad threshMinPerc, threshMaxPerc, sharedAlerts, mark, ping, alertSound, maxAlerts, reAlertSec, priority, or event="..tostring(anEvent)..", priority=" .. tostring(rulesTbl["priority"]) .. ", reAlertSec=" .. tostring(rulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(rulesTbl["maxAlerts"]) .. ", maxQueueTime=" .. tostring(rulesTbl["maxQueueTime"]) .. ", threshMinPerc=" .. tostring(rulesTbl["threshMinPerc"]) .. ", threshMaxPerc=" .. tostring(rulesTbl["threshMaxPerc"]) .. ", tableToString=" .. tableToString(rulesTbl))
          return nil
        end
        badValue = anEvent
        local eventMatch = false
        for i,v in ipairs(validEvents) do
          if anEvent == v then
            eventMatch = true
            eventCount = eventCount +1
            badValue = nil
            break
          end
        end
        if eventMatch == false then
          debugger("validTypeEventRulesTbls 5. ERROR. Returning False. Bad value=" .. tostring(badValue) .. " in eventTbl=" .. tableToString(eventTbl))
          return nil
        end
        if type(rulesTbl) ~= "table" then
          debugger("validTypeEventRulesTbls 6. ERROR. Returning False. Not Table rulesTbl=" .. type(rulesTbl))
          return nil
        end
        for aRule,_ in pairs(rulesTbl) do
          badValue = aRule
          local ruleMatch = false
          for i2,v2 in ipairs(validEventRules) do
            if aRule == v2 then
              ruleMatch = true
              ruleCount = ruleCount +1
              badValue = nil
              break
            end
          end
          if ruleMatch == false then
            debugger("validTypeEventRulesTbls 7. ERROR. Returning False. Bad value=" .. tostring(badValue) .. " in rulesTbl=" .. tableToString(rulesTbl))
            return nil
          end
        end
      end
    end
  end
  if #emptyTypesToRemove > 0 then
    for k,v in ipairs(emptyTypesToRemove) do
      debugger("validTypeEventRulesTbls 6. Removing Bad type=" .. tostring(v))
      typeTbl[v] = nil
    end
  end
  if debug then debugger("validTypeEventRulesTbls 7. SUCCESS. typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", ruleCount=" .. tostring(ruleCount)..", emptyTypes="..tostring(#emptyTypesToRemove)) end
  return true,typeCount,eventCount,ruleCount,emptyTypesToRemove
end
-- ################################################## Custom/Expanded TeamsManager methods start here #################################################


-- ################################################## Basic Core ArmyManager methods start here #################################################
function pArmyManager:addPlayer(playerID, playerName)
  if debug or self.debug then debugger("addPlayer 1. teamID=" ..tostring(self.teamID).. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, nil, nil, nil, nil, true, playerID) then debugger("pArmyManager:addPlayer 2. INVALID input. Returning nil.") return nil end
  if type(playerName) ~= "string" then
    playerName = playerID -- Placeholder value for nil
  end
  self.playerIDsNames[playerID] = playerName
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pArmyManager:createUnit(unitID, defID) -- this has two return types: nil if none found, or array of units if one or more found.
  if debug or self.debug then debugger("createUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:createUnit 2. INVALID input. Returning nil.") return nil end
  local aUnit
  local unitTeamNow = Spring.GetUnitTeam(unitID)
  if unitTeamNow ~= self.teamID then
    debugger("createUnit 4. ERROR. Wrong team! There's no good reason for this! No. Returning nil. unitTeamNow=" .. tostring(unitTeamNow) .. ", self.teamID=" .. tostring(self.teamID))
    return nil
  end
  if unitTeamNow ~= self.teamID and teamsManager:isEnemy(unitTeamNow, self.teamID) then
    local enemyUnits = teamsManager:getUnitsIfInitialized(unitID)
    if type(enemyUnits) == "nil" then
      if debug or self.debug then debugger("createUnit 3. Enemy unit not initialized. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
    elseif #enemyUnits == 1 then
      aUnit = table.remove(enemyUnits,1)
      if debug or self.debug then debugger("createUnit 4. One Enemy unit found. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow)) end
      if unitTeamNow == aUnit.parent.teamID then
        if debug or self.debug then debugger("createUnit 5. ERROR. Enemy unit already in current. This method shouldn't be called if it already exists. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow)) end
        return aUnit
      else
        if debug or self.debug then debugger("createUnit 6. Enemy unit found in different army. It must have been given out of LOS. Moving it to the new teamID Army and returning the result. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow)) end
        return teamsManager:moveUnit(unitID,aUnit.defID,aUnit.parent.teamID,unitTeamNow)
      end
    else
      debugger("createUnit 7. ERROR. Unit found in multiple(" .. tostring(#enemyUnits) .. ") armies. This shouldn't be possible? Could keep the most recently updated one, but is it really worth coding? Screw it, let's just nuke them from orbit to be sure! Making a new after. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow))
      for k, eUnit in pairs(enemyUnits) do
        eUnit:setLost(false)
      end
    end
  else
    aUnit = self:getUnit(unitID)
  end
  if type(aUnit) ~= "nil" then
    debugger("createUnit 8. ERROR. Already EXISTS in armyManager.units. aUnit.ID=" .. tostring(aUnit.ID) .. ", teamID=".. tostring(self.teamID))
    return aUnit
  end
  aUnit = pUnit:clone()
  aUnit.parent = self
  self.units[unitID] = aUnit
  aUnit:setAllIDs(unitID, defID)
  aUnit:setTypes()
  local gameSecs = Spring.GetGameSeconds()
  aUnit.created = gameSecs
  self.lastUpdate = gameSecs
  aUnit.lastUpdate = gameSecs
  aUnit.lastSetIdle = gameSecs - 5
  local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(aUnit.ID)
  if type(health) == "number" then
    aUnit.health = {["HP"]=health, ["maxHP"]=maxHealth, ["paralyzeDamage"]=paralyzeDamage, ["captureProgress"]=captureProgress, ["buildProgress"]=buildProgress}
  end
  local eventTble = aUnit:getTypesRulesForEvent("created", true, false)
  if buildProgress and buildProgress == 1 and type(eventTble) == "table" then
    if debug then debugger("createUnit 9. Has rules for created. Sending to addUnitToAlertQueue(). unitID=" .. type(aUnit.unitID) .. ", unitDefID=" .. type(aUnit.defID) .. ", teamID=" .. type(self.teamID)) end
    teamsManager:addUnitToAlertQueue(aUnit, eventTble)
  end
  if debug or self.debug then debugger("createUnit 10. aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  return aUnit
end

function pArmyManager:getUnit(unitID)  -- Get unit by unitID. Returns the unit object or nil if not found
  if debug or self.debug then debugger("getUnit 1. unitID=" .. tostring(unitID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:getUnit 2. INVALID input. Returning nil.") return nil end
  local aUnit = self.units[unitID]
  if type(aUnit) == "nil" then
    if debug or self.debug then debugger("getUnit 3. unitID=" .. tostring(unitID) .. " does not exist in armyManager.units") end
    return nil -- This is expected to happen when this method is used to check if the unit exists in the armyManager
  end
  if debug or self.debug then debugger("getUnit 4. FOUND unitID=" .. tostring(unitID) .. ", aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID)) end
  return aUnit
end

function pArmyManager:getOrCreateUnit(unitID, defID)
  if debug or self.debug then debugger("pArmyManager:getOrCreateUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:getOrCreateUnit 2. INVALID input. Returning nil.") return nil end
  return self:getUnit(unitID) or self:createUnit(unitID, defID)
end

function pArmyManager:getTypesRulesForEvent(defIDOrTypeRules, event, topPriorityOnly, canAlertNow, unitObj) -- mandatory defID | unit["typeRules"] (for efficiency), string event, bool/nil (default false) topPriorityOnly. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}
  if debug or self.debug then debugger("getTypesRulesForEvent 1. teamID=" ..tostring(self.teamID).. ", defID=" .. tostring(defIDOrTypeRules) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly).. ", canAlertNow="..tostring(canAlertNow).. ", unitObj="..type(unitObj)) end
  if type(event) ~= "string" or (type(topPriorityOnly) ~= "boolean" and topPriorityOnly ~= nil) or (unitObj ~= nil and type(unitObj) ~= "table") or (canAlertNow and type(unitObj) ~= "table") then
    debugger("getTypesRulesForEvent 2. ERROR. event not string, not unitObj with canAlertNow. teamID=" ..tostring(self.teamID).. ", defID=" .. tostring(defIDOrTypeRules) .. ", event=" .. tostring(event))
    return nil
  end
  local typesEventRulesTbl
  if type(defIDOrTypeRules) == "table" and next(defIDOrTypeRules) ~= nil then
    typesEventRulesTbl = defIDOrTypeRules
  elseif type(defIDOrTypeRules) == "number" then
    if not isSpectator then
      typesEventRulesTbl = self.defTypesEventsRules[defIDOrTypeRules] -- {defID = {type = {event = {rules}}}}
      if debug or self.debug then debugger("getTypesRulesForEvent 3. Is Player.") end
    else
      if debug or self.debug then debugger("getTypesRulesForEvent 3. isSpectator.") end
      typesEventRulesTbl = teamsManager.defTypesEventsRules[defIDOrTypeRules]
    end
  else
    debugger("getTypesRulesForEvent 3. ERROR. defIDOrTypeRules not table or number defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ",typeRulesTbl="..type(typesEventRulesTbl) .. ", teamID=".. tostring(self.teamID))
    return nil
  end
  local typesEventsTbl = {}; local matches = 0; local priorityNum = 99999
  for aType, eventsTbl in pairs(typesEventRulesTbl) do -- {type = {event = {rules}}}
    if debug then debugger("getTypesRulesForEvent 4. aType=" .. tostring(aType) .. ", typesEventRules=" .. type(eventsTbl) .. ", event=" .. tostring(event)) end
    if type(eventsTbl) == "table" and type(aType) == "string" then
      local eventMatch = eventsTbl[event]
      if type(eventMatch) == "table" and next(eventMatch) ~= nil then
        if (not topPriorityOnly or eventMatch["priority"] < priorityNum) and (not canAlertNow or (canAlertNow and self:canAlertNow(unitObj, {[aType] = {[event] = eventMatch}}))) then
          if topPriorityOnly and matches == 1 then
            typesEventsTbl = {}
            matches = 0
          end
          if debug then debugger("getTypesRulesForEvent 5. Adding match to tmpEventTbl. aType=" .. tostring(aType) .. ", event=" .. tostring(event)) end
          typesEventsTbl[aType] = {[event] = eventMatch}
          matches = matches + 1
        end
      end
    end
  end
  if matches == 0 then
    if debug then debugger("getTypesRulesForEvent 6. No matches, returning nil. event=" .. tostring(event)) end
    return nil
  end
  if debug then debugger("getTypesRulesForEvent 7. Returning matches=" .. tostring(matches) .. ", event=" .. tostring(event) .. ", typesEventRules=" .. type(typesEventsTbl)) end
  return typesEventsTbl -- {type = {event = {rules}}}
end

function pArmyManager:canAlertNow(unitObj, typeEventRulesTbl) -- Input can only have 1 Type and 1 Event -- {type = {event = {rules}}}
  if debug or self.debug then debugger("canAlertNow 1. unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl)) end
  if type(unitObj) ~= "table" or type(unitObj.parent.teamID) ~= "number" or type(typeEventRulesTbl) ~= "table" then
    debugger("canAlertNow 2. ERROR, returning nil. Need unitObj and typeEventRulesTbl. Can't initEventLastAlerts(). unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl))
    return nil
  end
  local aType,anEventTbl = next(typeEventRulesTbl)
  if type(anEventTbl) ~= "table" then
    debugger("canAlertNow 3. ERROR, returning nil. Not anEventTbl=".. type(anEventTbl))
    return nil
  end
  local anEvent,aRulesTbl = next(anEventTbl)
  if type(aRulesTbl) ~= "table" then
    debugger("canAlertNow 4. ERROR, returning nil. Not aRulesTbl=".. type(aRulesTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if aRulesTbl["sharedAlerts"] then
    alertBaseObj = alertBaseObj.parent
    if debug then debugger("canAlertNow 5. Is a sharedAlert.") end
    if isSpectator then
      alertBaseObj = teamsManager
    end
  end
  alertBaseObj = alertBaseObj["lastAlerts"][aType][anEvent]
  local gameSecs = Spring.GetGameSeconds()
  if debug then debugger("canAlertNow 6. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. " < " .. tostring(alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. " / " .. tostring(aRulesTbl["maxAlerts"])..", mark="..tostring(aRulesTbl["mark"])..", ping="..tostring(aRulesTbl["ping"])..", alertSound="..tostring(aRulesTbl["alertSound"])) end
  if ((type(aRulesTbl["mark"]) ~= "string") and (type(aRulesTbl["ping"]) ~= "string") and type(aRulesTbl["alertSound"]) ~= "string") or alertBaseObj["isQueued"] or gameSecs < alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"] or (aRulesTbl["maxAlerts"] ~= 0 and alertBaseObj["alertCount"] >= aRulesTbl["maxAlerts"]) then
    if debug then debugger("canAlertNow 7. Too soon or no alert rules. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. " < " .. tostring(alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(aRulesTbl["maxAlerts"])..", mark="..tostring(aRulesTbl["mark"])..", ping="..tostring(aRulesTbl["ping"])..", alertSound="..tostring(aRulesTbl["alertSound"])) end --  .. ", tableToString=" .. tableToString(aRulesTbl)
    return false
  end
  if debug or self.debug then debugger("canAlertNow 8. TRUE. unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl)) end
  return true
end

function pArmyManager:hasTypeEventRules(defIDOrTypeRules, aType, event) -- mandatory defID | unit["typeRules"] (for efficiency)
  if debug or self.debug then debugger("hasTypeEventRules 1. defID=".. tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
  local typeRulesTbl
  if type(defIDOrTypeRules) == "table" and next(defIDOrTypeRules) ~= nil then
    typeRulesTbl = defIDOrTypeRules
  elseif type(defIDOrTypeRules) == "number" then
    if not isSpectator then
      typeRulesTbl = self.defTypesEventsRules[defIDOrTypeRules]
      if debug or self.debug then debugger("hasTypeEventRules 2. Is Player. defID="..tostring(defIDOrTypeRules)..", type typeRulesTbl="..tostring(typeRulesTbl)) end
    else
      if debug or self.debug then debugger("hasTypeEventRules 3. isSpectator. defID="..tostring(defIDOrTypeRules)) end
      typeRulesTbl = teamsManager.defTypesEventsRules[defIDOrTypeRules]
    end
  else
    debugger("hasTypeEventRules 4. ERROR. defIDOrTypeRules not table or number defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", typeRulesTbl="..type(typeRulesTbl) .. ", teamID=".. tostring(self.teamID))
    return false
  end
  if type(typeRulesTbl) ~= "table" then
    if debug or self.debug then debugger("hasTypeEventRules 5. FALSE. Not table defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", typeRulesTbl="..type(typeRulesTbl) .. ", teamID=".. tostring(self.teamID)) end
    return false
  end
  if defIDOrTypeRules and not aType and not event then
    if debug or self.debug then debugger("hasTypeEventRules 6. TRUE. Found requested defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
    return true
  end
  for kType,evntTbl in pairs(typeRulesTbl) do
    if aType and kType == aType and event and type(evntTbl[event]) == "table" then
      if debug or self.debug then debugger("hasTypeEventRules 7. TRUE. Found type and event. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
      return true
    elseif not event and aType and kType == aType and type(evntTbl) == "table" then
      if debug or self.debug then debugger("hasTypeEventRules 8. TRUE. Found type. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
      return true
    elseif not aType and event and type(evntTbl[event]) == "table" then
      if debug or self.debug then debugger("hasTypeEventRules 9. TRUE. Found event. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
      return true
    end
  end
  if debug or self.debug then debugger("hasTypeEventRules 10. FALSE. Couldn't find type and/or event. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
  return false
end

-- ################################################## Custom/Expanded ArmyManager methods start here #################################################


-- ################################################## Basic Core Unit methods starts here #################################################
function pUnit:setID(unitID)
  if debug or self.debug then debugger("setID 1. unitID=" .. tostring(unitID)) end
  if not teamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then debugger("pUnit:setID 2. INVALID input. Returning nil.") return nil end
  self.ID = unitID
  if debug or self.debug then debugger("setID 2. self.ID=" .. tostring(self.ID) .. ", unitID=".. tostring(unitID)) end
  self.lastUpdate = Spring.GetGameSeconds()
  return self.ID
end

function pUnit:setDefID(defID)
  if debug or self.debug then debugger("setDefID 1. self.ID=" .. tostring(self.ID) .. ", self.defID=".. tostring(self.defID) .. ", unitDefID=".. tostring(defID) .. ", type(self.ID)=".. type(self.ID) .. ", type(self.defID)=".. type(self.defID)) end
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pUnit:setDefID 2. INVALID input. Returning nil.") return nil end
  self.defID = defID
  self.lastUpdate = Spring.GetGameSeconds()
  return self.defID
end

function pUnit:setAllIDs(unitID, unitDefID)
  if debug or self.debug then debugger("setAllIDs 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(unitDefID) .. ", unitTeamID=" .. tostring(self.parent.teamID)) end
  return self:setID(unitID) == unitID and self:setDefID(unitDefID) == unitDefID
end

function pUnit:setIdle()
  if debug or self.debug then debugger("setIdle 1. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if not self.isIdle then
    self.isIdle = true
    if self:hasTypeEventRules(nil, "idle") then
        self.parent["idle"][self.ID] = self
      local typeRules = self:getTypesRulesForEvent("idle", true, true)
      if typeRules then
        if debug or self.debug then debugger("setIdle 2. Going to addUnitToAlertQueue. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
        teamsManager:addUnitToAlertQueue(self, typeRules)
      end
    end
    self.lastSetIdle = Spring.GetGameFrame()
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setIdle 3. Has been setIdle. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end

function pUnit:setNotIdle()
  if debug or self.debug then debugger("setNotIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if self.isIdle then
    self.isIdle = false
      if self.parent["idle"] and self.parent["idle"][self.ID] ~= nil then
        self.parent["idle"][self.ID] = nil
      end
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setNotIdle 2. Has been setNotIdle. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end
-- ATTENTION!!! ###### Use "alertDelay" with the "idle" event to prevent false positives. ".1" works well
function pUnit:getIdle()
  if debug or self.debug then debugger("getIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  if not self.isCompleted then
    local _, _, _, _, buildProgress = self:getHealth() -- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress -- -- threshMinPerc=.5
    if buildProgress == nil or buildProgress < 1 then
      if debug or self.debug then debugger("getIdle 2. Not fully constructed, so returning NOT IDLE. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
      self:setNotIdle()
      return self.isIdle
    else
      self.isCompleted = true
    end
  end
  local count = 0
  if self.isFactory then
    count = Spring.GetFactoryCommands(self.ID, 0) -- GetFactoryCommands(unitID, 0)
    if debug or self.debug then debugger("getIdle 3. isFactory with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    if count == nil then
      if debug or self.debug then debugger("getIdle 3.1. count is nil for factory. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      count = 1
    end
  else
    count = Spring.GetUnitCommandCount(self.ID) -- was spGetCommandQueue(self.ID, 0) which is Deprecated
    if debug or self.debug then debugger("getIdle 4. Builder with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    if count == nil then
      if debug or self.debug then debugger("getIdle 4.1. count is nil. This can happen when the commander is dead. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      count = 1
    end
  end
  if debug or self.debug then debugger("getIdle 5. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ", CommandQueueCount=" .. tostring(count) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if count == nil then
    if debug or self.debug then debugger("getIdle 4.1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    count = 0
  end
  if count > 0 then
    if debug or self.debug then debugger("getIdle 6. Wasn't actually Idle. Calling setNotIdle to correct it. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    self:setNotIdle()
    return self.isIdle
  elseif self.isIdle == false then
    self:setIdle()
    if debug or self.debug then debugger("getIdle 7. Was actually Idle, corrected. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  -- IMPORTANT: Only setIdle can initiate alert, else there'll be double alerts due to the alert method checking idle after it was removed from queue but before the alert happens/logged
  end
  return self.isIdle
end

function pUnit:setLost(destroyed) -- destroyed = true default
  if debug or self.debug then debugger("setLost 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed)) end
  if type(destroyed) ~= "nil" and type(destroyed) ~= "boolean" then
    debugger("setLost 2. ERROR. destroyed NOT nil or bool. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed))
  end
  self:getCoords() -- Must do this immediately before the unit has completed death animation
  if destroyed == nil then
    destroyed = true
  end
  self:setNotIdle() -- Removes it from idle lists/queues
  if type(self.parent["unitsLost"]) ~= "table" then self.parent["unitsLost"] = {} end
  self.parent["unitsLost"][self.ID] = self
  self.parent.units[self.ID] = nil
  local unitTypes = self["typeRules"] -- {type = {event = {rules}}}} -- Remove unit from all Type/Event lists in parent army (except Lost)
  if debug or self.debug then debugger("setLost 4. About to try removing unit from all Type/Event lists in parent army (except Lost). translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)) end
  if type(unitTypes) == "table" then
    for aType, eventTbl in pairs(unitTypes) do
      if type(aType) == "string" and type(self.parent[aType]) == "table" and self.parent[aType][self.ID] ~= nil then
        if debug or self.debug then debugger("setLost 5. Removed self from parent[" .. tostring(aType) .. "] translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(eventTbl)=" .. type(eventTbl)) end
        self.parent[aType][self.ID] = nil
        if type(eventTbl) == "table" then
          for anEvent, rules in pairs(eventTbl) do
            if type(anEvent) == "string" and type(self.parent[anEvent]) == "table" and self.parent[anEvent][self.ID] ~= nil then
              self.parent[anEvent][self.ID] = nil
              if debug or self.debug then debugger("setLost 6. Removed self from parent[" .. tostring(anEvent) .. "], translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
            end
          end
        end
      end
    end
  end
  if destroyed then
    self.isLost = true
    local destroyedEvent = self:getTypesRulesForEvent("destroyed", true, false)
    if destroyedEvent then
      if debug or self.debug then debugger("setLost 7. Unit has rule to alert when destroyed, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      teamsManager:addUnitToAlertQueue(self, destroyedEvent) -- {type = {event = {rules}}}
    end
  end
  self.lost = Spring.GetGameSeconds()
  self.lastUpdate = Spring.GetGameSeconds()
  if deleteDestroyed then
    self.parent["unitsLost"][self.ID] = nil
  else
    return self
  end
end

-- Unused method, but could be handy later
function pUnit:getTypeRules(aType)
  if debug or self.debug then debugger("getTypesRules 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types) .. ", translatedHumanName=" ..tostring(UnitDefs[self.defID].translatedHumanName)) end
  return self["typeRules"][aType]
end

function pUnit:getTypesRulesForEvent(event, topPriorityOnly, canAlertNow) -- string event. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}, topPriorityOnly returns just their one with best priority
  if debug or self.debug then debugger("pUnit:getTypesRulesForEvent 1. Returning self.parent:getTypesRulesForEvent(" .. tostring(self.defID) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly) .. "), unitID=" .. tostring(self.ID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if type(self["typeRules"]) ~= "table" or next(self["typeRules"]) == nil then
    debugger("pUnit:getTypesRulesForEvent 2. ERROR. Unit has no rules. Shouldn't happen. event=" .. tostring(event) .. ", teamID="..tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)  .. ", next(self[typeRules])=".. tostring(next(self["typeRules"])).. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName))
    return false
  end
  return self.parent:getTypesRulesForEvent(self["typeRules"], event, topPriorityOnly, canAlertNow, self)
end

function pUnit:setTypes()
  if debug or self.debug then debugger("setTypes 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if UnitDefs[self.defID].isFactory then
    self.isFactory = true
    self.parent.factories[self.ID] = self
  end
  local unitTypes
  if not isSpectator then
    unitTypes = self.parent.defTypesEventsRules[self.defID] -- {defID = {type = {event = {rules}}}}
  else
    unitTypes = teamsManager.defTypesEventsRules[self.defID]
  end
  if debug or self.debug then debugger("setTypes 2. translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)) end
  if type(unitTypes) ~= "table" or next(unitTypes) == nil then
    debugger("setTypes 2.1. ERROR. All created units should have rules associated to them. translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes))
  end
  self["typeRules"] = unitTypes; self.hasDamagedEvent = false
  for aType, eventsTbl in pairs(unitTypes) do
    if type(aType) ~= "string" then
      debugger("setTypes 2.2. ERROR. aType not string. aType="..tostring(aType)..", unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)..", tableToString="..tableToString(aType))
      return nil
    end
    if self.parent[aType] == nil then self.parent[aType] = {} end
    self.parent[aType][self.ID] = self
    if debug or self.debug then debugger("setTypes 3. Added self to my army's list of=" .. tostring(aType) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    if eventsTbl["damaged"] and isEnabledDamagedWidget then
      self.hasDamagedEvent = true
    end
    local baseObj = self
    if type(eventsTbl) == "table" and eventsTbl["sharedAlerts"] == true then -- Unnecessary now since below only does non-shared
      baseObj = baseObj.parent
      if isSpectator then
        baseObj = teamsManager
      end
    end
    for event,rulesTbl in pairs(eventsTbl) do
      if not rulesTbl["sharedAlerts"] then
        if type(baseObj["lastAlerts"]) ~= "table" then
          if debug then debugger("setTypes 4. lastAlerts="..type(baseObj["lastAlerts"])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
          baseObj["lastAlerts"] = {}
        end
        local lastAlerts = baseObj["lastAlerts"]
        if type(lastAlerts[aType]) ~= "table" then
          if debug then debugger("setTypes 5. unitOrArmyObj["..tostring(aType).."]="..type(lastAlerts[aType])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
          lastAlerts[aType] = {}
        end
        if type(lastAlerts[aType][event]) ~= "table" then
          lastAlerts[aType][event] = {}
          lastAlerts[aType][event]["lastNotify"] = 0
          lastAlerts[aType][event]["alertCount"] = 0
          lastAlerts[aType][event]["isQueued"] = false
          if debug then debugger("setTypes 6. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        end
      end
      if event == "thresholdHP" and rulesTbl["threshMinPerc"] then -- adding instantiation of persistent events
        if type(self.parent["thresholdHP"]) ~= "table" then
          self.parent["thresholdHP"] = {}
        end
        if not self.hasDamagedEvent then -- if doesn't have damaged event, must manually add
          self.parent["thresholdHP"][self.ID] = self
          if debug or self.debug then debugger("setTypes 7. Added self to thresholdHP. unitID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        elseif self.hasDamagedEvent and self.parent["thresholdHP"][self.ID] then -- if has damaged event, it is automaticaly added/removed from the thresholdHP table by getHealth()
          self.parent["thresholdHP"][self.ID] = nil
          if debug or self.debug then debugger("setTypes 8. Removing self from thresholdHP. unitID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        end
      elseif event == "idle" and type(self.parent["idle"]) ~= "table" then
        if debug or self.debug then debugger("setTypes TEST. About to create idle table. Which now has type=" .. type(self.parent["idle"])) end
        self.parent["idle"] = {}
      end
    end
  end
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pUnit:hasTypeEventRules(aType, event)
  if debug or self.debug then debugger("pUnit:hasTypeEventRules 1. SHELL. Will return from parent method. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  if type(self["typeRules"]) ~= "table" or next(self["typeRules"]) == nil then
    debugger("pUnit:hasTypeEventRules 2. ERROR. Unit has no rules. Shouldn't happen. event=" .. tostring(event) .. ", teamID="..tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)  .. ", next(self[typeRules])=".. tostring(next(self["typeRules"])).. ", name=" .. tostring(UnitDefs[self.defID].translatedHumanName))
    return false
  end
  return self.parent:hasTypeEventRules(self["typeRules"], aType, event)
end

function pUnit:getCoords()
  if debug or self.debug then debugger("getCoords 1. Getting unit's current position, else sending back the most recent coords." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
  local x,y,z = Spring.GetUnitPosition( self.ID )
  if type(x) == "number" then
    if debug or self.debug then debugger("getCoords 2. Returning unit's current position coords="..tostring(x).."-"..tostring(y).."-"..tostring(z)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
    if self["coords"] == nil then self["coords"] = {} end
    self["coords"]["x"] = x; self["coords"]["y"] = y; self["coords"]["z"] = z
    return x, y, z
  elseif type(self.coords["x"]) == "number" then
    if debug or self.debug then debugger("getCoords 3. Returning unit's old position because getCoords returned nil. coords="..tostring(x).."-"..tostring(y).."-"..tostring(z)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
    return self.coords["x"], self.coords["y"], self.coords["z"]
  end
  if debug or self.debug then debugger("getCoords 4. FAIL. Unable to return any coords." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
  return nil, nil, nil
end

function pUnit:getHealth()
  if debug or self.debug then debugger("getHealth 1. Getting unit's current health, else sending back the most recent health." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
  local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(self.ID)
  if isEnabledDamagedWidget and not self.hasDamagedEvent then self.hasDamagedEvent = true end
  if type(health) == "number" then
    if not self.isCompleted and buildProgress == 1 then self.isCompleted = true end
    if self.isCompleted then
      if self["health"]["HP"] and health < self["health"]["HP"] and self:hasTypeEventRules(nil, "damaged") then
        local damagedEvent = self:getTypesRulesForEvent("damaged", true, true)
        if damagedEvent then
          if debug or self.debug then debugger("getHealth 2. Unit has rule to alert when damaged, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
          teamsManager:addUnitToAlertQueue(self, damagedEvent) -- {type = {event = {rules}}}
        end
      end
      self.health = {["HP"]=health, ["maxHP"]=maxHealth, ["paralyzeDamage"]=paralyzeDamage, ["captureProgress"]=captureProgress, ["buildProgress"]=buildProgress}
      if self:hasTypeEventRules(nil, "thresholdHP") then
        if debug or self.debug then debugger("getHealth 3. Has thresholdHP. unitID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        local topPriority; local bestPriority = 9999; local thresholdMet = false; local isShared = false
        local healthPerc = self["health"]["HP"] / self["health"]["maxHP"]
        if debug or self.debug then debugger("getHealth 4. thresholdHP, healthPerc=" .. tostring(healthPerc)) end
        if healthPerc < 1 then
          for aType,eventTbl in pairs(self["typeRules"]) do
            if type(eventTbl["thresholdHP"]) == "table" and type(eventTbl["thresholdHP"]["threshMinPerc"]) == "number" then
              if healthPerc < eventTbl["thresholdHP"]["threshMinPerc"] then
                thresholdMet = true
                if eventTbl["thresholdHP"]["priority"] < bestPriority and self.parent:canAlertNow(self, {[aType] = {["thresholdHP"] = eventTbl["thresholdHP"]}}) then
                  if debug or self.debug then debugger("getHealth 5. Adding canAlert thresholdHP, healthPerc=" .. tostring(healthPerc)..", threshMinPerc="..eventTbl["thresholdHP"]["threshMinPerc"]..", priority="..tostring(eventTbl["thresholdHP"]["priority"])) end
                  topPriority = {[aType] = {["thresholdHP"] = eventTbl["thresholdHP"]}}
                  bestPriority = eventTbl["thresholdHP"]["priority"]
                  isShared = eventTbl["thresholdHP"]["sharedAlerts"]
                end
              end
            end
          end
        end
        if type(topPriority) == "table" then
          if debug or self.debug then debugger("getHealth 6. Below thresholdHP. Going to addUnitToAlertQueue.") end
          teamsManager:addUnitToAlertQueue(self, topPriority)
        end
        if debug or self.debug then debugger("getHealth TEST1. thresholdMet="..tostring(thresholdMet)..", in thresholdHP="..type(self.parent["thresholdHP"][self.ID])..", isEnabledDamagedWidget="..tostring(isEnabledDamagedWidget)..", self.hasDamagedEvent="..tostring(self.hasDamagedEvent)) end
        local alertBaseObj = self.parent
        if isSpectator and isShared then
          alertBaseObj = teamsManager
        end
        if type(alertBaseObj["thresholdHP"]) ~= "table" then
          alertBaseObj["thresholdHP"] = {}
        end
        if thresholdMet and alertBaseObj["thresholdHP"][self.ID] == nil then
          if debug or self.debug then debugger("getHealth TEST2. Adding self to thresholdHP table because thresholdMet.") end
          alertBaseObj["thresholdHP"][self.ID] = self
        elseif isEnabledDamagedWidget and self.hasDamagedEvent and not thresholdMet and alertBaseObj["thresholdHP"][self.ID] then
          if debug or self.debug then debugger("getHealth TEST3. Removing self from threshold table.") end
          alertBaseObj["thresholdHP"][self.ID] = nil
        end
      end
    end
    if debug or self.debug then debugger("getHealth 7. Returning unit's current health. health="..tostring(health)..", maxHealth="..tostring(maxHealth)..", paralyzeDamage="..tostring(paralyzeDamage)..", captureProgress="..tostring(captureProgress)..", buildProgress="..tostring(buildProgress)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
    return health, maxHealth, paralyzeDamage, captureProgress, buildProgress
  elseif type(self.health["HP"]) == "number" then
    if debug or self.debug then debugger("getHealth 8. Returning unit's old health because GetUnitHealth returned nil. health="..tostring(self.health["HP"])..", maxHealth="..tostring(self.health["maxHealth"])..", paralyzeDamage="..tostring(self.health["paralyzeDamage"])..", captureProgress="..tostring(self.health["captureProgress"])..", buildProgress="..tostring(self.health["buildProgress"])..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
    return self.health["HP"], self.health["maxHealth"], self.health["paralyzeDamage"], self.health["captureProgress"], self.health["buildProgress"]
  end
  if debug or self.debug then debugger("getHealth 9. FAIL. Unable to return any health attributes." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
  return nil
end
-- ################################################## Custom/Expanded Unit methods start here #################################################

-- ################################################# Unit Type Rules Assembly start here #################################################
local function addToRelTeamDefsRules(defID, key)
  if debug then debugger("addToRelTeamDefsRules 1. defID=" .. tostring(defID) .. ", key=" .. tostring(key)) end
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("addToRelTeamDefsRules 2. INVALID input. Returning nil.") return nil end
  if type(key) ~= "string" or type(defID) ~= "number" then debugger("addToRelTeamDefsRules 3. INVALID KEY or defID input. Returning nil. key="..tostring(key)..", defID="..tostring(defID)) return nil end
  if not isSpectator then
    if debug then debugger("addToRelTeamDefsRules 4. Adding Team Rules. key="..tostring(key)..", defID="..tostring(defID)) end
    if next(trackMyTypesRules) ~= nil and type(trackMyTypesRules[key]) == "table" and next(trackMyTypesRules[key]) ~= nil then
      if type(relevantMyUnitDefsRules[defID]) == "nil" then relevantMyUnitDefsRules[defID] = {} end
      relevantMyUnitDefsRules[defID][key] = trackMyTypesRules[key]
    end
    if next(trackAllyTypesRules) ~= nil and type(trackAllyTypesRules[key]) == "table" and next(trackAllyTypesRules[key]) ~= nil then
      if type(relevantAllyUnitDefsRules[defID]) == "nil" then relevantAllyUnitDefsRules[defID] = {} end
      relevantAllyUnitDefsRules[defID][key] = trackAllyTypesRules[key]
    end
    if next(trackEnemyTypesRules) ~= nil and type(trackEnemyTypesRules[key]) == "table" and next(trackEnemyTypesRules[key]) ~= nil then
      if type(relevantEnemyUnitDefsRules[defID]) == "nil" then relevantEnemyUnitDefsRules[defID] = {} end
      relevantEnemyUnitDefsRules[defID][key] = trackEnemyTypesRules[key]
    end
  else
    if debug then debugger("addToRelTeamDefsRules 4. Adding Spectator Rule. key="..tostring(key)..", defID="..tostring(defID)) end
    if next(trackSpectatorTypesRules) ~= nil and type(trackSpectatorTypesRules[key]) == "table" and next(trackSpectatorTypesRules[key]) ~= nil then
      if type(relevantSpectatorUnitDefsRules[defID]) == "nil" then relevantSpectatorUnitDefsRules[defID] = {} end
      relevantSpectatorUnitDefsRules[defID][key] = trackSpectatorTypesRules[key]
    end
  end
end

local function makeRelTeamDefsRules() -- This should ensure that types are only added to armyManager if there are events defined, and validate events/rules
if debug then debugger("makeRelTeamDefsRules 1.") end
  if not isSpectator then
    if type(trackMyTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackMyTypesRules) then return false end
    if type(trackAllyTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackAllyTypesRules) then return false end
    if type(trackEnemyTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackEnemyTypesRules) then return false end
  else
    if debug then debugger("makeRelTeamDefsRules TEST. Validating Spectator rules") end
    if type(trackSpectatorTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackSpectatorTypesRules) then return false end
  end
  if alertAllTaken and (type(alertAllTakenRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(alertAllTakenRules)) then return false end
  if alertAllGiven and (type(alertAllGivenRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(alertAllGivenRules)) then return false end
  for unitDefID, unitDef in pairs(UnitDefs) do
    if not string.find(unitDef.name, 'critter') and not string.find(unitDef.name, 'raptor') and (not unitDef.modCategories or not unitDef.modCategories.object) then
      if unitDef.customParams.iscommander then
        if debug then debugger("Assigning Commander types with unitDefID[" ..tostring(unitDefID) .. "].translatedHumanName=" ..tostring(UnitDefs[unitDefID].translatedHumanName)) end
        addToRelTeamDefsRules(unitDefID, "commander")
        addToRelTeamDefsRules(unitDefID, "constructor")
      elseif unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1]) and not unitDef.customParams.isairbase and unitDef.movementclass ~= "NANO" then
        if unitDef.canAssist or unitDef.canAssist then
          addToRelTeamDefsRules(unitDefID, "constructor")
        elseif unitDef.isBuilding and unitDef.isFactory then
          addToRelTeamDefsRules(unitDefID, "factory")
          if unitDef.customParams.techlevel == '2' then
            addToRelTeamDefsRules(unitDefID, "factoryT2")
          elseif unitDef.customParams.techlevel == '3' then
            addToRelTeamDefsRules(unitDefID, "factoryT3")
          else
            addToRelTeamDefsRules(unitDefID, "factoryT1")
          end
        end
      elseif unitDef.canResurrect then
        addToRelTeamDefsRules(unitDefID, "rezBot")
      end
      if unitDef.isBuilding and unitDef.customParams and unitDef.customParams.metal_extractor and unitDef.extractsMetal > 0 then -- or def.extractsMetal > 0
        addToRelTeamDefsRules(unitDefID, "mex")
        if unitDef.customParams.techlevel == '2' then
          addToRelTeamDefsRules(unitDefID, "mexT2")
        else
          addToRelTeamDefsRules(unitDefID, "mexT1")
        end
      end
      if unitDef.isBuilding and unitDef.customParams and unitDef.customParams.unitgroup == "energy" then -- or def.energyMake > 10
        addToRelTeamDefsRules(unitDefID, "energyGen")
      if unitDef.customParams.techlevel == '2' then
          addToRelTeamDefsRules(unitDefID, "energyGenT2")
        else
          addToRelTeamDefsRules(unitDefID, "energyGenT1")
        end
      end
      if unitDef.isBuilding and ((type(unitDef["radarDistance"]) == "number" and unitDef["radarDistance"] > 1900) or (type(unitDef["sonarDistance"]) == "number" and unitDef["sonarDistance"] > 850)) then
        addToRelTeamDefsRules(unitDefID, "radar")
      end
      if unitDef.isBuilding and unitDef.customParams.unitgroup == "nuke" then
        addToRelTeamDefsRules(unitDefID, "nuke")
      end
      if unitDef.isBuilding and unitDef.customParams.unitgroup == "antinuke" then
        addToRelTeamDefsRules(unitDefID, "antinuke")
      end
      if not unitDef.isBuilding and unitDef.canMove and not (unitDef.customParams.iscommander or unitDef.customParams.isscavcommander) then
        addToRelTeamDefsRules(unitDefID, "allMobileUnits")
        if unitDef.customParams.techlevel == "2" then
          addToRelTeamDefsRules(unitDefID, "unitsT2")
        elseif unitDef.customParams.techlevel == "3" then
          addToRelTeamDefsRules(unitDefID, "unitsT3")
        else
          addToRelTeamDefsRules(unitDefID, "unitsT1")
        end
        local droneTxt = "Drone"; local hoverTxt = "hover"
        if unitDef.movementclass and string.find(unitDef.movementclass:lower(), hoverTxt:lower()) and not unitDef.canFly then
          addToRelTeamDefsRules(unitDefID, "hoverUnits")
        elseif unitDef.minwaterdepth and not unitDef.canFly then -- water unit
          addToRelTeamDefsRules(unitDefID, "waterUnits")
          if unitDef.customParams.techlevel == "2" then
            addToRelTeamDefsRules(unitDefID, "waterT2")
          elseif unitDef.customParams.techlevel == "3" then
            addToRelTeamDefsRules(unitDefID, "waterT3")
          else
            addToRelTeamDefsRules(unitDefID, "waterT1")
          end
        elseif not unitDef.canFly then
          addToRelTeamDefsRules(unitDefID, "groundUnits")
          if unitDef.customParams.techlevel == "2" then
            addToRelTeamDefsRules(unitDefID, "groundT2")
          elseif unitDef.customParams.techlevel == "3" then
            addToRelTeamDefsRules(unitDefID, "groundT3")
          else
            addToRelTeamDefsRules(unitDefID, "groundT1")
          end
        elseif unitDef.canFly and not string.find(UnitDefs[unitDefID].translatedHumanName:lower(), droneTxt:lower()) then
          addToRelTeamDefsRules(unitDefID, "airUnits")
          if unitDef.customParams and unitDef.customParams.techlevel == '2' then
            addToRelTeamDefsRules(unitDefID, "airT2")
          elseif unitDef.customParams and unitDef.customParams.techlevel == '3' then
            addToRelTeamDefsRules(unitDefID, "airT3")
          else
            addToRelTeamDefsRules(unitDefID, "airT1")
          end
        end
      end
    end
  end
  return true
end

-- ################################################# Idle Alerts start here #################################################
function widget:UnitIdle(unitID, defID, teamID)
  if debug then debugger("widget:UnitIdle 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID)..", defIDType=" .. type(defID) .. ", teamID=" .. tostring(teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = teamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    if debug then debugger("widget:UnitIdle 2. Going to getOrCreateUnit, then setIdle") end
    anArmy:getOrCreateUnit(unitID, defID):setIdle() -- automatically alerts when not idle
  end
end

function widget:UnitDestroyed(unitID, defID, teamID, attackerID, attackerDefID, attackerTeam)	-- Triggered when unit dies or construction canceled/destroyed while being built
  if debug then debugger("widget:UnitDestroyed 1. Unit taken. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", attackerID=" ..tostring(attackerID) .. ", attackerDefID=" ..tostring(attackerDefID) .. ", attackerTeam=" ..tostring(attackerTeam) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  if debug then debugger("UnitDestroyed 2 unitID=" ..tostring(unitID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local army = teamsManager:getArmyManager(teamID)
  if army then
    local aUnit = army:getUnit(unitID)
    if aUnit then
      aUnit:setLost()
    elseif army:hasTypeEventRules(defID, nil, "destroyed") then
      army:getOrCreateUnit(unitID, defID):setLost() -- automatically alerts
    end
  end
end

function widget:UnitTaken(unitID, defID, oldTeamID, newTeamID) -- Taken or given
  if not teamsManager:validIDs(true, unitID, true, defID, true, oldTeamID, true, newTeamID, nil, nil) then debugger("UnitTaken 0. INVALID input. Returning nil. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", oldTeamID=" .. tostring(oldTeamID) .. ", newTeamID=" .. tostring(newTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then debugger("widget:UnitTaken 1. Unit taken. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID)  .. ", oldTeamID=" ..tostring(oldTeamID) .. ", newTeamID=" ..tostring(newTeamID)) end
  if teamsManager:getArmyManager(oldTeamID):hasTypeEventRules(defID) or teamsManager:getArmyManager(newTeamID):hasTypeEventRules(defID) then
    local oldArmy = teamsManager:getArmyManager(oldTeamID)
    if oldArmy then
      local aUnit = oldArmy:getOrCreateUnit(unitID, defID)
      if aUnit then
        teamsManager:moveUnit(unitID, defID, oldTeamID, newTeamID) -- automatically alerts
        aUnit:getIdle() -- automatically alerts when not idle
      end
    end
  end
end

function widget:UnitCreated(unitID, defID, teamID, builderID) -- Starts being built
  if debug then debugger("widget:UnitCreated 1. Unit construction started. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", teamID=" ..tostring(teamID) .. ", builderID=" ..tostring(builderID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local army = teamsManager:getArmyManager(teamID)
  if army and army:hasTypeEventRules(defID) then
    army:getOrCreateUnit(unitID, defID) -- automatically alerts
  end
end

function widget:UnitFinished(unitID, defID, teamID, builderID) -- Finished being built
  if debug then debugger("widget:UnitFinished 1 is now completed and ready. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", teamID=" ..tostring(teamID) .. ", builderID=" ..tostring(builderID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local army = teamsManager:getArmyManager(teamID)
  if army and army:hasTypeEventRules(defID) then
    local aUnit = army:getOrCreateUnit(unitID, defID)
    if debug then debugger("widget:UnitFinished 2. Sending alert. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", teamID=" ..tostring(teamID) .. ", builderID=" ..tostring(builderID)) end
    local finishedEvent = aUnit:getTypesRulesForEvent("finished", true, true)
    if finishedEvent then
      teamsManager:addUnitToAlertQueue(aUnit, finishedEvent)
    end
    aUnit:getIdle() -- automatically alerts
  end
end

function widget:UnitEnteredLos(unitID, teamID, allyTeam, defID) -- Called when a unit enters LOS of an allyteam. Its called after the unit is in LOS, so you can query that unit. The allyTeam is who's LOS the unit entered.
  if isSpectator then
    return
  end
  if defID == nil then
    defID = Spring.GetUnitDefID(unitID)
    if defID == nil then
      debugger("widget:UnitEnteredLos 0. Cannot get defID for unit?")
      return nil
    end
  end
  if not teamsManager:validIDs(true, unitID, nil, nil, true, teamID, nil, nil, nil, nil) then debugger("UnitEnteredLos 0. INVALID input. Returning nil unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", allyTeam=" .. tostring(allyTeam) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then debugger("widget:UnitEnteredLos 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", allyTeam=" .. tostring(allyTeam) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end -- 
  local anArmy = teamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    local aUnit = anArmy:getOrCreateUnit(unitID, defID)
    if aUnit then
      local losEvent = aUnit:getTypesRulesForEvent("los", true, true)
      if losEvent then
        teamsManager:addUnitToAlertQueue(aUnit, losEvent)
      end
    end
  end
end

local function checkPersistentEvents() -- Checks all of the events that BAR widgets don't cover
  if debug then debugger("checkPersistentEvents 1.") end
  local armiesToCheck
  if isSpectator then
    if debug then debugger("checkPersistentEvents 2. isSpectator, using all armies.") end
    armiesToCheck = teamsManager.armies
  else
    if debug then debugger("checkPersistentEvents 2. Is Player, using myArmyManager.") end
    armiesToCheck = {myTeamID = teamsManager.myArmyManager}
  end
  local deadUnits = {} -- ensure dead units get removed from persistently checked tables
  for _, anArmyManager in pairs(armiesToCheck) do
    if not anArmyManager.isGaia then
      if type(anArmyManager["idle"]) == "table" then
        for unitID, unit in pairs(anArmyManager["idle"]) do
          if Spring.GetUnitIsDead(unitID) then
            if debug then debugger("checkPersistentEvents 3. Dead Unit found.") end
            deadUnits[unitID] = unit
          elseif not teamsManager:getQueuedEvents(unit,nil,nil,"idle") and unit:getIdle() == true then
            if debug then debugger("checkPersistentEvents 4. Builder idle. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", teamID=" .. tostring(unit.parent.teamID)) end
            local typeRules = unit:getTypesRulesForEvent("idle", true, true)
            if typeRules then
              if debug then debugger("checkPersistentEvents 5. CanAlertNow for idle. Going to addUnitToAlertQueue.") end
              teamsManager:addUnitToAlertQueue(unit, typeRules)
            end
          end
        end
      end
      if type(anArmyManager["thresholdHP"]) == "table" then
        for unitID, unit in pairs(anArmyManager["thresholdHP"]) do
          if Spring.GetUnitIsDead(unitID) then
            if debug then debugger("checkPersistentEvents 5. Removing Dead Unit.") end
            deadUnits[unitID] = unit
          else
            if debug then debugger("checkPersistentEvents 5. Checking thresholdHP. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", teamID=" .. tostring(unit.parent.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
            if not teamsManager:getQueuedEvents(unit,nil,nil,"thresholdHP") then
              unit:getHealth() -- automatically alerts
            end
          end
        end
      end
      -- Next phase - non-unit events
      -- anArmyManager.resources["metal"]["currentLevel"], anArmyManager.resources["metal"]["storage"], anArmyManager.resources["metal"]["pull"], anArmyManager.resources["metal"]["income"], anArmyManager.resources["metal"]["expense"], anArmyManager.resources["metal"]["share"], anArmyManager.resources["metal"]["sent"], anArmyManager.resources["metal"]["received"] = Spring.GetTeamResources (anArmyManager.teamID, "metal")
      -- if debug then debugger("checkPersistentEvents 6. Checking Metal. teamID=" ..tostring(anArmyManager.teamID)..", currentLevel="..anArmyManager.resources["metal"]["currentLevel"]..", storage="..anArmyManager.resources["metal"]["storage"]..", pull="..anArmyManager.resources["metal"]["pull"]..", income="..anArmyManager.resources["metal"]["income"]..", expense="..anArmyManager.resources["metal"]["expense"]..", share="..anArmyManager.resources["metal"]["share"]..", sent="..anArmyManager.resources["metal"]["sent"]..", received="..anArmyManager.resources["metal"]["received"]) end
      -- anArmyManager.resources["energy"]["currentLevel"], anArmyManager.resources["energy"]["storage"], anArmyManager.resources["energy"]["pull"], anArmyManager.resources["energy"]["income"], anArmyManager.resources["energy"]["expense"], anArmyManager.resources["energy"]["share"], anArmyManager.resources["energy"]["sent"], anArmyManager.resources["energy"]["received"] = Spring.GetTeamResources (anArmyManager.teamID, "metal")
      -- if debug then debugger("checkPersistentEvents 7. Checking Energy. teamID=" ..tostring(anArmyManager.teamID)..", currentLevel="..anArmyManager.resources["energy"]["currentLevel"]..", storage="..anArmyManager.resources["energy"]["storage"]..", pull="..anArmyManager.resources["energy"]["pull"]..", income="..anArmyManager.resources["energy"]["income"]..", expense="..anArmyManager.resources["energy"]["expense"]..", share="..anArmyManager.resources["energy"]["share"]..", sent="..anArmyManager.resources["energy"]["sent"]..", received="..anArmyManager.resources["energy"]["received"]) end
    end
  end
  if next(deadUnits) ~= nil then
    for _, unit in pairs(deadUnits) do
      unit:setLost()
    end
  end
end

-- TODO: How to make this widget only be run if monitoring is enabled? MAYBE widget only brought in from other file? UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
-- function widget:UnitDamaged(unitID, defID, teamID, damage, paralyzer, weaponDefID, projectileID, attackerUnitID, attackerDefID, attackerTeamID)
--   isEnabledDamagedWidget = true
--   if debug then debugger("widget:UnitDamaged 1. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", damage=" .. tostring(damage) .. ", paralyzer=" .. tostring(paralyzer) .. ", weaponDefID=" .. tostring(weaponDefID) .. ", projectileID=" .. tostring(projectileID) .. ", attackerUnitID=" .. tostring(attackerUnitID) .. ", attackerDefID=" .. tostring(attackerDefID) .. ", attackerTeamID=" .. tostring(attackerTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
--   local army = teamsManager:getArmyManager(teamID)
--   if army and (army:hasTypeEventRules(defID, nil, "damaged") or army:hasTypeEventRules(defID, nil, "thresholdHP")) then
--     if debug then debugger("widget:UnitDamaged 2. Going to damaged-getHealth") end
--     army:getOrCreateUnit(unitID, defID):getHealth() -- automatically alerts for damaged and thresholdHP
--   end
-- end

-- Disregard unless this is fixed in BAR. Would go above.
  -- if attackerUnitID and attackerDefID and attackerTeamID then -- Can't because BAR always nil for these in UnitDamaged
  --   army = teamsManager:getArmyManager(attackerTeamID)
  --   if army and army:hasTypeEventRules(defID, nil, "attacks") then
  --     local aUnit = army:getOrCreateUnit(unitID, defID)
  --     if aUnit then
  --       if true then debugger("widget:UnitDamaged 3. Attacker found. Going to getTypesRulesForEvent") end
  --       local attacksEvent = aUnit:getTypesRulesForEvent("attacks", true, true)
  --       if attacksEvent then
  --         if true then debugger("widget:UnitDamaged 4. Has attacksEvent. Going to addUnitToAlertQueue") end
  --         teamsManager:addUnitToAlertQueue(aUnit, attacksEvent)
  --       end
  --     end
  --   end
  -- end

-- doesn't run when spectating
function widget:CommandsChanged() -- Called when the command descriptions changed, e.g. when selecting or deselecting a unit. Because widget:UnitIdle doesn't happen when the player removes the last unit in the factory queue
  if isSpectator then return
  elseif debug then debugger("widget:CommandsChanged 1. Called when the command descriptions changed, e.g. when selecting or deselecting a unit.") end
	if type(teamsManager.myArmyManager.factories) == "table" then
    for unitID, unit in pairs(teamsManager.myArmyManager.factories) do
      if debug then debugger("CommandsChanged 2. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", isFactory=" .. tostring(unit.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
      if unit:getIdle() == true then -- automatically adds unit to idle alert queue if it applies
        if debug then debugger("widget:CommandsChanged 3. Factory added to parent[idle] table. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID)) end
      end
    end
  end
end

function widget:UnitLoaded(unitID, defID, teamID, transportID, transportTeamID) -- Called when a unit is loaded by a transport.
  if not teamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then debugger("UnitLoaded 0. INVALID input. Returning nil unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then debugger("widget:UnitLoaded 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = teamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    local aUnit = anArmy:getOrCreateUnit(unitID, defID)
    if aUnit then
      local loadedEvent = aUnit:getTypesRulesForEvent("loaded", true, true)
      if loadedEvent then
        teamsManager:addUnitToAlertQueue(aUnit, loadedEvent)
      end
    end
  end
end

function widget:StockpileChanged(unitID, defID, teamID, weaponNum, oldCount, newCount) -- Called when a units stockpile of weapons increases or decreases. See stockpile.
  if not teamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then debugger("StockpileChanged 0. INVALID input. Returning nil unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then debugger("widget:StockpileChanged 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = teamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    local aUnit = anArmy:getOrCreateUnit(unitID, defID)
    if aUnit then
      local loadedEvent = aUnit:getTypesRulesForEvent("stockpile", true, true)
      if loadedEvent then
        teamsManager:addUnitToAlertQueue(aUnit, loadedEvent)
      end
    end
  end
end

function widget:GameFrame(frame)
  if warnFrame == 1 then -- with 30 updateInterval, run roughlys every half second
    checkPersistentEvents()
    if alertQueue:getSize() > 0 then
      teamsManager:alert()
    end
  end
  warnFrame = (warnFrame + 1) % updateInterval
end

function widget:PlayerChanged(playerID)
  myTeamID = Spring.GetMyTeamID()
	isSpectator = Spring.GetSpectatingState()
end

function widget:Initialize()
	Spring.Echo("Starting " .. widgetName)
  widget:PlayerChanged()
	if true then debugger("widget:Initialize 1. isSpectator="..tostring(isSpectator)) end --  .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)
	if not makeRelTeamDefsRules() then
    debugger("makeRelTeamDefsRules() returned FALSE. Fix trackMyTypesRules, trackAllyTypesRules, trackEnemyTypesRules tables.")
    widgetHandler:RemoveWidget()
  end
  teamsManager:makeAllArmies() -- Build all teams/armies
  -- debug = true
  return
  --   -- TODO: Maybe. Load All Units if replay or starting mid-game ########## 
end

function widget:Shutdown()
	Spring.Echo(widgetName .. " widget disabled")
end
-- TODO: make separate lua files. VFS: https://springrts.com/wiki/Lua_VFS
-- TODO: make so only widgets needed are imported
-- When maxAlerts met using sharedAlerts, remove rule to keep new units being loaded, but don't worry about the existing units... until much later
-- For spectator: could make sharedAlerts=all/team so can have shared team alerts...