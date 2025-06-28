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
local validEvents = {"idle","damaged","destroyed","created","finished","los","enteredAir","stockpile","thresholdHP"}
local validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "maxQueueTime", "alertSound", "mark", "ping", "threshMinPerc", "threshMaxPerc"} -- if sharedAlerts it also contains: alertCount, lastNotify. ELSE these are stored in the unit with unitObj.lastAlerts[unitType][event] = {lastNotify=num,alertCount=num} 
-- most validEventRules are used in getEventRulesNotifyVars(typeEventRulesTbl, unitObj)
-- mark = only you see. ping = ALL ALLIES see it. Be careful with ping
-- Priority from 0-10, default 5. 0 ignores minSecsBetweenNotifications
-- When a unit has 2+ types, both with rules for the same event (like idle), the event with the highest priority is always used. If all have same priority, probably randomly chosen


-- TODO: create rules for below types in makeRelTeamDefsRules()  #####################
-- TODO: Maybe make threshold a rule instead of event?

-- multiple event rules allowed, but must be unique. Example: myCommanderRules can'the have 2 "idle", but can have all events: idle, damaged, and finished...
-- units can have multiple types, like making the commander also have the constructor type. makeRelTeamDefsRules() is used to do that.
-- {type = {event = {rules}}}
local myCommanderRules = {idle = {priority=6, maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, damaged = {maxAlerts=0, reAlertSec=30, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, thresholdHP = {maxAlerts=0, reAlertSec=60, mark=nil, alertSound="sounds/commands/cmd-selfd.wav", threshMinPerc=.5, priority=0} } -- idle = {maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"},  will sound alert when Commander idle/15 secs, (re)damaged once per 30 seconds (unlimited), and when damage causes HP to be under 50%
local myConstructorRules = {idle = {sharedAlerts=true, maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, destroyed = {maxAlerts=0, reAlertSec=1, mark="Con Lost", alertSound=nil}}
local myFactoryRules = {idle = {maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}}
local myRezBotRules = {idle = {maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}}
local myMexRules = {destroyed = {maxAlerts=0, reAlertSec=1, mark="Mex Lost", alertSound=nil}}
local myEnergyGenRules = {finished = {maxAlerts=0, reAlertSec=1, mark=nil, alertSound=nil}, destroyed = {maxAlerts=0, reAlertSec=1, mark=nil, alertSound=nil}} -- reAlertSec only used if mark/sound wanted. Saved so custom code can do something with the information.
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
local allyCommanderRules = {} -- Won't track
local allyConstructorRules = {}
local allyFactoryRules = {}
local allyFactoryT2Rules = {finished = {maxAlerts=1, reAlertSec=15, mark="T2 Ally", alertSound=nil}} -- So you know to badger them for a T2 constructor ;)
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
local enemyCommanderRules = {los = {maxAlerts=0, reAlertSec=30, mark="Commander", alertSound=nil, priority=0} } -- will mark "Commander" at location when (re)enters LoS, once per 30 seconds (unlimited)
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
local enemyNukeDefenseRules = {}
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
	nukeDefense = enemyNukeDefenseRules
}
local trackSpectatorTypesRules = {}
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

local UpdateInterval = 30
local TestSound = 'sounds/commands/cmd-selfd.wav'

table.insert(validEventRules,"lastNotify") -- add system only rules
table.insert(validEventRules,"alertCount") -- add system only rules

local myTeamID = Spring.GetMyTeamID()
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

local priorityQueue = {}
priorityQueue.__index = priorityQueue
function priorityQueue:new()
  local queue = {
    heap = {},
    size = 0
  }
  return setmetatable(queue, self)
end
-- validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "maxQueueTime", "alertSound", "mark", "ping", "threshMinPerc", "threshMaxPerc"} -- if sharedAlerts it also contains: alertCount, lastNotify. ELSE these are stored in the unit with unitObj.lastAlerts[unitType][event] = {lastNotify=num,alertCount=num} 
function priorityQueue:insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
  self.size = self.size + 1
  self.heap[self.size] = {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
  self:_swim(self.size)
end

function priorityQueue:pull() -- Returns/Removes the highest priority with vars: value, alertRulesTbl, priority, queuedTime
  if self:isEmpty() then
    return nil, nil
  end
  local top = self.heap[1]
  if self.size > 1 then
    self.heap[1] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1
    self:_sink(1)
  else
    self.heap[1] = nil
    self.size = 0
  end
  return top.value, top.alertRulesTbl, top.priority, top.queuedTime
end

function priorityQueue:peek(heapNum) -- Returns/Keeps the top/requested element, returning vars: value, alertRulesTbl, priority, queuedTime
  if self:isEmpty() or (type(heapNum) ~= "nil" and type(heapNum) ~= "number") or (type(heapNum) == "number" and (heapNum < 1 or heapNum > self.size)) then
    debugger("priorityQueue:peek(). ERROR. Invalid heapNum=" .. tostring(heapNum))
    return nil, nil
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
  local oldDebug = debug
  debug = false
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
  debug = oldDebug
  return allValid
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
  aUnit:setTypes(defID)  -- Probably doesn't belong here unless there's a way to import user config into setTypes()
  if UnitDefs[defID].isFactory then
    aUnit.isFactory = true -- needs to be here because idle check is different for factories
  end
  local gameSecs = Spring.GetGameSeconds()
  aUnit.created = gameSecs
  self.lastUpdate = gameSecs
  aUnit.lastUpdate = gameSecs
  aUnit.lastSetIdle = gameSecs - 5  -- If didn't set, then would throw error for trying to use math on a nil value
  if debug or self.debug then debugger("createUnit 9. aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID)) end
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

function pArmyManager:getTypesRulesForEvent(defID, event, topPriorityOnly) -- defID, string event, bool/nil (default false) topPriorityOnly. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}
  if debug or self.debug then debugger("pArmyManager:getTypesRulesForEvent 1. teamID=" .. self.teamID .. ", defID=" .. tostring(defID) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly)) end
  if type(defID) ~= "number" or type(event) ~= "string" or (type(topPriorityOnly) ~= "boolean" and topPriorityOnly ~= nil) then
    debugger("pArmyManager:getTypesRulesForEvent 2. ERROR. defID NOT number or event not string. teamID=" .. self.teamID .. ", defID=" .. tostring(defID) .. ", event=" .. tostring(event))
    return nil
  end
  local typesEventRules = self.defTypesEventsRules[defID] -- {defID = {type = {event = {rules}}}}
  if typesEventRules == nil or (type(typesEventRules) == "table" and next(typesEventRules) == nil) then
    if debug or self.debug then debugger("pArmyManager:getTypesRulesForEvent 3. Returning nil, defID not in defTypesEventsRules or empty event table. defID=" .. tostring(defID)) end
    return nil
  elseif type(typesEventRules) ~= "table" then
    debugger("pArmyManager:getTypesRulesForEvent 4. ERROR. typesEventRules NOT table. Returning nil. teamID=" .. self.teamID .. ", defID=" .. type(typesEventRules))
    return nil
  end
  local typesWithEventRules = {}
  local matches = 0
  local priorityNum = nil
  for aType, eventsTbl in pairs(typesEventRules) do -- {type = {event = {rules}}}
    if debug then debugger("pArmyManager:getTypesRulesForEvent 5. aType=" .. tostring(aType) .. ", typesEventRules=" .. type(eventsTbl) .. ", event=" .. tostring(event)) end
    if type(eventsTbl) ~= "table" then
      if debug then debugger("pArmyManager:getTypesRulesForEvent 6. Events NOT a table. Will continue to look for other good ones. aType=" .. tostring(aType) .. ", typesEventRules=" .. type(eventsTbl) .. ", event=" .. tostring(event)) end
    else
      local eventMatch = eventsTbl[event]
      if type(eventMatch) == "table" and next(eventMatch) ~= nil then
        if type(eventMatch["priority"]) ~= "number" then
          eventMatch["priority"] = 5
        end
        if not topPriorityOnly then
          if debug then debugger("pArmyManager:getTypesRulesForEvent 7. Adding match to tmpEventTbl. aType=" .. tostring(aType) .. ", event=" .. tostring(event)) end
          typesWithEventRules[aType] = {[event] = eventMatch}
          matches = matches + 1
        else
          local tmpType, tmpEventTbl = next(typesWithEventRules)
          if type(priorityNum) == "number" and eventMatch["priority"] < priorityNum and tmpType then
            if debug then debugger("pArmyManager:getTypesRulesForEvent 8. Removing previous topPriority tmpType=" .. tostring(tmpType) .. ", priorityNum=" .. tostring(priorityNum) .. ", because new priorityNum=" .. tostring(eventMatch["priority"])) end
            typesWithEventRules[tmpType] = nil
            matches = 0
          end
          tmpType, tmpEventTbl = next(typesWithEventRules)
          if type(tmpType) == "nil" or type(tmpEventTbl) == "nil" then
            priorityNum = eventMatch["priority"]
            if debug then debugger("pArmyManager:getTypesRulesForEvent 9. Adding new topPriority typeTbl to array. type aType=" .. tostring(aType) .. ", with priorityNum=" .. tostring(priorityNum)) end
            typesWithEventRules[aType] = {[event] = eventMatch}
            matches = 1
          end
        end
      end
    end
  end
  if matches == 0 then
    if debug then debugger("pArmyManager:getTypesRulesForEvent 10. No matches, returning nil. event=" .. tostring(event) .. ", typesEventRules=" .. tableToString(typesWithEventRules)) end
    return nil
  end
  if debug then debugger("pArmyManager:getTypesRulesForEvent 11. Returning matches=" .. tostring(matches) .. ", event=" .. tostring(event) .. ", typesEventRules=" .. type(typesWithEventRules)) end
  return typesWithEventRules -- {type = {event = {rules}}}
end

function pArmyManager:hasTypeRules(defID)
  if debug or self.debug then debugger("pArmyManager:hasTypeRules 1. defID=".. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pArmyManager:hasTypeRules 2. INVALID input. Returning nil.") return nil end
  local typeRules = self.defTypesEventsRules[defID]
  if typeRules == nil then
    if debug or self.debug then debugger("pArmyManager:hasTypeRules 3. Unit has no typeRules in defTypesEventsRules. returning false. defID=".. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
    return false
  end
  local type1, event1 = next(typeRules)
  if type(event1) ~= "table" then
    if debug or self.debug then debugger("pArmyManager:hasTypeRules 4. Unit has a type, but no Rules in defTypesEventsRules. returning false. defID=".. tostring(defID) .. ", teamID=".. tostring(self.teamID) .. ", types=" .. tostring(type1)) end
    return false
  end
  if debug or self.debug then debugger("pArmyManager:hasTypeRules 5. SUCCESS. Rules found in defTypesEventsRules. returning true. defID=".. tostring(defID) .. ", teamID=".. tostring(self.teamID) .. ", types=" .. tostring(type1)) end
  return true
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
    if self.parent:getTypesRulesForEvent(self.defID, "idle") then
      if type(self.parent["idle"]) ~= "table" then
        self.parent["idle"] = {}
      end
      if type(self.parent["idle"]) == "table" and self.parent["idle"][self.ID] == nil then
        self.parent["idle"][self.ID] = self
      end
      if type(idlingUnits[self.ID]) == "nil" then
        idlingUnitCount = idlingUnitCount + 1
        idlingUnits[self.ID] = 1
        warnFrame = 1 -- skip immediate warning. Some units are idle very briefly after finishing their previous work
      end
    end
    self.lastSetIdle = Spring.GetGameFrame()
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setIdle 2. Has been setIdle. GameFrame(" .. Spring.GetGameFrame() .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end

function pUnit:setNotIdle()
  if debug or self.debug then debugger("setNotIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if self.isIdle then
    self.isIdle = false
    if self.parent:getTypesRulesForEvent(self.defID, "idle") then
      if type(self.parent["idle"]) ~= "table" then
        self.parent["idle"] = {}
      end
      if type(self.parent["idle"]) == "table" and self.parent["idle"][self.ID] ~= nil then
        self.parent["idle"][self.ID] = nil
      end
      if idlingUnits[self.ID] ~= nil then
        idlingUnits[self.ID] = nil
        idlingUnitCount = idlingUnitCount - 1
      end
    end
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setNotIdle 2. Has been setNotIdle. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end
-- ATTENTION!!! ###### This waits 5 frames before returning that it is idle because some units are idle very briefly before starting on the next queued task
function pUnit:getIdle()
  if debug or self.debug then debugger("getIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(self.ID) -- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress
  if buildProgress < 1 then
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
    if debug or self.debug then debugger("getIdle 4. Constructor with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
  if debug or self.debug then debugger("getIdle 5. GameFrame(" .. Spring.GetGameFrame() .. ", Queue=" .. tostring(count) .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if count > 0 then
    if debug or self.debug then debugger("getIdle 6. Wasn't actually Idle. Calling setNotIdle to correct it. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    self:setNotIdle()
    return false -- doing it this way because for some reason then function receiving self.isIdle gets nil every time?
  elseif self.isIdle == false then
    self:setIdle()  -- lastSetIdle is only set when becoming idle from being not idle. Which means it will return false below to allow the extra second to prevent false positives
    if debug or self.debug then debugger("getIdle 7. Was actually Idle, corrected. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
  if self.isIdle and Spring.GetGameFrame() < self.lastSetIdle + 5 then -- because it may be idle very briefly before starting on the next queued task
    if debug or self.debug then debugger("getIdle 8. Hasn't been idle for a second. Returning false. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    return nil -- So that you can know if waiting for time to pass
  else
  if debug or self.debug then debugger("getIdle 9. Returning " .. tostring(self.isIdle) .. ". cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  return true -- doing it this way because for some reason then function receiving self.isIdle gets nil every time?
  end
end

-- TODO: Update to use relevant table
function pUnit:setLost(destroyed)
  if debug or self.debug then debugger("setLost 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed)) end
  if type(destroyed) ~= "nil" and type(destroyed) ~= "boolean" then
    debugger("setLost 2. ERROR. destroyed NOT nil or bool. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed))
  end
  if type(destroyed) == "nil" or destroyed == true then
    destroyed = true
  else
    destroyed = false
  end
  if destroyed then -- Mark isLost only when unit destroyed, not when given/stolen
    self.isLost = true
    if debug or self.debug then debugger("setLost 3. Marked isLost = true.") end
  end
  self:setNotIdle() -- Removes it from idle lists/queues
  self.parent.unitsLost[self.ID] = self
  self.parent.units[self.ID] = nil
  -- ######################## update to have it loop through all unit type lists ############################
  if type(self.parent.commanders[self.ID]) ~= "nil" then
    self.parent.commanders[self.ID] = nil
  end
  if type(self.parent.builders[self.ID]) ~= "nil" then
    self.parent.builders[self.ID] = nil
  end
  if type(self.parent.constructors[self.ID]) ~= "nil" then
    self.parent.constructors[self.ID] = nil
  end
  if type(self.parent.factories[self.ID]) ~= "nil" then
    self.parent.factories[self.ID] = nil
  end
  if type(self.parent.rezbots[self.ID]) ~= "nil" then
    self.parent.rezbots[self.ID] = nil
  end

  -- TODO: Remove above when ready
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
  self.lost = Spring.GetGameSeconds()
  self.lastUpdate = Spring.GetGameSeconds()
  return self
end

function pUnit:getTypesRules(types) -- Nil for all, string for one, or array of strings input. Should not store in unit, since it can move between teams. The armyManagers define which units are important to track.
  if debug or self.debug then debugger("getTypesRules 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(types) .. ", translatedHumanName=" .. UnitDefs[self.defID].translatedHumanName) end
  if self:hasTypeRules() == false then
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

function pUnit:getTypesRulesForEvent(event, topPriorityOnly) -- defID, string event. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}
  if debug or self.debug then debugger("pUnit:getTypesRulesForEvent 1. Returning self.parent:getTypesRulesForEvent(" .. tostring(self.defID) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly) .. "), unitID=" .. tostring(self.ID) .. ", teamID=".. tostring(self.parent.teamID)) end
  return self.parent:getTypesRulesForEvent(self.defID, event, topPriorityOnly)
end

-- ################################################## Custom/Expanded Unit methods starts here #################################################

-- TODO: Remove top to leave new at bottom
-- Where should this go? How to make it easily USER CONFIG expandable? ############################################
function pUnit:setTypes()
  if debug or self.debug then debugger("setTypes 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  -- ######################## update to have it loop through all unit type lists ############################
  local tmpBuilderUnitDefID = BuilderUnitDefIDs[self.defID]
  if tmpBuilderUnitDefID ~= nil and tmpBuilderUnitDefID > 0 and tmpBuilderUnitDefID < 4 then
    if debug or self.debug then debugger("setTypes 2. isBuilder ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isBuilder = true
    self.parent.builders[self.ID] = self -- Add to builders array
  end
  if tmpBuilderUnitDefID == 1 and idleCommanderAlert then
    if debug or self.debug then debugger("setTypes 3. isCommander ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isCommander = true
    self.parent.commanders[self.ID] = self -- Add to commanders array
  elseif tmpBuilderUnitDefID == 2 and idleConAlert then
    if debug or self.debug then debugger("setTypes 4. isConstructor ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isConstructor = true
    self.parent.constructors[self.ID] = self -- Add to constructors array
  elseif tmpBuilderUnitDefID == 3 and idleFactoryAlert then
    if debug or self.debug then debugger("setTypes 5. isFactory ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isFactory = true
    self.parent.factories[self.ID] = self -- Add to factories array
  elseif tmpBuilderUnitDefID == 4 and idleRezAlert then
    if debug or self.debug then debugger("setTypes 6. isRezBot ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isRezBot = true
    self.parent.rezBots[self.ID] = self -- Add to rezBots array
  end

  -- NEW. Get rid of old above
  if UnitDefs[self.defID].isFactory then
    self.isFactory = true
  end
  local unitTypes = self:getTypesRules() -- {type = {event = {rules}}}}
  if debug or self.debug then debugger("setTypes X. translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)) end
  if unitTypes ~= nil then
    for aType, event1 in pairs(unitTypes) do
      if self.parent[aType] == nil then
        self.parent[aType] = {}
        if debug or self.debug then debugger("setTypes Y. parent[" .. tostring(aType) .. "] just created with type=" .. type(self.parent[aType]) .. ". translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      end
      self.parent[aType][self.ID] = self
      if debug or self.debug then debugger("setTypes Z. Added self to parent[" .. tostring(aType) .. "], with type=" .. type(self.parent[aType]) .. ". translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    end
  end
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pUnit:hasTypeRules()
  if debug or self.debug then debugger("pUnit:hasTypeRules 1. SHELL returns from armyManager ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  return self.parent:hasTypeRules(self.defID)
end

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
  for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.iscommander and (next(trackMyTypesRules["commander"]) ~= nil or next(trackAllyTypesRules["commander"]) ~= nil or next(trackEnemyTypesRules["commander"]) ~= nil) then
      if debug then debugger("Assigning Commander BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      addToRelTeamDefsRules(unitDefID, "commander")
      addToRelTeamDefsRules(unitDefID, "constructor")
    elseif unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1] or (idleRezAlert and unitDef.canResurrect)) and not unitDef.customParams.isairbase then
      if unitDef.canAssist or unitDef.canAssist and (next(trackMyTypesRules["constructor"]) ~= nil or next(trackAllyTypesRules["constructor"]) ~= nil or next(trackEnemyTypesRules["constructor"]) ~= nil) then     -- check is this constructor was: unitDef.canConstruct and unitDef.canAssist 
        addToRelTeamDefsRules(unitDefID, "constructor")
        if debug then debugger("Assigning Constructor BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      elseif unitDef.isFactory and (next(trackMyTypesRules["factory"]) ~= nil or next(trackAllyTypesRules["factory"]) ~= nil or next(trackEnemyTypesRules["factory"]) ~= nil) then
        if debug then debugger("Assigning Factory BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "factory")
        -- table.insert(FactoryDefIDs, unitDefID) -- Needed?
      elseif idleRezAlert and unitDef.canResurrect and (next(trackMyTypesRules["rezBot"]) ~= nil or next(trackAllyTypesRules["rezBot"]) ~= nil or next(trackEnemyTypesRules["rezBot"]) ~= nil) then -- RezBot optional using idleRezAlert
        if debug then debugger("Assigning RezBot BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
        addToRelTeamDefsRules(unitDefID, "rezBot")
      end
    end
    -- if mex, radar...
    -- if next(trackAllMyUnitsRules) ~= nil or next(trackAllEnemyUnitsRules) ~= nil or next(trackAllAlliedUnitsRules) ~= nil then
      -- -- figure out how to do this. something like {hp, coords, destroyed}
    -- end
  end
end

-- OLD #### replaced by above
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1] or (idleRezAlert and unitDef.canResurrect)) and not unitDef.customParams.isairbase then
		if unitDef.customParams.iscommander then
			BuilderUnitDefIDs[unitDefID] = 1
      if debug then debugger("Assigning Commander BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
		elseif unitDef.canAssist or unitDef.canAssist then     -- check is this constructor was: unitDef.canConstruct and unitDef.canAssist 
			BuilderUnitDefIDs[unitDefID] = 2
      if debug then debugger("Assigning Constructor BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
		elseif unitDef.isFactory then  -- check is this factory
      if debug then debugger("Assigning Factory BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
			BuilderUnitDefIDs[unitDefID] = 3
			table.insert(FactoryDefIDs, unitDefID)
		elseif idleRezAlert and unitDef.canResurrect then -- RezBot optional using idleRezAlert
      if debug then debugger("Assigning RezBot BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
			BuilderUnitDefIDs[unitDefID] = 4
		else
    end
	end
end

-- TODO: Is this really needed? This is more for debugging in case someone spells the type wrong OR doesn't add it to the validEvents list.
local function validEvent(event) -- Tells whether event is in table of valid events
  if debug then debugger("validEvent 1. event=" .. tostring(event)) end
  for _, value in ipairs(validEvents) do
    if value == event then
      return true
    end
  end
  return false
end

-- TODO: Is this really needed? This is more for debugging in case someone messes up event definitions.
-- Maybe have it just test all rules at once?

local function validTypeEventRulesTbls(typeTbl) -- , returnCounts returnCounts returns the count of each type/event/rule
  if debug then debugger("validTypeEventRulesTbls 1. event=" .. type(typeTbl)) end
  if type(typeTbl) ~= "table" then
    debugger("validTypeEventRulesTbls 2. ERROR. Returning False. Not eventTbl=" .. type(typeTbl))
    return false
  end
  local typeCount = 0
  local eventCount = 0
  local ruleCount = 0
  local badValue = nil
  for aType,eventTbl in pairs(typeTbl) do -- Types not tracked. If needed, add later
    typeCount = typeCount +1
    if type(eventTbl) ~= "table" then
      debugger("validTypeEventRulesTbls 3. ERROR. Returning False. Not Table eventTbl=" .. type(eventTbl))
      return false
    end
    for anEvent,rulesTbl in pairs(eventTbl) do
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
        debugger("validTypeEventRulesTbls 4. ERROR. Returning False. Bad value=" .. tostring(badValue) .. " in eventTbl=" .. tableToString(eventTbl))
        return false
      end
      if type(rulesTbl) ~= "table" then
        debugger("validTypeEventRulesTbls 4. ERROR. Returning False. Not Table rulesTbl=" .. type(rulesTbl))
        return false
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
          debugger("validTypeEventRulesTbls 5. ERROR. Returning False. Bad value=" .. tostring(badValue) .. " in rulesTbl=" .. tableToString(rulesTbl))
          return false
        end
      end
    end
  end
  if debug then debugger("validTypeEventRulesTbls 6. SUCCESS. typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", ruleCount=" .. tostring(ruleCount)) end
  return true,typeCount,eventCount,ruleCount
end
-- validEvents = {"idle","damaged","destroyed","created","finished","los","enteredAir","stockpile","thresholdHP"}
-- validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "maxQueueTime", "alertSound", "mark", "ping", "threshMinPerc", "threshMaxPerc"} -- if sharedAlerts it also contains: alertCount, lastNotify. ELSE these are stored in the unit with unitObj.lastAlerts[unitType][event] = {lastNotify=num,alertCount=num} 

-- ################################################# Idle Alerts start here #################################################


function widget:PlayerChanged(playerID)
    myTeamID = Spring.GetMyTeamID()
	isSpectator = Spring.GetSpectatingState()
	if isSpectator then
		widgetHandler:RemoveWidget()
	end
end

-- TODO: Remove as it is relaced by new defTypesEventsRules logic
local function isBuilder(unitDefID)
    return BuilderUnitDefIDs[unitDefID] ~= nil
end

-- TEST if used. UNFINISHED
-- Maybe rename to getTypeEvents? and make it a unit method?
local function hasEventAlerts(unitID, defID, teamID, event)
  if debug then debugger("hasEventAlerts 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then debugger("hasEventAlerts 2. INVALID input. Returning nil.") return nil end
  if not validEvent(event) then debugger("hasEventAlerts 3. ERROR. Bad input value event=" .. tostring(event)) return nil end
  local army = teamsManager:getArmyManager(teamID)
  if army == nil then
    debugger("hasEventAlerts 4. ERROR. Army NOT FOUND. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event))
    return nil
  end
  local typeRulesTbl = army.defTypesEventsRules[defID] -- {defID = {type = {event = {rules}}}}
  if type(typeRulesTbl) ~= "table" then
    if debug then debugger("hasEventAlerts 5. DefID not in defTypesEventsRules or not table. typeRulesTbl=" .. type(typeRulesTbl) .. ", unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
    return nil
  end
  local unitType, eventsRulesTbl = next(typeRulesTbl, nil)
  -- TODO: I could validate user configured tables' structure all at once, instead of every time... HOWEVER, they COULD be accidentally messed up afterwards and be a pain to find?
  if type(unitType) ~= "string" or type(eventsRulesTbl) ~= "table" then
    debugger("hasEventAlerts 6. ERROR. Bad Type string=" .. type(unitType) .. " or Bad eventsRulesTbl=" .. type(eventsRulesTbl) .. ", unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event))
    return nil
  end
  if eventsRulesTbl[event] == nil then
    if debug then debugger("hasEventAlerts 7. Event not found for unit. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
  end
  local eventRules = eventsRulesTbl[event]
  if eventRules == nil or type(eventRules) ~= "table" then
    if debug then debugger("hasEventAlerts 7. eventRules not found. unitType=" .. tostring(unitType) .. ", eventRulesType=" .. type(eventRules) .. ", unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
    return nil
  end
  -- we finally know the type should have some rules! Might as well make sure it is tracked in an armyManager.
  local unit = army:getUnit(unitID)
  if unit == nil then -- not in army, but could have been given outside los. CreatUnit now handles that possibility
    unit = army:createUnit(unitID, defID)
    if unit == nil then
      debugger("hasEventAlerts 8. ERROR creating unit. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event))
      return nil
    end
  end

  
  local maxAlerts = eventsRulesTbl["maxAlerts"]
  local reAlertSec = eventsRulesTbl["reAlertSec"]
  local mark = eventsRulesTbl["mark"]
  local ping = eventsRulesTbl["ping"]
  local alertSound = eventsRulesTbl["alertSound"]
  local threshMinPerc = eventsRulesTbl["threshMinPerc"]
  local threshMaxPerc = eventsRulesTbl["threshMaxPerc"]
  local priority = eventsRulesTbl["priority"]


  if mark ~= nil or ping ~= nil or alertSound ~= nil then
    if debug then debugger("hasEventAlerts 9. Found 1+ alerts for unitType-event. unitType=" .. tostring(unitType) .. ", eventMatch=" .. type(eventRules) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
    if type(maxAlerts) ~= "number" or type(reAlertSec) ~= "number" then -- make a function validate this stuff?
      debugger("hasEventAlerts 10. ERROR. Invalid maxAlerts(" .. tostring(maxAlerts) .. ") or reAlertSec(" .. tostring(reAlertSec) .. "). Returning nil. unitType=" .. tostring(unitType) .. ", eventMatch=" .. tostring(eventRules) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event))
      return nil
    end

    -- should type tags be added to units? Could be useful. 

    -- If numPastNotify <= maxAlerts and isQueued(uType, event)
      -- if "priority" == 0 or "0" then 
        -- notify() 
      -- else
        -- add to queuedAlerts with { priority[1-10] = {type = {event = {rules}}}}
          -- Checks all of type before alerting, applies to any of type that meet event-rules. Might use more than one ping
      -- end
      -- 
    -- How do I track maxAlerts? Shouldn't be in the unit's army, as maxAlerts would be spread throughout the teams that leaves TeamsManager or MyArmy
    -- Still, how do I track it in one of those? Using the Types/Groups system already built. With myArmyAlertTracking{ [type] = { [event] = {times = #, lastAlert = gameSecs} } }
    -- or with ...Manager.typesAlertNum[type].[event].times = #
  end
  -- Process the rules to see if something needs to be done
  -- custom logic for events. Notifications come later
  if event == "idle" then
    unit:setIdle()
    -- special rules 
  elseif event == "created" then -- already created above
    -- special rules 
  elseif event == "finished" then -- already created above
    -- special rules 
  elseif event == "enteredAir" then
    -- special rules 
  elseif event == "los" then
    -- special rules 
  elseif event == "stockpile" then
    -- special rules 
  elseif event == "damaged" or "destroyed" then
    -- special rules 
    if event == "damaged" or "thresholdHP" then
      -- UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) end
      local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(unitID) -- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress
      -- How to get Call-in data to here? Global "event" var stores them?
      -- special rules 
    end
    if event == "destroyed" then
      unit:setLost()
      -- special rules 
    end
  else
  end

  
  -- if notify: mark ~= nil or ping ~= nil or alertSound ~= nil 
    -- notify
  

end

-- if there's type rules, AND the unit's event matches a type... @@@@@@$$$$$$$$$$$$$$$$##################^^^^^^^^^^^^^^^^^^^^%%%%%%%%%%%%%%%%%%
-- build logic for maxAlerts=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav" (Track in armyManager or teamsManager?) Stored how?
-- {destroyed = {maxAlerts=0, reAlertSec=1, mark=nil, alertSound=nil}} -- No alert means it only destroyed enemy mex will be tracked. To have it track alive mex, use "los"

-- events: idle,damaged,destroyed,created,finished,los,enteredAir,stockpile,

-- TODO: REPLACED ALREADY???
-- The isRelevantEvent function decides whether the Lua Callin Return type (damage, idle, completed, ...) is relevant for the unit type/teamID based on what the configuration.
-- Replaced with getEventRules, an ARMY method
local function isRelevantEvent(unitID, defID, teamID, event) -- ??
-- debug = true
if debug then debugger("isRelevantEvent 1 UnitDefID[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", teamID=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", event=" .. tostring(event)) end
  if not teamsManager:validIDs(nil, nil, true, defID, true, teamID, nil, nil, nil, nil) then debugger("isRelevantEvent 2. INVALID input. Returning nil.") return nil end
  if not validEvent(event) then debugger("isRelevantEvent 3. ERROR. Bad input value event=" .. tostring(event)) return nil end
  -- if spectator then
  --   --something
  local relTeamUnitDefRules
  if teamID == myTeamID then
    relTeamUnitDefRules = relevantMyUnitDefsRules
  elseif teamsManager:isAllied(teamID) then
    relTeamUnitDefRules = relevantAllyUnitDefsRules
  else -- Add Spectator?
    relTeamUnitDefRules = relevantEnemyUnitDefsRules
  end
  local typesEventRules = relTeamUnitDefRules[defID]
  if type(typesEventRules) ~= "table" then
    return false
  end
  for aType, eventsTbl in pairs(typesEventRules) do -- {defID = {type = {event = {rules}}}}
    if debug then debugger("isRelevantEvent 4. k=" .. tostring(aType) .. ", v=" .. tostring(eventsTbl) .. ", event=" .. event) end
    if type(eventsTbl[event]) == "table" then
      if debug then debugger("isRelevantEvent 5 Returning True. k=" .. tostring(aType) .. ", v=" .. tableToString(eventsTbl[event]) .. ", event=" .. event) end
      return true
    end
  end
  if debug then debugger("isRelevantEvent 6 Returning False.") end
  return false
end


-- Updated but new stuff is DISABLED ############# THIS SHOULD BE AN ARMYMANAGER METHOD
local function isUnitRelevant(defID, teamID)
  if debug then debugger("isUnitRelevant 1. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitTeam=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", isBuilder(unitDefID)=" .. tostring(isBuilder(defID))) end
	local army = teamsManager:getArmyManager(teamID)
  if army == nil then
    debugger("isUnitRelevant 2. ERROR. Army NOT FOUND. Returning nil. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitTeam=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", isBuilder(unitDefID)=" .. tostring(isBuilder(defID)))
    return nil
  end
  if debug then debugger("isUnitRelevant 3. Returning=" .. tostring(army.defTypesEventsRules[defID]) .. ", UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitTeam=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", isBuilder(unitDefID)=" .. tostring(isBuilder(defID))) end
  return army:hasTypeRules(defID)
end

local function isUnitIdle(unitID)
	if type(unitID) == "nil" and type(Spring.GetUnitDefID(unitID)) == "nil" then
    if debug then debugger("isUnitIdle. Somehow no unitID=" .. tostring(unitID) .. ", or not Spring.GetUnitDefID(unitID)?") end
    -- Spring.Echo("isUnitIdle. Somehow no unitID=" .. tostring(unitID) .. ", or not Spring.GetUnitDefID(unitID)?")
    -- ArmyManager.getUnit to return unit
    -- Unit method isUnitIdle 
    local count = spGetCommandQueue(unitID, 0)
	  return count == 0
		-- return false
	end




	local _, _, _, _, buildProgress = spGetUnitHealth(unitID) -- GetUnitHealth(unitID): return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress
	if buildProgress < 1 then
    if debug then debugger("isUnitIdle NOT BUILT. buildProgress=" .. buildProgress .. ", Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]) end
		-- Spring.Echo("isUnitIdle NOT BUILT. buildProgress=" .. buildProgress .. ", Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)])
		return false
	end
  if debug then debugger("isUnitIdle Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]) end
  -- Spring.Echo("isUnitIdle Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)])
	local builderType = BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]
	if builderType == 3 then -- Factory
    local cmdLen = Spring.GetFactoryCommands(unitID, 0)      -- This is best to use for just total units requested
    if debug then debugger("isUnitIdle FACTORY unitID[" .. unitID .. "], count=" .. cmdLen) end
    --Spring.Echo("isUnitIdle FACTORY unitID[" .. unitID .. "], count=" .. cmdLen)
		return cmdLen == 0
	end
  local cmdLen = spGetCommandQueue(unitID, 0)
  if debug then debugger("isUnitIdle unitID[" .. unitID .. "], count=" .. cmdLen) end
  --Spring.Echo("isUnitIdle unitID[" .. unitID .. "], count=" .. count)
	return cmdLen == 0
end

local function markUnitAsIdle(unitID)
	if type(idlingUnits[unitID]) == "nil" then
	  idlingUnitCount = idlingUnitCount + 1
		idlingUnits[unitID] = 1
		warnFrame = 1 -- skip immediate warning. Some units are idle very briefly after finishing their previous work
	end
end

local function markUnitAsNotIdle(unitID)
	if idlingUnits[unitID] ~= nil then
    	idlingUnits[unitID] = nil
		idlingUnitCount = idlingUnitCount - 1
	end
end

local function maybeMarkUnitAsIdle(unitID, defID, teamID) -- TODO: Should be unnecessary because unit:setIdle should take care of this
	if debug then debugger("maybeMarkUnitAsIdle 1. unitID=" .. tostring(unitID) .. ", defID=" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitTeam=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID)) end
	-- if isUnitRelevant(defID, teamID) and isUnitIdle(unitID) then
  local army = teamsManager:getArmyManager(teamID)
  if army and army:hasTypeRules(defID) then
    army:getOrCreateUnit(unitID, defID):getIdle()
		-- markUnitAsIdle(unitID)
	end
end

function widget:UnitIdle(unitID, defID, teamID)
  if debug then debugger("widget:UnitIdle 1. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID)) end
	-- Spring.Echo("UnitIdle. Check Botlab spGetFactoryCommands(26761,0)=" .. spGetFactoryCommands(26761, 0) .. ", translatedHumanName=" .. UnitDefs[362].translatedHumanName)
	-- This will be called by ArmyManager to check if the unit is relevant for the armyManager
  local anArmy = teamsManager:getArmyManager(teamID)
  local unit
  if anArmy and anArmy:getTypesRulesForEvent(defID, "idle") then
    unit = teamsManager:getOrCreateUnit(unitID, defID, teamID)
    if unit == nil then
      debugger("widget:UnitIdle 2. ERROR. Failed getOrCreateUnit. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID))
      return nil
    end
  else
    if debug then debugger("widget:UnitIdle 3. No event for unit. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID)) end
    return nil
  end
  -- local relEvent = isRelevantEvent(unitID, defID, teamID, "idle")
  -- if debug then debugger("widget:UnitIdle 22. isRelevantEvent=" .. tostring(relEvent) .. ", UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID)) end
  

  -- if isUnitRelevant(defID, teamID) then
  -- if teamsManager:getArmyManager(teamID):hasTypeRules(defID) then
    -- if debug then debugger("widget:UnitIdle 2. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID)) end
    -- local unit = teamsManager:getUnit(unitID,teamID)
    -- if unit == nil then
    --   unit = teamsManager:createUnit(unitID, defID, teamID)
    -- end
    -- if unit == nil then
    --   debugger("widget:UnitIdle 3. ERROR. Unit NOT CREATED. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID))
    -- end
    if debug then debugger("widget:UnitIdle 4. Going to setIdle. UnitDefs[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", unitID=" .. tostring(unitID) .. ", unitTeam=" .. tostring(teamID)) end
    unit:setIdle()
    -- markUnitAsIdle(unitID)

	-- end
end
--[[
    -- to call using a variable for method name:
    -- local aTest = "setIdle"
    -- unit[aTest](unit, 1234)

  if defID has rules for idle event -- replaces isUnitRelevant()
    get/create unit
    unit:setIdle() -- replaces isUnitIdle(unitID), markUnitAsIdle, and maybeMarkUnitAsIdle()
    add unit to alertQueue -- checks before alerting

    addAlert(unitObj)
    
    local eventRules = getEventRules("idle") -- because a unit can belong to multiple types, meaning it could have multiple configurations for an event
    local mostImportant = 10
    for each of the unit's types
      if priority == nil then
        priority = 5
      end
      if priority == 0
        call alert immediately
      
        if not already there for same reason
        addToQueue(unitObj, event, priority)
]]
-- TODO: Needs to setLost()
function widget:UnitDestroyed(unitID, defID, unitTeam, attackerID, attackerDefID, attackerTeam)
	-- Triggered when unit dies or construction canceled/destroyed while being built
  if debug then debugger("UnitDestroyed unitID=" .. unitID .. ", translatedHumanName=" .. UnitDefs[defID].translatedHumanName) end
	-- Spring.Echo("UnitDestroyed unitID=" .. unitID .. ", translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName)
  local army = teamsManager:getArmyManager(unitTeam)
  if army and army:hasTypeRules(defID) then
    army:getOrCreateUnit(unitID, defID):setLost()
  end
	-- markUnitAsNotIdle(unitID)
end

function widget:UnitTaken(unitID, defID, oldTeamID, newTeamID)
  -- Relevant if moving to/from myTeamID
  -- Otherwise, must decide based on isRelevant rules
  -- For simplicity, can treat as destroyed or created by myTeamID
  if teamsManager:getArmyManager(oldTeamID):hasTypeRules(defID) or teamsManager:getArmyManager(newTeamID):hasTypeRules(defID) then
    -- markUnitAsNotIdle(unitID)
    local oldArmy = teamsManager:getArmyManager(oldTeamID)
    if oldArmy then
      local unit = oldArmy:getOrCreateUnit(unitID, defID)
      teamsManager:moveUnit(unitID, defID, oldTeamID, newTeamID)
      unit:getIdle()
      -- maybeMarkUnitAsIdle(unitID, unitDefID, newTeamID)
      -- markUnitAsIdle(unitID)
    end
  end
end

function widget:UnitFinished(unitID, defID, teamID, builderID)
  if debug then debugger("UnitFinished 1 is now constructed. unitID=" .. unitID .. ", unitDefID=" .. defID .. ", teamID=" .. teamID) end
	-- Unit could already exist
  local aUnit = teamsManager:createUnit(unitID, defID, teamID)

  -- TODO: How to get commander when spawns in? UnitCreated ?

  local army = teamsManager:getArmyManager(teamID)
  if army and army:hasTypeRules(defID) then
    army:getOrCreateUnit(unitID, defID):getIdle()
  end
  -- maybeMarkUnitAsIdle(unitID, defID, teamID)
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

local function checkQueuesOfInactiveUnits() -- Only checks units with idle event rules and are in the parent["idle"] table
  if debug then debugger("checkQueuesOfInactiveUnits 1.") end
  if type(teamsManager.myArmyManager["idle"]) == "table" then
    for unitID, unit in pairs(teamsManager.myArmyManager["idle"]) do
      if debug then debugger("checkQueuesOfInactiveUnits 2. unitID=" .. unitID .. ", defID=" .. unit.defID .. ", isFactory=" .. tostring(unit.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
      if unit:getIdle() == true then
        if debug then debugger("checkQueuesOfInactiveUnits 3. Builder idle. unitID=" .. unitID .. ", defID=" .. unit.defID) end
        -- markUnitAsIdle(unitID)
      else
        if debug then debugger("checkQueuesOfInactiveUnits 4. Builder NOT idle. unitID=" .. unitID .. ", defID=" .. unit.defID) end
        -- markUnitAsNotIdle(unitID)
      end
    end
  end
  -- for unitID, v in pairs(idlingUnits) do
	-- 	if not isUnitIdle(unitID) then
	-- 		markUnitAsNotIdle(unitID)
	-- 	end
	-- end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

  -- sends destroyed AND "thresholdHP"
end

local function checkQueuesOfFactories()
	local myFactories = Spring.GetTeamUnitsByDefs(myTeamID, FactoryDefIDs)
  if debug then debugger("checkQueuesOfFactories 1 " .. tostring(myFactories[1])) end
	-- Spring.Echo("checkQueuesOfFactories " .. tostring(myFactories[1]))
	for v, unitID in pairs(myFactories) do
	  if debug then debugger("checkQueuesOfFactories unitID=" .. unitID .. ", v=" .. v) end -- this isn't a key value table
    -- Spring.Echo("checkQueuesOfFactories unitID=" .. unitID .. ", v=" .. v)
    -- This will be called by ArmyManager to check if the unit is relevant for the armyManager
		-- if teamsManager:getArmyManager(teamID):hasTypeRules(defID) and isUnitIdle(unitID) then
    if teamsManager:getArmyManager(teamID):hasTypeRules(defID) and isUnitIdle(unitID) then
			markUnitAsIdle(unitID)
		else
			markUnitAsNotIdle(unitID)
		end
	end
end
-- local aUnit = teamsManager:createUnit(5506, 244, 0) -- Factory
-- local bUnit = teamsManager:createUnit(13950, 245, 0) -- Con plane
-- local bUnit = teamsManager:createUnit(?, 276, 0) -- Con plane
function widget:CommandsChanged() -- Called when the command descriptions changed, e.g. when selecting or deselecting a unit. Because widget:UnitIdle doesn't happen when factory queue is removed by player
  if debug then debugger("CommandsChanged 1. Called when the command descriptions changed, e.g. when selecting or deselecting a unit.") end
	-- local factories = teamsManager.myArmyManager["factory"]
  if type(teamsManager.myArmyManager["factory"]) == "table" then
    for unitID, unit in pairs(teamsManager.myArmyManager["factory"]) do
      if debug then debugger("CommandsChanged 2. unitID=" .. unitID .. ", defID=" .. unit.defID .. ", isFactory=" .. tostring(unit.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
      if unit:getIdle() == true then
        if debug then debugger("CommandsChanged 3. Factory added to parent[idle] table. unitID=" .. unitID .. ", defID=" .. unit.defID) end
        -- markUnitAsIdle(unitID)
      else
        if debug then debugger("CommandsChanged 4. Factory NOT idle. unitID=" .. unitID .. ", defID=" .. unit.defID) end
        -- markUnitAsNotIdle(unitID)
      end
    end
  end
  -- checkQueuesOfFactories()
end
-- figure out logic for if new alert is added to queue
function widget:GameFrame(frame)
  -- if warnFrame >= 1 then -- with 30 UpdateInterval, would run every half second
  if idlingUnitCount > 0 then -- or numAlerts > 0 
    if warnFrame >= 0 then
      checkQueuesOfInactiveUnits()
      if idlingUnitCount > 0 then -- still idling after we checked the queues
        Spring.PlaySoundFile(TestSound, 1.0, 'ui')  --              ############ Sound File Enable
        -- Here is where prioritization should go 
        -- Get and use BuilderUnitDefIDs[unitDefID] to get local builderType = (1,2,3)
        -- Use builderType to play correct sound notification
      end
    end
		warnFrame = (warnFrame + 1) % UpdateInterval
	end
  -- warnFrame = (warnFrame + 1) % UpdateInterval -- With changes at top, this would automatically run every half second
end

function widget:Shutdown()
	Spring.Echo(widgetName .. " widget disabled")
end

-- ############################################################# Alerts Section ###########################################
-- {defID = {type = {event = {rules}}}}
-- components: {type = {event = {rules}
local function getEventRulesNotifyVars(typeEventRulesTbl, unitObj) -- validates and returns alertVarsTbl key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
  if debug then debugger("getEventRulesNotifyVars 1. unitObj=" .. type(unitObj) .. ", typeEventRulesTbl=" .. type(typeEventRulesTbl)) end
  local validTbl,typeCount,eventCount,rulesCount = validTypeEventRulesTbls(typeEventRulesTbl)
  if validTbl == false or type(unitObj) ~= "table" or unitObj.defID == nil then
    debugger("getEventRulesNotifyVars 2. ERROR, returning nil. NOT unitObj or validTypeEventRulesTbls=" .. type(validTypeEventRulesTbls) .. ", unitObj=" .. type(unitObj))
    return nil
  end
  if not validTbl or typeCount ~= 1 or eventCount ~= 1 then
    debugger("getEventRulesNotifyVars 3. ERROR. Returning nil. Bad typeEventRulesTbl. validTbl=" .. tostring(validTbl) .. ", typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", rulesCount=" .. tostring(rulesCount) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
    return nil
  end
  local unitType, eventTbl = next(typeEventRulesTbl)
  local event, rulesTbl = next(eventTbl)

  local maxAlerts = rulesTbl["maxAlerts"] or 0
  local reAlertSec = rulesTbl["reAlertSec"] or 10
  local priority = rulesTbl["priority"] or 5
  local maxQueueTime = rulesTbl["maxQueueTime"] or false -- false or number
  local mark = rulesTbl["mark"] or false -- t/f or string
  local ping = rulesTbl["ping"] or false -- t/f or string
  local alertSound = rulesTbl["alertSound"] or false -- false or string
  local sharedAlerts = rulesTbl["sharedAlerts"] or false -- nil or true
  local threshMinPerc = rulesTbl["threshMinPerc"] or 0 -- number 0-.999
  local threshMaxPerc = rulesTbl["threshMaxPerc"] or 1 -- number 0.001-1

  if type(maxAlerts) ~= "number" or type(reAlertSec) ~= "number" or type(priority) ~= "number" or ((type(maxQueueTime) ~= "number" and type(maxQueueTime) ~= "boolean") or (type(maxQueueTime) == "boolean" and maxQueueTime ~= false)) or (type(mark) ~= "string" and type(mark) ~= "boolean") or (type(ping) ~= "string" and type(ping) ~= "boolean") or (type(alertSound) ~= "string" and type(alertSound) ~= "boolean") or (type(alertSound) == "boolean" and alertSound ~= false) or type(sharedAlerts) ~= "boolean" or (type(threshMinPerc) ~= "number" or (threshMinPerc < 0 or threshMinPerc >= 1)) or (type(threshMaxPerc) ~= "number" or (threshMaxPerc > 1 or threshMaxPerc <= threshMinPerc)) then
    debugger("getEventRulesNotifyVars 4. ERROR. Returning nil. Bad threshMinPerc, threshMaxPerc, sharedAlerts, mark, ping, alertSound, maxAlerts, reAlertSec or priority=" .. tostring(priority) .. ", reAlertSec=" .. tostring(reAlertSec) .. ", maxAlerts=" .. tostring(maxAlerts) .. ", maxQueueTime=" .. tostring(maxQueueTime) .. ", threshMinPerc=" .. tostring(threshMinPerc) .. ", threshMaxPerc=" .. tostring(threshMaxPerc) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
    return nil
  end
  if sharedAlerts then
    local lastSharedNotify = rulesTbl["lastNotify"] or 0 -- nil or GameSec
    local alertCount = rulesTbl["alertCount"] or 0 -- nil or GameSec
    if type(lastSharedNotify) ~= "number" or type(alertCount) ~= "number" then
      debugger("getEventRulesNotifyVars 5. ERROR. Returning nil. Bad alertCount or lastSharedNotify=" .. type(lastSharedNotify) .. ", type(alertCount)=" .. type(alertCount) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
      return nil
    end
    return {["teamID"]=unitObj.parent.teamID, ["unitType"]=unitType, ["event"]=event, ["lastNotify"]=lastSharedNotify, ["sharedAlerts"]=sharedAlerts, ["priority"]=priority, ["reAlertSec"]=reAlertSec, ["maxAlerts"]=maxAlerts, ["alertCount"]=alertCount, ["maxQueueTime"]=maxQueueTime, ["alertSound"]=alertSound, ["mark"]=mark, ["ping"]=ping, ["threshMinPerc"]=threshMinPerc, ["threshMaxPerc"]=threshMaxPerc}
  else
    if type(unitObj.lastAlerts) ~= "table" then
      unitObj.lastAlerts = {}
    end
    if type(unitObj.lastAlerts[unitType]) ~= "table" then
      unitObj.lastAlerts[unitType] = {}
    end
    if type(unitObj.lastAlerts[unitType][event]) ~= "table" then
      unitObj.lastAlerts[unitType][event] = {}
    end
    local lastNotify = unitObj.lastAlerts[unitType][event].lastNotify or 0
    local alertCount = unitObj.lastAlerts[unitType][event].alertCount or 0
    if type(lastNotify) ~= "number" or type(alertCount) ~= "number" then
      debugger("getEventRulesNotifyVars 6. ERROR. Returning nil. Bad lastUnitNotify. lastUnitNotify=" .. type(lastNotify) .. ", tableToString=" .. tableToString(typeEventRulesTbl))
      return nil
    end
    return {["teamID"]=unitObj.parent.teamID, ["unitType"]=unitType, ["event"]=event, ["lastNotify"]=lastNotify, ["sharedAlerts"]=sharedAlerts, ["priority"]=priority, ["reAlertSec"]=reAlertSec, ["maxAlerts"]=maxAlerts, ["alertCount"]=alertCount, ["maxQueueTime"]=maxQueueTime, ["alertSound"]=alertSound, ["mark"]=mark, ["ping"]=ping, ["threshMinPerc"]=threshMinPerc, ["threshMaxPerc"]=threshMaxPerc}
  end
end

-- validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "maxQueueTime", "alertSound", "mark", "ping", "threshMinPerc", "threshMaxPerc"} -- if sharedAlerts it also contains: alertCount, lastNotify. ELSE these are stored in the unit with unitObj.lastAlerts[unitType][event] = {lastNotify=num,alertCount=num} 
local function addUnitAlert(typeEventRulesTbl, unitObj) -- Use [unit or armyMgr]:getTypesRulesForEvent() with topPriorityOnly = true. Must have one of each: type,event
  if debug then debugger("addUnitAlert 1. ") end
  local alertVarsTbl = getEventRulesNotifyVars(typeEventRulesTbl, unitObj)
  if alertVarsTbl == nil then -- all is verified by getEventRulesNotifyVars()
    debugger("addUnitAlert 2. ERROR. Returning nil. getEventRulesNotifyVars() returned nil. alertVarsTbl=" .. type(alertVarsTbl))
    return nil
  end
  local gameSecs = Spring.GetGameSeconds()
  if gameSecs < alertVarsTbl.lastNotify + alertVarsTbl.reAlertSec or (alertVarsTbl.maxAlerts ~= 0 and alertVarsTbl.alertCount >= alertVarsTbl.maxAlerts) then -- Before adding to queue, check unit's event last notify/maxAlerts
    if debug then debugger("addUnitAlert 3. Too soon=" .. tostring(gameSecs) .. "<" .. tostring(alertVarsTbl.lastNotify + alertVarsTbl.reAlertSec) .. ", or reached maxAlerts=" .. tostring(alertVarsTbl.alertCount) .. "/" .. tostring(alertVarsTbl.maxAlerts) .. ", tableToString=" .. tableToString(alertVarsTbl)) end
    return false
  end


  
  alertQueue:insert(unitObj,alertVarsTbl, alertVarsTbl.priority)

    
  if not alertQueue:isEmpty() then -- ensure not adding duplicates and manage situations where an alert should be removed and/or replaced
    -- If already in queue for same event, vars used: teamID, unitType, event, sharedAlerts, priority, maxQueueTime, threshMinPerc, threshMaxPerc
    if alertVarsTbl.sharedAlerts == false then
      if debug then debugger("addUnitAlert 4. sharedAlerts=" .. tostring(alertVarsTbl.sharedAlerts) .. ". Starting checks to decide if this alert should be queued and/or others removed/replaced. alertVarsTbl.sharedAlerts=" .. tostring(alertVarsTbl.sharedAlerts)) end


    end
    -- if same unit changed teams or lost/detroyed
    
    -- if unit/sharedAlert in queue, find with: 
      -- indivAlerts: unitObj = alertQueue.heap[#].value -- value = unitObj
      -- sharedAlerts: teamID, unitType, event

    -- if better priority, replace if matched: 
    -- if not better priority, reject new: 
  
    -- If better priority damage/thresholdHP alert, add it (if priority > 0) and remove other from queue 
    -- If in queue and destroyed/lost, remove from queue, or it pulls new units until unit.isLost = false

    -- If unit moved teams, handled by function teamsManager:moveUnit()
      -- add 
  end


  -- alertQueue:insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
  -- alertQueue:peek(heapNum) -- Returns/Keeps the top/requested element, returning vars: value, alertRulesTbl, priority, queuedTime

-- If shared event has higher priority and is on cooldown, use individual event rule?

 -- Create priority queue to enable the following
  -- If already in queue for same event
    -- if better priority: replace
    -- if not better priority: reject new
  -- If already in queue for different event?
    -- Add it
  -- If better priority damage/thresholdHP alert, add it (if priority > 0) and remove other from queue 
    -- thresholdHP should probably be demoted to a rule
    -- look with damage eventRulesTbl topPriorityOnly
  -- No, don't do this. If, event not desroyed and, in queue when destroyed/lost, remove from queue, or it pulls new units until unit.isLost = false


end
-- validEvents = {"idle","damaged","destroyed","created","finished","los","enteredAir","stockpile","thresholdHP"}
-- validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "maxQueueTime", "alertSound", "mark", "ping", "threshMinPerc", "threshMaxPerc"} -- if sharedAlerts it also contains: alertCount, lastNotify. ELSE these are stored in the unit with unitObj.lastAlerts[unitType][event] = {lastNotify=num,alertCount=num} 

-- alertQueue:getSize() -- Returns the number of elements in the queue.
-- alertQueue:isEmpty() -- Returns true if the queue is empty, false otherwise.
-- alertQueue:insert(value, priority) -- Inserts a new element with the given priority.
-- alertQueue:pull() -- Retrieves and removes the element with the highest priority.
-- alertQueue:peek() -- Returns the element with the highest priority without removing it.
-- alertQueue:__lessThan(i, j) -- Helper functions for heap operations (min-heap)
-- alertQueue:_swap(i, j)
-- alertQueue:_swim(k)
-- alertQueue:_sink(k)

local function addAlert() -- placeholder for alerts that aren't unit specific
  if debug then debugger("addAlert 1. ") end


end


local function isAlertQueued()
  if debug then debugger("isAlertQueued 1. ") end


end










makeRelTeamDefsRules()
-- debug = true
teamsManager:makeAllArmies() -- Build all teams/armies
debug = false



-- debugger("isAllied(0,1)=" .. tostring(teamsManager:isAllied(0, 1)))
-- debugger("isAllied(1,2)=" .. tostring(teamsManager:isAllied(1, 2)))

-- debugger("isEnemy(0,1)=" .. tostring(teamsManager:isEnemy(0, 1)))
-- debugger("isEnemy(1,2)=" .. tostring(teamsManager:isEnemy(1, 2)))
-- debugger("getUnit(5506)=" .. tostring(teamsManager:getUnit(5506, 0).defID))
-- debugger("NoTeam getUnit(5506)=" .. tostring(teamsManager:getUnit(5506).defID))
-- teamsManager:moveUnit(5506, 244, 0, 1)
-- debugger("getUnit(5506).parent.teamID=" .. tostring(teamsManager:getUnit(5506).parent.teamID))

  -- debugger("getUnit(5506).parent.teamID=" .. tostring(teamsManager:getUnit(5506)))

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
-- debugger("Army hasTypeRules=" .. tostring(gUnit.parent:hasTypeRules(gUnit.defID)) .. ", name=" .. tostring(UnitDefs[gUnit.defID].translatedHumanName))
-- debugger("Unit hasTypeRules=" .. tostring(enemyCUnit:hasTypeRules()) .. ", name=" .. tostring(UnitDefs[enemyCUnit.defID].translatedHumanName))
-- debugger("Unit hasTypeRules=" .. tostring(enemyCUnit:hasTypeRules()) .. ", name=" .. tostring(UnitDefs[enemyCUnit.defID].translatedHumanName))
-- local typeRules = cUnit:getTypesRulesForEvent("idle")
-- local typeRules = cUnit:getTypesRules({"commander"})
-- debugger("validTypeEventRulesTbls=" .. tostring(validTypeEventRulesTbls(typeRules)))
-- debugger("tableToString=" .. tableToString(typeRules))
-- cUnit:setLost(false)
-- debugger("unitsLost[bUnit.ID]=" .. type(cUnit.parent.unitsLost[cUnit.ID]))
-- local priorityRules = cUnit:getTypesRulesForEvent("idle",true)
-- local typeRules2,typeCount2,eventCount2,ruleCount2 = validTypeEventRulesTbls(priorityRules)
-- debugger("priorityRules validTypeEventRulesTbls2=" .. tostring(typeRules2) .. ", typeCount2=" .. tostring(typeCount2) .. ", eventCount2=" .. tostring(eventCount2) .. ", ruleCount2=" .. tostring(ruleCount2) .. ", tableToString2=" .. tableToString(priorityRules))



-- local searchTxt = "Commander"
-- local aTeamNum = 0
-- for unitDefID, unitDef in pairs(UnitDefs) do
--   if string.find(UnitDefs[unitDefID].translatedHumanName:lower(), searchTxt:lower()) then
--     -- debugger(searchTxt .. " defID=" .. unitDefID .. ", name=" .. tostring(UnitDefs[unitDefID].translatedHumanName))
--     local index, foundUnitID = next(Spring.GetTeamUnitsByDefs ( aTeamNum, unitDefID)) -- return: nil | table unitTable = { [1] = number unitID, ... }
--     if foundUnitID then
--       debugger("teamID=" .. aTeamNum .. ", " .. searchTxt .. " unitID=" .. tostring(foundUnitID) .. ", defID=" .. unitDefID .. ", name=" .. tostring(UnitDefs[unitDefID].translatedHumanName))
--     end
--   end
-- end

local cUnit = teamsManager:createUnit(19913, 282, 0) -- my Commander
local aUnit = teamsManager:createUnit(5506, 244, 0) -- T2 Plane Factory
local bUnit = teamsManager:createUnit(13950, 245, 0) -- Adv. Con plane
local gUnit = teamsManager:createUnit(25549, 251, 0) -- Adv. Geothermal
local arr = {"constructor", "radar"}

local allyCUnit = teamsManager:createUnit(425, 49, 1) -- Ally Commander

local enemyCUnit = teamsManager:createUnit(24908, 49, 2) -- Enemy Commander

local cUnitRules = cUnit:getTypesRulesForEvent("idle", true)
local aUnitRules = aUnit:getTypesRulesForEvent("idle", true)
local bUnitRules = bUnit:getTypesRulesForEvent("idle", true)
local enemyCUnitRules = enemyCUnit:getTypesRulesForEvent("los", true)


-- TestingArea
debug = true
-- aUnit.debug = true

-- local kioi = {teamID=0, unitType="commander", event="idle", lastNotify=0, sharedAlerts=false, priority=2, reAlertSec=15, maxAlerts=false, alertCount=1, maxQueueTime=nil, alertSound="sounds/commands/cmd-selfd.wav", mark=nil, ping=false, threshMinPerc=.5, threshMaxPerc=0.9}
local kioi = {commander = {idle = {lastNotify=0, sharedAlerts=false, priority=2, reAlertSec=15, maxAlerts=false, alertCount=1, maxQueueTime=nil, alertSound="sounds/commands/cmd-selfd.wav", mark=nil, ping=false, threshMinPerc=.5, threshMaxPerc=0.9}}}
-- cUnit.parent:getTypesRulesForEvent(cUnit.defID, "idle", true)
debugger("Starting myCommander")
addUnitAlert(cUnitRules , cUnit)
-- debugger("Starting my T2 Plane Factory")
-- addUnitAlert(aUnitRules, aUnit)
-- debugger("Starting my Adv. Con plane")
-- addUnitAlert(bUnitRules, bUnit)
-- debugger("Starting Enemy Commander")
-- addUnitAlert(enemyCUnitRules, enemyCUnit)


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

-- alertQueue:insert("E1", {a="b"}, 5) -- alertQueue:insert(value, alertRulesTbl, priority)
-- alertQueue:insert("B1", {a="b"}, 2)
-- alertQueue:insert("A1", {a="b"}, 1)
-- alertQueue:insert("C1", {a="b"}, 3)
-- alertQueue:insert("A2", {a="b"}, 1)
-- alertQueue:insert("E2", {a="b"}, 5)
-- alertQueue:insert("B2", {a="b"}, 2)
-- debugger("alertQueue.heap[1].priority=" .. tostring(alertQueue.heap[1].priority) .. ", alertQueue.heap[2].priority=" .. tostring(alertQueue.heap[2].priority) .. ", alertQueue.heap[3].priority=" .. tostring(alertQueue.heap[3].priority))
-- local pull1a,pull1b = alertQueue:pull()
-- local pull2a,pull2b = alertQueue:pull()
-- local pull3a,pull3b = alertQueue:pull()
-- debugger("alertQueue:pull()=" .. tostring(pull1b) .. ", alertQueue.heap[2].priority=" .. tostring(pull2b) .. ", alertQueue.heap[3].priority=" .. tostring(pull3b))

-- NO tableToString unless it doesn't include "value" -- debugger("alertQueue.heap=" .. tableToString(alertQueue.heap))

-- teamID, unitType, event

-- function getQueuedEvent()
local unitToFind = gUnit
local tm = cUnit.parent.teamID
local uTp = "constructor"
local evnt = "idle"
local shr = true
local toFind
debugger("Searching for unit vas: teamID="..tostring(tm)..", unitType="..tostring(uTp)..", event="..tostring(evnt)..", sharedAlerts="..tostring(shr)) -- tostring(UnitDefs[cUnit.defID].translatedHumanName) -- tostring(alertQueue.heap[heapNum].value.defID)
if alertQueue:isEmpty() == false then -- How to remove a value from the priority queue
  local size = alertQueue:getSize()
  -- if size == 1 and alertQueue.heap[1].value == unitToFind then
  if size == 1 then
    debugger("Only 1 in queue, checking for match.")
    if tm == alertQueue.heap[1].alertRulesTbl.teamID and uTp == alertQueue.heap[1].alertRulesTbl.unitType and evnt == alertQueue.heap[1].alertRulesTbl.event and (shr and alertQueue.heap[1].alertRulesTbl.sharedAlerts or (shr == false and alertQueue.heap[1].alertRulesTbl.sharedAlerts == false and alertQueue.heap[1].value == unitToFind)) then
      debugger("Found, but size=1, so just doing pull().")
      toFind = alertQueue.heap[1]
    end
  else
    -- all have to match on teamID, unitType, event
      -- if both shared it's a match
      -- if unshared must match individual value/unitObj
    for heapNum,valPriTbl in ipairs(alertQueue.heap) do
      local val = valPriTbl.value
      local priority = valPriTbl.priority
      local alertRulesTbl = valPriTbl.alertRulesTbl
      local queuedTime = valPriTbl.queuedTime

      local aSharer = alertRulesTbl.sharedAlerts
      local aTm = alertRulesTbl.teamID
      local aUTp = alertRulesTbl.unitType
      local aEvnt = alertRulesTbl.event
      -- debugger("heap=" .. tostring(heapNum) .. ", val=" .. tostring(val) .. ", aSharer=" .. tostring(aSharer) .. ", priority=" .. tostring(priority) .. ", queuedTime=" .. tostring(queuedTime) .. ", aTm=" .. tostring(aTm) .. ", aUTp=" .. tostring(aUTp) .. ", aEvnt=" .. tostring(aEvnt) .. ", alertRulesTbl=" .. type(alertRulesTbl))
      debugger("Queued unit vars: heapNum=" .. tostring(heapNum) .. ", unitObjType=" .. type(val) .. ", shared=" .. tostring(aSharer).. "/"..tostring(alertQueue.heap[heapNum].alertRulesTbl.sharedAlerts) .. ", priority=" .. tostring(priority).. "/"..tostring(alertQueue.heap[heapNum].alertRulesTbl.priority) .. ", queuedTime=" .. tostring(queuedTime) .. ", teamID=" .. tostring(aTm).. "/"..tostring(alertQueue.heap[heapNum].alertRulesTbl.teamID) .. ", unitType=" .. tostring(aUTp).. "/"..tostring(alertQueue.heap[heapNum].alertRulesTbl.unitType) .. ", event=" .. tostring(aEvnt).. "/"..tostring(alertQueue.heap[heapNum].alertRulesTbl.event) .. ", alertRulesTbl=" .. type(alertRulesTbl))
      -- if val == unitToFind or (shr and aSharer and (tm == aTm and uTp == aUTp and evnt == aEvnt)) then -- works but not on all criteria
      -- if tm == alertQueue.heap[heapNum].valPriTbl.teamID and uTp == alertQueue.heap[heapNum].valPriTbl.unitType and evnt == alertQueue.heap[heapNum].valPriTbl.event and (shr and alertQueue.heap[heapNum].valPriTbl.sharedAlerts or (shr == false and alertQueue.heap[heapNum].valPriTbl.sharedAlerts == false and alertQueue.heap[heapNum].value == unitToFind)) then
      
      if tm == alertQueue.heap[heapNum].alertRulesTbl.teamID and uTp == alertQueue.heap[heapNum].alertRulesTbl.unitType and evnt == alertQueue.heap[heapNum].alertRulesTbl.event and (shr and alertQueue.heap[heapNum].alertRulesTbl.sharedAlerts or (shr == false and alertQueue.heap[heapNum].alertRulesTbl.sharedAlerts == false and alertQueue.heap[heapNum].value == unitToFind)) then
        toFind = heapNum
        debugger("Match toRemove=" .. tostring(toFind) .. ", translatedHumanName=" .. tostring(UnitDefs[alertQueue.heap[heapNum].value.defID].translatedHumanName))
        break
      end
    end
  end
  if toFind then
    debugger("updating alertQueue.")
    alertQueue.heap[toFind] = alertQueue.heap[size]
    alertQueue.heap[size] = nil
    alertQueue.size = size - 1
    alertQueue:_sink(1)
  end
end


alertQueue:insert(aUnit,kioi, 0)

-- NO tableToString unless it doesn't include "value" -- debugger("alertQueue.heap=" .. tableToString(alertQueue.heap))

local i = 1
while alertQueue:isEmpty() == false do
  local val,alertRulesTbl, priority, gameSec = alertQueue:pull()
  debugger(i .. " value=" .. type(val) .. ", alertRulesTbl=" .. type(alertRulesTbl) .. ", priority=" .. tostring(priority) .. ", gameSec=" .. tostring(gameSec))
  i = i + 1
end


-- local kioi = {teamID=0, unitType="commander", event="idle", lastNotify=0, sharedAlerts=false, priority=2, reAlertSec=15, maxAlerts=0, alertCount=1, maxQueueTime=nil, alertSound="sounds/commands/cmd-selfd.wav", mark=nil, ping=false, threshMinPerc=.5, threshMaxPerc=0.9}
-- {teamID=, unitType=, event=, lastNotify=, sharedAlerts=, priority=, reAlertSec=, maxAlerts=, alertCount=, maxQueueTime=, alertSound=, mark=, ping=, threshMinPerc=, threshMaxPerc=}
-- {teamID=, unitType=, event=, lastNotify=, sharedAlerts=, priority=, reAlertSec=, maxAlerts=, alertCount=, maxQueueTime=, alertSound=, mark=, ping=, threshMinPerc=, threshMaxPerc=}
-- {teamID=, unitType=, event=, lastNotify=, sharedAlerts=, priority=, reAlertSec=, maxAlerts=, alertCount=, maxQueueTime=, alertSound=, mark=, ping=, threshMinPerc=, threshMaxPerc=}

-- :insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}


-- alertQueue:insert(value, alertRulesTbl, priority) -- alertRulesTbl should have all (key,pair) vars that can be used to determine whether and how to alert key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}

debug = false
-- string.format("%p", my_object) -- get memory address of object/table. Crashes
-- alertQueue:getSize() -- Returns the number of elements in the queue.
-- alertQueue:isEmpty() -- Returns true if the queue is empty, false otherwise.
-- alertQueue:insert(value, alertRulesTbl, priority) -- Inserts a new element with the given priority.
-- alertQueue:pull() -- Retrieves and removes the element with the highest priority.
-- alertQueue:peek() -- Returns the element with the highest priority without removing it.
-- alertQueue:__lessThan(i, j) -- Helper functions for heap operations (min-heap)
-- alertQueue:_swap(i, j)
-- alertQueue:_swim(k)
-- alertQueue:_sink(k)

-- for k, v in pairs(teamsManager.armies) do
--   debugger("Testing all teams. teamID=" .. tostring(v.teamID) .. ", allianceID=" .. tostring(v.allianceID) .. ", playerID0Name=" .. tostring(v.playerIDsNames[0]) .. ", playerID1Name=" .. tostring(v.playerIDsNames[1]))
-- end

-- local protoUnit = pUnit:clone()
-- protoUnit.parent = pUnit
-- protoUnit:setAllIDs(26761)
-- if debug then debugger("protoUnit 1. ID=" .. tostring(protoUnit.ID) .. ", defID=".. tostring(protoUnit.defID) .. ", teamID=".. tostring(protoUnit.teamID)) end
  -- local protoUnit = pUnit:clone()
  -- protoUnit.isCommander, protoUnit.isBuilder = true, true

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
-- Spring.GetUnitHealth
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

-- SYNCHED
-- function widget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture) -- return: bool allow -- Called just before a unit is transferred to a different team, the boolean return value determines whether or not the transfer is permitted.


-- Spring.PlaySoundFile ( string soundfile [, number volume = 1.0 [, number posx [, number posy [, number posz [, number speedx[, number speedy[, number speedz[, number | string channel ]]]]]]]] )

-- Summary:
-- allyID = allyTeamID  -- Gaia always highest alliance and compID
-- competitorID = teamID  -- Humans, AIs and Gaia
-- personID = playerID  -- Humans only

-- non-function version of teamsManager:makeAllArmies()
-- local gaiaTeamID = Spring.GetGaiaTeamID()  -- Game's Gaia (environment) compID, but not considered an AI
-- local tmpTxt = "compID/AllyID check\n"
-- for _,compID in pairs(Spring.GetTeamList()) do -- Iterate through all compIDs (teamIDs)
-- 	local teamID2,leaderNum,isDead,isAiTeam,strSide,allianceID = Spring.GetTeamInfo(compID)
-- 	if compID == gaiaTeamID then -- Game's Gaia (environment) actor 
--     if debug then tmpTxt = tmpTxt .. "Gaia Env is on teamID " .. compID .. " in allianceID " .. allianceID .. ", isDead=" .. tostring(isDead) .. "\n" end
--     local aTeam = teamsManager:newArmyManager(gaiaTeamID, allianceID)
--     -- aTeam.isGaia = true
--   elseif isAiTeam then
-- 		if debug then tmpTxt = tmpTxt .. "AI is on teamID " .. compID .. " in allianceID " .. allianceID .. ", isDead=" .. tostring(isDead) .. "\n" end
--     local aTeam = teamsManager:newArmyManager(compID, allianceID)
--     -- aTeam.isAI = true
--   else -- compID is Human
--     for _,playerID in pairs(Spring.GetPlayerList(compID)) do -- Get all players on the compID
--       local playerName, isActive, isSpectatorTmp, teamIDTmp, allyTeamIDTmp, pingTime, cpuUsage, country, rank, customPlayerKeys = Spring.GetPlayerInfo(compID)
--       if teamIDTmp == compID then
--         local tmpPlayerText = "playerID " .. playerID
--         if isActive then
--           if debug then tmpPlayerText = tmpPlayerText .. " is Active" end
--         else
--           if debug then tmpPlayerText = tmpPlayerText .. " is Inactive" end
--         end
--         if isSpectatorTmp then
--           if debug then tmpPlayerText = tmpPlayerText .. " Spectator" end
--         else
--           if debug then tmpPlayerText = tmpPlayerText .. " Participant" end
--         local aTeam = teamsManager:newArmyManager(compID, allianceID, playerID) -- playerID should be added automatically
--         end
--         if debug then tmpPlayerText = tmpPlayerText .. " with teamID " .. teamIDTmp .. " in allianceID " .. allyTeamIDTmp .. ", isDead=" .. tostring(isDead) .. "\n" end
--         if debug then tmpTxt = tmpTxt .. tmpPlayerText end
--       end
--     end
--   end
-- end
-- if debug then Spring.Echo(tmpTxt) end



-- local playerName, isActive, isSpectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customPlayerKeys = Spring.GetPlayerInfo(playerID )
-- return: nil | string "name", bool isActive, bool isSpectator, number teamID, number allyTeamID, number pingTime, number cpuUsage, string "country", number rank, table customPlayerKeys

-- Spring.GetPlayerRoster() gets all player/team/allyTeam information
-- Returns playerName,playerID,teamID,allianceID,isSpectator,cpuUsage,pingTime

--[[
-- PriorityQueue.lua
-- A simple priority queue implementation in Lua using a min-heap.

local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

function PriorityQueue:new()
  local queue = {
    heap = {},
    size = 0
  }
  return setmetatable(queue, self)
end

-- Returns the number of elements in the queue.
function PriorityQueue:getSize()
  return self.size
end

-- Returns true if the queue is empty, false otherwise.
function PriorityQueue:isEmpty()
  return self.size == 0
end

-- Inserts a new element with the given priority.
function PriorityQueue:insert(value, priority)
  self.size = self.size + 1
  self.heap[self.size] = {value = value, priority = priority}
  self:_swim(self.size)
end

-- Retrieves and removes the element with the highest priority.
function PriorityQueue:pull()
  if self:isEmpty() then
    return nil, nil
  end
  local top = self.heap[1]
  if self.size > 1 then
    self.heap[1] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1
    self:_sink(1)
  else
    self.heap[1] = nil
    self.size = 0
  end
  return top.value, top.priority
end

-- Returns the element with the highest priority without removing it.
function PriorityQueue:peek()
  if self:isEmpty() then
    return nil, nil
  end
  return self.heap[1].value, self.heap[1].priority
end

-- Helper functions for heap operations (min-heap)
function PriorityQueue:__lessThan(i, j)
  return self.heap[i].priority < self.heap[j].priority
end

function PriorityQueue:_swap(i, j)
  self.heap[i], self.heap[j] = self.heap[j], self.heap[i]
end

function PriorityQueue:_swim(k)
  while k > 1 and self:__lessThan(k, math.floor(k / 2)) do
    self:_swap(k, math.floor(k / 2))
    k = math.floor(k / 2)
  end
end

function PriorityQueue:_sink(k)
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

return PriorityQueue
]]