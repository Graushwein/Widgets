local widgetName = "Test"
function widget:GetInfo()
	return {
		name = widgetName,
		desc = "Test",
		author = "Graushwein",
		date = "May 29, 2025",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

-- VFS: https://springrts.com/wiki/Lua_VFS

-- ################################################# Config variables starts here #################################################

-- NOTHING IN THIS SECTION IS IMPLEMENTED YET

local soundVolume = 1.0 -- Set the volume between 0.0 and 1.0. NOT USED
-- What type of notifications has to be send, false means it wont notify for that type of building/unit

-- FIXME: needs to be incorporated
-- Discord Tomruler,  (EVENT_BINDS, EVENT_ENABLED, load_binds(), queuedCommands, do_metrics()) at https://github.com/Tomruler/beyondallbuttplug/blob/main/beyond_all_buttplug.lua
-- Has some economy stuff too
-- also https://github.com/tumeden/BAR-Widgets/blob/main/unit_SCV.lua

local idleCommanderAlert = true
local idleConAlert = true
local idleFactoryAlert = true
local idleRezAlert = true	-- make false if you don't want to be alerted to idle rezbots
-- NOTE: NEEDS TESTING - Monitoring Health means this widget will be called whenever ANY unit is damaged, so it could cause performance issues
-- TODO: How to make this widget only have the widget run if monitoring is enabled? MAYBE widget only brought in from other file? UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)


-- Not implemented yet
-- if 2 or more type of notifications has to send, then this many seconds will be there between those notifications
local minSecsBetweenNotifications = 3 -- Second

local trackAllMyUnitsRules = {} -- or use something like {hp, coords, ,damaged, destroyed} -- What else?
local trackAllEnemyUnitsRules = {} -- 
local trackAllAlliedUnitsRules = {} -- 

-- Newly added event types will need to be added here
local validEvents = {"created","finished","idle","damaged","taken","destroyed","los","enteredAir","stockpile","thresholdHP"}
local validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "alertDelay", "maxQueueTime", "alertSound", "mark", "ping","messageTo","messageTxt", "threshMinPerc", "threshMaxPerc"}
-- most validEventRules are used in getEventRulesNotifyVars(typeEventRulesTbl, unitObj)
-- mark = only you see. ping = ALL ALLIES see it. Be careful with ping
-- Priority from 0-99999, decimals okay, default 5. 0 ignores minSecsBetweenNotifications and will notify immediately
-- When a unit has 2+ types, both with rules for the same event (like idle), the event with the highest priority is always used, (TODO: unless the other is already queued). If all have same priority, probably randomly chosen

-- TODO: create rules for below types in makeRelTeamDefsRules()  #####################
-- TODO: Maybe make threshold a rule instead of event?

-- How to add new unit unitTypes: (names not validated)
  -- Copy/paste a type line below, like "local myMexRules...", change to "exampleRules" varName to be unique and configure the rules using the many examples
  -- Below in one of the 3 appropriate "track[team]TypesRules", like trackMyTypesRules, add another line like, "example = exampleRules"
  -- In makeRelTeamDefsRules(), add the appropriate "if" statement for the units and use addToRelTeamDefsRules(unitDefID, "example")

-- How to add new events:
  -- Add it to validEvents above, like "exampleEvent". Case-sensitive everywhere
  -- Use it in function/widget, like "widget:UnitIdle()", and do anArmy:hasTypeEventRules(defID, nil, "exampleEvent"), then tell it what to do next, like addUnitToAlertQueue()

  -- How to add new rules:
    -- Add it to validEventRules above, like "exampleRule". Case-sensitive everywhere
    -- Add it to the return values at the end of getEventRulesNotifyVars() following the examples on that line
    -- Add its validation rules in validTypeEventRulesTbls() following the examples
    -- TIP: Most rules are processed in the methods that have "alert" and "queue" in their names

-- multiple event rules allowed, but must be unique. Example: myCommanderRules can'the have 2 "idle", but can have all events: idle, damaged, and finished...
-- units can have multiple types, like making the commander also have the constructor type. makeRelTeamDefsRules() is used to do that.
-- {unitType = {event = {rules}}}
local myCommanderRules = {idle = {priority=2, maxAlerts=0, reAlertSec=5, alertDelay=.1, mark="Commander Idle", alertSound="sounds/commands/cmd-selfd.wav"}, damaged = {maxAlerts=0, reAlertSec=30, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, thresholdHP = {maxAlerts=0, reAlertSec=60, mark=nil, alertSound="sounds/commands/cmd-selfd.wav", threshMinPerc=.5, priority=0} } -- idle = {maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"},  will sound alert when Commander idle/15 secs, (re)damaged once per 30 seconds (unlimited), and when damage causes HP to be under 50%
local myConstructorRules = {idle = {sharedAlerts=true, maxAlerts=0, reAlertSec=10, alertDelay=.1, mark="Constructor Idle", alertSound="sounds/commands/cmd-selfd.wav"}, destroyed = {maxAlerts=0, reAlertSec=1, mark="Con Lost", alertSound=nil}}
local myFactoryRules = {idle = {maxAlerts=0, reAlertSec=15, alertDelay=.1, mark="Factory Idle", alertSound="sounds/commands/cmd-selfd.wav"}, finished = {maxAlerts=0, reAlertSec=0, mark=nil, alertSound=nil}}
local myRezBotRules = {idle = {sharedAlerts=true, maxAlerts=0, reAlertSec=15, alertDelay=.1, mark="RezBot Idle", messageTo="me",messageTxt="messageTxt"}, destroyed = {sharedAlerts=true, maxAlerts=0, reAlertSec=100, mark="Rezbot Lost", alertSound=nil}}
local myMexRules = {destroyed = {maxAlerts=0, reAlertSec=2, mark="Mex Lost", alertSound=nil}, taken = {maxAlerts=0, reAlertSec=1, mark="Mex Taken", alertSound=nil}}
local myEnergyGenRules = {finished = {maxAlerts=0, reAlertSec=20, mark=nil, alertSound=nil}, destroyed = {maxAlerts=0, reAlertSec=1, mark="Generator Lost", alertSound=nil}} -- reAlertSec only used if mark/sound wanted. Saved so custom code can do something with the information.
local myRadarRules = {finished = {maxAlerts=0, reAlertSec=1, mark="Radar Built", alertSound="sounds/commands/cmd-selfd.wav"}, destroyed = {maxAlerts=0, reAlertSec=1, mark="Radar Lost", alertSound="sounds/commands/cmd-selfd.wav"}}
-- local myRules = 
-- To mitigate performance hits from "UnitDamaged()", could have a list of types/groups to check once every X frames/seconds
local trackMyTypesRules = {
	commander = myCommanderRules,
  constructor = myConstructorRules,
  factory = myFactoryRules,
  rezBot = myRezBotRules,
	mex = myMexRules,
	energyGen = myEnergyGenRules,
	radar = myRadarRules
}
local allyCommanderRules = {} -- Won't track unless rules added to it
local allyConstructorRules = {}
local allyFactoryRules = {}
local allyFactoryT2Rules = {finished = {maxAlerts=1, reAlertSec=15, mark="T2 Ally", alertSound=nil, messageTo="allies",messageTxt="T2 Con Plz!"}} -- So you know to badger them for a T2 constructor ;)
local allyRezBotRules = {}
local allyMexRules = {destroyed = {maxAlerts=0, reAlertSec=1, mark="Ally Mex Lost", alertSound=nil}}
local allyEnergyGenRules = {}
local allyRadarRules = {}
-- local allyRules = 
local trackAllyTypesRules = {
  commander = allyCommanderRules,
  constructor = allyConstructorRules,
  factory = allyFactoryRules,
  factoryT2 = allyFactoryT2Rules,
  rezBot = allyRezBotRules,
	mex = allyMexRules,
	energyGen = allyEnergyGenRules,
	radar = allyRadarRules
}
local enemyCommanderRules = {los = {maxAlerts=0, reAlertSec=30, ping="Commander", alertSound=nil, priority=0, messageTo="all",messageTxt="Get em!"} } -- will mark "Commander" at location when (re)enters LoS, once per 30 seconds (unlimited)
local enemyConstructorRules = {}
local enemyFactoryRules = {}
local enemyFactoryT2Rules = {los = {maxAlerts=1, reAlertSec=15, mark="T2 enemy", alertSound=nil}} -- Hope you're ready!
local enemyRezBotRules = {}
local enemyMexRules = {destroyed = {maxAlerts=0, reAlertSec=1, mark=nil, alertSound=nil}} -- No alert means it only destroyed enemy mex will be tracked. To have it track alive mex, use "los"
local enemyEnergyGenRules = {}
local enemyRadarRules = {}
local enemyUnitsT2Rules = {}
local enemyUnitsT3Rules = {}
local enemyUnitsAirRules = {}
local enemyUnitsAirT2Rules = {}
local enemyNukeRules = {}
local enemyAntiNukeRules = {}
-- local enemyRules = {}
local trackEnemyTypesRules = {
	commander = enemyCommanderRules,
  constructor = enemyConstructorRules,
  factory = enemyFactoryRules,
  factoryT2 = enemyFactoryT2Rules,
  rezBot = enemyRezBotRules,
	mex = enemyMexRules,
	energyGen = enemyEnergyGenRules,
	radar = enemyRadarRules,
	unitsT2 = enemyUnitsT2Rules,
	unitsT3 = enemyUnitsT3Rules,
	air = enemyUnitsAirRules,
	airT2 = enemyUnitsAirT2Rules,
	nuke = enemyNukeRules,
	antinuke = enemyAntiNukeRules
}
local trackSpectatorTypesRules = {}
-- , messageTo="spectators",messageTxt="messageTxt"
-- UnitEnteredAir() --> "unitID, unitDefID, teamID" for commanders
-- UnitCreated() --> "unitID, unitDefID, teamID, builderID" for tracking T2/T3, (anti)nukes, LOLCannon ...
-- StockpileChanged() --> "unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount" for nuke


-- the above helps populate below when widget started
local relevantMyUnitDefsRules = {} -- unitDefID (key), typeArray {commander,builder} Types match to types above --  -- {defID = {type = {event = {rules}}}}
local relevantAllyUnitDefsRules = {} -- unitDefs wanted in ally armyManagers
local relevantEnemyUnitDefsRules = {} -- unitDefs wanted in enemy armyManagers
local relevantSpectatorUnitDefs = {}

--[[ For Reference, Discord Tomruler, at https://github.com/Tomruler/beyondallbuttplug/blob/main/beyond_all_buttplug.lua
    -- if EVENT_ENABLED["ON_COM_DAMAGED"] then
    --   -- TODO: Rebind commander if they died and were revived/gifted.
    --   bab_event_CurrentComHitpoints = bab_eventf_calc_com_hitpoints()
    --   if bab_event_CurrentComHitpoints > bab_event_OldComHitpoints then
    --       bab_event_OldComHitpoints = bab_event_CurrentComHitpoints
    --   end
    -- end
    -- if EVENT_ENABLED["ON_LOSE_UNIT"] and bab_event_CurrentLosses > bab_event_OldLosses then
    --   insert_bound_command(frame, "ON_LOSE_UNIT", bab_event_CurrentLosses - bab_event_OldLosses)
    --   Spring.Echo("Event: ON_LOSE_UNIT triggered on frame: "..frame)
    --   bab_event_OldLosses = bab_event_CurrentLosses
    -- end

    -- Aggro examples or code to work/interface with?
    -- Build order reminder list https://gist.github.com/Gamepro03/7fbfb0cea578a162fb5d4d580dbf4a8b
    -- Area Influence https://github.com/DrChinny/BAR-Widgets/blob/main/Influence_Version_2.lua
    -- Interesting - Player Unit Types Display (see how many of each unit your enemies have) https://gist.github.com/salinecitrine/8086e13cf85edc1f2a2f98b232a981e4
    -- 
    -- Could part of this be something like a "New-Modder Friendly Framework"?
]]



-- ################################################## Config variables ends here ##################################################
-- DONT change code below this if you are not sure what you are doing
local debug = false
local spGetUnitDefID= Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetCommandQueue     = Spring.GetCommandQueue
local spGetFactoryCommands = Spring.GetFactoryCommands -- TODO: Change to use Spring.GetFullBuildQueue(unitId) ? #########
local spGetUnitHealth = Spring.GetUnitHealth

local UpdateInterval = 30 -- 30 runs once per second, 1=30/sec, 60=1/2sec
local TestSound = 'sounds/commands/cmd-selfd.wav'

table.insert(validEventRules,"lastNotify") -- add system only rules
table.insert(validEventRules,"alertCount") -- add system only rules

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local isSpectator
local warnFrame = 0

local BuilderUnitDefIDs = {} -- unitDefID (key), builderType [1=com, 2=con, 3=factory, 4=rezbot]
-- local BuilderUnits = {} -- Use ArmyManager unitID (key), unitDefID -- Incorporated into ArmyManager
local FactoryDefIDs = {}

local idlingUnits = {}
local idlingUnitCount = 0

local function debugger(...)
    Spring.Echo(...)
end

local function tableToString(tbl, indent)
  if (type(tbl) == "table" and tbl.isPrototype) or (type(indent) == "table" and indent.isPrototype) then
    return "DON'T SEND PROTOs TO tableToString FUNCTION. IT WILL CRASH!"
  end
  indent = indent or 4
  local str = ""
  -- Add indentation for nested tables
  str = str .. string.rep(".", indent) .. "{\n"
  -- Iterate through table elements
  if type(tbl) ~= "table" then
    str = str .. type(tbl) .. "=" .. tostring(tbl) -- If not a table, return its string representation
  else
    for k, v in pairs(tbl) do
      if (type(k) == "table" and k.isPrototype) or (type(v) == "table" and v.isPrototype) then
        return "DON'T SEND PROTOs TO tableToString FUNCTION. IT WILL CRASH!"
      end
      str = str .. string.rep(".", indent + 1)
      -- Format key
      if type(k) == "string" then
        str = str .. k .. " = "
      else
        str = str .. "[" .. tostring(k) .. "] = "
      end
      -- Handle different value types
      if type(v) == "table" then
        -- Recursively call for nested tables
        str = str .. tableToString(v, indent + 2) .. ",\n"
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

local function concatenateKeyValuePairs(table, keySep, sep)
  keySep = keySep or "="
  sep = sep or ", "
  local result = ""
  for k, v in pairs(table) do
    Spring.Echo("conc1: k=" .. tostring(k) .. ", v=" .. tostring(v))
    result = result .. tostring(k) .. keySep .. tostring(v) .. ", "
  end
  result = string.sub(result, 1, -3)  -- Remove the trailing ", "
  Spring.Echo("conc2 result: " .. result)
  return result
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
-- validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "maxQueueTime", "alertSound", "mark", "ping", "threshMinPerc", "threshMaxPerc","messageTo","messageTxt"} -- if sharedAlerts it also contains: alertCount, lastNotify. ELSE these are stored in the unit with unitObj.lastAlerts[unitType][event] = {lastNotify=num,alertCount=num} 
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
-- type(nil) would return "nil", and type(false) would return "boolean". If there is need to differentiate

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
teamsManager.myArmyManager = nil  -- will hold easy quick reference to main player's armyManager
teamsManager.lastUpdate = nil -- TODO: Can use Spring.GetGameSeconds ( ), OR Spring.GetTimer ( )/Spring.DiffTimers ( timer cur, timer ago [, bool inMilliseconds ] ) 
teamsManager.debug = false

