---@diagnostic disable: duplicate-set-field
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
VFS.Include("LuaUI/easy_alerts_utils/ea_teams_mgr_lib.lua")
-- ################################################# Config variables starts here #################################################
local soundVolume = 1.0 -- Set the volume between 0.0 and 1.0. NOT USED

UpdateInterval = 30

-- TeamsManager.config.enabledEventRules = true -- No need to use this. It is automatically set by providing Initialize typesRules or nil
TeamsManager.config.minReAlertSec = 3 -- to prevent a bunch at once
TeamsManager.config.deleteDestroyed = false -- For possible RAM concerns. Though, in the few small tests I tried it didn't seem to save more RAM
TeamsManager.config.FunctionRunCounts = false
TeamsManager.config.logEvents = false
debug = false
-- local logEventsTbl = {}
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
local myConstructorRules = {idle = {sharedAlerts=true, reAlertSec=60, mark="Con Idle", alertDelay=.1}, destroyed = {mark="Con Lost"}, given = {mark="Con Given"}}
local myFactoryRules = {idle = {sharedAlerts=true, reAlertSec=60, mark="Idle Factory", alertDelay=.1}}
local myRezBotRules = {idle = {sharedAlerts=true, reAlertSec=60, alertDelay=.1, messageTo="me",messageTxt="RezBot Idle"}}
local myMexRules = {destroyed = {reAlertSec=5, mark="Mex Lost"}, taken = {mark="Mex Taken"}}
local myRadarRules = {destroyed = {mark="Radar Lost"}}
local myNukeRules = {stockpile = {messageTo="me", messageTxt="Nuke Ready", mark="Nuke Ready", alertSound="sounds/commands/cmd-selfd.wav"}}
-- More Unit Types:
local myEnergyGenT2Rules = {}; local myAntiNukeRules = {}; local myFactoryT1Rules = {}; local myFactoryT2Rules = {}; local myFactoryT3Rules = {}; local myMexT1Rules = {}; local myMexT2Rules = {}; local myEnergyGenRules = {}; local myEnergyGenT1Rules = {}; local myAllMobileUnitsRules = {}; local myUnitsT1Rules = {}; local myUnitsT2Rules = {}; local myUnitsT3Rules = {}; local myHoverUnitsRules = {}; local myWaterUnitsRules = {}; local myWaterT1Rules = {}; local myWaterT2Rules = {}; local myWaterT3Rules = {}; local myGroundUnitsRules = {}; local myGroundT1Rules = {}; local myGroundT2Rules = {}; local myGroundT3Rules = {}; local myAirUnitsRules = {}; local myAirT1Rules = {}; local myAirT2Rules = {}; local myAirT3Rules = {}
local trackMyTypesRules = {commander = myCommanderRules, constructor = myConstructorRules, factory = myFactoryRules, rezBot = myRezBotRules,	mex = myMexRules, energyGenT2 = myEnergyGenT2Rules,radar = myRadarRules, nuke = myNukeRules, antiNuke = myAntiNukeRules, factoryT1 = myFactoryT1Rules, factoryT2 = myFactoryT2Rules, factoryT3 = myFactoryT3Rules, mexT1 = myMexT1Rules, mexT2 = myMexT2Rules, energyGen = myEnergyGenRules, energyGenT1 = myEnergyGenT1Rules, allMobileUnits = myAllMobileUnitsRules, unitsT1 = myUnitsT1Rules, unitsT2 = myUnitsT2Rules, unitsT3 = myUnitsT3Rules, hoverUnits = myHoverUnitsRules, waterUnits = myWaterUnitsRules, waterT1 = myWaterT1Rules, waterT2 = myWaterT2Rules, waterT3 = myWaterT3Rules, groundUnits = myGroundUnitsRules, groundT1 = myGroundT1Rules, groundT2 = myGroundT2Rules, groundT3 = myGroundT3Rules, airUnits = myAirUnitsRules, airT1 = myAirT1Rules, airT2 = myAirT2Rules, airT3 = myAirT3Rules}

-- TeamsManager.eventRules["trackMyTypesRules"] = trackMyTypesRules

-- allyRules
local allyCommanderRules = {} -- Must have a rule to make it track the units. No alert means it only destroyed enemy mex will be tracked. To have it track alive mex, use "los"
local allyFactoryT2Rules = {finished = {sharedAlerts=true, maxAlerts=1, mark="T2 Ally Factory", alertDelay=30, messageTo="me", messageTxt="T2 Ally"}} -- So you can badger them for a T2 constructor ;)
local allyMexRules = {destroyed = {sharedAlerts=true, mark="Ally Mex Lost"}}
local allyEnergyGenT2Rules = {destroyed = {sharedAlerts=true, mark="Ally Fusion Lost"}}
local allyRadarRules = {destroyed = {sharedAlerts=true, mark="Ally Radar Lost"}} -- , alertDelay=30
local allyNukeRules = {stockpile = {sharedAlerts=true, messageTo="me", messageTxt="Ally Nuke Ready", alertSound="sounds/commands/cmd-selfd.wav"}}

