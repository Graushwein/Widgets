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

local trackAllMyUnitsRules = {} -- or use something like {hp, coords, destroyed} -- What else?
local trackAllEnemyUnitsRules = {} -- 
local trackAllAlliedUnitsRules = {} -- 

-- Newly added event types will need to be added here
local validEvents = {"idle","damaged","destroyed","created","finished","los","enteredAir","stockpile","thresholdHP"}
local validEventRules = {"maxTimes", "reAlertSec", "mark", "ping", "alertSound", "threshPerc"}

-- TODO: create rules for below types in makeRelTeamDefsRules()  #####################

	-- mark = only you see. ping = ALL ALLIES see it. Be careful with ping
local myCommanderRules = {idle = {maxTimes=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, damaged = {maxTimes=0, reAlertSec=30, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, thresholdHP = {maxTimes=0, reAlertSec=60, mark=nil, alertSound="sounds/commands/cmd-selfd.wav", threshPerc=.5} } -- will sound alert when Commander idle/15 secs, (re)damaged once per 30 seconds (unlimited), and when damage causes HP to be under 50%
local myConstructorRules = {idle = {maxTimes=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}, destroyed = {maxTimes=0, reAlertSec=1, mark="Con Lost", alertSound=nil}}
local myFactoryRules = {idle = {maxTimes=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}}
local myRezBotRules = {idle = {maxTimes=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav"}}
local myMexRules = {destroyed = {maxTimes=0, reAlertSec=1, mark="Mex Lost", alertSound=nil}}
local myEnergyGenRules = {finished = {maxTimes=0, reAlertSec=1, mark=nil, alertSound=nil}, destroyed = {maxTimes=0, reAlertSec=1, mark=nil, alertSound=nil}} -- reAlertSec only used if mark/sound wanted. Saved so custom code can do something with the information.
local myRadarRules = {finished = {maxTimes=0, reAlertSec=1, mark="Radar Built", alertSound="sounds/commands/cmd-selfd.wav"}, destroyed = {maxTimes=0, reAlertSec=1, mark="Radar Lost", alertSound="sounds/commands/cmd-selfd.wav"}}
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
local allyFactoryT2Rules = {finished = {maxTimes=1, reAlertSec=15, mark="T2 Ally", alertSound=nil}} -- So you know to badger them for a T2 constructor ;)
local allyRezBotRules = {}
local allyMexRules = {destroyed = {maxTimes=0, reAlertSec=1, mark="Ally Mex Lost", alertSound=nil}}
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
local enemyCommanderRules = {los = {maxTimes=0, reAlertSec=30, mark="Commander", alertSound=nil} } -- will mark "Commander" at location when (re)enters LoS, once per 30 seconds (unlimited)
local enemyConstructorRules = {}
local enemyFactoryRules = {}
local enemyFactoryT2Rules = {los = {maxTimes=1, reAlertSec=15, mark="T2 enemy", alertSound=nil}} -- Hope you're ready!
local enemyRezBotRules = {}
local enemyMexRules = {destroyed = {maxTimes=0, reAlertSec=1, mark=nil, alertSound=nil}} -- No alert means it only destroyed enemy mex will be tracked. To have it track alive mex, use "los"
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
local relevantMyUnitDefsRules = {} -- unitDefID (key), typeArray {commander,builder} Types match to types above -- TODO
local relevantAllyUnitDefsRules = {} -- ### unitDefs wanted in ally armyManagers  -- TODO
local relevantEnemyUnitDefsRules = {} -- ### unitDefs wanted in enemy armyManagers  -- TODO
local relevantSpectatorUnitDefs = {}
-- Not implemented yet
-- if 2 or more type of notifications has to send, then this many seconds will be there between those notifications
local timeBetweenNotifications = 3 -- Second

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

local myTeamID = Spring.GetMyTeamID()
local isSpectator
local warnFrame = 0

local BuilderUnitDefIDs = {} -- unitDefID (key), builderType [1=com, 2=con, 3=factory, 4=rezbot]
-- local BuilderUnits = {} -- Use ArmyManager unitID (key), unitDefID -- Incorporated into ArmyManager
local FactoryDefIDs = {}

local idlingUnits = {}
local idlingUnitCount = 0

-- ################################################# Prototypes starts here #################################################
-- type(nil) would return "nil", and type(false) would return "boolean". If there is need to differentiate
local function debugger(...)
  if debug then
    Spring.Echo("", ...)
  end
end

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
local object = clone( table, { clone = clone, isa = isa } )

local teamsManager = object:clone()
teamsManager.armies = {} -- armies key/value. Added with teamsManager[teamID] key = [armyManager].
teamsManager.myArmyManager = nil  -- will hold easy quick reference to main player's armyManager
teamsManager.lastUpdate = nil -- TODO: Can use Spring.GetGameSeconds ( ), OR Spring.GetTimer ( )/Spring.DiffTimers ( timer cur, timer ago [, bool inMilliseconds ] ) 
teamsManager.debug = false

local pArmyManager = object:clone()

pArmyManager.units = {} -- units key/value. Added with armyManager[unitID] = [unitObject]. Objects in multiple arrays are the same object (memory efficient), so changing one will change all
pArmyManager.unitsLost = {} -- key/value unitsLost[unitID] = [unitObject] of unit objects destroyed, taken, or given
pArmyManager.unitsReceived = {} -- key/value unitsReceived[unitID] = [unitObject] of unit objects given by an ally. Possibly used for notifications, but should remove after notified
pArmyManager.relTypesRules = {}
pArmyManager.builders = {} -- builders key/value. Added with armyManager.Builders[unitID] = [unitObject]
pArmyManager.commanders = {} -- commanders key/value. Added with armyManager.Commanders[unitID] = [unitObject]
pArmyManager.constructors = {} -- constructors key/value. Added with armyManager.Constructors[unitID] = [unitObject]
pArmyManager.factories = {} -- factories key/value. Added with armyManager.Factories[unitID] = [unitObject]
pArmyManager.rezbots = {} -- rezbots key/value. Added with armyManager.rezbots[unitID] = [unitObject]
pArmyManager.playerIDsNames = {} -- key/value of playerIDsNames[playerID] = [playerName], usually only one, that can control the army's units. TODO: Could hold Player objects
pArmyManager.isMyTeam = nil
pArmyManager.allianceID = nil
pArmyManager.teamID = nil -- teamID of the armyManager 
pArmyManager.lastUpdate = nil -- Game seconds last update time of the armyManager (NOT IMPLEMENTED YET)
pArmyManager.isAI = nil
pArmyManager.isGaia = nil
pArmyManager.debug = false  -- ############################ArmyManager debug mode enable################################################

local pUnit = object:clone()

pUnit.debug = false  -- ############################Prototype Unit debug mode enable################################################
pUnit.isIdle = false
pUnit.typesRules = {}
pUnit.isBuilder = nil -- is this unit a builder?
pUnit.isCommander = nil -- is this unit a commander?
pUnit.isConstructor = nil -- is this unit a constructor?
pUnit.isFactory = nil -- is this unit a factory?
pUnit.isRezBot = nil -- is this unit a rezbot?
pUnit.created = nil
pUnit.lost = nil
pUnit.parent = nil
pUnit.teamID = nil
pUnit.lastSetIdle = nil
pUnit.lastUpdate = nil -- Game seconds last update time of the unit (NOT used YET)
pUnit.health = nil -- health of the unit (NOT IMPLEMENTED YET)



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
  if not teamsManager:validIDs(nil, nil, nil, nil, true, teamID, true, allianceID, true, playerID) then debugger("newArmyManager 2. INVALID input. Returning nil.") return nil end
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
    armyManager.relTypesRules = relevantMyUnitDefsRules
  elseif Spring.AreTeamsAllied(teamID, myTeamID) then
    armyManager.relTypesRules = relevantAllyUnitDefsRules
  else
    armyManager.relTypesRules = relevantEnemyUnitDefsRules
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
    debugger("getArmyManager 3. Returning (Nil if not found) anArmy Type=" .. type(anArmy)) -- self.armies[teamID].teamID
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
  if type(teamID2) ~= "number" then
    teamID2 = self.myArmyManager.teamID
    if debug or self.debug then debugger("isAllied 4. Using myTeamID for T2. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  end
  local armyManager2 = self:getArmyManager(teamID2)
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
  aUnit:setLost()
  aUnit.parent = newTeamArmy
  newTeamArmy.units[unitID] = aUnit -- set here because it is only set in createUnit(), and setLost() removed from other army
  aUnit:setUnitType(aUnit.defID)
  newTeamArmy.unitsReceived[aUnit.ID] = aUnit
  self.lastUpdate = Spring.GetGameSeconds()
  return aUnit
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
-- 3. setUnitType(unit) NOW IN UNIT - sets the unit type (e.g., builder, commander, factory, rezbot) based on its unitDefID
-- 4. armyManager UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam) flow 
-- 4.1 Mark pUnit.isDead = true, pUnit.lastUpdate = Spring.GetGameSeconds(), pUnit.coordiates
-- 5. incorporate lastUpdate
-- 6. incorporate playerID
-- 7. Economy tracking

-- ArmyManager typical flow for creating unit:
-- 1. 
function pArmyManager:addPlayer(playerID, playerName)
  if debug or self.debug then debugger("addPlayer 1. playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
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
        eUnit:setLost()
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
  aUnit:setUnitType(defID)  -- Probably doesn't belong here unless there's a way to import user config into setUnitType()
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
  if debug or self.debug then debugger("setID 1. unitID=" .. tostring(unitID) .. ", unitID=".. tostring(unitID)) end
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
  if debug or self.debug then debugger("setIdle 1. GameSec(" .. Spring.GetGameSeconds() .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameSeconds() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if not self.isIdle then
    self.isIdle = true
    self.lastSetIdle = Spring.GetGameSeconds()
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setIdle 2. Has been setIdle. GameSec(" .. Spring.GetGameSeconds() .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameSeconds() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end

function pUnit:setNotIdle()
  if debug or self.debug then debugger("setNotIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if self.isIdle then
    self.isIdle = false
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then debugger("setNotIdle 2. Has been setNotIdle. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end
-- ATTENTION!!! ###### This waits a second before returning that it is idle because some units are idle very briefly before starting on the next queued task
function pUnit:getIdle()
  local count = spGetCommandQueue(self.ID, 0)
  if debug or self.debug then debugger("getIdle 1. GameSec(" .. Spring.GetGameSeconds() .. ", Queue=" .. tostring(count) .. ")-LastIdle(" .. self.lastSetIdle .. ")=" .. tostring(Spring.GetGameSeconds() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if count > 0 then
    if debug or self.debug then debugger("getIdle 2. Wasn't actually Idle. Calling setNotIdle to correct it. cmdQueue=" .. tostring(count) .. ", GameSec-LastIdle=" .. tostring(Spring.GetGameSeconds() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    self:setNotIdle()
    return self.isIdle
  end
  if not self.isIdle then
    self:setIdle()  -- lastSetIdle is only set when becoming idle from being not idle. Which means it will return false below to allow the extra second to prevent false positives
    if debug or self.debug then debugger("getIdle 3. Was actually Idle, corrected. cmdQueue=" .. tostring(count) .. ", GameSec-LastIdle=" .. tostring(Spring.GetGameSeconds() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
  if self.isIdle and Spring.GetGameSeconds() == self.lastSetIdle then -- because it may be idle very briefly before starting on the next queued task
    if debug or self.debug then debugger("getIdle 4. Hasn't been idle for a second. Returning false. cmdQueue=" .. tostring(count) .. ", GameSec-LastIdle=" .. tostring(Spring.GetGameSeconds() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end  
    return false
  end
  return self.isidle
end

-- TODO: Update to use relevant table
function pUnit:setLost()
  if debug or self.debug then debugger("setLost 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
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
  self.lost = Spring.GetGameSeconds()
  self.lastUpdate = Spring.GetGameSeconds()
  return self
end

function pUnit:getUnitTypesRules()
  if debug or self.debug then debugger("getUnitTypes 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", returns type=".. type(self.parent.relTypesRules[self.defID])) end
  return self.parent.relTypesRules[self.defID] -- returns table(s) for each type ascribed to it
end

-- ################################################## Custom/Expanded Unit methods starts here #################################################

-- TODO: 
-- OLD, phase out #################
-- Where should this go? How to make it easily USER CONFIG expandable? ############################################
-- is this even needed with the new system? No
function pUnit:setUnitType(defID)
  if debug or self.debug then debugger("setUnitType 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("pUnit:setUnitType 2. INVALID input. Returning nil.") return nil end
 -- ######################## update to have it loop through all unit type lists ############################
  local tmpBuilderUnitDefID = BuilderUnitDefIDs[self.defID]
  if tmpBuilderUnitDefID ~= nil and tmpBuilderUnitDefID > 0 and tmpBuilderUnitDefID < 4 then
    if debug or self.debug then debugger("setUnitType 2. isBuilder ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isBuilder = true
    self.parent.builders[self.ID] = self -- Add to builders array
  end
  if tmpBuilderUnitDefID == 1 and idleCommanderAlert then
    if debug or self.debug then debugger("setUnitType 3. isCommander ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isCommander = true
    self.parent.commanders[self.ID] = self -- Add to commanders array
  elseif tmpBuilderUnitDefID == 2 and idleConAlert then
    if debug or self.debug then debugger("setUnitType 4. isConstructor ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isConstructor = true
    self.parent.constructors[self.ID] = self -- Add to constructors array
  elseif tmpBuilderUnitDefID == 3 and idleFactoryAlert then
    if debug or self.debug then debugger("setUnitType 5. isFactory ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isFactory = true
    self.parent.factories[self.ID] = self -- Add to factories array
  elseif tmpBuilderUnitDefID == 4 and idleRezAlert then
    if debug or self.debug then debugger("setUnitType 6. isRezBot ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", tmpBuilderUnitDefID=" .. tostring(tmpBuilderUnitDefID)) end
    self.isRezBot = true
    self.parent.rezBots[self.ID] = self -- Add to rezBots array
  end
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

-- ################################################# Unit Type Rules Assembly start here #################################################

local function addToRelTeamDefsRules(defID, key)
  if debug then debugger("addToRelTeamDefsRules defID=" .. tostring(defID) .. ", key=" .. tostring(key)) end
  if not teamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then debugger("addToRelTeamDefsRules 2. INVALID input. Returning nil.") return nil end
  if type(key) ~= "string" then debugger("addToRelTeamDefsRules 3. INVALID KEY input. Returning nil.") return nil end
  -- if spectator then
  --   -- something
  -- end
  if next(trackMyTypesRules) ~= nil and type(trackMyTypesRules[key]) == "table" then
    relevantMyUnitDefsRules[defID] = {key = trackMyTypesRules[key]}
  end
  if next(trackAllyTypesRules) ~= nil and type(trackAllyTypesRules[key]) == "table" then
    relevantAllyUnitDefsRules[defID] = {key = trackAllyTypesRules[key]}
  end
  if next(trackEnemyTypesRules) ~= nil and type(trackEnemyTypesRules[key]) == "table" then
    relevantEnemyUnitDefsRules[defID] = {key = trackEnemyTypesRules[key]}
  end
end

local function makeRelTeamDefsRules()
  for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.iscommander and (next(trackMyTypesRules["commander"]) ~= nil or next(trackAllyTypesRules["commander"]) ~= nil or next(trackEnemyTypesRules["commander"]) ~= nil) then
      if debug then debugger("Assigning Commander BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
      addToRelTeamDefsRules(unitDefID, "commander")
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

-- OLD #### Build list of unit defIDs that should be tracked
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

local function validEvent(event)
  if debug then debugger("validEvent 1. event=" .. tostring(event)) end
  for _, value in ipairs(validEvents) do
    if value == event then
      return true
    end
  end
  return false
end

local function validEventRule(rule)
  if debug then debugger("validEvent 1. event=" .. tostring(rule)) end
  for _, value in ipairs(validEventRules) do
    if value == rule then
      return true
    end
  end
  return false
end
-- ################################################# Idle Alerts start here #################################################


function widget:PlayerChanged(playerID)
    myTeamID = Spring.GetMyTeamID()
	isSpectator = Spring.GetSpectatingState()
	if isSpectator then
		widgetHandler:RemoveWidget()
	end
end

local function isBuilder(unitDefID)
    return BuilderUnitDefIDs[unitDefID] ~= nil
end

local function hasEventAlerts(unitID, defID, teamID, event)
  if debug then debugger("hasEventAlerts 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID)) end
  if not teamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then debugger("hasEventAlerts 2. INVALID input. Returning nil.") return nil end
  if not validEvent(event) then debugger("hasEventAlerts 3. ERROR. Bad input value event=" .. tostring(event)) return nil end
  local army = teamsManager:getArmyManager(teamID)
  if army == nil then
    debugger("hasEventAlerts 4. ERROR. Army NOT FOUND. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event))
    return nil
  end
  local typeRulesTbl = army.relTypesRules[defID]
  if type(typeRulesTbl) ~= "table" then
    if debug then debugger("hasEventAlerts 5. DefID not in relTypesRules. typeRulesTbl not table. typeRulesTbl=" .. type(typeRulesTbl) .. ", unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
    return nil
  end
  local unitType, eventsRulesTbl = next(typeRulesTbl, nil)
  -- TODO: I could validate user configured tables' structure all at once, instead of every time... HOWEVER, they COULD be accidentally messed up afterwards and be a pain to find?
  if type(unitType) ~= "string" or type(eventsRulesTbl) ~= "table" or eventsRulesTbl[event] == nil then
    debugger("hasEventAlerts 6. ERROR. Bad Type string=" .. type(unitType) .. " or Bad eventsRulesTbl=" .. type(eventsRulesTbl) .. ", unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event))
    return nil
  end
  local eventMatch = eventsRulesTbl[event]
  if eventMatch == nil or type(eventMatch) ~= "table" then
    if debug then debugger("hasEventAlerts 7. eventMatch not found. unitType=" .. tostring(unitType) .. ", eventMatch=" .. type(eventMatch) .. ", unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
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
  local maxTimes = eventsRulesTbl["maxTimes"]
  local reAlertSec = eventsRulesTbl["reAlertSec"]
  local mark = eventsRulesTbl["mark"]
  local ping = eventsRulesTbl["ping"]
  local alertSound = eventsRulesTbl["alertSound"]
  local threshPerc = eventsRulesTbl["threshPerc"]

  -- Process the rules to see if something needs to be done

  if mark ~= nil or ping ~= nil or alertSound ~= nil then
    if debug then debugger("hasEventAlerts 9. Found 1+ alerts for unitType-event. unitType=" .. tostring(unitType) .. ", eventMatch=" .. type(eventMatch) .. ", unitDefID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", event=" .. tostring(event)) end
    if type(maxTimes) ~= "number" or type(reAlertSec) ~= "number" then -- make a function validate this stuff?
      
    end
  end
  

end
-- local validEvents = {"idle","damaged","destroyed","created","finished","los","enteredAir","stockpile","thresholdHP"}
-- local validEventRules = {"maxTimes", "reAlertSec", "mark", "ping", "alertSound", "threshPerc"}

-- if there's type rules, AND the unit's event matches a type... @@@@@@$$$$$$$$$$$$$$$$##################^^^^^^^^^^^^^^^^^^^^%%%%%%%%%%%%%%%%%%
-- build logic for maxTimes=0, reAlertSec=15, mark=nil, alertSound="sounds/commands/cmd-selfd.wav" (Track in armyManager or teamsManager?) Stored how?
-- {destroyed = {maxTimes=0, reAlertSec=1, mark=nil, alertSound=nil}} -- No alert means it only destroyed enemy mex will be tracked. To have it track alive mex, use "los"

-- events: idle,damaged,destroyed,created,finished,los,enteredAir,stockpile,

-- TODO: REPLACED ALREADY???
-- The isRelevantEvent function decides whether the Lua Callin Return type (damage, idle, completed, ...) is relevant for the unit type/teamID based on what the configuration.
local function isRelevantEvent(defID, teamID, event) -- ??
  if debug then debugger("isRelevantEvent 1 UnitDefID[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", teamID=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", event=" .. tostring(event)) end
  if not teamsManager:validIDs(nil, nil, true, defID, true, teamID, nil, nil, nil, nil) then debugger("isRelevantEvent 2. INVALID input. Returning nil.") return nil end
  if not validEvent(event) then debugger("isRelevantEvent 3. ERROR. Bad input value event=" .. tostring(event)) return nil end
  -- if spectator then
  --   --something
  -- elseif
  if teamID == myTeamID then
    if debug then debugger("isRelevantEvent 4 returning=" .. tostring(next(relevantMyUnitDefsRules) ~= nil and relevantMyUnitDefsRules[defID] ~= nil and relevantMyUnitDefsRules[defID][event] ~= nil) .. ", UnitDefID[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", teamID=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", event=" .. tostring(event)) end
    return next(relevantMyUnitDefsRules) ~= nil and relevantMyUnitDefsRules[defID] ~= nil and relevantMyUnitDefsRules[defID][event] ~= nil
  elseif teamsManager:isAllied(teamID) then
    if debug then debugger("isRelevantEvent 5 returning=" .. tostring(next(relevantAllyUnitDefsRules) ~= nil and relevantAllyUnitDefsRules[defID] ~= nil and relevantAllyUnitDefsRules[defID][event] ~= nil) .. ", UnitDefID[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", teamID=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", event=" .. tostring(event)) end
    return next(relevantAllyUnitDefsRules) ~= nil and relevantAllyUnitDefsRules[defID] ~= nil and relevantAllyUnitDefsRules[defID][event] ~= nil
  else
    if debug then debugger("isRelevantEvent 6 returning=" .. tostring(next(relevantEnemyUnitDefsRules) ~= nil and relevantEnemyUnitDefsRules[defID] ~= nil and relevantEnemyUnitDefsRules[defID][event] ~= nil) .. ", UnitDefID[" .. tostring(defID) .. "].translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName) .. ", teamID=" .. tostring(teamID) .. ", myTeamID=" .. tostring(myTeamID) .. ", event=" .. tostring(event)) end
    return next(relevantEnemyUnitDefsRules) ~= nil and relevantEnemyUnitDefsRules[defID] ~= nil and relevantEnemyUnitDefsRules[defID][event] ~= nil
  end
end


-- ############# THIS SHOULD BE AN ARMYMANAGER METHOD
local function isUnitRelevant(unitDefID, unitTeam)
  if debug then debugger("isUnitRelevant UnitDefs[" .. tostring(unitDefID) .. "].translatedHumanName=" .. tostring(UnitDefs[unitDefID].translatedHumanName) .. ", unitTeam=" .. tostring(unitTeam) .. ", myTeamID=" .. tostring(myTeamID) .. ", isBuilder(unitDefID)=" .. tostring(isBuilder(unitDefID))) end
  --Spring.Echo("isUnitRelevant UnitDefs[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName .. ", unitTeam=" .. unitTeam .. ", myTeamID=" .. myTeamID .. ", isBuilder(unitDefID)=" .. tostring(isBuilder(unitDefID)))
	return unitTeam == myTeamID and isBuilder(unitDefID)
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



  -- GetUnitHealth(unitID): return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress
	local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
	if buildProgress < 1 then
    if debug then debugger("isUnitIdle NOT BUILT. buildProgress=" .. buildProgress .. ", Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]) end
		-- Spring.Echo("isUnitIdle NOT BUILT. buildProgress=" .. buildProgress .. ", Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)])
		return false
	end
  if debug then debugger("isUnitIdle Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]) end
  -- Spring.Echo("isUnitIdle Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName=" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)])
	local builderType = BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]
	if builderType == 3 then -- Factory
    local cmdLen = spGetFactoryCommands(unitID, 0)      -- TODO: Change to use Spring.GetFullBuildQueue(unitId) ? #########
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

local function maybeSetIdle()
  if debug then debugger("maybeSetIdle 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
	-- if isUnitRelevant(unitDefID, unitTeam) and isUnitIdle(unitID) then
	-- 	markUnitAsIdle(unitID)
	-- end
end
local function maybeMarkUnitAsIdle(unitID, unitDefID, unitTeam)
  -- This will be called by ArmyManager to check if the unit is relevant for the armyManager
	if isUnitRelevant(unitDefID, unitTeam) and isUnitIdle(unitID) then
		markUnitAsIdle(unitID)
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
  if debug then debugger("UnitIdle. Check Botlab translatedHumanName=" .. UnitDefs[362].translatedHumanName) end
	-- Spring.Echo("UnitIdle. Check Botlab spGetFactoryCommands(26761,0)=" .. spGetFactoryCommands(26761, 0) .. ", translatedHumanName=" .. UnitDefs[362].translatedHumanName)
	-- This will be called by ArmyManager to check if the unit is relevant for the armyManager
  if isUnitRelevant(unitDefID, unitTeam) then
    if debug then debugger("UnitIdle UnitDefs[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName .. ", unitID=" .. unitID .. ", unitTeam=" .. unitTeam) end
    --Spring.Echo("UnitIdle UnitDefs[" .. unitDefID .. "].translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName .. ", unitID=" .. unitID .. ", unitTeam=" .. unitTeam)
		markUnitAsIdle(unitID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	-- Triggered when unit dies or construction canceled/destroyed while being built
  if debug then debugger("UnitDestroyed unitID=" .. unitID .. ", translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName) end
	-- Spring.Echo("UnitDestroyed unitID=" .. unitID .. ", translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName)
	markUnitAsNotIdle(unitID)
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
  -- Relevant if moving to/from myTeamID
  -- Otherwise, must decide based on isRelevant rules
  -- For simplicity, can treat as destroyed or created by myTeamID
    markUnitAsNotIdle(unitID)
	maybeMarkUnitAsIdle(unitID, unitDefID, newTeamID)
end

function widget:UnitFinished(unitID, unitDefID, teamID, builderID)
  debug = true
  if debug then debugger("UnitFinished being constructed. unitID=" .. unitID .. ", unitDefID=" .. unitDefID .. ", teamID=" .. teamID) end
	-- Unit could already exist
  local aUnit = teamsManager:createUnit(unitID, unitDefID, teamID)

  -- TODO: How to get commander when spawns in? UnitCreated ?

-- START HERE. WORK ON BELOW

  maybeMarkUnitAsIdle(unitID, unitDefID, teamID)
end

function widget:Initialize()
	Spring.Echo("Starting " .. widgetName)
    widget:PlayerChanged()
	if isSpectator then
		return
	end
  if Spring.GetGameSeconds() > 1 then
    -- TODO: Load All Units ########## 
  end
end

local function checkQueuesOfInactiveUnits()
  for unitID, v in pairs(idlingUnits) do
		if not isUnitIdle(unitID) then
			markUnitAsNotIdle(unitID)
		end
	end
end

local function checkQueuesOfFactories()
	local myFactories = Spring.GetTeamUnitsByDefs(myTeamID, FactoryDefIDs)
  if debug then debugger("checkQueuesOfFactories " .. tostring(myFactories[1])) end
	-- Spring.Echo("checkQueuesOfFactories " .. tostring(myFactories[1]))
	for v, unitID in pairs(myFactories) do
	  if debug then debugger("checkQueuesOfFactories unitID=" .. unitID .. ", v=" .. v) end -- this isn't a key value table
    -- Spring.Echo("checkQueuesOfFactories unitID=" .. unitID .. ", v=" .. v)
    -- This will be called by ArmyManager to check if the unit is relevant for the armyManager
		if isUnitRelevant(Spring.GetUnitDefID(unitID), myTeamID) and isUnitIdle(unitID) then
			markUnitAsIdle(unitID)
		else 
			markUnitAsNotIdle(unitID)
		end
	end
end

function widget:CommandsChanged(chgd)
	-- Called when the command descriptions changed, e.g. when selecting or deselecting a unit. Because widget:UnitIdle doesn't happen when factory queue is removed by player
  if debug then debugger("CommandsChanged. Called when the command descriptions changed, e.g. when selecting or deselecting a unit. chgd=" .. tostring(chgd)) end
	-- Spring.Echo("CommandsChanged. Called when the command descriptions changed, e.g. when selecting or deselecting a unit. chgd=" .. tostring(chgd))
	checkQueuesOfFactories()
end

function widget:GameFrame(frame)
    if idlingUnitCount > 0 then
		if warnFrame >= 0 then
			checkQueuesOfInactiveUnits()
			if idlingUnitCount > 0 then -- still idling after we checked the queues
				-- Spring.PlaySoundFile(TestSound, 1.0, 'ui')  --              ############ Sound File Enable
				-- Here is where prioritization should go 
				-- Get and use BuilderUnitDefIDs[unitDefID] to get local builderType = (1,2,3)
				-- Use builderType to play correct sound notification
				
				
			end
		end
		warnFrame = (warnFrame + 1) % UpdateInterval
	end
end

function widget:Shutdown()
	Spring.Echo(widgetName .. " widget disabled")
end


makeRelTeamDefsRules()
teamsManager:makeAllArmies() -- Build all teams/armies

-- loadAllExistingUnits


-- debugger("isAllied(0,1)=" .. tostring(teamsManager:isAllied(0, 1)))
-- debugger("isAllied(1,2)=" .. tostring(teamsManager:isAllied(1, 2)))

-- debugger("isEnemy(0,1)=" .. tostring(teamsManager:isEnemy(0, 1)))
-- debugger("isEnemy(1,2)=" .. tostring(teamsManager:isEnemy(1, 2)))
-- debugger("getUnit(5506)=" .. tostring(teamsManager:getUnit(5506, 0).defID))
-- debugger("NoTeam getUnit(5506)=" .. tostring(teamsManager:getUnit(5506).defID))
-- teamsManager:moveUnit(5506, 244, 0, 1)
-- debugger("getUnit(5506).parent.teamID=" .. tostring(teamsManager:getUnit(5506).parent.teamID))

-- if type(aUnit) ~= "nil" then
  -- aUnit:setIdle()
  -- aUnit:getIdle()
  -- aUnit.lastSetIdle = Spring.GetGameSeconds() - 2
  -- aUnit:getIdle()
  -- aUnit:setIdle()
  -- aUnit:setNotIdle()
  -- aUnit:setLost()
  -- debugger("getUnit(5506).parent.teamID=" .. tostring(teamsManager:getUnit(5506)))
-- end

-- local aUnit = teamsManager:createUnit(5506, 244, 0) -- Factory
-- local aUnit = teamsManager:createUnit(13950, 245, 0) -- Con plane
-- aUnit.debug = true
debug = false

--???????????????????????  Time to start on the non class stuff. Get that working first. Then add functionality, like health.


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

local function tableToString(tbl, indent)
  indent = indent or 4
  local str = ""
  -- Add indentation for nested tables
  str = str .. string.rep(".", indent) .. "{\n"
  -- Iterate through table elements
  if type(tbl) ~= "table" then
    str = str .. type(tbl) .. "." .. tostring(tbl) -- If not a table, return its string representation
  else
    for k, v in pairs(tbl) do
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
      elseif type(v) == "string" then
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
-- Spring.GetTeamUnits(teamId)
-- Spring.GetUnitTeam
-- Spring.GetCommandQueue
-- Spring.GetFactoryCommands
-- Spring.GetUnitHealth
-- Spring.GetTeamUnits(teamId)
-- Spring.GetUnitCommands(unitId, -1)
-- Spring.GetFullBuildQueue(unitId)
-- Spring.ValidUnitID(unitId)

-- function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) end
-- function widget:GameStart() end -- Called upon the start of the game. Not called when a saved game is loaded.
-- function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID) end -- Called when a unit enters LOS of an allyteam. Its called after the unit is in LOS, so you can query that unit. The allyTeam is who's LOS the unit entered.
-- function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID) end -- Called when a unit leaves LOS of an allyteam. For widgets, this one is called just before the unit leaves los, so you can still get the position of a unit that left los.
-- function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam) end -- Called when a unit is loaded by a transport.
-- function widget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount) end -- Called when a units stockpile of weapons increases or decreases. See stockpile.


-- Spring.SendMessageToPlayer ( number playerID, string message )
-- Spring.PlaySoundFile ( string soundfile [, number volume = 1.0 [, number posx [, number posy [, number posz [, number speedx[, number speedy[, number speedz[, number | string channel ]]]]]]]] )

-- Spring.IsAboveMiniMap ( number x, number y ) -- return: nil | bool isAbove    ### Does what?
-- How to get if mouse over minimap?

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