local pArmyManager = protoObject:clone()

pArmyManager.units = {} -- units key/value. Added with armyManager[unitID] = [unitObject]. Objects in multiple arrays/tables are the same object (memory efficient)
pArmyManager.unitsLost = {} -- key/value unitsLost[unitID] = [unitObject] of unit objects destroyed, taken, or given
pArmyManager.unitsReceived = {} -- key/value unitsReceived[unitID] = [unitObject] of unit objects given by an ally. Possibly used for notifications, but should remove after notified
pArmyManager.defTypesEventsRules = {} -- relevantMyUnitDefsRules is {defID = {type = {event = {rules}}}}
-- pArmyManager.[type] -- REMINDER. All units a type automatically add themselves to the type-named table in their parent army unitID = unitObject for easy referencing

pArmyManager.playerIDsNames = {} -- key/value of playerIDsNames[playerID] = [playerName], usually only one, that can control the army's units. TODO: Could hold Player objects
pArmyManager.isMyTeam = nil
pArmyManager.allianceID = nil
pArmyManager.teamID = nil -- teamID of the armyManager 
pArmyManager.lastUpdate = nil -- Game seconds last update time of the armyManager (NOT IMPLEMENTED YET)
pArmyManager.isAI = nil
pArmyManager.isGaia = nil
pArmyManager.debug = false  -- ############################ArmyManager debug mode enable################################################

-- TODO: remove old manual type logic below after verifying the new methods
pArmyManager.builders = {} -- builders key/value. Added with armyManager.Builders[unitID] = [unitObject]
pArmyManager.commanders = {} -- commanders key/value. Added with armyManager.Commanders[unitID] = [unitObject]
pArmyManager.constructors = {} -- constructors key/value. Added with armyManager.Constructors[unitID] = [unitObject]
pArmyManager.factories = {} -- factories key/value. Added with armyManager.Factories[unitID] = [unitObject]
pArmyManager.rezbots = {} -- rezbots key/value. Added with armyManager.rezbots[unitID] = [unitObject]


local pUnit = protoObject:clone()

pUnit.parent = nil -- to get the unit's armyManager
pUnit.ID = nil -- unitID
pUnit.defID = nil -- unitDefID
-- unitObj.parent.teamID -- REMINDER: This is how to get the unit's teamID 
pUnit.isIdle = false -- Use the get/set-methods instead.
pUnit.lastSetIdle = nil -- uses GetGameFrame()
pUnit.created = nil -- gameSecs
pUnit.coords = nil
pUnit.lost = nil -- gameSecs
pUnit.isLost = false
pUnit.lastUpdate = nil -- Game seconds last update time of the unit (NOT used YET)
pUnit.health = nil -- health of the unit (NOT IMPLEMENTED YET)
pUnit.debug = false  -- ############################Prototype Unit debug mode enable################################################


pUnit.isBuilder = nil -- is this unit a builder?
pUnit.isCommander = nil -- is this unit a commander?
pUnit.isConstructor = nil -- is this unit a constructor?
pUnit.isFactory = nil -- is this unit a factory?
pUnit.isRezBot = nil -- is this unit a rezbot?



-- Spring.GetPlayerList ( [ number teamID = -1 | bool onlyActive = false [, number teamID | bool onlyActive ] ] )
-- return: nil | { [1] = number playerID, etc... } -- From 104.0 onwards spectators will be ignored if a valid (>=0) teamID is given.

-- GetTeamList ( [ number allyTeamID = -1 ] ) return: nil | { [1] = number teamID, etc... }

-- player number 0 (team 0, allyteam 0)

-- FixedAllies ( ) return: nil | bool enabled. Means teams can change
-- TODO: Add way for armies to change alliances #######################################################

-- TODO: Add input params