local allyRezBotRules = {}; local allyFactoryRules = {}; local allyConstructorRules = {}; local allyAntiNukeRules = {}; local allyFactoryT1Rules = {}; local allyFactoryT3Rules = {}; local allyMexT1Rules = {}; local allyMexT2Rules = {}; local allyEnergyGenRules = {}; local allyEnergyGenT1Rules = {}; local allyAllMobileUnitsRules = {}; local allyUnitsT1Rules = {}; local allyUnitsT2Rules = {}; local allyUnitsT3Rules = {}; local allyHoverUnitsRules = {}; local allyWaterUnitsRules = {}; local allyWaterT1Rules = {}; local allyWaterT2Rules = {}; local allyWaterT3Rules = {}; local allyGroundUnitsRules = {}; local allyGroundT1Rules = {}; local allyGroundT2Rules = {}; local allyGroundT3Rules = {}; local allyAirUnitsRules = {}; local allyAirT1Rules = {}; local allyAirT2Rules = {}; local allyAirT3Rules = {}
local trackAllyTypesRules = {commander = allyCommanderRules, constructor = allyConstructorRules, factory = allyFactoryRules, factoryT2 = allyFactoryT2Rules, rezBot = allyRezBotRules, mex = allyMexRules, energyGenT2 = allyEnergyGenT2Rules, radar = allyRadarRules, nuke = allyNukeRules, antiNuke = allyAntiNukeRules, factoryT1 = allyFactoryT1Rules, factoryT3 = allyFactoryT3Rules, mexT1 = allyMexT1Rules, mexT2 = allyMexT2Rules, energyGen = allyEnergyGenRules, energyGenT1 = allyEnergyGenT1Rules, allMobileUnits = allyAllMobileUnitsRules, unitsT1 = allyUnitsT1Rules, unitsT2 = allyUnitsT2Rules, unitsT3 = allyUnitsT3Rules, hoverUnits = allyHoverUnitsRules, waterUnits = allyWaterUnitsRules, waterT1 = allyWaterT1Rules, waterT2 = allyWaterT2Rules, waterT3 = allyWaterT3Rules, groundUnits = allyGroundUnitsRules, groundT1 = allyGroundT1Rules, groundT2 = allyGroundT2Rules, groundT3 = allyGroundT3Rules, airUnits = allyAirUnitsRules, airT1 = allyAirT1Rules, airT2 = allyAirT2Rules, airT3 = allyAirT3Rules}

-- TeamsManager.eventRules["trackAllyTypesRules"] = trackAllyTypesRules

-- enemyRules
local enemyCommanderRules = {los = {reAlertSec=60, mark="Commander", priority=0, messageTo="me",messageTxt="Get em!"} } -- will mark "Commander" at location when (re)enters LoS, once per 30 seconds (unlimited)
local enemyFactoryT2Rules = {los = {sharedAlerts=true, maxAlerts=1, mark="T2 enemy"}} -- Hope you're ready.
local enemyAntiNukeRules = {los = {sharedAlerts=true, maxAlerts=1, reAlertSec=1, mark="AntiNuke Spotted"}}
local enemyNukeRules = {los = {sharedAlerts=true, maxAlerts=1, reAlertSec=1, mark="Nuke Spotted"}}

local enemyConstructorRules = {}; local enemyRadarRules = {}; local enemyUnitsT2Rules = {}; local enemyUnitsT3Rules = {}; local enemyFactoryRules = {}; local enemyMexRules = {}; local enemyEnergyGenT2Rules = {}; local enemyRezBotRules = {}; local enemyFactoryT1Rules = {}; local enemyFactoryT3Rules = {}; local enemyMexT1Rules = {}; local enemyMexT2Rules = {}; local enemyEnergyGenRules = {}; local enemyEnergyGenT1Rules = {}; local enemyAllMobileUnitsRules = {}; local enemyUnitsT1Rules = {}; local enemyHoverUnitsRules = {}; local enemyWaterUnitsRules = {}; local enemyWaterT1Rules = {}; local enemyWaterT2Rules = {}; local enemyWaterT3Rules = {}; local enemyGroundUnitsRules = {}; local enemyGroundT1Rules = {}; local enemyGroundT2Rules = {}; local enemyGroundT3Rules = {}; local enemyAirUnitsRules = {}; local enemyAirT1Rules = {}; local enemyAirT2Rules = {}; local enemyAirT3Rules = {}
local trackEnemyTypesRules = {commander = enemyCommanderRules, constructor = enemyConstructorRules, rezBot = enemyRezBotRules, radar = enemyRadarRules, nuke = enemyNukeRules, antiNuke = enemyAntiNukeRules, factory = enemyFactoryRules, factoryT1 = enemyFactoryT1Rules, factoryT2 = enemyFactoryT2Rules, factoryT3 = enemyFactoryT3Rules, mex = enemyMexRules, mexT1 = enemyMexT1Rules, mexT2 = enemyMexT2Rules, energyGen = enemyEnergyGenRules, energyGenT1 = enemyEnergyGenT1Rules, energyGenT2 = enemyEnergyGenT2Rules, allMobileUnits = enemyAllMobileUnitsRules, unitsT1 = enemyUnitsT1Rules, unitsT2 = enemyUnitsT2Rules, unitsT3 = enemyUnitsT3Rules, hoverUnits = enemyHoverUnitsRules, waterUnits = enemyWaterUnitsRules, waterT1 = enemyWaterT1Rules, waterT2 = enemyWaterT2Rules, waterT3 = enemyWaterT3Rules, groundUnits = enemyGroundUnitsRules, groundT1 = enemyGroundT1Rules, groundT2 = enemyGroundT2Rules, groundT3 = enemyGroundT3Rules, airUnits = enemyAirUnitsRules, airT1 = enemyAirT1Rules, airT2 = enemyAirT2Rules, airT3 = enemyAirT3Rules}

-- TeamsManager.eventRules["trackEnemyTypesRules"] = trackEnemyTypesRules

-- spectatorRules
local spectatorCommanderRules = {thresholdHP = {reAlertSec=120, threshMinPerc=.6, mark="Commander In Danger", alertSound="sounds/commands/cmd-selfd.wav", priority=1}, loaded = {mark="Com-Drop", alertSound="sounds/commands/cmd-selfd.wav", priority=1}}
local spectatorConstructorRules = {} -- {idle = {sharedAlerts=true, reAlertSec=60, alertDelay=.1, mark="Idle Con"}, destroyed = {sharedAlerts=true, reAlertSec=30, mark="Con Destroyed"}}
local spectatorFactoryT2Rules = {created = {sharedAlerts=true, maxAlerts=3, mark="T2 Factory Started"}, finished = {sharedAlerts=true, maxAlerts=3, mark="T2 Factory Finished"}}
local spectatorFactoryT3Rules = {created = {sharedAlerts=true, maxAlerts=3, mark="T3 Factory Started", alertSound="sounds/commands/cmd-selfd.wav"}, finished = {sharedAlerts=true, maxAlerts=3, mark="T3 Factory Finished", alertSound="sounds/commands/cmd-selfd.wav"}}
local spectatorMexT2Rules = {created = {sharedAlerts=true, maxAlerts=1, reAlertSec=30, mark="MexT2 Started"}, thresholdHP = {sharedAlerts=true, threshMinPerc=.8, reAlertSec=60, mark="MexT2 Damaged"}}
local spectatorEnergyGenT2Rules = {created = {sharedAlerts=true, maxAlerts=3, mark="EnergyT2 Started"}, thresholdHP = {sharedAlerts=true, threshMinPerc=.8, reAlertSec=60, mark="EnergyGenT2 Damaged"}}
local spectatorRadarRules = {}
local spectatorNukeRules = {stockpile = {sharedAlerts=true, maxAlerts=5, mark="Nuke Ready"}, created = {sharedAlerts=true, mark="Nuke Started", alertSound="sounds/commands/cmd-selfd.wav"}, finished = {reAlertSec=1, mark="Nuke Finished", alertSound="sounds/commands/cmd-selfd.wav"}}
local spectatorAntiNukeRules = {created = {sharedAlerts=true, maxAlerts=5, mark="Antinuke Started"}, finished = {sharedAlerts=true, maxAlerts=5, mark="AntiNuke Finished"}}
local spectatorLRPCRules = {created = {sharedAlerts=true, maxAlerts=5, mark="LRPC Started"}, finished = {sharedAlerts=true, maxAlerts=5, mark="LRPC Finished"}}
local spectatorRFLRPCRules = {created = {sharedAlerts=true, maxAlerts=5, mark="RFLRPC Started"}, finished = {sharedAlerts=true, maxAlerts=5, mark="RFLRPC Finished"}}