-- ################################################## Basic Core TeamsManager methods start here #################################################
function teamsManager:makeAllArmies()  -- Will only run if no armies exist. Returns teamsManager.armies
  if debug or self.debug then debugger("makeAllArmies 1. numArmies=".. #teamsManager.armies) end
  -- if #teamsManager.armies == 0 then
  --   debugger("makeAllArmies 1. numArmies=".. #teamsManager.armies)
  --   return nil
  -- end
  local gaiaTeamID = Spring.GetGaiaTeamID()  -- Game's Gaia (environment) compID, but not considered an AI
  local tmpTxt = "teamID/AllyID check\n"
  for _,teamID1 in pairs(Spring.GetTeamList()) do -- Iterate through all compIDs (teamIDs)
    local teamID2,leaderNum,isDead,isAiTeam,strSide,allianceID = Spring.GetTeamInfo(teamID1)
    if teamID1 == gaiaTeamID then -- Game's Gaia (environment) actor 
      if debug or self.debug then tmpTxt = tmpTxt .. "Gaia Env is on teamID " .. teamID1 .. " in allianceID " .. allianceID .. ", isDead=" .. tostring(isDead) .. "\n" end
      if debug or self.debug then debugger("makeAllArmies 2. Adding Gaia.") end
      self:newArmyManager(gaiaTeamID, allianceID)
      -- aTeam.isGaia = true
    elseif isAiTeam then
      if debug or self.debug then tmpTxt = tmpTxt .. "AI is on teamID " .. teamID1 .. " in allianceID " .. allianceID .. ", isDead=" .. tostring(isDead) .. "\n" end
      if debug or self.debug then debugger("makeAllArmies 3. Adding AI.") end
      self:newArmyManager(teamID1, allianceID)
      -- aTeam.isAI = true
    else -- compID is Human
      for _,playerID in pairs(Spring.GetPlayerList(teamID1)) do -- Get all players on the compID
        local playerName, isActive, isSpectatorTmp, teamIDTmp, allyTeamIDTmp, pingTime, cpuUsage, country, rank, customPlayerKeys = Spring.GetPlayerInfo(teamID1)
        if teamIDTmp == teamID1 then
          local tmpPlayerText = "playerID " .. playerID
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
          if debug or self.debug then tmpPlayerText = tmpPlayerText .. " with teamID " .. teamIDTmp .. " in allianceID " .. allyTeamIDTmp .. ", isDead=" .. tostring(isDead) .. "\n" end
          if debug or self.debug then tmpTxt = tmpTxt .. tmpPlayerText end
        end
      end
    end
  end
  if debug or self.debug then debugger(tmpTxt) end
end

-- WARNING 1: If playerID not used, will assume is an AI
-- WARNING 2: Possible to add Spectators because it doesn't check
function teamsManager:newArmyManager(teamID, allianceID, playerID, playerName) -- Returns newArmyManager child object. playerID optional. Creates the requested new army with the basic IDs. Will return nil if already exists because a different method should be used.
  if debug or self.debug then debugger("newArmyManager 1. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
  -- can't validate playerID here because AIs don't have one (nil)
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID, true, allianceID, nil, nil) then debugger("newArmyManager 2. INVALID input. Returning nil.") return nil end
  local armyManager = self:getArmyManager(teamID)
  -- if an armyManager with teamID already exists, return nil
  if type(armyManager) ~= "nil" then
    debugger("newArmyManager 3. ERROR ArmyManager ALREADY EXISTS. Returning nil. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID))
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
  armyManager.parent = self -- link to teamsManager that holds this armyManager
  self.armies[teamID] = armyManager
  if debug or self.debug then debugger("newArmyManager 5. New Army created. armyManager Type=" .. type(armyManager) .. ", teamID=" .. tostring(armyManager.teamID) .. ", allianceID=" .. tostring(armyManager.allianceID) .. ", self.armies[teamID].teamID=" .. tostring(self.armies[teamID].teamID)) end
  if teamID == myTeamID then
    armyManager.isMyTeam = true
    self.myArmyManager = armyManager
    armyManager.defTypesEventsRules = relevantMyUnitDefsRules
  elseif Spring.AreTeamsAllied(teamID, myTeamID) then
    armyManager.defTypesEventsRules = relevantAllyUnitDefsRules
  else
    armyManager.defTypesEventsRules = relevantEnemyUnitDefsRules
  end
  for aDef,aTypesTbl in pairs(armyManager.defTypesEventsRules) do
    for aType, eventsTbl in pairs(aTypesTbl) do
      for event,rulesTbl in pairs(eventsTbl) do
        if rulesTbl["sharedAlerts"] then
          local baseObj = armyManager
          if type(baseObj["lastAlerts"]) ~= "table" then
            if debug then debugger("newArmyManager 6. lastAlerts="..type(baseObj["lastAlerts"])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
            baseObj["lastAlerts"] = {}
          end
          local lastAlerts = baseObj["lastAlerts"]
          if type(lastAlerts[aType]) ~= "table" then
            if debug then debugger("newArmyManager 7. unitOrArmyObj[unitType]="..type(lastAlerts[aType])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
            lastAlerts[aType] = {}
          end
          if type(lastAlerts[aType][event]) ~= "table" then
            if debug then debugger("newArmyManager 8. unitOrArmyObj[unitType][event]="..type(lastAlerts[aType][event])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event)) end
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

  if type(playerID) == "nil" then
    if teamID == Spring.GetGaiaTeamID() then
      armyManager.isGaia = true
      armyManager.lastUpdate = gameSecs -- Game seconds last update time of the armyManager
      if debug or self.debug then debugger("newArmyManager 6. Gaia created. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", isGaia=" .. tostring(armyManager.isGaia)) end
    else
      armyManager.isAI = true
      armyManager.lastUpdate = gameSecs -- Game seconds last update time of the armyManager
      if debug or self.debug then debugger("newArmyManager 7. AI created. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", isAI=" .. tostring(armyManager.isAI)) end
    end
    return armyManager
  end
  armyManager:addPlayer(playerID, playerName)
  if debug or self.debug then debugger("newArmyManager 8. Player created. armyManager Type=" .. type(armyManager) .. ", teamID=" .. tostring(armyManager.teamID) .. ", allianceID=" .. tostring(armyManager.allianceID) .. ", playerName=" .. tostring(armyManager.playerIDsNames[playerID])) end
  return armyManager
end

function teamsManager:getArmyManager(teamID) -- Returns nexisting ArmyManager child object or nil if doesn't exist
  if debug or self.debug then debugger("getArmyManager 1. teamID=" .. tostring(teamID)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID, nil, nil, nil, nil) then debugger("getArmyManager 2. INVALID input. Returning nil.") return nil end
  local anArmy = self.armies[teamID]
  if type(anArmy) == "nil" then
    if debug or self.debug then debugger("getArmyManager 3. Returning (Nil because teamID=" .. tostring(teamID) .. " not found) anArmy Type=" .. type(anArmy)) end -- self.armies[teamID].teamID
    return nil
  end
  if debug or self.debug then debugger("getArmyManager 4. Found and returning anArmy Type=" .. type(anArmy) .. ", teamID=" .. tostring(self.armies[teamID].teamID)) end -- self.armies[teamID].teamID
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
function teamsManager:getUnitsIfInitialized(unitID) -- This should only be used before creating an enemy unit, because they can be given while outside los.
  if debug or self.debug then debugger("teamsManager:getUnitsIfInitialized 1. unitID=" .. tostring(unitID)) end
  if not teamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then debugger("teamsManager:getUnitsIfInitialized 2. INVALID input. Returning nil.") return nil end
  local unitsFound = {}
  local aUnit
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
    return nil -- or raise an error, or create objects/functions to track multiple team armies
  end
  return armyManager:createUnit(unitID, defID)
end

function teamsManager:isAllied(teamID1, teamID2)  -- If teamID2 not given, assumes it is myTeamID 
  if debug or self.debug then debugger("isAllied 1. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID1, nil, nil, nil, nil) then debugger("isAllied 2. INVALID input. Returning nil.") return nil end
  local armyManager1 = self:getArmyManager(teamID1)
  if not armyManager1 then
    debugger("isAllied 3. ERROR. Army1 Obj not returned. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2))
    return nil
  end
  local armyManager2
  if type(teamID2) ~= "number" then
    teamID2 = self.myArmyManager.teamID
    armyManager2 = self.myArmyManager
    if debug or self.debug then debugger("isAllied 4. Using myTeamID for T2. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  else
    armyManager2 = self:getArmyManager(teamID2)
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

-- TODO: TEST
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
  aUnit:setLost(false)
  aUnit.parent = newTeamArmy
  newTeamArmy.units[unitID] = aUnit -- set here because it is only set in createUnit(), and setLost() removed from other army
  aUnit:setTypes(aUnit.defID)
  newTeamArmy.unitsReceived[aUnit.ID] = aUnit
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
  if debug then debugger("validIDs 1. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID)) end
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
  Spring.MarkerAddPoint( x, y, z, pointerText, localOnly) -- localOnly = mark
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
  if toWhom == "me" then
    Spring.SendMessageToPlayer(myPlayerID, message) -- "me" myPlayerID
  elseif toWhom == "all" then
    Spring.SendMessage(message) -- "all"
  elseif toWhom == "allies" then
    Spring.SendMessageToAllyTeam(teamsManager.myArmyManager.allianceID, message) -- "allies" teamsManager.myArmyManager.allianceID
  elseif toWhom == "spectators" then
    Spring.SendMessageToSpectators(message) -- "spectators"
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
  if type(alertVarsTbl["alertSound"]) == "string" then -- play audio
    if debug or self.debug then debugger("alert 5. About to play alertSound. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    alertSound(alertVarsTbl["alertSound"])
    success = true
  end
  if type(alertVarsTbl["messageTxt"]) == "string" and type(alertVarsTbl["messageTo"]) == "string" then
    if debug or self.debug then debugger("alert 6. Going to alertMessage. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    alertMessage(alertVarsTbl["messageTxt"], alertVarsTbl["messageTo"])
    success = true
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
      if pointerText == true then
        pointerText = ""
      end
      local x, y, z = unitObj:getUnitPosition()
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
    end
    alertBaseObj = alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]
    local gameSec = Spring.GetGameSeconds()
    alertBaseObj["lastNotify"] = gameSec
    alertBaseObj["alertCount"] = (alertBaseObj["alertCount"] + 1)
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
  local alertVarsTbl = self:getEventRulesNotifyVars(unitObj, typeEventRulesTbl)
  if type(alertVarsTbl) ~= "table" then -- all is verified by getEventRulesNotifyVars()
    debugger("addUnitToAlertQueue 3. ERROR. Returning nil. getEventRulesNotifyVars() returned nil. alertVarsTbl=" .. type(alertVarsTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if alertVarsTbl["sharedAlerts"] then
    alertBaseObj = unitObj.parent
  end
  alertBaseObj = alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]
  local gameSecs = Spring.GetGameSeconds()
  if ((type(alertVarsTbl["mark"]) ~= "string") and (type(alertVarsTbl["ping"]) ~= "string") and type(alertVarsTbl["alertSound"]) ~= "string") or alertBaseObj["isQueued"] or gameSecs < alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"] or (alertVarsTbl["maxAlerts"] ~= 0 and alertBaseObj["alertCount"] >= alertVarsTbl["maxAlerts"]) then
    if debug then debugger("addUnitToAlertQueue 4. Too soon or no alert rules. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(alertVarsTbl["maxAlerts"])..", mark="..tostring(alertVarsTbl["mark"])..", ping="..tostring(alertVarsTbl["ping"])..", alertSound="..tostring(alertVarsTbl["alertSound"]) .. ", tableToString=" .. tableToString(alertVarsTbl)) end
    return false
  end
  if alertVarsTbl["priority"] == 0 then
    if debug then debugger("addUnitToAlertQueue 4. SUCCESS. Priority 0 goes straight to alert(). priority=" .. tostring(alertVarsTbl["priority"])) end
    self:alert(unitObj, alertVarsTbl)
    return true
  end
  if not alertQueue:isEmpty() then -- ensure not adding duplicates and manage situations where an alert should be removed and/or replaced
    -- If already in queue for same event, vars used: teamID, unitType, event, sharedAlerts, priority, maxQueueTime, threshMinPerc, threshMaxPerc
    if debug then debugger("addUnitToAlertQueue 5. sharedAlerts=" .. tostring(alertVarsTbl["sharedAlerts"]) .. ". Starting checks to decide if this alert should be queued and/or others removed/replaced. alertVarsTbl.sharedAlerts=" .. tostring(alertVarsTbl["sharedAlerts"])) end
    local alertMatchesTbls
    if alertVarsTbl["sharedAlerts"] then
      alertMatchesTbls = self:getQueuedEvents(nil,alertVarsTbl.teamID,alertVarsTbl["unitType"],alertVarsTbl["event"],nil,nil)
      if alertMatchesTbls then -- if shared, and same type/event, then don't add the new one
        if debug then debugger("addUnitToAlertQueue 6. ERROR. Rejected because same shared type/event was present. Returning nil. alertVarsTbl=" .. tableToString(alertVarsTbl)) end
        return nil
      end
      if debug then debugger("addUnitToAlertQueue 7. SUCCESS. Added sharedAlert to queue.") end
      alertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
      return true
    else
      alertMatchesTbls = self:getQueuedEvents(unitObj,alertVarsTbl.teamID,nil,alertVarsTbl["event"],nil, nil) -- alertVarsTbl["sharedAlerts"]
    end
    if alertMatchesTbls then
      local useNewAlert = true
      local bestPriority = alertVarsTbl["priority"]
      local removeHeapNums = {}
      for heapNum,value in ipairs(alertMatchesTbls) do -- {heapNum = {value = unitObj, alertRulesTbl = {[rule] = [value]}, priority = priority, queuedTime = Spring.GetGameSeconds()}}
        if debug then debugger("addUnitToAlertQueue TEST. alertQueue.size="..tostring(value["priority"])) end -- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
        if bestPriority < value["priority"] then -- Remove duplicate with worse priority -- self.heap[heapNum].value
          if debug then debugger("addUnitToAlertQueue 8. Will need to remove heap="..tostring(heapNum)) end -- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
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
          end
          unitOrArmyObj["lastAlerts"][removeObj.alertRulesTbl["unitType"]][removeObj.alertRulesTbl["event"]]["isQueued"] = false
        end
      end
      if useNewAlert and bestPriority == alertVarsTbl["priority"] then
        if debug then debugger("addUnitToAlertQueue 11. Adding requested alert after removing one with worse priority.") end
        alertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
        return true
      end
      if debug then debugger("addUnitToAlertQueue 12. alertQueue already has same or better, no need to add the new one.") end
      return false
    end
  end
  if debug then debugger("addUnitToAlertQueue 13. SUCCESS. There were no matches. Adding to queue.") end
  alertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
  return true
end

-- {defID = {type = {event = {rules}}}}
-- components: {type = {event = {rules}
-- Returns single-level key/value table with everything needed for addUnitToAlertQueue
function teamsManager:getEventRulesNotifyVars(unitObj,typeEventRulesTbl ) -- validates and returns alertVarsTbl key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
  if debug then debugger("getEventRulesNotifyVars 1. unitObj=" .. type(unitObj) .. ", typeEventRulesTbl=" .. type(typeEventRulesTbl)) end
  -- local isValidTbl,typeCount,eventCount,ruleCount = self:validTypeEventRulesTbls(typeEventRulesTbl)
  local typeCount = 0; local eventCount = 0; local unitType; local event; local rulesTbl
  for aType, eventsTbl in pairs(typeEventRulesTbl) do
    typeCount = typeCount + 1
    unitType = aType
    for anEvent, aRulesTbl in pairs(eventsTbl) do
      eventCount = eventCount + 1
      event = anEvent
      rulesTbl = aRulesTbl
    end
  end
  -- if isValidTbl == false or type(unitObj) ~= "table" or unitObj.defID == nil then
  --   debugger("getEventRulesNotifyVars 2. ERROR, returning nil. NOT unitObj or typeEventRulesTbl=" .. type(typeEventRulesTbl) .. ", unitObj=" .. type(unitObj))
  --   return nil
  -- else
    if typeCount ~= 1 or eventCount ~= 1 then -- if not isValidTbl or typeCount ~= 1 or eventCount ~= 1 then
      debugger("getEventRulesNotifyVars 3. ERROR. Returning nil. Bad typeEventRulesTbl or multiple events provided. validTbl=" .. tostring(isValidTbl) .. ", typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", rulesCount=" .. tostring(ruleCount) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
    return nil
  end
  -- local unitType, eventTbl = next(typeEventRulesTbl)
  -- if eventTbl == nil or type(eventTbl) ~= "table" or type(unitType) ~= "string" then
  --   debugger("getEventRulesNotifyVars 3.1. ERROR. Returning nil. Bad unitType or typeEventRulesTbl. unitType=" .. tostring(unitType) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
  --   return nil
  -- end
  -- local event, rulesTbl = next(eventTbl)
  -- if rulesTbl == nil or type(rulesTbl) ~= "table" or type(event) ~= "string" then
  --   debugger("getEventRulesNotifyVars 3.2. ERROR. Returning nil. Bad event or rulesTbl. event=" .. tostring(event) .. ", rulesTbl=" .. type(rulesTbl) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
  --   return nil
  -- end
  local alertBaseObj = unitObj
  if rulesTbl["sharedAlerts"] then
    alertBaseObj = unitObj.parent
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
  local validFound = false
  local unitObj, alertVarsTbl, priority, queuedSec
  local gameSecs = Spring.GetGameSeconds()
  local heapNum = 1
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
      -- ADD LOS RULES HERE, maybe?
    -- if alert no longer valid, like idle or thresholdHP  -- {"created","finished","idle","damaged","taken","destroyed","los","enteredAir","stockpile","thresholdHP"}
      unitObj["isQueued"] = false
    end
  end
  if validFound then
    if debug then debugger("getNextQueuedAlert 6. SUCCESS Valid found with remaining time="..queuedSec + alertVarsTbl["maxQueueTime"] - gameSecs) end
    return unitObj, alertVarsTbl, priority
  end
  if debug then debugger("getNextQueuedAlert 7. None found.") end
  return nil, nil, nil
end

-- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
function teamsManager:getQueuedEvents(unitObj,teamID,unitType,event,priorityLessThan,sharedAlerts) -- leaves them in queue. 
  if debug then debugger("getQueuedEvents 1. Searching for unit teamID="..tostring(teamID)..", unitType="..tostring(unitType)..", event="..tostring(event)..", sharedAlerts="..tostring(sharedAlerts)..", priorityLessThan="..tostring(priorityLessThan)) end
  local matchedEvents = {}
  local matches = 0
  local size = alertQueue:getSize()
  if size > 0 then
    for heapNum,valPriTbl in ipairs(alertQueue.heap) do -- should probably replace alertQueue.heap[heapNum] with valPriTbl $$$$$$$$$$$$
      if debug then debugger("getQueuedEvents 2. Queued unit vars: heapNum=" .. tostring(heapNum) .. ", sharedAlert="..tostring(alertQueue.heap[heapNum].alertRulesTbl["sharedAlerts"]) .. ", priority="..tostring(alertQueue.heap[heapNum]["priority"]) .. ", queuedTime=" .. tostring(valPriTbl["queuedTime"]) .. ", teamID=" .. tostring(alertQueue.heap[heapNum].alertRulesTbl.teamID) .. ", unitType=" .. tostring(alertQueue.heap[heapNum].alertRulesTbl["unitType"]) .. ", event=" .. tostring(alertQueue.heap[heapNum].alertRulesTbl["event"]) .. ", unitName=" .. tostring(UnitDefs[alertQueue.heap[heapNum].value.defID].translatedHumanName)) end
      if (type(teamID) == "nil" or (type(teamID) == "number" and teamID == alertQueue.heap[heapNum].alertRulesTbl.teamID)) and
      (type(unitType) == "nil" or (type(unitType) == "string" and unitType == alertQueue.heap[heapNum].alertRulesTbl["unitType"])) and
      (type(event) == "nil" or (type(event) == "string" and event == alertQueue.heap[heapNum].alertRulesTbl["event"])) and
      (type(unitObj) == "nil" or (type(unitObj) == "table" and unitObj == alertQueue.heap[heapNum].value)) and
      (type(sharedAlerts) == "nil" or sharedAlerts == alertQueue.heap[heapNum].alertRulesTbl["sharedAlerts"]) and
      (type(priorityLessThan) == "nil" or (type(priorityLessThan) == "number" and alertQueue.heap[heapNum].priority < priorityLessThan )) then
        -- table.insert(matchedEvents,alertQueue.heap[heapNum])
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

function teamsManager:validTypeEventRulesTbls(typeTbl) -- , returnCounts returnCounts returns the count of each type/event/rule
  if debug then debugger("validTypeEventRulesTbls 1. event=" .. type(typeTbl)) end
  if type(typeTbl) ~= "table" then
    debugger("validTypeEventRulesTbls 2. ERROR. Returning False. Not eventTbl=" .. type(typeTbl))
    return nil
  end
  local typeCount = 0
  local eventCount = 0
  local ruleCount = 0
  local emptyTypesToRemove = {}
  local badValue = nil
  for aType,eventTbl in pairs(typeTbl) do -- Types not tracked. If needed, add later
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
        rulesTbl["sharedAlerts"] = rulesTbl["sharedAlerts"] == true and rulesTbl["sharedAlerts"] or nil -- true or nil
        rulesTbl["maxQueueTime"] = type(rulesTbl["maxQueueTime"]) == "number" and rulesTbl["maxQueueTime"] or 120 -- number
        rulesTbl["maxAlerts"] = type(rulesTbl["maxAlerts"]) == "number" and rulesTbl["maxAlerts"] or nil
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
        if type(rulesTbl["threshMinPerc"]) ~= "number" or rulesTbl["threshMinPerc"] < 0 then
          rulesTbl["threshMinPerc"] = 0
        elseif rulesTbl["threshMinPerc"] >= 1 then
          debugger("validTypeEventRulesTbls 3.3. ERROR. Bad threshMinPerc. Must be: 0 > threshMinPerc < 1. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
          return nil
        end
        if type(rulesTbl["threshMaxPerc"]) ~= "number" or rulesTbl["threshMaxPerc"] < 0 then
          rulesTbl["threshMaxPerc"] = 1
        elseif rulesTbl["threshMaxPerc"] <= rulesTbl["threshMinPerc"] or rulesTbl["threshMaxPerc"] > 1 then
          debugger("validTypeEventRulesTbls 3.4. ERROR. Bad threshMaxPerc. Must be 0-1 and greater than threshMinPerc. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
          return nil
        end
        if (rulesTbl["maxAlerts"]~= nil and type(rulesTbl["maxAlerts"]) ~= "number") or type(rulesTbl["reAlertSec"]) ~= "number" or type(rulesTbl["priority"]) ~= "number" or (rulesTbl["maxQueueTime"] ~= nil and rulesTbl["maxQueueTime"] ~= false and type(rulesTbl["maxQueueTime"]) ~= "number") or (type(rulesTbl["mark"]) ~= "string" and rulesTbl["mark"] ~= nil) or (type(rulesTbl["ping"]) ~= "string" and rulesTbl["ping"] ~= nil) or (type(rulesTbl["alertSound"]) ~= "string" and rulesTbl["alertSound"] ~= nil) or (type(rulesTbl["sharedAlerts"]) ~= "boolean" and rulesTbl["sharedAlerts"] ~= nil) or (type(rulesTbl["threshMinPerc"]) ~= "number" or (rulesTbl["threshMinPerc"] < 0 or rulesTbl["threshMinPerc"] >= 1)) or (type(rulesTbl["threshMaxPerc"]) ~= "number" or (rulesTbl["threshMaxPerc"] > 1 or rulesTbl["threshMaxPerc"] <= 0 or rulesTbl["threshMaxPerc"] <= rulesTbl["threshMinPerc"])) then
          debugger("validTypeEventRulesTbls 4. ERROR. Returning nil. Bad threshMinPerc, threshMaxPerc, sharedAlerts, mark, ping, alertSound, maxAlerts, reAlertSec or priority=" .. tostring(rulesTbl["priority"]) .. ", reAlertSec=" .. tostring(rulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(rulesTbl["maxAlerts"]) .. ", maxQueueTime=" .. tostring(rulesTbl["maxQueueTime"]) .. ", threshMinPerc=" .. tostring(rulesTbl["threshMinPerc"]) .. ", threshMaxPerc=" .. tostring(rulesTbl["threshMaxPerc"]) .. ", tableToString=" .. tableToString(rulesTbl))
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
-- ArmyManager HAS:
-- 1. isUnitSameTeam(unit) - checks if the unit is on the same team as the armyManager
-- 2. hasUnit(unitID, unitDefID, unitTeamID) - ensures the unit exists in the armyManager, creates it if not
-- 3. getUnit(unitID) - gets the unit by unitID, returns the unit object or nil if not found
-- 4. createUnit(unitID, unitDefID, unitTeamID) - creates a new unit object if it does not exist in the armyManager
-- ArmyManager NEEDS:
-- 1. armyManager.isUnitRelevant(unit) - checks if the unit is relevant for the armyManager (e.g., is a builder)
-- 2. getOrCreateUnit(unitID, unitDefID, unitTeamID) - gets or creates the unit in the armyManager
-- 3. setTypes(unit) NOW IN UNIT - sets the unit type (e.g., builder, commander, factory, rezbot) based on its unitDefID
-- 4. armyManager UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam) flow 
-- 4.1 Mark pUnit.isDead = true, pUnit.lastUpdate = Spring.GetGameSeconds(), pUnit.coordiates
-- 5. incorporate lastUpdate
-- 6. incorporate playerID
-- 7. Economy tracking

-- ArmyManager typical flow for creating unit:
-- 1. 
function pArmyManager:addPlayer(playerID, playerName)
  if debug or self.debug then debugger("addPlayer 1. teamID=" .. self.teamID .. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
  if not teamsManager:validIDs(nil, nil, nil, nil, nil, nil, nil, nil, true, playerID) then debugger("pArmyManager:addPlayer 2. INVALID input. Returning nil.") return nil end
  if type(playerName) ~= "string" then
    playerName = playerID -- Placeholder value
  end
  self.playerIDsNames[playerID] = playerName
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pArmyManager:createUnit(unitID, defID)
  if debug or self.debug then debugger("createUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:createUnit 2. INVALID input. Returning nil.") return nil end
  local aUnit
  local unitTeamNow = Spring.GetUnitTeam(unitID)
  if unitTeamNow ~= self.teamID then
    debugger("createUnit 4. ERROR. Wrong team! There's no good reason for this! No. Returning nil. unitTeamNow=" .. tostring(unitTeamNow) .. ", self.teamID=" .. self.teamID)
    return nil
  end
  if teamsManager:isEnemy(unitTeamNow) then
    local enemyUnits = teamsManager:getUnitsIfInitialized(unitID) -- this has two return types: nil if none found, or array of units if one or more found.
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
  aUnit:setTypes()  -- Probably doesn't belong here unless there's a way to import user config into setTypes()
  if UnitDefs[defID].isFactory then
    aUnit.isFactory = true -- needs to be here because idle check is different for factories
  end
  local gameSecs = Spring.GetGameSeconds()
  aUnit.created = gameSecs
  self.lastUpdate = gameSecs
  aUnit.lastUpdate = gameSecs
  aUnit.lastSetIdle = gameSecs - 5  -- If didn't set, then would throw error for trying to use math on a nil value
  local eventTble = aUnit:getTypesRulesForEvent("created", true, false)
  if type(eventTble) == "table" then
    if debug then debugger("createUnit 9. Has rules for created. Sending to addUnitToAlertQueue(). unitID=" .. type(aUnit.unitID) .. ", unitDefID=" .. type(aUnit.defID) .. ", teamID=" .. type(self.teamID)) end
    teamsManager:addUnitToAlertQueue(aUnit, eventTble)
  end
  if debug or self.debug then debugger("createUnit 10. aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  return aUnit
end

-- Used to verify it is in the army, and/or return the unit object
function pArmyManager:getUnit(unitID)  -- Get unit by unitID. Returns the unit object or nil if not found
  if debug or self.debug then debugger("getUnit 1. unitID=" .. tostring(unitID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:getUnit 2. INVALID input. Returning nil.") return nil end
  local aUnit = self.units[unitID]
  if type(aUnit) == "nil" then
    if debug or self.debug then debugger("getUnit 3. unitID=" .. tostring(unitID) .. " does not exist in armyManager.units") end
    return nil -- This is expected to happen when this method is used to verify that the unit does not already exist
  end
  if debug or self.debug then debugger("getUnit 4. FOUND unitID=" .. tostring(unitID) .. ", aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID)) end
  return aUnit
end

function pArmyManager:getOrCreateUnit(unitID, defID)
  if debug or self.debug then debugger("pArmyManager:getOrCreateUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:getOrCreateUnit 2. INVALID input. Returning nil.") return nil end
  return self:getUnit(unitID) or self:createUnit(unitID, defID)
end

function pArmyManager:getTypesRulesForEvent(defID, event, topPriorityOnly, canAlertNow, unitObj) -- defID, string event, bool/nil (default false) topPriorityOnly. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}
  if debug or self.debug then debugger("getTypesRulesForEvent 1. teamID=" .. self.teamID .. ", defID=" .. tostring(defID) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly).. ", canAlertNow="..tostring(canAlertNow).. ", unitObj="..type(unitObj)) end
  if type(defID) ~= "number" or type(event) ~= "string" or (type(topPriorityOnly) ~= "boolean" and topPriorityOnly ~= nil) or (unitObj ~= nil and type(unitObj) ~= "table") or (canAlertNow and type(unitObj) ~= "table") then
    debugger("getTypesRulesForEvent 2. ERROR. defID NOT number, event not string, not unitObj with canAlertNow. teamID=" .. self.teamID .. ", defID=" .. tostring(defID) .. ", event=" .. tostring(event))
    return nil
  end
  local typesEventRulesTbl = self.defTypesEventsRules[defID] -- {defID = {type = {event = {rules}}}}
  if typesEventRulesTbl == nil or type(typesEventRulesTbl) ~= "table" then
    if debug or self.debug then debugger("getTypesRulesForEvent 3. No types for deID, or typesEventRules NOT table. Returning nil. defID"..tostring(defID) .. ", event=" .. tostring(event)..", teamID=" .. self.teamID .. ", typesEventRulesTbl=" .. type(typesEventRulesTbl) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
    return nil
  end
  local typesEventsTbl = {}
  local matches = 0
  local priorityNum = 99999
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
    if debug then debugger("getTypesRulesForEvent 6. No matches, returning nil. event=" .. tostring(event) .. ", typesEventRules=" .. tableToString(typesEventsTbl)) end
    return nil
  end
  if debug then debugger("getTypesRulesForEvent 7. Returning matches=" .. tostring(matches) .. ", event=" .. tostring(event) .. ", typesEventRules=" .. type(typesEventsTbl)) end
  return typesEventsTbl -- {type = {event = {rules}}}
end

function pArmyManager:canAlertNow(unitObj, typeEventRulesTbl) -- only has 1 Type and 1 Event -- {type = {event = {rules}}}
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
  end
  alertBaseObj = alertBaseObj["lastAlerts"][aType][anEvent]
  local gameSecs = Spring.GetGameSeconds()
  if debug then debugger("canAlertNow 6T. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(aRulesTbl["maxAlerts"])..", mark="..tostring(aRulesTbl["mark"])..", ping="..tostring(aRulesTbl["ping"])..", alertSound="..tostring(aRulesTbl["alertSound"])) end
  if ((type(aRulesTbl["mark"]) ~= "string") and (type(aRulesTbl["ping"]) ~= "string") and type(aRulesTbl["alertSound"]) ~= "string") or alertBaseObj["isQueued"] or gameSecs < alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"] or (aRulesTbl["maxAlerts"] ~= 0 and alertBaseObj["alertCount"] >= aRulesTbl["maxAlerts"]) then
    if debug then debugger("canAlertNow 6. Too soon or no alert rules. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(aRulesTbl["maxAlerts"])..", mark="..tostring(aRulesTbl["mark"])..", ping="..tostring(aRulesTbl["ping"])..", alertSound="..tostring(aRulesTbl["alertSound"]) .. ", tableToString=" .. tableToString(aRulesTbl)) end
    return false
  end
  if debug or self.debug then debugger("canAlertNow 8. TRUE. unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl)) end
  return true
end

function pArmyManager:hasTypeEventRules(defID, aType, event) -- defID mandatory
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:hasTypeEventRules 0. INVALID input. Returning nil.") return nil end
  if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 1. defID=".. tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local typeRulesTbl = self.defTypesEventsRules[defID]
  if type(typeRulesTbl) ~= "table" then
    if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 2. FALSE. Not table defID="..tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ",typeRulesTbl="..type(typeRulesTbl) .. ", teamID=".. tostring(self.teamID)) end
    return false
  end
  if defID and not aType and not event then
    if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 3. TRUE. Found requested defID="..tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
    return true
  end
  for kType,evntTbl in pairs(typeRulesTbl) do
    if aType and kType == aType and event and type(evntTbl[event]) == "table" then
      if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 4. TRUE. Found type and event. defID="..tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
      return true
    elseif not event and aType and kType == aType and type(evntTbl) == "table" then
      if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 5. TRUE. Found type. defID="..tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
      return true
    elseif not aType and event and type(evntTbl[event]) == "table" then
      if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 6. TRUE. Found event. defID="..tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
      return true
    end
  end
  if debug or self.debug then debugger("pArmyManager:hasTypeEventRules 7. FALSE. Couldn't find type and/or event. defID="..tostring(defID)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  return false
end

-- Could have this run once when adding to defsTypesEventsRulesTbl
function pArmyManager:initEventLastAlerts(unitObj, unitType, event) -- armyObj for sharedEvent, else unitObj. Nil defaults to armyObj
  if debug then debugger("pArmyManager:initEventLastAlerts 1. unitOrArmyObj="..type(unitObj)..", unitType="..tostring(unitType)..", event="..tostring(event)) end
  if type(unitObj) ~= "table" or (unitObj.parent ~= self and unitObj.parent ~= self.parent) or type(unitType) ~= "string" or type(event) ~= "string" then
    debugger("pArmyManager:initEventLastAlerts 2. ERROR, Returning nil. BAD event, unitType, or unitOrArmyObj=".. type(unitObj) .. ", unitType=".. tostring(unitType) .. ", event=" .. tostring(event))
    return nil
  end
  -- if type(unitObj["lastAlerts"]) ~= "table" then
  --   if debug then debugger("pArmyManager:initEventLastAlerts 3. lastAlerts="..type(unitObj["lastAlerts"])..", unitOrArmyObj="..type(unitObj)..", unitType="..tostring(unitType)..", event="..tostring(event))end
  --     unitObj["lastAlerts"] = {}
  --   end
  --   unitObj = unitObj["lastAlerts"]
  --   if type(unitObj[unitType]) ~= "table" then
  --     if debug then debugger("pArmyManager:initEventLastAlerts 4. unitOrArmyObj[unitType]="..type(unitObj[unitType])..", unitOrArmyObj="..type(unitObj)..", unitType="..tostring(unitType)..", event="..tostring(event))end
  --     unitObj[unitType] = {}
  --   end
  --   if type(unitObj[unitType][event]) ~= "table" then
  --     if debug then debugger("pArmyManager:initEventLastAlerts 5. unitOrArmyObj[unitType][event]="..type(unitObj[unitType][event])..", unitOrArmyObj="..type(unitObj)..", unitType="..tostring(unitType)..", event="..tostring(event)) end
  --     unitObj[unitType][event] = {}
  --     unitObj[unitType][event]["lastNotify"] = 0
  --     unitObj[unitType][event]["alertCount"] = 0
  --     unitObj[unitType][event]["isQueued"] = false
  --   end
return true
  -- debugger("pArmyManager:initEventLastAlerts 3. THIS ISN'T USE ANYMORE.")  
  -- -- end
  -- -- debug = false
  -- if debug then debugger("pArmyManager:initEventLastAlerts 5. lastAlerts="..type(unitObj["lastAlerts"])..", unitOrArmyObj[unitType]="..type(unitObj[unitType])..", unitOrArmyObj[unitType][event]="..type(unitObj[unitType][event])..", unitOrArmyObj="..type(unitObj)..", unitType="..tostring(unitType)..", event="..tostring(event)..", lastNotify="..tostring(unitObj[unitType][event]["lastNotify"])..", alertCount="..tostring(unitObj[unitType][event]["alertCount"])..", isQueued="..tostring(unitObj[unitType][event]["isQueued"])) end
  -- return true
end
-- ################################################## Custom/Expanded ArmyManager methods start here #################################################






-- ################################################## Basic Core Unit methods starts here #################################################
-- pUnit HAS:
-- 1. setID(unitID) - sets the unit ID and updates lastUpdate time
-- 2. setDefID(unitDefID) - sets the unit definition ID and updates lastUpdate time
-- 4. setAllIDs(unitID, unitDefID, unitTeamID) - sets all IDs and updates lastUpdate time
-- pUnit NEEDS:
-- 5. maybeMarkUnitAsIdle(unitID, unitDefID, unitTeam) - checks if the unit is relevant and idle, then marks it as idle (NOT IMPLEMENTED YET)
-- 6. getHealth() - gets the unit health (NOT IMPLEMENTED YET)
-- 7. isDestroyed() - if is destroyed, sets the relevant unit attributes (NOT IMPLEMENTED YET)
-- 7. get/setCoordinates() - gets/sets the unit coordinates (NOT IMPLEMENTED YET)

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

function pUnit:setAllIDs(unitID, unitDefID)	-- return nil // Optionals: [number unitID], [number unitDefID]
  if debug or self.debug then debugger("setAllIDs 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(unitDefID) .. ", unitTeamID=" .. tostring(self.parent.teamID)) end
  return self:setID(unitID) == unitID and self:setDefID(unitDefID) == unitDefID
end

function pUnit:setIdle()
  if debug or self.debug then debugger("setIdle 1. GameFrame(" .. Spring.GetGameFrame() .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if not self.isIdle then
    self.isIdle = true
    -- if self:hasTypeEventRules(nil, "idle") then
      if type(self.parent["idle"]) ~= "table" then
        self.parent["idle"] = {}
      end
      -- if type(self.parent["idle"]) == "table" and self.parent["idle"][self.ID] == nil then
        self.parent["idle"][self.ID] = self
      -- end
      -- local typeRules = self:getTypesRulesForEvent("idle", true, true)
      -- if typeRules then
        if debug or self.debug then debugger("setIdle 2. Going to addUnitToAlertQueue. GameFrame(" .. Spring.GetGameFrame() .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
        teamsManager:addUnitToAlertQueue(self, self:getTypesRulesForEvent("idle", true, true)) -- addUnitToAlertQueue(self, typeRules)
      -- end
    -- end
    self.lastSetIdle = Spring.GetGameFrame()
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setIdle 3. Has been setIdle. GameFrame(" .. Spring.GetGameFrame() .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end

function pUnit:setNotIdle()
  if debug or self.debug then debugger("setNotIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if self.isIdle then
    self.isIdle = false
    if type(self.parent["idle"]) ~= "table" and self:hasTypeEventRules(nil, "idle") then
      self.parent["idle"] = {}
    end
    -- if type(self.parent["idle"]) == "table" and self.parent["idle"][self.ID] ~= nil then
      self.parent["idle"][self.ID] = nil
    -- end
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setNotIdle 2. Has been setNotIdle. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end
-- ATTENTION!!! ###### This waits 5 frames before returning that it is idle because some units are idle very briefly before starting on the next queued task
function pUnit:getIdle()
  if debug or self.debug then debugger("getIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(self.ID) -- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress
  if buildProgress == nil or buildProgress < 1 then
    if debug or self.debug then debugger("getIdle 2. Not fully constructed, so returning NOT IDLE. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    self:setNotIdle()
    return self.isIdle
  end
  local count
  if self.isFactory then
    count = Spring.GetFactoryCommands(self.ID, 0) -- GetFactoryCommands(unitID, 0)
    if debug or self.debug then debugger("getIdle 3. isFactory with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  else
    count = spGetCommandQueue(self.ID, 0)
    if debug or self.debug then debugger("getIdle 4. Builder with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
  if debug or self.debug then debugger("getIdle 5. GameFrame(" .. Spring.GetGameFrame() .. ", CommandQueueCount=" .. tostring(count) .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if count > 0 then
    if debug or self.debug then debugger("getIdle 6. Wasn't actually Idle. Calling setNotIdle to correct it. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    self:setNotIdle()
    return self.isIdle -- doing it this way because for some reason then function receiving self.isIdle gets nil every time?
  elseif self.isIdle == false then
    self:setIdle()  -- lastSetIdle is only set when becoming idle from being not idle. Which means it will return false below to allow the extra second to prevent false positives
    if debug or self.debug then debugger("getIdle 7. Was actually Idle, corrected. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
  return self.isIdle
  -- if self.isIdle and Spring.GetGameFrame() < self.lastSetIdle + 5 then -- because it may be idle very briefly before starting on the next queued task
  --   if debug or self.debug then debugger("getIdle 8. Hasn't been idle for a second. Returning false. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  --   return nil -- So that you can know if waiting for time to pass
  -- else
  -- if debug or self.debug then debugger("getIdle 9. Returning " .. tostring(self.isIdle) .. ". cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  -- return true -- doing it this way because for some reason then function receiving self.isIdle gets nil every time?
  -- end
end

-- TODO: Update to use relevant table. Think I did, but need to remove old
function pUnit:setLost(destroyed) -- destroyed = true default
  if debug or self.debug then debugger("setLost 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed)) end
  if type(destroyed) ~= "nil" and type(destroyed) ~= "boolean" then
    debugger("setLost 2. ERROR. destroyed NOT nil or bool. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed))
  end
  local x,y,z = Spring.GetUnitPosition( self.ID )
  self.coords = {x=x, y=y, z=z}
  destroyed = destroyed or true
  self:setNotIdle() -- Removes it from idle lists/queues
  if type(self.parent["unitsLost"]) ~= "table" then
    self.parent["unitsLost"] = {}
  end
  self.parent["unitsLost"][self.ID] = self
  self.parent.units[self.ID] = nil
  local unitTypes = self:getTypesRules() -- {type = {event = {rules}}}} -- Remove unit from all Type/Event lists in parent army (except Lost)
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
  else
    local takenEvent = self:getTypesRulesForEvent("taken", true, false)
    if takenEvent then
      if debug or self.debug then debugger("setLost 8. Unit has rule to alert when taken, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      teamsManager:addUnitToAlertQueue(self, takenEvent) -- {type = {event = {rules}}}
    end
  end
  self.lost = Spring.GetGameSeconds()
  self.lastUpdate = Spring.GetGameSeconds()
  return self
end

function pUnit:getTypesRules(types) -- Nil for all, string for one, or array of strings input. Should not store in unit, since it can move between teams. The armyManagers define which units are important to track.
  if debug or self.debug then debugger("getTypesRules 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types) .. ", translatedHumanName=" .. UnitDefs[self.defID].translatedHumanName) end
  if self:hasTypeEventRules() == false then
    if debug or self.debug then debugger("getTypesRules 2. Unit has no typeRules in defTypesEventsRules. returning nil. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types)) end
    return nil
  end
  if types == nil then
    if debug or self.debug then debugger("getTypesRules 3. Nil means returning all typesRules. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types)) end
    return self.parent.defTypesEventsRules[self.defID] -- {defID = {type = {event = {rules}}}}
  elseif type(types) == "string" then
    if debug or self.debug then debugger("getTypesRules 4. Returning matching typeRules, if there. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types)) end
    return {[types] = self.parent.defTypesEventsRules[self.defID][types]}
  elseif type(types) == "table" then
    local typeTble = {}
    for i, aType in ipairs(types) do
      if type(self.parent.defTypesEventsRules[self.defID][aType]) == "table" then
        if debug or self.debug then debugger("getTypesRules 5. Match found in loop, adding it. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types)) end
        typeTble[aType] = self.parent.defTypesEventsRules[self.defID][aType]
      end
    end
    if debug or self.debug then debugger("getTypesRules 6. returning all matching typesRules. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types)) end
    return typeTble
  else
    debugger("getTypesRules 7. ERROR. Invalid input. Returning nil. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types))
    return nil
  end
end

function pUnit:getTypesRulesForEvent(event, topPriorityOnly, canAlertNow) -- defID, string event. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}
  if debug or self.debug then debugger("pUnit:getTypesRulesForEvent 1. Returning self.parent:getTypesRulesForEvent(" .. tostring(self.defID) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly) .. "), unitID=" .. tostring(self.ID) .. ", teamID=".. tostring(self.parent.teamID)) end
  return self.parent:getTypesRulesForEvent(self.defID, event, topPriorityOnly, canAlertNow, self)
end

-- TODO: Remove top to leave new at bottom
-- Where should this go? How to make it easily USER CONFIG expandable? ############################################
function pUnit:setTypes()
  if debug or self.debug then debugger("setTypes 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if UnitDefs[self.defID].isFactory then
    self.isFactory = true
  end
  local unitTypes = self:getTypesRules() -- {type = {event = {rules}}}}
  if debug or self.debug then debugger("setTypes 2. translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)) end
  if type(unitTypes) == "table" then
    for aType, eventsTbl in pairs(unitTypes) do
      if self.parent[aType] == nil then
        self.parent[aType] = {}
      end
      self.parent[aType][self.ID] = self
      if debug or self.debug then debugger("setTypes 3. Added self to parent." .. tostring(self.parent[aType]) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      local baseObj = self
      if type(eventsTbl) == "table" and eventsTbl["sharedAlerts"] == true then
        baseObj = baseObj.parent
      end
      for event,rulesTbl in pairs(eventsTbl) do
        -- debugger("setTypes TEST sharedAlerts="..tostring(rulesTbl["sharedAlerts"])..", tostring rulesTbl="..tableToString(rulesTbl))
        if not rulesTbl["sharedAlerts"] then
          if type(baseObj["lastAlerts"]) ~= "table" then
            if debug then debugger("setTypes 4. lastAlerts="..type(baseObj["lastAlerts"])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
            baseObj["lastAlerts"] = {}
          end
          local lastAlerts = baseObj["lastAlerts"]
          if type(lastAlerts[aType]) ~= "table" then
            if debug then debugger("setTypes 5. unitOrArmyObj[unitType]="..type(lastAlerts[aType])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
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
      end

    end
  end
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pUnit:hasTypeEventRules(aType,event)
  if debug or self.debug then debugger("hasTypeEventRules 1. SHELL returns from armyManager ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  return self.parent:hasTypeEventRules(self.defID,aType,event)
end

function pUnit:getUnitPosition()
  if debug or self.debug then debugger("getUnitPosition 1. Getting unit's current position, else sending back the most recent coords." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
  local x,y,z = Spring.GetUnitPosition( self.ID )
  if type(x) == "number" then
    if debug or self.debug then debugger("getUnitPosition 2. Returning unit's current position coords="..tostring(x).."-"..tostring(y).."-"..tostring(z)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
    self.coords = {x=x, y=y, z=z}
    return x, y, z
    elseif type(self.coords.x) == "number" then
    if debug or self.debug then debugger("getUnitPosition 3. Returning unit's old position because GetUnitPosition returned nil. coords="..tostring(x).."-"..tostring(y).."-"..tostring(z)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
    return self.coords.x, self.coords.y, self.coords.z
  end
  if debug or self.debug then debugger("getUnitPosition 4. FAIL. Unable to return any coordss." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
  return nil, nil, nil
end
-- ################################################## Custom/Expanded Unit methods starts here #################################################




-- ################################################# Unit Type Rules Assembly start here #################################################

local function addToRelTeamDefsRules(defID, key)
  if debug then debugger("addToRelTeamDefsRules 1. defID=" .. tostring(defID) .. ", key=" .. tostring(key)) end
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("addToRelTeamDefsRules 2. INVALID input. Returning nil.") return nil end
  if type(key) ~= "string" then debugger("addToRelTeamDefsRules 3. INVALID KEY input. Returning nil.") return nil end
  -- if spectator then
  --   -- something
  -- end
  if next(trackMyTypesRules) ~= nil and type(trackMyTypesRules[key]) == "table" and next(trackMyTypesRules[key]) ~= nil then
    if type(relevantMyUnitDefsRules[defID]) == "nil" then
      relevantMyUnitDefsRules[defID] = {}
    end
    relevantMyUnitDefsRules[defID][key] = trackMyTypesRules[key]
  end
  if next(trackAllyTypesRules) ~= nil and type(trackAllyTypesRules[key]) == "table" and next(trackAllyTypesRules[key]) ~= nil then
    if type(relevantAllyUnitDefsRules[defID]) == "nil" then
      relevantAllyUnitDefsRules[defID] = {}
    end
    relevantAllyUnitDefsRules[defID][key] = trackAllyTypesRules[key]
  end
  if next(trackEnemyTypesRules) ~= nil and type(trackEnemyTypesRules[key]) == "table" and next(trackEnemyTypesRules[key]) ~= nil then
    if type(relevantEnemyUnitDefsRules[defID]) == "nil" then
      relevantEnemyUnitDefsRules[defID] = {}
    end
    relevantEnemyUnitDefsRules[defID][key] = trackEnemyTypesRules[key]
  end
end

local function makeRelTeamDefsRules() -- This should ensure that types are only added to armyManager.defTypesEventsRules if there are events defined
if debug then debugger("makeRelTeamDefsRules 1.") end
  if type(trackMyTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackMyTypesRules) then return false end
  if type(trackAllyTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackAllyTypesRules) then return false end
  if type(trackEnemyTypesRules) ~= "table" or not teamsManager:validTypeEventRulesTbls(trackEnemyTypesRules) then return false end
  for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.iscommander and (next(trackMyTypesRules["commander"]) ~= nil or next(trackAllyTypesRules["commander"]) ~= nil or next(trackEnemyTypesRules["commander"]) ~= nil) then
      if debug then debugger("Assigning Commander types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      addToRelTeamDefsRules(unitDefID, "commander")
      addToRelTeamDefsRules(unitDefID, "constructor")
    elseif unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1] or (idleRezAlert and unitDef.canResurrect)) and not unitDef.customParams.isairbase then
      if unitDef.canAssist or unitDef.canAssist and (next(trackMyTypesRules["constructor"]) ~= nil or next(trackAllyTypesRules["constructor"]) ~= nil or next(trackEnemyTypesRules["constructor"]) ~= nil) then     -- check is this constructor was: unitDef.canConstruct and unitDef.canAssist 
        addToRelTeamDefsRules(unitDefID, "constructor")
        if debug then debugger("Assigning Constructor types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      elseif unitDef.isBuilding and unitDef.isFactory and (next(trackMyTypesRules["factory"]) ~= nil or next(trackAllyTypesRules["factory"]) ~= nil or next(trackEnemyTypesRules["factory"]) ~= nil) then
        if debug then debugger("Assigning Factory types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "factory")
        if unitDef.customParams.unitgroup == "buildert2" then
          if debug then debugger("Assigning T2 Factory types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
          addToRelTeamDefsRules(unitDefID, "factoryT2")
        end
      elseif idleRezAlert and unitDef.canResurrect and (next(trackMyTypesRules["rezBot"]) ~= nil or next(trackAllyTypesRules["rezBot"]) ~= nil or next(trackEnemyTypesRules["rezBot"]) ~= nil) then -- RezBot optional using idleRezAlert
        if debug then debugger("Assigning RezBot types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "rezBot")
      end
    end
    if unitDef.isBuilding and unitDef.customParams and unitDef.customParams.metal_extractor then
      if debug then debugger("Assigning Metal Extractor types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "mex")
    end
    if unitDef.isBuilding and unitDef.customParams and unitDef.customParams.unitgroup == "energy" then
      if debug then debugger("Assigning energyGen types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "energyGen")
    end
    if unitDef.isBuilding and ((type(unitDef["radarDistance"]) == "number" and unitDef["radarDistance"] > 1999) or (type(unitDef["sonarDistance"]) == "number" and unitDef["sonarDistance"] > 850)) then
      if debug then debugger("Assigning Radar types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "radar")
    end
    if unitDef.customParams.unitgroup == "nuke" then
      if debug then debugger("Assigning Nuke types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      addToRelTeamDefsRules(unitDefID, "nuke")
    end
    if unitDef.customParams.unitgroup == "antinuke" then
      debugger("Assigning antiNuke types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName)
      addToRelTeamDefsRules(unitDefID, "antinuke")
    end
    local searchTxt = "Drone"
    if unitDef.canFly and unitDef.canMove and not string.find(UnitDefs[unitDefID].translatedHumanName:lower(), searchTxt:lower()) then
      if debug then debugger("Assigning air types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      addToRelTeamDefsRules(unitDefID, "air")
      -- ### TODO: Add airT2
    end
    if unitDef.customParams.techLevel == 2 then
      debugger("Assigning T2 types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName)
      addToRelTeamDefsRules(unitDefID, "unitsT2")
    end
    if unitDef.customParams.techLevel == 3 then
      debugger("Assigning T3 types with unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName)
      addToRelTeamDefsRules(unitDefID, "unitsT3")
    end
    
    -- if mex, radar...
    -- if next(trackAllMyUnitsRules) ~= nil or next(trackAllEnemyUnitsRules) ~= nil or next(trackAllAlliedUnitsRules) ~= nil then
      -- -- figure out how to do this. something like {hp, coords, destroyed}
    -- end
  end
  return true
end

-- ################################################# Idle Alerts start here #################################################

function widget:PlayerChanged(playerID)
    myTeamID = Spring.GetMyTeamID()
	isSpectator = Spring.GetSpectatingState()
	if isSpectator then
		widgetHandler:RemoveWidget()
	end
end

function widget:UnitIdle(unitID, defID, teamID)
  if debug then debugger("widget:UnitIdle 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = teamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID, nil, "idle") then
    teamsManager:getOrCreateUnit(unitID, defID, teamID):setIdle() -- automatically alerts for this
    -- local unit = teamsManager:getOrCreateUnit(unitID, defID, teamID)
    -- if unit then
    --   unit:setIdle() -- automatically alerts for this
    -- end
	end
end

function widget:UnitDestroyed(unitID, defID, unitTeam, attackerID, attackerDefID, attackerTeam)	-- Triggered when unit dies or construction canceled/destroyed while being built
  if debug then debugger("UnitDestroyed 1. Unit taken. unitID=" .. unitID .. ", unitDefID=" .. defID .. ", attackerID=" .. attackerID .. ", attackerDefID=" .. attackerDefID .. ", attackerTeam=" .. attackerTeam) end
  -- local x,y,z = Spring.GetUnitPosition( unitID )
  if debug then debugger("UnitDestroyed 2 unitID=" .. unitID .. ", translatedHumanName=" .. UnitDefs[defID].translatedHumanName..", x=".. x ..", y=".. y ..", z=".. z) end
  local army = teamsManager:getArmyManager(unitTeam)
  if army and army:hasTypeEventRules(defID, nil, "destroyed") then
    army:getOrCreateUnit(unitID, defID):setLost() -- automatically alerts for this
  end
end

function widget:UnitTaken(unitID, defID, oldTeamID, newTeamID)
  if debug then debugger("UnitTaken 1. Unit taken. unitID=" .. unitID .. ", unitDefID=" .. defID  .. ", oldTeamID=" .. oldTeamID .. ", newTeamID=" .. newTeamID) end
  if teamsManager:getArmyManager(oldTeamID):hasTypeEventRules(defID) or teamsManager:getArmyManager(newTeamID):hasTypeEventRules(defID) then
    local oldArmy = teamsManager:getArmyManager(oldTeamID)
    if oldArmy then
      local aUnit = oldArmy:getOrCreateUnit(unitID, defID)
      if aUnit then
        teamsManager:moveUnit(unitID, defID, oldTeamID, newTeamID) -- automatically alerts for this
        if newTeamID == myTeamID then
          aUnit:getIdle() -- automatically alerts for this
        end
      end
    end
  end
end

function widget:UnitCreated(unitID, defID, teamID, builderID)
  if debug then debugger("UnitCreated 1. Unit construction started. unitID=" .. unitID .. ", unitDefID=" .. defID .. ", teamID=" .. teamID .. ", builderID=" .. builderID) end
  local army = teamsManager:getArmyManager(teamID)
  if army and army:hasTypeEventRules(defID, nil, "created") then
    army:getOrCreateUnit(unitID, defID) -- automatically alerts for this
  end
end

function widget:UnitFinished(unitID, defID, teamID, builderID)
  if debug then debugger("UnitFinished 1 is now completed and ready. unitID=" .. unitID .. ", unitDefID=" .. defID .. ", teamID=" .. teamID .. ", builderID=" .. builderID) end
  local army = teamsManager:getArmyManager(teamID)
  if army and army:hasTypeEventRules(defID, nil, "finished") then
    local aUnit = army:getOrCreateUnit(unitID, defID)
    if debug then debugger("UnitFinished 2. Sending alert. unitID=" .. unitID .. ", unitDefID=" .. defID .. ", teamID=" .. teamID .. ", builderID=" .. builderID) end
    local finishedEvent = aUnit:getTypesRulesForEvent("finished", true, true)
    if finishedEvent then
      teamsManager:addUnitToAlertQueue(aUnit, finishedEvent)
    end
    aUnit:getIdle()
  end
end

function widget:Initialize()
	Spring.Echo("Starting " .. widgetName)
    widget:PlayerChanged()
	if isSpectator then
		return
	end
  -- loadAllExistingUnits #############
  -- if Spring.GetGameSeconds() > 1 then
  --   -- TODO: Load All Units if replay or starting mid-game ########## 
  -- end
end

function widget:UnitEnteredLos(unitID, teamID, allyTeam, defID) -- Called when a unit enters LOS of an allyteam. Its called after the unit is in LOS, so you can query that unit. The allyTeam is who's LOS the unit entered.
  if debug then debugger("UnitEnteredLos 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", allyTeam=" .. tostring(allyTeam)) end --  .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)
  if defID == nil then
    defID = Spring.GetUnitDefID(unitID)
    if defID == nil then
      debugger("UnitEnteredLos 2. Cannot get defID for unit?")
      return nil
    end
  end
  local anArmy = teamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID, nil, "los") then
    local aUnit = teamsManager:getOrCreateUnit(unitID, defID, teamID)
    local losEvent = aUnit:getTypesRulesForEvent("los", true, false)
    if losEvent then
      teamsManager:addUnitToAlertQueue(aUnit, losEvent)
    end
  end
end

-- Need to ensure GameFrame checks every time and readds them to alerts as needed
-- check HP too?
local function checkQueuesOfInactiveUnits() -- Only checks units with idle event rules and are in the parent["idle"] table
  if debug then debugger("checkQueuesOfInactiveUnits 1.") end
  if type(teamsManager.myArmyManager["idle"]) == "table" then
    for unitID, unit in pairs(teamsManager.myArmyManager["idle"]) do
      if debug then debugger("checkQueuesOfInactiveUnits 2. unitID=" .. unitID .. ", defID=" .. unit.defID .. ", isFactory=" .. tostring(unit.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
      if unit:getIdle() == true then
        if debug then debugger("checkQueuesOfInactiveUnits 3. Builder idle. unitID=" .. unitID .. ", defID=" .. unit.defID) end
        local canAlertNowTbl = unit:getTypesRulesForEvent("idle", true, true)
        if canAlertNowTbl then
          teamsManager:addUnitToAlertQueue(unit, canAlertNowTbl)
        end
      -- else
      --   if debug then debugger("checkQueuesOfInactiveUnits 4. Builder NOT idle. unitID=" .. unitID .. ", defID=" .. unit.defID) end
      end
    end
  end
end

-- function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

--   -- sends destroyed AND "thresholdHP"
-- end

function widget:CommandsChanged() -- Called when the command descriptions changed, e.g. when selecting or deselecting a unit. Because widget:UnitIdle doesn't happen when factory queue is removed by player
  if debug then debugger("CommandsChanged 1. Called when the command descriptions changed, e.g. when selecting or deselecting a unit.") end
	-- local factories = teamsManager.myArmyManager["factory"]
  if type(teamsManager.myArmyManager["factory"]) == "table" then
    for unitID, unit in pairs(teamsManager.myArmyManager["factory"]) do
      if debug then debugger("CommandsChanged 2. unitID=" .. unitID .. ", defID=" .. unit.defID .. ", isFactory=" .. tostring(unit.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
      if unit:getIdle() == true then -- automatically adds unit to idle alert queue if it applies
        if debug then debugger("CommandsChanged 3. Factory added to parent[idle] table. unitID=" .. unitID .. ", defID=" .. unit.defID) end
      else
        if debug then debugger("CommandsChanged 4. Factory NOT idle. unitID=" .. unitID .. ", defID=" .. unit.defID) end
      end
    end
  end
end
-- commander start position Spring.GetAllyTeamStartBox ( number allyID )
-- figure out logic for if new alert is added to queue
function widget:GameFrame(frame)
  if warnFrame == 1 then -- with 30 UpdateInterval, would run every half second
  -- if idlingUnitCount > 0 then -- or numAlerts > 0 
    -- if warnFrame == 0 then
      checkQueuesOfInactiveUnits() -- Needed
      if priorityQueue:isEmpty() == false then -- still idling after we checked the queues
        teamsManager:alert()
      end
    -- end
		-- warnFrame = (warnFrame + 1) % UpdateInterval
	end
  warnFrame = (warnFrame + 1) % UpdateInterval -- With changes at top, this would automatically run every half second
  -- debugger("warnFrame="..warnFrame)
end

function widget:Shutdown()
	Spring.Echo(widgetName .. " widget disabled")
end




debug = false
if not makeRelTeamDefsRules() then
  debugger("makeRelTeamDefsRules() returned FALSE. Fix trackMyTypesRules, trackAllyTypesRules, trackEnemyTypesRules tables.")
  widgetHandler:RemoveWidget()
end
teamsManager:makeAllArmies() -- Build all teams/armies

-- debugger("aUnitTypeRules=" .. tableToString(aUnit:getTypesRules()))
-- debugger("bUnitTypeRules Con=" .. tableToString(bUnit:getTypesRules("constructor")))
-- debugger("bUnitTypeRules arr=" .. tableToString(bUnit:getTypesRules(arr)))
-- debugger("bUnit.parent[constructor] type=" .. type(bUnit.parent["constructor"]))
-- debugger("bUnit.parent[constructor] type=" .. tableToString(bUnit.parent["constructor"]))
-- bUnit:setTypes()
-- bUnit:setLost()
-- debugger("unitsLost[bUnit.ID]=" .. type(bUnit.parent.unitsLost[bUnit.ID]))
-- debugger("units[bUnit.ID]=" .. tostring(bUnit.parent.units[bUnit.ID])) -- should be nil
-- debugger("parent[constructor][bUnit.ID]=" .. tostring(bUnit.parent["constructor"][bUnit.ID])) -- should be nil
-- debugger("parent[radar][bUnit.ID]=" .. tostring(bUnit.parent["radar"][bUnit.ID])) -- should be nil
-- debugger("bUnit.parent.defTypesEventsRules=" .. tableToString(bUnit.parent.defTypesEventsRules))
-- debugger("enemy defTypesEventsRules=" .. tableToString(teamsManager:getArmyManager(3).defTypesEventsRules))
-- debugger("1 getOrCreateUnit=" .. teamsManager:getOrCreateUnit(13950, 245, 0).ID)
-- debugger("2 getOrCreateUnit=" .. teamsManager:getOrCreateUnit(13950, 245, 0).ID)
-- debugger("Army hasTypeEventRules=" .. tostring(gUnit.parent:hasTypeEventRules(gUnit.defID)) .. ", name=" .. tostring(UnitDefs[gUnit.defID].translatedHumanName))
-- debugger("Unit hasTypeEventRules=" .. tostring(enemyCUnit:hasTypeEventRules()) .. ", name=" .. tostring(UnitDefs[enemyCUnit.defID].translatedHumanName))
-- debugger("Unit hasTypeEventRules=" .. tostring(enemyCUnit:hasTypeEventRules()) .. ", name=" .. tostring(UnitDefs[enemyCUnit.defID].translatedHumanName))
-- local typeRules = cUnit:getTypesRulesForEvent("idle")
-- local typeRules = cUnit:getTypesRules({"commander"})
-- debugger("validTypeEventRulesTbls=" .. tostring(validTypeEventRulesTbls(typeRules)))
-- debugger("tableToString=" .. tableToString(typeRules))
-- cUnit:setLost(false)
-- debugger("unitsLost[bUnit.ID]=" .. type(cUnit.parent.unitsLost[cUnit.ID]))
-- local priorityRules = cUnit:getTypesRulesForEvent("idle",true)
-- local typeRules2,typeCount2,eventCount2,ruleCount2 = validTypeEventRulesTbls(priorityRules)
-- debugger("priorityRules validTypeEventRulesTbls2=" .. tostring(typeRules2) .. ", typeCount2=" .. tostring(typeCount2) .. ", eventCount2=" .. tostring(eventCount2) .. ", ruleCount2=" .. tostring(ruleCount2) .. ", tableToString2=" .. tableToString(priorityRules))

-- local searchTxt = "Sonar"
-- local aTeamNum = 0
-- for unitDefID, unitDef in pairs(UnitDefs) do
--   if string.find(UnitDefs[unitDefID].translatedHumanName:lower(), searchTxt:lower()) then
--     debugger(searchTxt .. " defID=" .. unitDefID .. ", name=" .. tostring(UnitDefs[unitDefID].translatedHumanName))
--     local index, foundUnitID = next(Spring.GetTeamUnitsByDefs ( aTeamNum, unitDefID)) -- return: nil | table unitTable = { [1] = number unitID, ... }
--     if foundUnitID then
--       debugger("teamID=" .. aTeamNum .. ", " .. searchTxt .. " unitID=" .. tostring(foundUnitID) .. ", defID=" .. unitDefID .. ", name=" .. tostring(UnitDefs[unitDefID].translatedHumanName)..", tableToString="..tableToString(unitDef))
--     end
--   end
-- end
-- for id,unitDef in pairs(UnitDefs) do
--   for name,param in unitDef:pairs() do
--     Spring.Echo(name,param)
--   end
-- end

-- local cUnit = teamsManager:createUnit(19913, 282, 0) -- my Commander
-- local aUnit = teamsManager:createUnit(5506, 244, 0) -- T2 Plane Factory
-- local bUnit = teamsManager:createUnit(13950, 245, 0) -- Adv. Con plane
-- local gUnit = teamsManager:createUnit(25549, 251, 0) -- Adv. Geothermal
-- local arr = {"constructor", "radar"}

-- local allyCUnit = teamsManager:createUnit(425, 49, 1) -- Ally Commander

-- local enemyCUnit = teamsManager:createUnit(24908, 49, 2) -- Enemy Commander


-- cUnit.parent:hasTypeEventRules(cUnit.defID) -- cUnit.parent:hasTypeEventRules(cUnit.defID, aType, event)
-- cUnit.parent:hasTypeEventRules(cUnit.defID, "commander")
-- cUnit.parent:hasTypeEventRules(cUnit.defID, "commander", "idle")
-- cUnit.parent:hasTypeEventRules(cUnit.defID, nil, "idle")


-- TestingArea
-- aUnit.debug = true

-- lastAlerts[aType][event]["lastNotify"] = 0
-- lastAlerts[aType][event]["alertCount"] = 0
-- lastAlerts[aType][event]["isQueued"] = false

-- local cUnitRules = cUnit:getTypesRulesForEvent("idle", true, true)
-- local aUnitRules = aUnit:getTypesRulesForEvent("idle", true, false)
-- local bUnitRules = bUnit:getTypesRulesForEvent("idle", true, true)
-- cUnit["lastAlerts"]["commander"]["idle"]["lastNotify"] = Spring.GetGameSeconds()
-- cUnit:getTypesRulesForEvent("idle", true, true)
-- local enemyCUnitRules = enemyCUnit:getTypesRulesForEvent("los", true, false)


-- if debug then debugger("LastAlert before="..tostring(cUnit["lastAlerts"]["commander"]["idle"]["lastNotify"])) end
-- local x, y, z = cUnit:getUnitPosition()
-- cUnit:setIdle()
-- cUnit.lastSetIdle = 0

-- debug = true
-- cUnit:getIdle()
-- teamsManager:alert()


-- teamsManager:addUnitToAlertQueue(cUnit,cUnitRules)
-- if debug then debugger("LastAlert after="..tostring(cUnit["lastAlerts"]["commander"]["idle"]["lastNotify"])) end
-- teamsManager:alert()
-- teamsManager:addUnitToAlertQueue(cUnit,cUnitRules)
-- if debug then debugger("LastAlert after2="..tostring(cUnit["lastAlerts"]["commander"]["idle"]["lastNotify"])) end
-- teamsManager:alert()



-- debugger("Starting tableToString="..tableToString(enemyCUnit.parent.defTypesEventsRules))

-- local kioi = {teamID=0, unitType="commander", event="idle", lastNotify=0, sharedAlerts=false, priority=2, reAlertSec=15, maxAlerts=false, alertCount=1, maxQueueTime=nil, alertSound="sounds/commands/cmd-selfd.wav", mark=nil, ping=false, threshMinPerc=.5, threshMaxPerc=0.9}
-- cUnit.parent:getTypesRulesForEvent(cUnit.defID, "idle", true, false)
-- debugger("Starting myCommander")
-- teamsManager:addUnitToAlertQueue( cUnit,cUnitRules )
-- debugger("Starting my T2 Plane Factory")
-- teamsManager:addUnitToAlertQueue(aUnit,aUnitRules )
-- debugger("Starting my Adv. Con plane")
-- teamsManager:addUnitToAlertQueue(bUnit,bUnitRules )
-- debugger("Starting Enemy Commander")
-- teamsManager:addUnitToAlertQueue(enemyCUnit,enemyCUnitRules )

-- alertQueue:insert(aUnit,kioi, 0)


-- alertQueue:insert(bUnit,kioi, 5) -- alertQueue:insert(value, alertRulesTbl, priority)
-- alertQueue:insert(cUnit,kioi, 2)
-- alertQueue:insert(gUnit,kioi, 2)
-- alertQueue:insert(gUnit,kioi, 1)
-- alertQueue:insert(aUnit,kioi, 5)
-- alertQueue:insert(allyCUnit,kioi, 2)
-- alertQueue:insert(enemyCUnit,kioi, 2)
-- alertQueue:insert(gUnit,kioi, 3)
-- alertQueue:insert(bUnit,kioi, 6)
-- alertQueue:insert(cUnit,kioi, .01)
-- debugger("alertQueue.heap[1]["priority"]=" .. tostring(alertQueue.heap[1]["priority"]) .. ", alertQueue.heap[2]["priority"]=" .. tostring(alertQueue.heap[2]["priority"]) .. ", alertQueue.heap[3]["priority"]=" .. tostring(alertQueue.heap[3]["priority"]))
-- local pull1a,pull1b = alertQueue:pull()
-- local pull2a,pull2b = alertQueue:pull()
-- local pull3a,pull3b = alertQueue:pull()
-- debugger("alertQueue:pull()=" .. tostring(pull1b) .. ", alertQueue.heap[2]["priority"]=" .. tostring(pull2b) .. ", alertQueue.heap[3]["priority"]=" .. tostring(pull3b))

-- NO tableToString unless it doesn't include "value" -- debugger("alertQueue.heap=" .. tableToString(alertQueue.heap))



local unitObj = cUnit
local teamID = nil -- cUnit.parent.teamID
local unitType = nil -- "commander"
local event = nil -- "idle"
local sharedAlerts = false
local priorityLessThan = 8



-- local matchedEvents = teamsManager:getQueuedEvents(unitObj,teamID,unitType,event,priorityLessThan,sharedAlerts)


-- NO tableToString unless it doesn't include "value" -- debugger("alertQueue.heap=" .. tableToString(alertQueue.heap))

-- local i = 1
-- while alertQueue:isEmpty() == false do
--   local val,alertRulesTbl, priority, gameSec = alertQueue:pull()
--   debugger(i .. " value=" .. type(val) .. ", alertRulesTbl=" .. type(alertRulesTbl) .. ", priority=" .. tostring(priority) .. ", gameSec=" .. tostring(gameSec))
--   i = i + 1
-- end


-- local kioi = {teamID=0, unitType="commander", event="idle", lastNotify=0, sharedAlerts=false, priority=2, reAlertSec=15, maxAlerts=0, alertCount=1, maxQueueTime=nil, alertSound="sounds/commands/cmd-selfd.wav", mark=nil, ping=false, threshMinPerc=.5, threshMaxPerc=0.9}
-- {teamID=, unitType=, event=, lastNotify=, sharedAlerts=, priority=, reAlertSec=, maxAlerts=, alertCount=, maxQueueTime=, alertSound=, mark=, ping=, threshMinPerc=, threshMaxPerc=}
-- {teamID=, unitType=, event=, lastNotify=, sharedAlerts=, priority=, reAlertSec=, maxAlerts=, alertCount=, maxQueueTime=, alertSound=, mark=, ping=, threshMinPerc=, threshMaxPerc=}
-- {teamID=, unitType=, event=, lastNotify=, sharedAlerts=, priority=, reAlertSec=, maxAlerts=, alertCount=, maxQueueTime=, alertSound=, mark=, ping=, threshMinPerc=, threshMaxPerc=}

-- :insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}

-- alertQueue:insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}

debug = false

-- for k, v in pairs(teamsManager.armies) do
--   debugger("Testing all teams. teamID=" .. tostring(v.teamID) .. ", allianceID=" .. tostring(v.allianceID) .. ", playerID0Name=" .. tostring(v.playerIDsNames[0]) .. ", playerID1Name=" .. tostring(v.playerIDsNames[1]))
-- end


-- ######################################## Utility functions start here #################################################

-- Spring.GetMyPlayerID() -- Returns the personID of whoever's running the code
-- Spring.GetMyTeamID() -- Returns the compID of whoever's running the code
-- Spring.GetAllyTeamList() -- Returns table of compIDs for all alliance members
-- Spring.GetMyAllyTeamID() -- Returns the allyID of whoever's running the code
-- Spring.GetTeamInfo(teamID) -- Returns compID info. return: nil | number teamID, number leader, bool isDead, bool isAiTeam, string "side", number allyTeam, number incomeMultiplier, table customTeamKeys
-- Spring.GetTeamList(allyTeamID)  -- Returns table of compIDs for all competitors, last is Gaia.
-- Spring.GetPlayerList(teamID [, onlyactive]) -- Returns table of personIDs for all humans
-- Spring.GetPlayerRoster() -- All person info. Other Players would be here, but all are AIs - number teamID, number leader, bool isDead, bool isAiTeam, string "side", number allyTeam, number incomeMultiplier, table customTeamKeys
-- Spring.GetTeamAllyTeamID(teamID) -- Returns allyID for the compID? Returns nil if the team does not exist.
-- Spring.Utilities.GetAllyTeamCount() -- Returns total number of alliances
-- Spring.GetGaiaTeamID() -- competitorID for environment, not considered an AI
-- Spring.MarkerAddPoint ( number x, number y, number z [, string text = "" [, bool localOnly ]] )
-- Spring.AreTeamsAllied(teamID1, teamID2)

-- Spring.GetUnitPosition(unitID)
-- Spring.GetUnitDefID
-- Spring.GetTeamUnitsByDefs(myTeamID, FactoryDefIDs)
-- Spring.GetTeamUnitsByDefs ( number teamID, number unitDefID | tableUnitDefs = { number unitDefID1, ... } ) -- return: nil | table unitTable = { [1] = number unitID, ... }
-- Spring.GetTeamUnits(teamId)
-- Spring.GetUnitTeam
-- Spring.GetCommandQueue
-- Spring.GetFactoryCommands
-- Spring.GetTeamUnits(teamId)
-- Spring.GetUnitCommands(unitId, -1)
-- Spring.GetFullBuildQueue(unitId)
-- Spring.ValidUnitID(unitId)
-- Spring.GetTeamUnitStats ( number teamID, string "metal" | "energy" ) -- return: nil | number used, number produced, number excessed, number received, number sent
-- Spring.GetTeamResources ( number teamID, string "metal" | "energy" ) -- return: nil | number currentLevel, number storage, number pull, number income, number expense, number share, number sent, number received
-- Spring.GetTeamUnitsSorted ( number teamID ) -- return: nil | table unitDefTable = { [number unitDefID] = { [1] = number unitID, ... }, ... }
-- Spring.GetUnitHealth ( number unitID ) -- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress -- Build progress is returned as floating point number between 0.0 and 1.0.
-- Spring.GetUnitResources ( number unitID ) -- return: nil | number metalMake, number metalUse, number energyMake, number energyUse
-- Spring.GetUnitMetalExtraction ( number unitID ) -- return: nil | number metalExtraction
-- Spring.GetUnitStockpile ( number unitID ) -- return: nil | number numStockpiled, number numStockpileQued, number buildPercent
-- Spring.GetUnitPosition ( number unitID [, bool midPos [, bool aimPos ]] ) -- return: nil | number basePointX, number basePointY, number basePointZ [, number midPointX, number midPointY, number midPointZ [, number aimPointX, number aimPointY, number aimPointZ ]] -- Since 89.0, returns the base (default), middle or aim position of the unit.
-- Spring.GetUnitSensorRadius ( number unitID, string type ) -- return: nil | number radius -- Possible types are: los, airLos, radar, sonar, seismic, radarJammer, sonarJammer
-- Spring.IsPosInRadar ( number x, number y, number z, number allyID ) -- return: bool isInRadar
-- Spring.IsAboveMiniMap ( number x, number y ) -- return: nil | bool isAbove
-- Spring.SendMessageToPlayer ( number playerID, string message ) -- return: nil

-- function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) end
-- function widget:GameStart() end -- Called upon the start of the game. Not called when a saved game is loaded.
-- function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID) end -- Called when a unit enters LOS of an allyteam. Its called after the unit is in LOS, so you can query that unit. The allyTeam is who's LOS the unit entered.
-- function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID) end -- Called when a unit leaves LOS of an allyteam. For widgets, this one is called just before the unit leaves los, so you can still get the position of a unit that left los.
-- function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam) end -- Called when a unit is loaded by a transport.
-- function widget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount) end -- Called when a units stockpile of weapons increases or decreases. See stockpile.
-- function widget:IsAbove(x, y) -- Called every Update. Must return true for Mouse* events and GetToolTip to be called.
-- function widget:GameID(gameID) -- Called once to deliver the gameID. As of 101.0+ the string is encoded in hex.
-- Spring.PlaySoundFile ( string soundfile [, number volume = 1.0 [, number posx [, number posy [, number posz [, number speedx[, number speedy[, number speedz[, number | string channel ]]]]]]]] )
-- function widget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture) -- return: bool allow -- Called just before a unit is transferred to a different team, the boolean return value determines whether or not the transfer is permitted.
-- local playerName, isActive, isSpectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customPlayerKeys = Spring.GetPlayerInfo(playerID ) -- return: nil | string "name", bool isActive, bool isSpectator, number teamID, number allyTeamID, number pingTime, number cpuUsage, string "country", number rank, table customPlayerKeys
-- Spring.GetPlayerRoster() gets all player/team/allyTeam information -- -- Returns playerName,playerID,teamID,allianceID,isSpectator,cpuUsage,pingTime

--[[ ################################### Building If Statements from Strings ####################################################################
local operators = {
  [">"] = function(x, y) return x > y end,
  ["="] = function(x, y) return x == y end,
  ["+"] = function(x, y) return x + y end, -- add more as needed
}

local op = ">" --  variable storing the operator as a string
local result = operators[op](var1, var2) -- calling the appropriate function

--========================================================================================================

str = { '>60', '>60', '>-60', '=0' }
del = 75

local operators = {
    [">"] = function(x, y) return x > y end,
    ["="] = function(x, y) return x == y end,
}

function decode_prog(var1, var2)
    local op = string.sub(var1, 1, 1) -- Fetch the arithmetic operator we intend to use.
    local number = tonumber(string.sub(var1, 2)) -- Strip the operator from the number string and convert the result to a numeric value.

    local result = operators[op](var2, number) -- Invoke the respective function from the operators table based on what character we see at position one.

    if result then
        print("condition met")
    else 
        print('condition not met')
    end
end

for i = 1, #str do
    decode_prog(str[i], del)
end

]]
--[[
    -- to call using a variable for method name:
    -- local aTest = "setIdle"
    -- unit[aTest](unit, 1234)
]]

-- how to remove item from alertQueue
    -- if matchedEvents then
    --   debugger("updating alertQueue.")
    --   alertQueue.heap[matchedEvents] = alertQueue.heap[size]
    --   alertQueue.heap[size] = nil
    --   alertQueue.size = size - 1
    --   alertQueue:_sink(1)
    -- end