local spectatorFactoryRules = {}; local spectatorRezBotRules = {}; local spectatorMexRules = {}; local spectatorUnitsT2Rules = {}; local spectatorUnitsT3Rules = {}; local spectatorFactoryT1Rules = {}; local spectatorMexT1Rules = {}; local spectatorEnergyGenRules = {}; local spectatorEnergyGenT1Rules = {}; local spectatorAllMobileUnitsRules = {}; local spectatorUnitsT1Rules = {}; local spectatorHoverUnitsRules = {}; local spectatorWaterUnitsRules = {}; local spectatorWaterT1Rules = {}; local spectatorWaterT2Rules = {}; local spectatorWaterT3Rules = {}; local spectatorGroundUnitsRules = {}; local spectatorGroundT1Rules = {}; local spectatorGroundT2Rules = {}; local spectatorGroundT3Rules = {}; local spectatorAirUnitsRules = {}; local spectatorAirT1Rules = {}; local spectatorAirT2Rules = {}; local spectatorAirT3Rules = {}
local trackSpectatorTypesRules = {commander = spectatorCommanderRules, constructor = spectatorConstructorRules, rezBot = spectatorRezBotRules, radar = spectatorRadarRules, nuke = spectatorNukeRules, antiNuke = spectatorAntiNukeRules, factory = spectatorFactoryRules, factoryT1 = spectatorFactoryT1Rules, factoryT2 = spectatorFactoryT2Rules, factoryT3 = spectatorFactoryT3Rules, mex = spectatorMexRules, mexT1 = spectatorMexT1Rules, mexT2 = spectatorMexT2Rules, energyGen = spectatorEnergyGenRules, energyGenT1 = spectatorEnergyGenT1Rules, energyGenT2 = spectatorEnergyGenT2Rules, allMobileUnits = spectatorAllMobileUnitsRules, unitsT1 = spectatorUnitsT1Rules, unitsT2 = spectatorUnitsT2Rules, unitsT3 = spectatorUnitsT3Rules, hoverUnits = spectatorHoverUnitsRules, waterUnits = spectatorWaterUnitsRules, waterT1 = spectatorWaterT1Rules, waterT2 = spectatorWaterT2Rules, waterT3 = spectatorWaterT3Rules, groundUnits = spectatorGroundUnitsRules, groundT1 = spectatorGroundT1Rules, groundT2 = spectatorGroundT2Rules, groundT3 = spectatorGroundT3Rules, airUnits = spectatorAirUnitsRules, airT1 = spectatorAirT1Rules, airT2 = spectatorAirT2Rules, airT3 = spectatorAirT3Rules, LRPC = spectatorLRPCRules, RFLRPC = spectatorRFLRPCRules}

-- TeamsManager.eventRules["trackSpectatorTypesRules"] = trackSpectatorTypesRules

-- Example custom group below: CustomGroups = {["groupName1"] = {["unitNames"] = {"termite", "mammoth"}, ["eventsRules"] = {["idle"] = {mark = "Custom Group Test"}}}, ["groupName2"] = {["unitNames"] = {"guard", "twin guard"}, ["eventsRules"] = {["destroyed"] = {mark = "Custom Group Test"}}}}
local myCustomGroups = {}
local allyCustomGroups = {}
local enemyCustomGroups = {}
local spectatorCustomGroups = {}

-- TeamsManager.eventRules["myCustomGroups"] = myCustomGroups
-- TeamsManager.eventRules["allyCustomGroups"] = allyCustomGroups
-- TeamsManager.eventRules["enemyCustomGroups"] = enemyCustomGroups
-- TeamsManager.eventRules["spectatorCustomGroups"] = spectatorCustomGroups

-- ################################################## Config variables ends here ##################################################
-- DON'T change code below this if you are not sure what you are doing
local warnFrame = 0

-- Newly added event events/rules will need to be added here
-- most TeamsManager.validEventRules are used in getEventRulesNotifyVars(typeEventRulesTbl, unitObj)
-- local validEvents = {"created","finished","idle","destroyed","los","thresholdHP","taken","given","damaged","loaded","stockpile"}
-- local TeamsManager.validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "alertDelay", "maxQueueTime", "alertSound", "mark", "ping","messageTo","messageTxt", "threshMinPerc"} -- TODO: , "threshMaxPerc" with economy
-- table.insert(TeamsManager.validEventRules,"lastNotify") -- add system only rules
-- table.insert(TeamsManager.validEventRules,"alertCount") -- add system only rules

local tmsMgr
-- ################################################# Idle Alerts start here #################################################
function widget:UnitIdle(unitID, defID, teamID)
  TeamsManager.funcCounts.numIdle = TeamsManager.funcCounts.numIdle + 1
  if debug then Debugger("widget:UnitIdle 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID)..", defIDType=" .. type(defID) .. ", teamID=" .. tostring(teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = TeamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    if debug then Debugger("widget:UnitIdle 2. Going to getOrCreateUnit, then setIdle") end
    anArmy:getOrCreateUnit(unitID, defID):setIdle() -- automatically alerts when not idle
  end
end

function widget:UnitDestroyed(unitID, defID, teamID, attackerID, attackerDefID, attackerTeam)	-- Triggered when unit dies or construction canceled/destroyed while being built
  TeamsManager.funcCounts.numDestroyed = TeamsManager.funcCounts.numDestroyed + 1
  if debug then Debugger("widget:UnitDestroyed 1. Unit taken. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", attackerID=" ..tostring(attackerID) .. ", attackerDefID=" ..tostring(attackerDefID) .. ", attackerTeam=" ..tostring(attackerTeam) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  if debug then Debugger("UnitDestroyed 2 unitID=" ..tostring(unitID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local army = TeamsManager:getArmyManager(teamID)
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
  TeamsManager.funcCounts.numTaken = TeamsManager.funcCounts.numTaken + 1
  -- if not TeamsManager:validIDs(true, unitID, true, defID, true, oldTeamID, true, newTeamID, nil, nil) then Debugger("UnitTaken 0. INVALID input. Returning nil. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", oldTeamID=" .. tostring(oldTeamID) .. ", newTeamID=" .. tostring(newTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then Debugger("widget:UnitTaken 1. Unit taken. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID)  .. ", oldTeamID=" ..tostring(oldTeamID) .. ", newTeamID=" ..tostring(newTeamID)) end
  if not IsSpectator and (TeamsManager:getArmyManager(oldTeamID):hasTypeEventRules(defID) or TeamsManager:getArmyManager(newTeamID):hasTypeEventRules(defID)) then
    local oldArmy = TeamsManager:getArmyManager(oldTeamID)
    if oldArmy then
      local aUnit = oldArmy:getOrCreateUnit(unitID, defID)
      if aUnit then
        TeamsManager:moveUnit(unitID, defID, oldTeamID, newTeamID) -- automatically alerts
        aUnit:getIdle() -- automatically alerts when not idle
      end
    end
  end
end

function widget:UnitCreated(unitID, defID, teamID, builderID) -- Starts being built
  TeamsManager.funcCounts.numCreated = TeamsManager.funcCounts.numCreated + 1
  if debug then Debugger("widget:UnitCreated 1. Unit construction started. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", teamID=" ..tostring(teamID) .. ", builderID=" ..tostring(builderID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local army = TeamsManager:getArmyManager(teamID)
  if army and army:hasTypeEventRules(defID) then
    army:getOrCreateUnit(unitID, defID) -- automatically alerts
  end
end

function widget:UnitFinished(unitID, defID, teamID, builderID) -- Finished being built
  TeamsManager.funcCounts.numFinished = TeamsManager.funcCounts.numFinished + 1
  if debug then Debugger("widget:UnitFinished 1 is now completed and ready. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", teamID=" ..tostring(teamID) .. ", builderID=" ..tostring(builderID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local army = TeamsManager:getArmyManager(teamID)
  if army and army:hasTypeEventRules(defID) then
    local aUnit = army:getOrCreateUnit(unitID, defID)
    if debug then Debugger("widget:UnitFinished 2. Sending alert. unitID=" .. tostring(unitID) .. ", unitDefID=" ..tostring(defID) .. ", teamID=" ..tostring(teamID) .. ", builderID=" ..tostring(builderID)) end
    local finishedEvent = aUnit:getTypesRulesForEvent("finished", true, true)
    if finishedEvent then
      TeamsManager:addUnitToAlertQueue(aUnit, finishedEvent)
    end
    aUnit:getIdle() -- automatically alerts
  end
end

function widget:UnitEnteredLos(unitID, teamID, allyTeam, defID) -- Called when a unit enters LOS of an allyteam. Its called after the unit is in LOS, so you can query that unit. The allyTeam is who's LOS the unit entered.
  TeamsManager.funcCounts.numLOS = TeamsManager.funcCounts.numLOS + 1
  if IsSpectator then
    return
  end
  if defID == nil then
    defID = Spring.GetUnitDefID(unitID)
    if defID == nil then
      Debugger("widget:UnitEnteredLos 0. Cannot get defID for unit?")
      return nil
    end
  end
  -- if not TeamsManager:validIDs(true, unitID, nil, nil, true, teamID, nil, nil, nil, nil) then Debugger("UnitEnteredLos 0. INVALID input. Returning nil unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", allyTeam=" .. tostring(allyTeam) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then Debugger("widget:UnitEnteredLos 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", allyTeam=" .. tostring(allyTeam) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end -- 
  local anArmy = TeamsManager:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    local aUnit = anArmy:getOrCreateUnit(unitID, defID)
    if aUnit then
      local losEvent = aUnit:getTypesRulesForEvent("los", true, true)
      if losEvent then
        TeamsManager:addUnitToAlertQueue(aUnit, losEvent)
      end
    end
  end
end

local function checkPersistentEvents() -- Checks all of the events that BAR widgets don't cover
  TeamsManager.funcCounts.numCkPrst = TeamsManager.funcCounts.numCkPrst + 1
  if debug then Debugger("checkPersistentEvents 1.") end
  local armiesToCheck
  if IsSpectator then
    if debug then Debugger("checkPersistentEvents 2. IsSpectator, using all armies.") end
    armiesToCheck = TeamsManager.armies
  else
    if debug then Debugger("checkPersistentEvents 2. Is Player, using myArmyManager.") end
    armiesToCheck = {MyTeamID = TeamsManager.myArmyManager}
  end
  local deadUnits = {} -- ensure dead units get removed from persistently checked tables
  for _, anArmyManager in pairs(armiesToCheck) do
    if not anArmyManager.isGaia then
      if type(anArmyManager["idle"]) == "table" then
        for unitID, unit in pairs(anArmyManager["idle"]) do
          if Spring.GetUnitIsDead(unitID) then
            if debug then Debugger("checkPersistentEvents 3. Dead Unit found.") end
            deadUnits[unitID] = unit
          elseif not TeamsManager:getQueuedEvents(unit,nil,nil,"idle") and unit:getIdle() == true then
            if debug then Debugger("checkPersistentEvents 4. Builder idle. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", teamID=" .. tostring(unit.parent.teamID)) end
            local typeRules = unit:getTypesRulesForEvent("idle", true, true)
            if typeRules then
              if debug then Debugger("checkPersistentEvents 5. CanAlertNow for idle. Going to addUnitToAlertQueue.") end
              TeamsManager:addUnitToAlertQueue(unit, typeRules)
            end
          end
        end
      end
      if type(anArmyManager["thresholdHP"]) == "table" then
        for unitID, unit in pairs(anArmyManager["thresholdHP"]) do
          if Spring.GetUnitIsDead(unitID) then
            if debug then Debugger("checkPersistentEvents 5. Removing Dead Unit.") end
            deadUnits[unitID] = unit
          else
            if debug then Debugger("checkPersistentEvents 5. Checking thresholdHP. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", teamID=" .. tostring(unit.parent.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
            if not TeamsManager:getQueuedEvents(unit,nil,nil,"thresholdHP") then
              unit:getHealth() -- automatically alerts
            end
          end
        end
      end
      -- Next phase - non-unit events
      -- anArmyManager.resources["metal"]["currentLevel"], anArmyManager.resources["metal"]["storage"], anArmyManager.resources["metal"]["pull"], anArmyManager.resources["metal"]["income"], anArmyManager.resources["metal"]["expense"], anArmyManager.resources["metal"]["share"], anArmyManager.resources["metal"]["sent"], anArmyManager.resources["metal"]["received"] = Spring.GetTeamResources (anArmyManager.teamID, "metal")
      -- if debug then Debugger("checkPersistentEvents 6. Checking Metal. teamID=" ..tostring(anArmyManager.teamID)..", currentLevel="..anArmyManager.resources["metal"]["currentLevel"]..", storage="..anArmyManager.resources["metal"]["storage"]..", pull="..anArmyManager.resources["metal"]["pull"]..", income="..anArmyManager.resources["metal"]["income"]..", expense="..anArmyManager.resources["metal"]["expense"]..", share="..anArmyManager.resources["metal"]["share"]..", sent="..anArmyManager.resources["metal"]["sent"]..", received="..anArmyManager.resources["metal"]["received"]) end
      -- anArmyManager.resources["energy"]["currentLevel"], anArmyManager.resources["energy"]["storage"], anArmyManager.resources["energy"]["pull"], anArmyManager.resources["energy"]["income"], anArmyManager.resources["energy"]["expense"], anArmyManager.resources["energy"]["share"], anArmyManager.resources["energy"]["sent"], anArmyManager.resources["energy"]["received"] = Spring.GetTeamResources (anArmyManager.teamID, "metal")
      -- if debug then Debugger("checkPersistentEvents 7. Checking Energy. teamID=" ..tostring(anArmyManager.teamID)..", currentLevel="..anArmyManager.resources["energy"]["currentLevel"]..", storage="..anArmyManager.resources["energy"]["storage"]..", pull="..anArmyManager.resources["energy"]["pull"]..", income="..anArmyManager.resources["energy"]["income"]..", expense="..anArmyManager.resources["energy"]["expense"]..", share="..anArmyManager.resources["energy"]["share"]..", sent="..anArmyManager.resources["energy"]["sent"]..", received="..anArmyManager.resources["energy"]["received"]) end
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
--   funcCounts.numDamaged = funcCounts.numDamaged + 1
--   TeamsManager.isEnabledDamagedWidget = true
--   if debug then Debugger("widget:UnitDamaged 1. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", damage=" .. tostring(damage) .. ", paralyzer=" .. tostring(paralyzer) .. ", weaponDefID=" .. tostring(weaponDefID) .. ", projectileID=" .. tostring(projectileID) .. ", attackerUnitID=" .. tostring(attackerUnitID) .. ", attackerDefID=" .. tostring(attackerDefID) .. ", attackerTeamID=" .. tostring(attackerTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
--   local army = TeamsManager:getArmyManager(teamID)
--   if army and (army:hasTypeEventRules(defID, nil, "damaged") or army:hasTypeEventRules(defID, nil, "thresholdHP")) then
--     if debug then Debugger("widget:UnitDamaged 2. Going to damaged-getHealth") end
--     army:getOrCreateUnit(unitID, defID):getHealth() -- automatically alerts for damaged and thresholdHP
--   end
-- end

-- Disregard unless this is fixed in BAR. Would go above.
  -- if attackerUnitID and attackerDefID and attackerTeamID then -- Can't because BAR always nil for these in UnitDamaged
  --   army = TeamsManager:getArmyManager(attackerTeamID)
  --   if army and army:hasTypeEventRules(defID, nil, "attacks") then
  --     local aUnit = army:getOrCreateUnit(unitID, defID)
  --     if aUnit then
  --       if true then Debugger("widget:UnitDamaged 3. Attacker found. Going to getTypesRulesForEvent") end
  --       local attacksEvent = aUnit:getTypesRulesForEvent("attacks", true, true)
  --       if attacksEvent then
  --         if true then Debugger("widget:UnitDamaged 4. Has attacksEvent. Going to addUnitToAlertQueue") end
  --         TeamsManager:addUnitToAlertQueue(aUnit, attacksEvent)
  --       end
  --     end
  --   end
  -- end

-- doesn't run when spectating
function widget:CommandsChanged() -- Called when the command descriptions changed, e.g. when selecting or deselecting a unit. Because widget:UnitIdle doesn't happen when the player removes the last unit in the factory queue
  TeamsManager.funcCounts.numCommands = TeamsManager.funcCounts.numCommands + 1
  if IsSpectator then return
  elseif debug then Debugger("widget:CommandsChanged 1. Called when the command descriptions changed, e.g. when selecting or deselecting a unit.") end
	if type(TeamsManager.myArmyManager.factories) == "table" then
    for unitID, unit in pairs(TeamsManager.myArmyManager.factories) do
      if debug then Debugger("CommandsChanged 2. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", isFactory=" .. tostring(unit.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
      if unit:getIdle() == true then -- automatically adds unit to idle alert queue if it applies
        if debug then Debugger("widget:CommandsChanged 3. Factory added to parent[idle] table. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID)) end
      end
    end
  end
  -- AlertMessage("Easy Alerts is fully running :( ", "me")
end

function widget:UnitLoaded(unitID, defID, teamID, transportID, transportTeamID) -- Called when a unit is loaded by a transport.
  TeamsManager.funcCounts.numLoaded = TeamsManager.funcCounts.numLoaded + 1
  -- if not tmsMgr:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then Debugger("UnitLoaded 0. INVALID input. Returning nil unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then Debugger("widget:UnitLoaded 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = tmsMgr:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    local aUnit = anArmy:getOrCreateUnit(unitID, defID)
    if aUnit then
      local loadedEvent = aUnit:getTypesRulesForEvent("loaded", true, true)
      if loadedEvent then
        tmsMgr:addUnitToAlertQueue(aUnit, loadedEvent)
      end
    end
  end
end

function widget:StockpileChanged(unitID, defID, teamID, weaponNum, oldCount, newCount) -- Called when a units stockpile of weapons increases or decreases. See stockpile.
  TeamsManager.funcCounts.numStockpile = TeamsManager.funcCounts.numStockpile + 1
  -- if not tmsMgr:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then Debugger("StockpileChanged 0. INVALID input. Returning nil unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", transportID=" .. tostring(transportID) .. ", transportTeamID=" .. tostring(transportTeamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) return nil end
  if debug then Debugger("widget:StockpileChanged 1. unitID=" .. tostring(unitID)..", defID=" .. tostring(defID) .. ", teamID=" .. tostring(teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  local anArmy = tmsMgr:getArmyManager(teamID)
  if anArmy and anArmy:hasTypeEventRules(defID) then
    local aUnit = anArmy:getOrCreateUnit(unitID, defID)
    if aUnit then
      local loadedEvent = aUnit:getTypesRulesForEvent("stockpile", true, true)
      if loadedEvent then
        tmsMgr:addUnitToAlertQueue(aUnit, loadedEvent)
      end
    end
  end
end

-- function widget:GameFrame(frame)
--   if warnFrame == 1 then -- with 30 UpdateInterval, run roughlys every half second
--     checkPersistentEvents()
--     if AlertQueue:getSize() > 0 then
--       tmsMgr:alert()
--     end
--   end
--   warnFrame = (warnFrame + 1) % UpdateInterval
-- end

function widget:PlayerChanged(playerID)
  MyTeamID = Spring.GetMyTeamID()
	IsSpectator = Spring.GetSpectatingState()
end

function widget:Initialize()
  widget:PlayerChanged()
	Spring.Echo("Starting " .. widgetName)
  tmsMgr = TeamsManager:Initialize(trackMyTypesRules, trackAllyTypesRules, trackEnemyTypesRules, trackSpectatorTypesRules, myCustomGroups,allyCustomGroups,enemyCustomGroups,spectatorCustomGroups)
	if not tmsMgr then
    Debugger("makeRelTeamDefsRules() or loadCustomGroups() returned FALSE. Fix trackMyTypesRules, trackAllyTypesRules, trackEnemyTypesRules, or custom group tables tables.")
    widget:Shutdown()
  end
  local gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
	if true then Debugger("widget:Initialize 1. gameID="..tostring(gameID)..", IsSpectator="..tostring(IsSpectator)) end --  .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)
  -- debug = true
  return
  --   -- TODO: Maybe. Load All Units if replay or starting mid-game ########## 
end

function widget:Shutdown()
	if TeamsManager.config.FunctionRunCounts then Debugger("FunctionRunCounts:\n numArmies="..tostring(TeamsManager.funcCounts.numArmies).."\n numCreateUnit="..tostring(TeamsManager.funcCounts.numCreateUnit)..", numStockpile="..tostring(TeamsManager.funcCounts.numStockpile).."\n numLoaded="..tostring(TeamsManager.funcCounts.numLoaded).."\n numCommands="..tostring(TeamsManager.funcCounts.numCommands).."\n numCkPrst="..tostring(TeamsManager.funcCounts.numCkPrst).."\n numLOS="..tostring(TeamsManager.funcCounts.numLOS).."\n numFinished="..tostring(TeamsManager.funcCounts.numFinished).."\n numCreated="..tostring(TeamsManager.funcCounts.numCreated).."\n numTaken="..tostring(TeamsManager.funcCounts.numTaken).."\n numIdle="..tostring(TeamsManager.funcCounts.numIdle).."\n numDestroyed="..tostring(TeamsManager.funcCounts.numDestroyed).."\n numGetHealth="..tostring(TeamsManager.funcCounts.numGetHealth).."\n numGetCoords="..tostring(TeamsManager.funcCounts.numGetCoords).."\n numHasRules="..tostring(TeamsManager.funcCounts.numHasRules).."\n numSetTypes="..tostring(TeamsManager.funcCounts.numSetTypes).."\n numDamaged="..tostring(TeamsManager.funcCounts.numDamaged).."\n numSetLost="..tostring(TeamsManager.funcCounts.numSetLost).."\n numGetIdle="..tostring(TeamsManager.funcCounts.numGetIdle).."\n numSetNotIdle="..tostring(TeamsManager.funcCounts.numSetNotIdle).."\n numSetIdle="..tostring(TeamsManager.funcCounts.numSetIdle).."\n numHasEventRules="..tostring(TeamsManager.funcCounts.numHasEventRules).."\n numCanAlert="..tostring(TeamsManager.funcCounts.numCanAlert).."\n numGetRulesForEvent="..tostring(TeamsManager.funcCounts.numGetRulesForEvent).."\n numGetOrCreate="..tostring(TeamsManager.funcCounts.numGetOrCreate).."\n numGetUnit="..tostring(TeamsManager.funcCounts.numGetUnit).."\n numValidRules="..tostring(TeamsManager.funcCounts.numValidRules).."\n numGetQueued="..tostring(TeamsManager.funcCounts.numGetQueued).."\n numGetNextAlert="..tostring(TeamsManager.funcCounts.numGetNextAlert).."\n numGetNotifyVars="..tostring(TeamsManager.funcCounts.numGetNotifyVars).."\n numAddAlert="..tostring(TeamsManager.funcCounts.numAddAlert).."\n numAlert="..tostring(TeamsManager.funcCounts.numAlert).."\n numValidIDs="..tostring(TeamsManager.funcCounts.numValidIDs).."\n numMoveUnit="..tostring(TeamsManager.funcCounts.numMoveUnit).."\n numIsAllied="..tostring(TeamsManager.funcCounts.numIsAllied).."\n numIfInitialized="..tostring(TeamsManager.funcCounts.numIfInitialized).."\n numGetArmy="..tostring(TeamsManager.funcCounts.numGetArmy)) end
  if TeamsManager.config.logEvents then
    local gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
    SaveTable("myData", TeamsManager.config.logEventsTbl, ("ea"..gameID..".lua"))
  end
  Spring.Echo(widgetName .. " widget disabled")
end

function widget:GameOver()
  Spring.Echo("GameOver: "..widgetName)
end
-- TODO: make separate lua files. VFS: https://springrts.com/wiki/Lua_VFS
-- TODO: make so only widgets needed are imported
-- When maxAlerts met using sharedAlerts, remove rule to keep new units being loaded, but don't worry about the existing units... until much later
-- For spectator: could make sharedAlerts=all/team so can have shared team alerts...