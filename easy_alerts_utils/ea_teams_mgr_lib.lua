-- Library files should not have GetInfo(), causes crash by caller lua
VFS.Include("LuaUI/easy_alerts_utils/ea_general_lib.lua")

MyTeamID = Spring.GetMyTeamID()
-- MyPlayerID = Spring.GetMyPlayerID()
IsSpectator = Spring.GetSpectatingState()

TeamsManager = ProtoObject:clone()
TeamsManager.debug = false
TeamsManager.armies = {} -- armies key/value. Added with TeamsManager[teamID] key = [armyManager].
TeamsManager.myArmyManager = nil  -- will hold easy quick reference to main player's armyManager.
TeamsManager.lastUpdate = 0
TeamsManager.relevantMyUnitDefsRules = {} -- unitDefID (key), typeArray {commander,builder} Types match to types above --  -- {defID = {type = {event = {rules}}}}
TeamsManager.relevantAllyUnitDefsRules = {} -- unitDefs wanted in ally armyManagers
TeamsManager.relevantEnemyUnitDefsRules = {} -- unitDefs wanted in enemy armyManagers
TeamsManager.relevantSpectatorUnitDefsRules = {}
TeamsManager.lastAlertTime = 0

TeamsManager.config = {}
TeamsManager.config.minReAlertSec = 3 -- to prevent a bunch at once
TeamsManager.config.logEvents = false
TeamsManager.config.deleteDestroyed = false -- For possible RAM concerns. Though, in the few small tests I tried it didn't seem to save more RAM
TeamsManager.config.FunctionRunCounts = false

TeamsManager.defTypesEventsRules = {}
TeamsManager.validEvents = {"created","finished","idle","destroyed","los","thresholdHP","taken","given","damaged","loaded","stockpile"}
TeamsManager.validEventRules = {"sharedAlerts", "priority", "reAlertSec", "maxAlerts", "alertDelay", "maxQueueTime", "alertSound", "mark", "ping","messageTo","messageTxt", "threshMinPerc"} -- TODO: , "threshMaxPerc" with economy
table.insert(TeamsManager.validEventRules,"lastNotify") -- add system only rules
table.insert(TeamsManager.validEventRules,"alertCount") -- add system only rules
TeamsManager.funcCounts = {numArmies=0, numStockpile=0, numLoaded=0, numCommands=0, numCkPrst=0, numLOS=0, numFinished=0, numCreated=0, numTaken=0, numIdle=0, numDestroyed=0, numGetHealth=0, numGetCoords=0, numHasRules=0, numSetTypes=0, numDamaged=0, numSetLost=0, numGetIdle=0, numSetNotIdle=0, numSetIdle=0, numHasEventRules=0, numCanAlert=0, numGetRulesForEvent=0, numGetOrCreate=0, numGetUnit=0, numCreateUnit=0, numValidRules=0, numGetQueued=0, numGetNextAlert=0, numGetNotifyVars=0, numAddAlert=0, numAlert=0, numValidIDs=0, numMoveUnit=0, numIsAllied=0, numIfInitialized=0, numGetArmy=0}
TeamsManager.eventRules = {}
TeamsManager.logEventsTbl = {}

TeamsManager.isEnabledDamagedWidget = false -- This will toggle itself if widget:UnitDamaged is enabled. If performance is an issue, try commenting it out there.

local pArmyManager = ProtoObject:clone()
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

local pUnit = ProtoObject:clone()
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
function TeamsManager:makeAllArmies()
  if debug or self.debug then Debugger("makeAllArmies 1.") end
  local gaiaTeamID = Spring.GetGaiaTeamID()  -- Game's Gaia (environment) compID, but not considered an AI
  local tmpTxt = "makeAllArmies.  teamID/AllyID check\n"
  for _,teamID1 in pairs(Spring.GetTeamList()) do
    local teamID2,leaderNum,isDead,isAiTeam,strSide,allianceID = Spring.GetTeamInfo(teamID1)
    if teamID1 == gaiaTeamID then -- Game's Gaia (environment) actor 
      if debug or self.debug then tmpTxt = tmpTxt .. "Gaia Env is on teamID " ..tostring(teamID1) .. " in allianceID " .. tostring(allianceID) .. ", isDead=" .. tostring(isDead) .. "\n" end
      if debug or self.debug then Debugger("makeAllArmies 2. Adding Gaia.") end
      self:newArmyManager(gaiaTeamID, allianceID)
    elseif isAiTeam then
      if debug or self.debug then tmpTxt = tmpTxt .. "AI is on teamID " ..tostring(teamID1) .. " in allianceID " .. tostring(allianceID) .. ", isDead=" .. tostring(isDead) .. "\n" end
      if debug or self.debug then Debugger("makeAllArmies 3. Adding AI.") end
      self:newArmyManager(teamID1, allianceID)
    else -- compID is Human
      for _,playerID in pairs(Spring.GetPlayerList(teamID1)) do -- Get all players on the compID
        local playerName, isActive, IsSpectatorTmp, teamIDTmp, allyTeamIDTmp, pingTime, cpuUsage, country, rank, customPlayerKeys = Spring.GetPlayerInfo(teamID1)
        if teamIDTmp == teamID1 then
          local tmpPlayerText = "playerID " .. tostring(playerID)
          if isActive then
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " is Active" end
          else
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " is Inactive" end
          end
          if IsSpectatorTmp then
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " Spectator" end
          else
            if debug or self.debug then tmpPlayerText = tmpPlayerText .. " Participant" end
            local anArmy = self:getArmyManager(teamID1)
            if type(anArmy) == "nil" then
              if debug or self.debug then Debugger("makeAllArmies 4. Adding newArmyManager. teamID=" .. tostring(teamID1) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
              anArmy = self:newArmyManager(teamID1, allianceID, playerID, playerName)
            else
              if debug or self.debug then Debugger("makeAllArmies 5. Adding Player. playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
              anArmy:addPlayer(playerID, playerName)
            end
          end
          if debug or self.debug then tmpPlayerText = tmpPlayerText .. " with teamID " ..tostring(teamIDTmp) .. " in allianceID " .. tostring(allyTeamIDTmp) .. ", isDead=" .. tostring(isDead) .. "\n" end
          if debug or self.debug then tmpTxt = tmpTxt .. tmpPlayerText end
        end
      end
    end
  end
  if debug or self.debug then Debugger(tmpTxt) end
  if IsSpectator then
    TeamsManager.defTypesEventsRules = self.relevantSpectatorUnitDefsRules
    for aDef,aTypesTbl in pairs(TeamsManager.defTypesEventsRules) do
      for aType, eventsTbl in pairs(aTypesTbl) do
        for event,rulesTbl in pairs(eventsTbl) do
          if rulesTbl["sharedAlerts"] then
            local baseObj = TeamsManager
            if type(baseObj["lastAlerts"]) ~= "table" then
              if debug then Debugger("newTeamsManager 6. Creating lastAlerts.")end
              baseObj["lastAlerts"] = {}
            end
            local lastAlerts = baseObj["lastAlerts"]
            if type(lastAlerts[aType]) ~= "table" then
              if debug then Debugger("newTeamsManager 7. Creating unitOrArmyObj["..tostring(aType).."]")end
              lastAlerts[aType] = {}
            end
            if type(lastAlerts[aType][event]) ~= "table" then
              if debug then Debugger("newTeamsManager 8. Creating unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]") end
              lastAlerts[aType][event] = {}
              lastAlerts[aType][event]["lastNotify"] = 0
              lastAlerts[aType][event]["alertCount"] = 0
              lastAlerts[aType][event]["isQueued"] = false
              if debug then Debugger("newTeamsManager 9. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", sharedAlerts="..tostring(rulesTbl["sharedAlerts"])) end
            end
          end
        end
      end
    end
  end
  if debug then Debugger("newTeamsManager 10. Ending.") end
end

-- WARNING 1: If playerID not used, will assume is an AI
-- WARNING 2: Possible to add Spectators because it doesn't check
function TeamsManager:newArmyManager(teamID, allianceID, playerID, playerName) -- Returns newArmyManager child object. playerID optional. Creates the requested new army with the basic IDs. Will return nil if already exists because a different method should be used.
  TeamsManager.funcCounts.numArmies = TeamsManager.funcCounts.numArmies + 1
  if debug or self.debug then Debugger("newArmyManager 1. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
  if not TeamsManager:validIDs(nil, nil, nil, nil, true, teamID, true, allianceID, nil, nil) then Debugger("newArmyManager 2. INVALID input. Returning nil.") return nil end
  local armyManager = self:getArmyManager(teamID)
  if type(armyManager) ~= "nil" then -- if an armyManager with teamID already exists, return nil
    Debugger("newArmyManager 3. ERROR, shouldn't happen. ArmyManager ALREADY EXISTS. Returning nil. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID))
    return nil
  end
  armyManager = pArmyManager:clone()
  if type(armyManager) == "nil" then
    Debugger("newArmyManager 4. ERROR ArmyManager NOT CREATED. Returning nil. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID))
    return nil
  end
  local gameSecs = Spring.GetGameSeconds()
  self.lastUpdate = gameSecs
  armyManager.lastUpdate = gameSecs -- Game seconds last update time of the armyManager
  armyManager.teamID = teamID
  armyManager.allianceID = allianceID
  armyManager.parent = self -- link the TeamsManager new armyManager
  self.armies[teamID] = armyManager
  if debug or self.debug then Debugger("newArmyManager 5. New Army created. armyManager Type=" .. type(armyManager) .. ", teamID=" .. tostring(armyManager.teamID) .. ", allianceID=" .. tostring(armyManager.allianceID) .. ", self.armies[teamID].teamID=" .. tostring(self.armies[teamID].teamID)) end
  if not IsSpectator and teamID == MyTeamID then
    armyManager.isMyTeam = true
    self.myArmyManager = armyManager
    armyManager.defTypesEventsRules = TeamsManager.relevantMyUnitDefsRules
  elseif Spring.AreTeamsAllied(teamID, MyTeamID) then
    armyManager.defTypesEventsRules = TeamsManager.relevantAllyUnitDefsRules
  else
    armyManager.defTypesEventsRules = TeamsManager.relevantEnemyUnitDefsRules
  end
  if IsSpectator == false then -- this is here because MakeAllArmies takes care of it when spectator
    for aDef,aTypesTbl in pairs(armyManager.defTypesEventsRules) do
      for aType, eventsTbl in pairs(aTypesTbl) do
        for event,rulesTbl in pairs(eventsTbl) do
          if rulesTbl["sharedAlerts"] then
            local baseObj = armyManager
            -- if IsSpectator then
            --   baseObj = TeamsManager
            -- end
            if type(baseObj["lastAlerts"]) ~= "table" then
              if debug then Debugger("newArmyManager 6. Creating lastAlerts.")end
              baseObj["lastAlerts"] = {}
            end
            local lastAlerts = baseObj["lastAlerts"]
            if type(lastAlerts[aType]) ~= "table" then
              if debug then Debugger("newArmyManager 7. Creating unitOrArmyObj["..tostring(aType).."]")end
              lastAlerts[aType] = {}
            end
            if type(lastAlerts[aType][event]) ~= "table" then
              if debug then Debugger("newArmyManager 8. Creating unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]") end
              lastAlerts[aType][event] = {}
              lastAlerts[aType][event]["lastNotify"] = 0
              lastAlerts[aType][event]["alertCount"] = 0
              lastAlerts[aType][event]["isQueued"] = false
              if debug then Debugger("newArmyManager 9. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", sharedAlerts="..tostring(rulesTbl["sharedAlerts"])) end
            end
          end
        end
      end
    end
  end
  if type(playerID) == "nil" then
    if teamID == Spring.GetGaiaTeamID() then
      armyManager.isGaia = true
      if debug or self.debug then Debugger("newArmyManager 10. Gaia created. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", isGaia=" .. tostring(armyManager.isGaia)) end
    else
      armyManager.isAI = true
      if debug or self.debug then Debugger("newArmyManager 11. AI created. teamID=" .. tostring(teamID) .. ", allianceID=" .. tostring(allianceID) .. ", playerID=" .. tostring(playerID) .. ", isAI=" .. tostring(armyManager.isAI)) end
    end
    return armyManager
  end
  armyManager:addPlayer(playerID, playerName)
  if debug or self.debug then Debugger("newArmyManager 12. Player created. armyManager Type=" .. type(armyManager) .. ", teamID=" .. tostring(armyManager.teamID) .. ", allianceID=" .. tostring(armyManager.allianceID) .. ", playerName=" .. tostring(armyManager.playerIDsNames[playerID])) end
  return armyManager
end

function TeamsManager:getArmyManager(teamID) -- Returns existing ArmyManager (child object) or nil if doesn't exist
	TeamsManager.funcCounts.numGetArmy = TeamsManager.funcCounts.numGetArmy + 1
  if debug or self.debug then Debugger("getArmyManager 1. teamID=" .. tostring(teamID)) end
  -- if not TeamsManager:validIDs(nil, nil, nil, nil, true, teamID, nil, nil, nil, nil) then Debugger("getArmyManager 2. INVALID input. Returning nil.") return nil end
  local anArmy = self.armies[teamID]
  if type(anArmy) == "nil" then
    if debug or self.debug then Debugger("getArmyManager 3. Should only happen while making armies. Returning Nil because teamID=" .. tostring(teamID) .. " not found) anArmy Type=" .. type(anArmy)) end
    return nil
  end
  if debug or self.debug then Debugger("getArmyManager 4. Found and returning anArmy Type=" .. type(anArmy) .. ", teamID=" .. tostring(self.armies[teamID].teamID)) end
  return anArmy
end

function TeamsManager:getUnit(unitID, teamID)
  if debug or self.debug then Debugger("TeamsManager:getUnit 1. unitID=" .. tostring(unitID) .. ", teamID=" .. tostring(teamID)) end
  -- if not TeamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then Debugger("TeamsManager:getUnit 2. INVALID input. Returning nil.") return nil end
  if type(teamID) == "nil" then
    if debug or self.debug then Debugger("TeamsManager:getUnit 3. Nil teamID. Trying Spring.GetUnitTeam(unitID). unitID=" .. tostring(unitID) .. ", teamID=" .. tostring(teamID)) end
    teamID = Spring.GetUnitTeam(unitID)
    -- if not TeamsManager:validIDs(nil, nil, nil, nil, true, teamID, nil, nil, nil, nil) then Debugger("TeamsManager:getUnit 4. INVALID input. Returning nil.") return nil end
  end
  local anArmy = self:getArmyManager(teamID)
  if type(anArmy) == "nil" then
    Debugger("TeamsManager:getUnit 5. ERROR. TeamsManager:getArmyManager= nil. Army NOT FOUND, but should exist. Returning nil. unitID=" .. tostring(unitID) .. ", anArmy.teamID=" .. tostring(teamID))
      return nil
  else
    if debug or self.debug then Debugger("TeamsManager:getUnit 6. Found ArmyManager, Returning anArmy:getUnit(unitID). unitID=" .. tostring(unitID) .. ", anArmy.teamID=" .. tostring(anArmy.teamID)) end
      return anArmy:getUnit(unitID)
  end
end
-- this has two return types: nil if none found, or array of units if one or more found.
function TeamsManager:getUnitsIfInitialized(unitID) -- This should only be used before creating an enemy unit, because they can be moved between teams while outside los.
	TeamsManager.funcCounts.numIfInitialized = TeamsManager.funcCounts.numIfInitialized + 1
  if debug or self.debug then Debugger("TeamsManager:getUnitsIfInitialized 1. unitID=" .. tostring(unitID)) end
  -- if not TeamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then Debugger("TeamsManager:getUnitsIfInitialized 2. INVALID input. Returning nil.") return nil end
  local unitsFound = {}; local aUnit
  for teamID, anArmy in pairs(self.armies) do
    aUnit = anArmy.units[unitID]
    if aUnit ~= nil then
      table.insert(unitsFound,aUnit)
    end
  end
  if debug or self.debug then Debugger("TeamsManager:getUnitsIfInitialized 3. Total units found=" .. tostring(#unitsFound)) end
  if #unitsFound == 0 then
    return nil
  elseif #unitsFound == 1 then
    return table.remove(unitsFound,1)
  else
    Debugger("TeamsManager:getUnitsIfInitialized 4. ERROR. MULTIPLE units found=" .. tostring(#unitsFound))
    return unitsFound
  end
end

function TeamsManager:createUnit(unitID, defID, teamID)
  if debug or self.debug then Debugger("TeamsManager:createUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", unitTeamID=" .. tostring(teamID)) end
  -- if not TeamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then Debugger("TeamsManager:createUnit 2. INVALID input. Returning nil.") return nil end
  local armyManager = self:getArmyManager(teamID)
  if type(armyManager) == "nil" then
    Debugger("TeamsManager:createUnit 3. ERROR. ArmyManager not found. unitTeamID=" .. tostring(teamID))
    return nil
  end
  return armyManager:createUnit(unitID, defID)
end

function TeamsManager:isAllied(teamID1, teamID2)  -- If playing and teamID2 not given, assumes it is MyTeamID 
	TeamsManager.funcCounts.numIsAllied = TeamsManager.funcCounts.numIsAllied + 1
  if debug or self.debug then Debugger("isAllied 1. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  -- if not TeamsManager:validIDs(nil, nil, nil, nil, true, teamID1, nil, nil, nil, nil) then Debugger("isAllied 2. INVALID input. Returning nil.") return nil end
  local armyManager1 = self:getArmyManager(teamID1)
  if not armyManager1 then
    Debugger("isAllied 3. ERROR. Army1 Obj not returned. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2))
    return nil
  end
  local armyManager2
  if not IsSpectator and type(teamID2) == "nil" then
    teamID2 = self.myArmyManager.teamID
    armyManager2 = self.myArmyManager
    if debug or self.debug then Debugger("isAllied 4. Using MyTeamID for T2. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  elseif type(teamID2) == "number" then
    armyManager2 = self:getArmyManager(teamID2)
  else
    Debugger("isAllied 5. ERROR. Need 2 teamIDs. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2) .. ", IsSpectator=" .. tostring(IsSpectator))
    return nil
  end
  if not armyManager2 then
    Debugger("isAllied 5. ERROR. Army2 Obj not returned. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2))
    return nil
  end
  local isAllied = armyManager1.allianceID == armyManager2.allianceID
  local isSpringAllied = Spring.AreTeamsAllied(teamID1, teamID2)
  if isAllied == isSpringAllied then
    if debug or self.debug then Debugger("isAllied 6. Spring agrees. isAllied=" .. tostring(isAllied) .. ", allianceID1=" .. tostring(armyManager1.allianceID) .. ", allianceID2=" .. tostring(armyManager2.allianceID)) end
    return isAllied
  else
    Debugger("isAllied 7. ERROR. Spring DISAGREES. Spring=" .. tostring(isSpringAllied) .. ", isAllied=" .. tostring(isAllied) .. ", allianceID1=" .. tostring(armyManager1.allianceID) .. ", allianceID2=" .. tostring(armyManager2.allianceID))
    return nil
  end
end

function TeamsManager:isEnemy(teamID1, teamID2)
  if debug or self.debug then Debugger("isEnemy 1. teamID1=" .. tostring(teamID1) .. ", teamID2=" .. tostring(teamID2)) end
  return self:isAllied(teamID1, teamID2) == false
end

function TeamsManager:moveUnit(unitID, defID, oldTeamID, newTeamID)
	TeamsManager.funcCounts.numMoveUnit = TeamsManager.funcCounts.numMoveUnit + 1
  if debug or self.debug then Debugger("moveUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", oldTeamID=" .. tostring(oldTeamID) .. ", newTeamID=" .. tostring(newTeamID)) end
  -- if not TeamsManager:validIDs(true, unitID, true, defID, true, oldTeamID, nil, nil, nil, nil) then Debugger("TeamsManager:moveUnit 2. INVALID input. Returning nil.") return nil end
  -- if not TeamsManager:validIDs(nil, nil, nil, nil, true, newTeamID, nil, nil, nil, nil) then Debugger("TeamsManager:moveUnit 3. INVALID input. Returning nil.") return nil end
  local oldTeamArmy = self:getArmyManager(oldTeamID)
  local newTeamArmy = self:getArmyManager(newTeamID)
  if type(oldTeamArmy) == "nil" or type(newTeamArmy) == "nil" then
    Debugger("moveUnit 4. ERROR. Either Army NOT found. oldTeamArmy=" .. type(oldTeamArmy) .. ", newTeamArmy" .. type(newTeamArmy))
    return nil
  end
  local aUnit = oldTeamArmy:getUnit(unitID)
  if type(aUnit) == "nil" then
    if debug or self.debug then Debugger("moveUnit 5. OldUnit not found CREATING IT AUTOMATICALLY. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", oldTeamID=" .. type(oldTeamID) .. ", newTeamID=" .. type(newTeamID)) end
    aUnit = self:createUnit(unitID, defID, oldTeamID)
    if type(aUnit) == "nil" then
      Debugger("moveUnit 6. ERROR. Failed to create/find new unit in oldTeamArmy. oldTeamArmy=" .. type(oldTeamArmy) .. ", newTeamArmy=" .. type(newTeamArmy))
      return nil
    end
  end
  local givenTaken
  if TeamsManager:isAllied(newTeamID, oldTeamID) then
    givenTaken = "given"
    if debug or self.debug then Debugger("moveUnit 9. Unit has been given. unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  else
    givenTaken = "taken"
    if debug or self.debug then Debugger("moveUnit 9. Unit has been taken. unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  end
  local takenEvent = aUnit:getTypesRulesForEvent(givenTaken, true, false)
  if takenEvent then
    if debug or self.debug then Debugger("moveUnit 10. Unit has rule to alert when taken/given, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    TeamsManager:addUnitToAlertQueue(aUnit, takenEvent)
  end
  aUnit:setLost(false)
  if not TeamsManager:getArmyManager(newTeamID):hasTypeEventRules(defID) then
    if debug or self.debug then Debugger("moveUnit 10. Unit has no rules on the new team, so making it nil. unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    aUnit = nil
    return
  end
  aUnit.parent = newTeamArmy
  newTeamArmy.units[unitID] = aUnit -- set here because it is only set in createUnit(), and setLost() removed from other army
  aUnit:setTypes(aUnit.defID)
  newTeamArmy.unitsReceived[aUnit.ID] = aUnit
  self.lastUpdate = Spring.GetGameSeconds()
  return aUnit
end

function TeamsManager:getOrCreateUnit(unitID, defID, teamID)
  if debug or self.debug then Debugger("TeamsManager:getOrCreateUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(teamID)) end
  -- if not TeamsManager:validIDs(true, unitID, true, defID, true, teamID, nil, nil, nil, nil) then Debugger("TeamsManager:getOrCreateUnit 2. INVALID input. Returning nil.") return nil end
  local anArmy = self:getArmyManager(teamID)
  if anArmy == nil then Debugger("TeamsManager:getOrCreateUnit 3. ERROR. Army NOT found. teamID=" .. tostring(teamID)) return nil end
  return anArmy:getOrCreateUnit(unitID, defID)
end

function TeamsManager:validIDs(vUnit, unitID, vdef, defID, vtm, teamID, vAlli, allianceID, vplr, playerID) -- only "v" vars=true will be validated
	TeamsManager.funcCounts.numValidIDs = TeamsManager.funcCounts.numValidIDs + 1
  if false then Debugger("validIDs 1. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID)) end
  local allValid = true
  if vUnit and type(unitID) ~= "number" then
    Debugger("validIDs 2. ERROR bad UnitID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vdef and type(defID) ~= "number" then
    Debugger("validIDs 3. ERROR bad defID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vtm and type(teamID) ~= "number" then
    Debugger("validIDs 4. ERROR bad teamID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vAlli and type(allianceID) ~= "number" then
    Debugger("validIDs 5. ERROR bad allianceID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  if vplr and type(playerID) ~= "number" then
    Debugger("validIDs 5. ERROR bad playerID. " .. tostring(vUnit) .. "-unitID=" .. tostring(unitID) .. ", " .. tostring(vdef) .. "-defID=" .. tostring(defID) .. ", " .. tostring(vtm) .. "-teamID=" .. tostring(teamID) .. ", " .. tostring(vAlli) .. "-allianceID=" .. tostring(allianceID) .. ", " .. tostring(vplr) .. "-playerID=" .. tostring(playerID))
    allValid = false
  end
  return allValid
end


function TeamsManager:alert(unitObj, alertVarsTbl) -- nil input alerts from AlertQueue. alertVarsTbl created by getEventRulesNotifyVars(unitObj,typeEventRulesTbl)
	TeamsManager.funcCounts.numAlert = TeamsManager.funcCounts.numAlert + 1
  if unitObj == nil and alertVarsTbl == nil then
    if debug or self.debug then Debugger("alert 1. Alert called without parameters. will attempt to use queue.") end
  else
    if debug or self.debug then Debugger("alert 1. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    if type(alertVarsTbl) ~= "table" then
      Debugger("alert 2. ERROR. Not nil or bad parameters. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl))
      return nil
    end
  end
  local success = false
  if unitObj == nil and alertVarsTbl == nil then
    if debug or self.debug then Debugger("alert 3. Going to getNextQueuedAlert.") end
    unitObj, alertVarsTbl, _ = self:getNextQueuedAlert()
    if alertVarsTbl == nil then
      if debug or self.debug then Debugger("alert 4. No alerts returned, exiting.") end
      return false
    end
  end
  if type(alertVarsTbl["alertSound"]) == "string" then -- play audio found in alertSound rule
    if debug or self.debug then Debugger("alert 5. About to play alertSound. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    AlertSound(alertVarsTbl["alertSound"])
    success = true
    TeamsManager.lastAlertTime = Spring.GetGameSeconds()
  end
  if type(alertVarsTbl["messageTxt"]) == "string" and type(alertVarsTbl["messageTo"]) == "string" then -- chat message and recipients
    if debug or self.debug then Debugger("alert 6. Going to alertMessage. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
    AlertMessage(alertVarsTbl["messageTxt"], alertVarsTbl["messageTo"])
    success = true
    TeamsManager.lastAlertTime = Spring.GetGameSeconds()
  end
  if type(unitObj) == "table" and type(unitObj.ID) == "number" and type(alertVarsTbl) == "table" then
    if debug or self.debug then Debugger("alert 7. Starting mark/ping part. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
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
        Debugger("alert 8. ERROR. Invalid coordinates=" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z))
        success = false
      else
        AlertPointer(x, y, z, pointerText, localOnly)
        if debug or self.debug then Debugger("alert 9. Returning True. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
        success = true
      end
    end
  end
  if success then
    local alertBaseObj = unitObj
    if alertVarsTbl["sharedAlerts"] then
      alertBaseObj = unitObj.parent
      if IsSpectator then
        alertBaseObj = TeamsManager
      end
    end
    alertBaseObj = alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]
    local gameSec = Spring.GetGameSeconds()
    alertBaseObj["lastNotify"] = gameSec
    alertBaseObj["alertCount"] = (alertBaseObj["alertCount"] + 1)
    TeamsManager.lastAlertTime = Spring.GetGameSeconds()
  end
  if debug or self.debug then Debugger("alert 10. was="..tostring(success)..", unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(alertVarsTbl)) end
  return success
end

function TeamsManager:addToEventTbl(aTbl,eventNum)
  
  
  local aConcat = "e"..tostring(eventNum) 
  TeamsManager.logEventsTbl[aConcat] = aTbl

end

function TeamsManager:addUnitToAlertQueue(unitObj, typeEventRulesTbl) -- Use [unit or armyMgr]:getTypesRulesForEvent() with topPriorityOnly = true. Must have one of each: type,event
	TeamsManager.funcCounts.numAddAlert = TeamsManager.funcCounts.numAddAlert + 1
  if debug or self.debug then Debugger("addUnitToAlertQueue 1. ") end
  if type(unitObj) ~= "table" or type(unitObj.ID) ~= "number" or type(typeEventRulesTbl) ~= "table" then
    Debugger("addUnitToAlertQueue 2. ERROR. Returning nil. Bad unit or rules table. unitObj.ID="..tostring(unitObj.ID)..", alertVarsTbl=" .. type(typeEventRulesTbl))
    return nil
  end
  unitObj:getCoords() -- in case it dies before the alert happens
  local alertVarsTbl = self:getEventRulesNotifyVars(unitObj, typeEventRulesTbl)
  if type(alertVarsTbl) ~= "table" then -- all is verified by getEventRulesNotifyVars()
    Debugger("addUnitToAlertQueue 3. ERROR. Returning nil. getEventRulesNotifyVars() returned nil. alertVarsTbl=" .. type(alertVarsTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if alertVarsTbl["sharedAlerts"] then
    alertBaseObj = unitObj.parent
    if IsSpectator then
      alertBaseObj = TeamsManager
    end
  end
  alertBaseObj = alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]
  local gameSecs = Spring.GetGameSeconds()
  if debug then Debugger("addUnitToAlertQueue 4. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(alertVarsTbl["maxAlerts"])..", mark="..tostring(alertVarsTbl["mark"])..", ping="..tostring(alertVarsTbl["ping"])..", alertSound="..tostring(alertVarsTbl["alertSound"]) .. ", TableToString=" .. TableToString(alertVarsTbl)) end
  if ((type(alertVarsTbl["mark"]) ~= "string") and (type(alertVarsTbl["ping"]) ~= "string") and type(alertVarsTbl["alertSound"]) ~= "string") or alertBaseObj["isQueued"] or gameSecs < alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"] or (alertVarsTbl["maxAlerts"] ~= 0 and alertBaseObj["alertCount"] >= alertVarsTbl["maxAlerts"]) then
    if debug then Debugger("addUnitToAlertQueue 4.1. Too soon or no alert rules. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. "<" .. tostring(alertBaseObj["lastNotify"] + alertVarsTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(alertVarsTbl["maxAlerts"])..", mark="..tostring(alertVarsTbl["mark"])..", ping="..tostring(alertVarsTbl["ping"])..", alertSound="..tostring(alertVarsTbl["alertSound"]) .. ", TableToString=" .. TableToString(alertVarsTbl)) end
    return false
  end
  local goodAlert = false
  if alertVarsTbl["priority"] == 0 then
    if debug then Debugger("addUnitToAlertQueue 5. SUCCESS. Priority 0 goes straight to alert(). priority=" .. tostring(alertVarsTbl["priority"])) end
    self:alert(unitObj, alertVarsTbl)
    goodAlert = true
  end




  if not goodAlert and not AlertQueue2:isEmpty() then -- ensure not adding duplicates and manage situations where an alert should be removed and/or replaced
    -- If already in queue for same event, vars used: teamID, unitType, event, sharedAlerts, priority, maxQueueTime, threshMinPerc, threshMaxPerc
    if debug then Debugger("addUnitToAlertQueue 6. sharedAlerts=" .. tostring(alertVarsTbl["sharedAlerts"]) .. ". Starting checks to decide if this alert should be queued and/or others removed/replaced. alertVarsTbl=" .. TableToString(alertVarsTbl)) end
    local alertMatchesTbls
    if alertVarsTbl["sharedAlerts"] then
      alertMatchesTbls = self:getQueuedEvents(nil,alertVarsTbl.teamID,alertVarsTbl["unitType"],alertVarsTbl["event"],nil,nil)
      if alertMatchesTbls then -- if shared, and same type/event, then don't add the new one
        if debug then Debugger("addUnitToAlertQueue 7. ERROR. Rejected because same shared type/event was present. Returning nil. alertVarsTbl=" .. TableToString(alertVarsTbl)) end
        return nil
      end
      if debug then Debugger("addUnitToAlertQueue 8. SUCCESS. Added sharedAlert to queue.") end
      AlertQueue2:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
      goodAlert = true
    else
      alertMatchesTbls = self:getQueuedEvents(unitObj,alertVarsTbl.teamID,nil,alertVarsTbl["event"],nil, nil)
    end
    if not goodAlert and alertMatchesTbls then
      local useNewAlert = true
      local bestPriority = alertVarsTbl["priority"]
      local removeHeapNums = {}
      -- for heapNum,value in ipairs(alertMatchesTbls) do -- {heapNum = {value = unitObj, alertRulesTbl = {[rule] = [value]}, priority = priority, queuedTime = Spring.GetGameSeconds()}}
      for i,qTbl in ipairs(alertMatchesTbls) do -- {heapNum = {value = unitObj, alertRulesTbl = {[rule] = [value]}, priority = priority, queuedTime = Spring.GetGameSeconds()}}
        if bestPriority < qTbl["priority"] then -- Remove duplicate with worse priority -- self.heap[heapNum].value
          if debug then Debugger("addUnitToAlertQueue 9. Will need to remove heap="..tostring(i)) end -- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
          table.insert(removeHeapNums,qTbl)
        else
          bestPriority = qTbl.alertRulesTbl["priority"]
          useNewAlert = false -- AlertQueue already has same or better, no need to add the new one
        end
      end
      if #removeHeapNums > 0 then
        for i,alrtQTbl in ipairs(removeHeapNums) do
          alrtQTbl = nil
        end
        
        for i = #AlertQueue2, 1, -1 do
          -- local value = AlertQueue2[i]
          -- Debugger(i, value)
          for i2,qTbl in ipairs(alertMatchesTbls) do
            if qTbl == AlertQueue2[i] then
              AlertQueue2[i] = nil
            end
          end
        end

        
      end
      if useNewAlert and bestPriority == alertVarsTbl["priority"] then
        if debug then Debugger("addUnitToAlertQueue 11. Adding requested alert after removing one with worse priority.") end
        goodAlert = true
      else
        if debug then Debugger("addUnitToAlertQueue 12. AlertQueue already has same or better, no need to add the new one.") end
        return false
      end
    end
  end
  -- if not goodAlert then
  --   if debug then Debugger("addUnitToAlertQueue 12.5. AlertQueue already has same or better, no need to add the new one.") end
  --   return false
  -- end
  if alertVarsTbl["priority"] > 0 then
    AlertQueue:insert(unitObj, alertVarsTbl, alertVarsTbl["priority"])
    alertBaseObj["isQueued"] = true
  end

  if TeamsManager.config.logEvents then
    alertVarsTbl["gmFr"] = Spring.GetGameFrame()
    if unitObj then
      alertVarsTbl["unit"] = {unitID=unitObj.ID,defID=unitObj.defID, teamID=unitObj.parent.teamID}
      if unitObj:getCoords() then
        alertVarsTbl["coords"] = {x=unitObj.coords["x"], y=unitObj.coords["y"], z=unitObj.coords["z"]}
      end
    end
    TeamsManager:addToEventTbl(alertVarsTbl,TeamsManager.funcCounts.numAddAlert)
  end
  
  if debug then Debugger("addUnitToAlertQueue 13. SUCCESS. Adding to queue.") end
  return true
end

-- Returns single-level key/value table with everything needed for addUnitToAlertQueue
function TeamsManager:getEventRulesNotifyVars(unitObj,typeEventRulesTbl ) -- validates and returns alertVarsTbl key,pair: {teamID, unitType, event, lastNotify, sharedAlerts, priority, reAlertSec, maxAlerts, alertCount, maxQueueTime, alertSound, mark, ping, threshMinPerc, threshMaxPerc}
	TeamsManager.funcCounts.numGetNotifyVars = TeamsManager.funcCounts.numGetNotifyVars + 1
  if debug then Debugger("getEventRulesNotifyVars 1. unitObj=" .. type(unitObj) .. ", typeEventRulesTbl=" .. type(typeEventRulesTbl)) end
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
    Debugger("getEventRulesNotifyVars 3. ERROR. Returning nil. Bad typeEventRulesTbl or multiple events provided. typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", TableToString=" .. TableToString(typeEventRulesTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if rulesTbl["sharedAlerts"] then
    alertBaseObj = unitObj.parent
    if IsSpectator then
      alertBaseObj = TeamsManager
    end
  end
  if not alertBaseObj or not alertBaseObj["lastAlerts"] or not alertBaseObj["lastAlerts"][unitType] or not alertBaseObj["lastAlerts"][unitType][event] or not alertBaseObj["lastAlerts"][unitType][event]["lastNotify"] or not alertBaseObj["lastAlerts"][unitType][event]["alertCount"] then
    Debugger("getEventRulesNotifyVars 4. ERROR. Returning nil. lastNotify or alertCount not initiated. unitType=" .. tostring(unitType) .. ", event=" .. tostring(event) .. ", sharedAlerts=" .. tostring(rulesTbl["sharedAlerts"]))
  end
  local lastNotify = alertBaseObj["lastAlerts"][unitType][event]["lastNotify"]
  local alertCount = alertBaseObj["lastAlerts"][unitType][event]["alertCount"]
  if type(lastNotify) ~= "number" or type(alertCount) ~= "number" then
    Debugger("getEventRulesNotifyVars 5. ERROR. Returning nil. Bad alertCount or lastSharedNotify=" .. type(lastNotify) .. ", type(alertCount)=" .. type(alertCount) .. ", TableToString=" .. TableToString(typeEventRulesTbl))
    return nil
  end
  return {["teamID"]=unitObj.parent.teamID, ["unitType"]=unitType, ["event"]=event, ["lastNotify"]=lastNotify, ["sharedAlerts"]=rulesTbl["sharedAlerts"], ["priority"]=rulesTbl["priority"], ["reAlertSec"]=rulesTbl["reAlertSec"], ["maxAlerts"]=rulesTbl["maxAlerts"], ["alertDelay"]=rulesTbl["alertDelay"], ["alertCount"]=alertCount, ["maxQueueTime"]=rulesTbl["maxQueueTime"], ["alertSound"]=rulesTbl["alertSound"], ["mark"]=rulesTbl["mark"], ["ping"]=rulesTbl["ping"], ["threshMinPerc"]=rulesTbl["threshMinPerc"], ["threshMaxPerc"]=rulesTbl["threshMaxPerc"]}
end

function TeamsManager:getNextQueuedAlert()
	TeamsManager.funcCounts.numGetNextAlert = TeamsManager.funcCounts.numGetNextAlert + 1
  if debug then Debugger("getNextQueuedAlert 1. queueSize="..tostring(AlertQueue:getSize())) end
  if Spring.GetGameSeconds() < TeamsManager.lastAlertTime + TeamsManager.config.minReAlertSec then
    if debug then Debugger("getNextQueuedAlert 1.1. Too soon due to minReAlertSec="..tostring(TeamsManager.config.minReAlertSec)..", remainingSecs="..TeamsManager.lastAlertTime + TeamsManager.config.minReAlertSec - Spring.GetGameSeconds()) end
    return nil
  end
  local validFound = false; local unitObj, alertVarsTbl, priority, queuedSec; local gameSecs = Spring.GetGameSeconds(); local heapNum = 1
  while validFound == false and AlertQueue:getSize() > 0 and heapNum <= AlertQueue:getSize() do
    unitObj, alertVarsTbl, priority, queuedSec = AlertQueue:peek(heapNum)
	if not alertVarsTbl or not unitObj then
		if debug then Debugger("getNextQueuedAlert 1.2. not alertVarsTbl or not unitObj="..type(unitObj)..", alertVarsTbl="..type(alertVarsTbl)) end
		return nil
	end
    if gameSecs <= queuedSec + alertVarsTbl["alertDelay"] then
      if debug then Debugger("getNextQueuedAlert 2. Still waiting alertDelay="..queuedSec + alertVarsTbl["alertDelay"] - gameSecs..", queueSize="..tostring(AlertQueue:getSize())) end
      heapNum = heapNum + 1
    else
      unitObj, alertVarsTbl, priority, queuedSec = AlertQueue:pull(heapNum)
		if not alertVarsTbl or not unitObj then
			if debug then Debugger("getNextQueuedAlert 2. not alertVarsTbl or not unitObj="..type(unitObj)..", alertVarsTbl="..type(alertVarsTbl)) end
			return nil
		end
      if debug then Debugger("getNextQueuedAlert 3. Pulled value=" .. type(unitObj) .. ", alertRulesTbl=" .. type(alertVarsTbl) .. ", priority=" .. tostring(priority) .. ", gameSecs=" .. tostring(gameSecs) .. ", unitName=" .. tostring(UnitDefs[unitObj.defID].translatedHumanName)) end
      if gameSecs <= queuedSec + alertVarsTbl["maxQueueTime"] then
        if debug then Debugger("getNextQueuedAlert 4. Valid found with remaining time="..queuedSec + alertVarsTbl["maxQueueTime"] - gameSecs) end
        validFound = true
      end
      if alertVarsTbl["event"] == "idle" and (alertVarsTbl["teamID"] ~= unitObj.parent.teamID or unitObj.isLost or unitObj:getIdle() == false) then -- important: "NOT unitObj:getIdle()" used because it returns nil while waiting the 5 frames to ensure the idle isn't a false positive.
        if debug then Debugger("getNextQueuedAlert 5. No longer idle.") end
        validFound = false
      end
      local alertBaseObj = unitObj
      if alertVarsTbl["sharedAlerts"] then
        alertBaseObj = unitObj.parent
        if IsSpectator then
          alertBaseObj = TeamsManager
        end
      end
      alertBaseObj["lastAlerts"][alertVarsTbl["unitType"]][alertVarsTbl["event"]]["isQueued"] = false
    end
  end
  if validFound then
    if debug then Debugger("getNextQueuedAlert 6. SUCCESS Valid found with remaining time="..queuedSec + alertVarsTbl["maxQueueTime"] - gameSecs) end
    return unitObj, alertVarsTbl, priority
  end
  if debug then Debugger("getNextQueuedAlert 7. None found.") end
  return nil, nil, nil
end

-- {value = value, alertRulesTbl = alertRulesTbl, priority = priority, queuedTime = Spring.GetGameSeconds()}
function TeamsManager:getQueuedEvents(unitObj,teamID,unitType,event,priorityLessThan,sharedAlerts) -- leaves them in queue. 
	TeamsManager.funcCounts.numGetQueued = TeamsManager.funcCounts.numGetQueued + 1
  if debug then Debugger("getQueuedEvents 1. Searching for unit teamID="..tostring(teamID)..", unitType="..tostring(unitType)..", event="..tostring(event)..", sharedAlerts="..tostring(sharedAlerts)..", priorityLessThan="..tostring(priorityLessThan)) end
  local matchedEvents = {}; local matches = 0; local size = AlertQueue2:getSize()
  if size > 0 then
    for i,valPriTbl in ipairs(AlertQueue2) do -- should probably replace AlertQueue.heap[heapNum] with valPriTbl $$$$$$$$$$$$
      if debug then Debugger("getQueuedEvents 2. Queued unit vars: heapNum=" .. tostring(i) .. ", sharedAlert="..tostring(valPriTbl.alertRulesTbl["sharedAlerts"]) .. ", priority="..tostring(valPriTbl["priority"]) .. ", queuedTime=" .. tostring(valPriTbl["queuedTime"]) .. ", teamID=" .. tostring(valPriTbl.alertRulesTbl.teamID) .. ", unitType=" .. tostring(valPriTbl.alertRulesTbl["unitType"]) .. ", event=" .. tostring(valPriTbl.alertRulesTbl["event"]) .. ", unitName=" .. tostring(UnitDefs[valPriTbl.value.defID].translatedHumanName)) end
      if (type(teamID) == "nil" or (type(teamID) == "number" and teamID == valPriTbl.alertRulesTbl.teamID)) and
      (type(unitType) == "nil" or (type(unitType) == "string" and unitType == valPriTbl.alertRulesTbl["unitType"])) and
      (type(event) == "nil" or (type(event) == "string" and event == valPriTbl.alertRulesTbl["event"])) and
      (type(unitObj) == "nil" or (type(unitObj) == "table" and unitObj == valPriTbl.value)) and
      (type(sharedAlerts) == "nil" or sharedAlerts == valPriTbl.alertRulesTbl["sharedAlerts"]) and
      (type(priorityLessThan) == "nil" or (type(priorityLessThan) == "number" and valPriTbl.priority < priorityLessThan )) then
        matches = matches +1
        table.insert(matchedEvents, valPriTbl) -- matchedEvents[matches] = AlertQueue2[heapNum] -- {heapNum = {value = unitObj, alertRulesTbl = {[rule] = [value]}, priority = priority, queuedTime = Spring.GetGameSeconds()}}
        if debug then Debugger("getQueuedEvents 3. Match found in heap=" .. tostring(i) .. ", unitName=" .. tostring(UnitDefs[valPriTbl.value.defID].translatedHumanName)) end
      end
    end
  end
  if matches < 1 then
    if debug then Debugger("getQueuedEvents 4. No matches found.") end
    return nil
  end
  if debug then Debugger("getQueuedEvents 5. Matches being returned=" .. tostring(matches)) end
  return matchedEvents
end

function TeamsManager:validTypeEventRulesTbls(typeTbl) --returns nil | true, typeCount, eventCount, ruleCount
	TeamsManager.funcCounts.numValidRules = TeamsManager.funcCounts.numValidRules + 1
  if debug then Debugger("validTypeEventRulesTbls 1. event=" .. type(typeTbl)) end
  if type(typeTbl) ~= "table" then
    Debugger("validTypeEventRulesTbls 2. ERROR. Returning False. Not eventTbl=" .. type(typeTbl))
    return nil
  end
  local typeCount = 0; local eventCount = 0; local ruleCount = 0; local emptyTypesToRemove = {}; local badValue = nil
  for aType,eventTbl in pairs(typeTbl) do
    if type(aType) ~= "string" then
      Debugger("validTypeEventRulesTbls 3. ERROR. Returning Nil. NOT string aType=" .. type(aType))
      return nil
    end
    if type(eventTbl) ~= "table" then
      if debug then Debugger("validTypeEventRulesTbls 3.1. Skipping this type because it could be a placeholder. Not eventTbl=" .. type(eventTbl) .. ", aType="..tostring(aType)) end
      table.insert(emptyTypesToRemove,aType)
    else
      typeCount = typeCount +1
      for anEvent,rulesTbl in pairs(eventTbl) do
        if type(anEvent) ~= "string" then
          Debugger("validTypeEventRulesTbls 3.2. ERROR. Returning False. NOT string anEvent=" .. type(anEvent))
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
          Debugger("validTypeEventRulesTbls 3.3. ERROR. Bad threshMinPerc or used without thresholdHP. Must be: 0 < threshMinPerc < 1. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
          return nil
        elseif type(rulesTbl["threshMinPerc"]) ~= "number" then
          rulesTbl["threshMinPerc"] = nil
        elseif rulesTbl["threshMinPerc"] == nil and anEvent == "thresholdHP" or rulesTbl["threshMinPerc"] and anEvent ~= "thresholdHP" or rulesTbl["threshMinPerc"] >= 1 or rulesTbl["threshMinPerc"] <= 0 then
          Debugger("validTypeEventRulesTbls 3.3. ERROR. Bad threshMinPerc or used without thresholdHP. Must be: 0 < threshMinPerc < 1. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
          return nil
        end
        -- if type(rulesTbl["threshMaxPerc"]) ~= "number" then -- Not implemented yet. Bad logic, do similar to threshMinPerc
        --   rulesTbl["threshMaxPerc"] = nil
        -- elseif (rulesTbl["threshMinPerc"] and rulesTbl["threshMaxPerc"] <= rulesTbl["threshMinPerc"]) or rulesTbl["threshMaxPerc"] >= 1 or rulesTbl["threshMaxPerc"] <= 0 then
        --   Debugger("validTypeEventRulesTbls 3.4. ERROR. Bad threshMaxPerc. Must be 0 < threshMinPerc < 1 and greater than threshMinPerc. aType=" .. tostring(aType) .. ", anEvent=" .. tostring(anEvent))
        --   return nil
        -- end
        -- Debugger("validTypeEventRulesTbls 4. TEST. threshMinPerc, threshMaxPerc, sharedAlerts, mark, ping, alertSound, maxAlerts, reAlertSec, priority, or event="..tostring(anEvent)..", priority=" .. tostring(rulesTbl["priority"]) .. ", reAlertSec=" .. tostring(rulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(rulesTbl["maxAlerts"]) .. ", maxQueueTime=" .. tostring(rulesTbl["maxQueueTime"]) .. ", threshMinPerc=" .. tostring(rulesTbl["threshMinPerc"]) .. ", threshMaxPerc=" .. tostring(rulesTbl["threshMaxPerc"]) .. ", TableToString=" .. TableToString(rulesTbl))
        if (rulesTbl["maxAlerts"]~= nil and type(rulesTbl["maxAlerts"]) ~= "number") or type(rulesTbl["reAlertSec"]) ~= "number" or type(rulesTbl["priority"]) ~= "number" or (rulesTbl["maxQueueTime"] ~= nil and rulesTbl["maxQueueTime"] ~= false and type(rulesTbl["maxQueueTime"]) ~= "number") or (type(rulesTbl["mark"]) ~= "string" and rulesTbl["mark"] ~= nil) or (type(rulesTbl["ping"]) ~= "string" and rulesTbl["ping"] ~= nil) or (type(rulesTbl["alertSound"]) ~= "string" and rulesTbl["alertSound"] ~= nil) or (type(rulesTbl["sharedAlerts"]) ~= "boolean" --[[ and rulesTbl["sharedAlerts"] ~= nil]]) or (rulesTbl["threshMinPerc"] ~= nil and type(rulesTbl["threshMinPerc"]) ~= "number" or (type(rulesTbl["threshMinPerc"]) == "number" and (rulesTbl["threshMinPerc"] <= 0 or rulesTbl["threshMinPerc"] >= 1))) or (rulesTbl["threshMaxPerc"] ~= nil and type(rulesTbl["threshMaxPerc"]) ~= "number" or ((type(rulesTbl["threshMaxPerc"]) == "number" and (rulesTbl["threshMaxPerc"] >= 1 or rulesTbl["threshMaxPerc"] <= 0)) or ((type(rulesTbl["threshMaxPerc"]) == "number" and rulesTbl["threshMinPerc"] == "number") and (rulesTbl["threshMaxPerc"] <= rulesTbl["threshMinPerc"])))) then
          Debugger("validTypeEventRulesTbls 4. ERROR. Returning nil. Bad threshMinPerc, threshMaxPerc, sharedAlerts, mark, ping, alertSound, maxAlerts, reAlertSec, priority, or event="..tostring(anEvent)..", priority=" .. tostring(rulesTbl["priority"]) .. ", reAlertSec=" .. tostring(rulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(rulesTbl["maxAlerts"]) .. ", maxQueueTime=" .. tostring(rulesTbl["maxQueueTime"]) .. ", threshMinPerc=" .. tostring(rulesTbl["threshMinPerc"]) .. ", threshMaxPerc=" .. tostring(rulesTbl["threshMaxPerc"]) .. ", TableToString=" .. TableToString(rulesTbl))
          return nil
        end
        badValue = anEvent
        local eventMatch = false
        for i,v in ipairs(self.validEvents) do
          if anEvent == v then
            eventMatch = true
            eventCount = eventCount +1
            badValue = nil
            break
          end
        end
        if eventMatch == false then
          Debugger("validTypeEventRulesTbls 5. ERROR. Returning False. Bad value=" .. tostring(badValue) .. " in eventTbl=" .. TableToString(eventTbl))
          return nil
        end
        if type(rulesTbl) ~= "table" then
          Debugger("validTypeEventRulesTbls 6. ERROR. Returning False. Not Table rulesTbl=" .. type(rulesTbl))
          return nil
        end
        for aRule,_ in pairs(rulesTbl) do
          badValue = aRule
          local ruleMatch = false
          for i2,v2 in ipairs(self.validEventRules) do
            if aRule == v2 then
              ruleMatch = true
              ruleCount = ruleCount +1
              badValue = nil
              break
            end
          end
          if ruleMatch == false then
            Debugger("validTypeEventRulesTbls 7. ERROR. Returning False. Bad value=" .. tostring(badValue) .. " in rulesTbl=" .. TableToString(rulesTbl))
            return nil
          end
        end
      end
    end
  end
  if #emptyTypesToRemove > 0 then
    for k,v in ipairs(emptyTypesToRemove) do
      Debugger("validTypeEventRulesTbls 6. Removing Bad type=" .. tostring(v))
      typeTbl[v] = nil
    end
  end
  if debug then Debugger("validTypeEventRulesTbls 7. SUCCESS. typeCount=" .. tostring(typeCount) .. ", eventCount=" .. tostring(eventCount) .. ", ruleCount=" .. tostring(ruleCount)..", emptyTypes="..tostring(#emptyTypesToRemove)) end
  return true,typeCount,eventCount,ruleCount,emptyTypesToRemove
end
-- ################################################## Custom/Expanded TeamsManager methods start here #################################################


-- ################################################# Unit Type Rules Assembly start here #################################################
function TeamsManager:addToRelTeamDefsRules(defID, key, playerRules, allyRules, enemyRules, spectatorRules)
  if debug then Debugger("addToRelTeamDefsRules 1. defID=" .. tostring(defID) .. ", key=" .. tostring(key)) end
  if not TeamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then Debugger("addToRelTeamDefsRules 2. INVALID input. Returning nil.") return nil end
  if type(key) ~= "string" or type(defID) ~= "number" then Debugger("addToRelTeamDefsRules 3. INVALID KEY or defID input. Returning nil. key="..tostring(key)..", defID="..tostring(defID)) return nil end
  if not IsSpectator then
    if debug then Debugger("addToRelTeamDefsRules 4. Adding Team Rules. key="..tostring(key)..", defID="..tostring(defID)) end
    if next(playerRules) ~= nil and type(playerRules[key]) == "table" and next(playerRules[key]) ~= nil then
      if type(TeamsManager.relevantMyUnitDefsRules[defID]) == "nil" then TeamsManager.relevantMyUnitDefsRules[defID] = {} end
      TeamsManager.relevantMyUnitDefsRules[defID][key] = playerRules[key]
    end
    if next(allyRules) ~= nil and type(allyRules[key]) == "table" and next(allyRules[key]) ~= nil then
      if type(TeamsManager.relevantAllyUnitDefsRules[defID]) == "nil" then TeamsManager.relevantAllyUnitDefsRules[defID] = {} end
      TeamsManager.relevantAllyUnitDefsRules[defID][key] = allyRules[key]
    end
    if next(enemyRules) ~= nil and type(enemyRules[key]) == "table" and next(enemyRules[key]) ~= nil then
      if type(TeamsManager.relevantEnemyUnitDefsRules[defID]) == "nil" then TeamsManager.relevantEnemyUnitDefsRules[defID] = {} end
      TeamsManager.relevantEnemyUnitDefsRules[defID][key] = enemyRules[key]
    end
  else
    if debug then Debugger("addToRelTeamDefsRules 4. Adding Spectator Rule. key="..tostring(key)..", defID="..tostring(defID)) end
    if next(spectatorRules) ~= nil and type(spectatorRules[key]) == "table" and next(spectatorRules[key]) ~= nil then
      if type(self.relevantSpectatorUnitDefsRules[defID]) == "nil" then self.relevantSpectatorUnitDefsRules[defID] = {} end
      self.relevantSpectatorUnitDefsRules[defID][key] = spectatorRules[key]
    end
  end
end

function TeamsManager:makeRelTeamDefsRules(playerRules, allyRules, enemyRules, spectatorRules, playerCustGrps, allyCustGrps, enemyCustGrps, spectatorCustGrps) -- This should ensure that types are only added to armyManager if there are events defined, and validate events/rules
if debug then Debugger("makeRelTeamDefsRules 1.") end
if not IsSpectator then
    if type(playerRules) ~= "table" or not TeamsManager:validTypeEventRulesTbls(playerRules) then return false end
    if type(allyRules) ~= "table" or not TeamsManager:validTypeEventRulesTbls(allyRules) then return false end
    if type(enemyRules) ~= "table" or not TeamsManager:validTypeEventRulesTbls(enemyRules) then return false end
  else
    if debug then Debugger("makeRelTeamDefsRules TEST. Validating Spectator rules") end
    if type(spectatorRules) ~= "table" or not TeamsManager:validTypeEventRulesTbls(spectatorRules) then return false end
  end
  for defID, unitDef in pairs(UnitDefs) do
    if not string.find(unitDef.name, 'critter') and not string.find(unitDef.name, 'raptor') and (not unitDef.modCategories or not unitDef.modCategories.object) then
      if unitDef.customParams.iscommander then
        if debug then Debugger("Assigning Commander types with unitDefID[" ..tostring(defID) .. "].translatedHumanName=" ..tostring(UnitDefs[defID].translatedHumanName)) end
        TeamsManager:addToRelTeamDefsRules(defID, "commander", playerRules, allyRules, enemyRules, spectatorRules)
        TeamsManager:addToRelTeamDefsRules(defID, "constructor", playerRules, allyRules, enemyRules, spectatorRules)
      elseif unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1]) and not unitDef.customParams.isairbase and unitDef.movementclass ~= "NANO" then
        if unitDef.canAssist or unitDef.canAssist then
          TeamsManager:addToRelTeamDefsRules(defID, "constructor", playerRules, allyRules, enemyRules, spectatorRules)
        elseif unitDef.isBuilding and unitDef.isFactory then
          TeamsManager:addToRelTeamDefsRules(defID, "factory", playerRules, allyRules, enemyRules, spectatorRules)
          if unitDef.customParams.techlevel == '2' then
            TeamsManager:addToRelTeamDefsRules(defID, "factoryT2", playerRules, allyRules, enemyRules, spectatorRules)
          elseif unitDef.customParams.techlevel == '3' then
            TeamsManager:addToRelTeamDefsRules(defID, "factoryT3", playerRules, allyRules, enemyRules, spectatorRules)
          else
            TeamsManager:addToRelTeamDefsRules(defID, "factoryT1", playerRules, allyRules, enemyRules, spectatorRules)
          end
        end
      elseif unitDef.canResurrect then
        TeamsManager:addToRelTeamDefsRules(defID, "rezBot", playerRules, allyRules, enemyRules, spectatorRules)
      end
      if unitDef.isBuilding then
        if string.find(unitDef.translatedTooltip:lower(), string.lower("range plasma cannon")) or string.find(unitDef.translatedTooltip:lower(), string.lower("Range Cluster Plasma Cannon")) or string.find(unitDef.translatedTooltip:lower(), string.lower("Range Plasma Launcher")) then
          TeamsManager:addToRelTeamDefsRules(defID, "LRPC", playerRules, allyRules, enemyRules, spectatorRules)
          if string.find(unitDef.translatedTooltip:lower(), string.lower("rapid")) or string.find(unitDef.translatedTooltip:lower(), string.lower("plasma launcher")) then
            TeamsManager:addToRelTeamDefsRules(defID, "RFLRPC", playerRules, allyRules, enemyRules, spectatorRules) -- LOL-Cannon
          end
        end
        if unitDef.customParams and unitDef.customParams.metal_extractor and unitDef.extractsMetal > 0 then -- or def.extractsMetal > 0
          TeamsManager:addToRelTeamDefsRules(defID, "mex", playerRules, allyRules, enemyRules, spectatorRules)
          if unitDef.customParams.techlevel == '2' then
            TeamsManager:addToRelTeamDefsRules(defID, "mexT2", playerRules, allyRules, enemyRules, spectatorRules)
          else
            TeamsManager:addToRelTeamDefsRules(defID, "mexT1", playerRules, allyRules, enemyRules, spectatorRules)
          end
        end
        if unitDef.customParams and unitDef.customParams.unitgroup == "energy" then -- or def.energyMake > 10
          TeamsManager:addToRelTeamDefsRules(defID, "energyGen", playerRules, allyRules, enemyRules, spectatorRules)
        if unitDef.customParams.techlevel == '2' then
            TeamsManager:addToRelTeamDefsRules(defID, "energyGenT2", playerRules, allyRules, enemyRules, spectatorRules)
          else
            TeamsManager:addToRelTeamDefsRules(defID, "energyGenT1", playerRules, allyRules, enemyRules, spectatorRules)
          end
        end
        if ((type(unitDef["radarDistance"]) == "number" and unitDef["radarDistance"] > 1900) or (type(unitDef["sonarDistance"]) == "number" and unitDef["sonarDistance"] > 850)) then
          TeamsManager:addToRelTeamDefsRules(defID, "radar", playerRules, allyRules, enemyRules, spectatorRules)
        end
        if unitDef.customParams.unitgroup == "nuke" then
          TeamsManager:addToRelTeamDefsRules(defID, "nuke", playerRules, allyRules, enemyRules, spectatorRules)
        end
        if unitDef.customParams.unitgroup == "antinuke" then
          TeamsManager:addToRelTeamDefsRules(defID, "antinuke", playerRules, allyRules, enemyRules, spectatorRules)
        end
      end
      if not unitDef.isBuilding and unitDef.canMove and not (unitDef.customParams.iscommander or unitDef.customParams.isscavcommander) then
        TeamsManager:addToRelTeamDefsRules(defID, "allMobileUnits", playerRules, allyRules, enemyRules, spectatorRules)
        if unitDef.customParams.techlevel == "2" then
          TeamsManager:addToRelTeamDefsRules(defID, "unitsT2", playerRules, allyRules, enemyRules, spectatorRules)
        elseif unitDef.customParams.techlevel == "3" then
          TeamsManager:addToRelTeamDefsRules(defID, "unitsT3", playerRules, allyRules, enemyRules, spectatorRules)
        else
          TeamsManager:addToRelTeamDefsRules(defID, "unitsT1", playerRules, allyRules, enemyRules, spectatorRules)
        end
        if unitDef.movementclass and string.find(unitDef.movementclass:lower(), string.lower("hover")) and not unitDef.canFly then
          TeamsManager:addToRelTeamDefsRules(defID, "hoverUnits", playerRules, allyRules, enemyRules, spectatorRules)
        elseif unitDef.minwaterdepth and not unitDef.canFly then -- water unit
          TeamsManager:addToRelTeamDefsRules(defID, "waterUnits", playerRules, allyRules, enemyRules, spectatorRules)
          if unitDef.customParams.techlevel == "2" then
            TeamsManager:addToRelTeamDefsRules(defID, "waterT2", playerRules, allyRules, enemyRules, spectatorRules)
          elseif unitDef.customParams.techlevel == "3" then
            TeamsManager:addToRelTeamDefsRules(defID, "waterT3", playerRules, allyRules, enemyRules, spectatorRules)
          else
            TeamsManager:addToRelTeamDefsRules(defID, "waterT1", playerRules, allyRules, enemyRules, spectatorRules)
          end
        elseif not unitDef.canFly then
          TeamsManager:addToRelTeamDefsRules(defID, "groundUnits", playerRules, allyRules, enemyRules, spectatorRules)
          if unitDef.customParams.techlevel == "2" then
            TeamsManager:addToRelTeamDefsRules(defID, "groundT2", playerRules, allyRules, enemyRules, spectatorRules)
          elseif unitDef.customParams.techlevel == "3" then
            TeamsManager:addToRelTeamDefsRules(defID, "groundT3", playerRules, allyRules, enemyRules, spectatorRules)
          else
            TeamsManager:addToRelTeamDefsRules(defID, "groundT1", playerRules, allyRules, enemyRules, spectatorRules)
          end
        elseif unitDef.canFly and not string.find(UnitDefs[defID].translatedHumanName:lower(), string.lower("Drone")) then
          TeamsManager:addToRelTeamDefsRules(defID, "airUnits", playerRules, allyRules, enemyRules, spectatorRules)
          if unitDef.customParams and unitDef.customParams.techlevel == '2' then
            TeamsManager:addToRelTeamDefsRules(defID, "airT2", playerRules, allyRules, enemyRules, spectatorRules)
          elseif unitDef.customParams and unitDef.customParams.techlevel == '3' then
            TeamsManager:addToRelTeamDefsRules(defID, "airT3", playerRules, allyRules, enemyRules, spectatorRules)
          else
            TeamsManager:addToRelTeamDefsRules(defID, "airT1", playerRules, allyRules, enemyRules, spectatorRules)
          end
        end
      end
      for i,cstmGroupRules in ipairs({playerCustGrps,allyCustGrps,enemyCustGrps,spectatorCustGrps}) do
        for grpName,nmEvtTbl in pairs(cstmGroupRules) do
          for i2,cstmName in ipairs(nmEvtTbl["unitNames"]) do
            if string.find(UnitDefs[defID].translatedHumanName:lower(), string.lower(cstmName)) then
              TeamsManager:addToRelTeamDefsRules(defID, grpName, playerRules, allyRules, enemyRules, spectatorRules)
            end
          end
        end
      end
    end
  end
  return true
end

function TeamsManager:Initialize(playerEvents, allyEvents, enemyEvents, spectatorEvents,playerCustGrps,allyCustGrps,enemyCustGrps,spectatorCustGrps)
  if not TeamsManager:loadCustomGroups(playerEvents,allyEvents,enemyEvents,spectatorEvents, playerCustGrps, allyCustGrps, enemyCustGrps, spectatorCustGrps) or not TeamsManager:makeRelTeamDefsRules(playerEvents, allyEvents, enemyEvents, spectatorEvents,playerCustGrps,allyCustGrps,enemyCustGrps,spectatorCustGrps) then
    if debug then Debugger("Initialize 1. loadCustomGroups failed.") end
	return nil
  end
  TeamsManager:makeAllArmies() -- Build all teams/armies
  return TeamsManager
end

function TeamsManager:loadCustomGroups(playerEvents,allyEvents,enemyEvents,spectatorEvents, playerCustGrps, allyCustGrps, enemyCustGrps, spectatorCustGrps)
  if debug then Debugger("loadCustomGroups 1.") end
  if playerCustGrps ~= nil and type(playerCustGrps) ~= "table" then Debugger("loadCustomGroups ERROR. Not Table. myCustomGroups="..tostring(playerCustGrps)); return false end
  if allyCustGrps ~= nil and type(allyCustGrps) ~= "table" then Debugger("loadCustomGroups ERROR. Not Table. allyCustomGroups="..tostring(allyCustGrps)); return false end
  if enemyCustGrps ~= nil and type(enemyCustGrps) ~= "table" then Debugger("loadCustomGroups ERROR. Not Table. enemyCustomGroups="..tostring(enemyCustGrps)); return false end
  if spectatorCustGrps ~= nil and type(spectatorCustGrps) ~= "table" then Debugger("loadCustomGroups ERROR. Not Table. spectatorCustomGroups="..tostring(spectatorCustGrps)); return false end
  local countTR = 0
  if debug then Debugger("loadCustomGroups 2. Assigning types with myCustomGroups=" ..TableToString(playerCustGrps) .. ", =") end
  local tmpTypesRules = {[1]=playerEvents,[2]=allyEvents,[3]=enemyEvents,[4]=spectatorEvents}
  local tmpCustomGroups = {[1]=playerCustGrps,[2]=allyCustGrps,[3]=enemyCustGrps,[4]=spectatorCustGrps}
  for i,custGrpTbl in pairs(tmpCustomGroups) do
    if debug then Debugger("loadCustomGroups 3. i=" ..tostring(i) .. ", =") end
    for grpName,unitsRulesTbl in pairs(custGrpTbl) do
      if type(grpName) ~= "string" or type(unitsRulesTbl) ~= "table" then Debugger("loadCustomGroups ERROR. countTR="..tostring(countTR)..", unitsRulesTbl not table or grpName not string. grpName="..tostring(grpName)..", unitsRulesTbl="..type(unitsRulesTbl)); return false end
      if tmpTypesRules[i][grpName] then Debugger("loadCustomGroups 4. ERROR. grpName already used in TypesRules countTR="..tostring(countTR)..", grpName="..tostring(grpName)..", unitsRulesTbl="..type(unitsRulesTbl)); return false end
      tmpTypesRules[i][grpName] = unitsRulesTbl["eventsRules"]
      if debug then Debugger("loadCustomGroups 5. Assigning types with typesRules[grpName]=" ..tostring(grpName) .. ", eventsRules="..TableToString(unitsRulesTbl["eventsRules"])) end
    end
  end
  if debug then Debugger("loadCustomGroups 6. Assigning types with typesRules[grpName]=" ..TableToString(playerEvents["groupName1"])) end
  return true
end

-- ################################################## Basic Core ArmyManager methods start here #################################################
function pArmyManager:addPlayer(playerID, playerName)
  if debug or self.debug then Debugger("addPlayer 1. teamID=" ..tostring(self.teamID).. ", playerID=" .. tostring(playerID) .. ", playerName=" .. tostring(playerName)) end
  -- if not TeamsManager:validIDs(nil, nil, nil, nil, nil, nil, nil, nil, true, playerID) then Debugger("pArmyManager:addPlayer 2. INVALID input. Returning nil.") return nil end
  if type(playerName) ~= "string" then
    playerName = playerID -- Placeholder value for nil
  end
  self.playerIDsNames[playerID] = playerName
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pArmyManager:createUnit(unitID, defID) -- this has two return types: nil if none found, or array of units if one or more found.
	TeamsManager.funcCounts.numCreateUnit = TeamsManager.funcCounts.numCreateUnit + 1
  if debug or self.debug then Debugger("createUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  -- if not TeamsManager:validIDs(true, unitID, true, defID, nil, nil, nil, nil, nil, nil) then Debugger("pArmyManager:createUnit 2. INVALID input. Returning nil.") return nil end
  local aUnit
  local unitTeamNow = Spring.GetUnitTeam(unitID)
  if unitTeamNow ~= self.teamID then
    Debugger("createUnit 4. ERROR. Wrong team! There's no good reason for this! No. Returning nil. unitTeamNow=" .. tostring(unitTeamNow) .. ", self.teamID=" .. tostring(self.teamID))
    return nil
  end
  if unitTeamNow ~= self.teamID and TeamsManager:isEnemy(unitTeamNow, self.teamID) then
    local enemyUnits = TeamsManager:getUnitsIfInitialized(unitID)
    if type(enemyUnits) == "nil" then
      if debug or self.debug then Debugger("createUnit 3. Enemy unit not initialized. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
    elseif #enemyUnits == 1 then
      aUnit = table.remove(enemyUnits,1)
      if debug or self.debug then Debugger("createUnit 4. One Enemy unit found. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow)) end
      if unitTeamNow == aUnit.parent.teamID then
        if debug or self.debug then Debugger("createUnit 5. ERROR. Enemy unit already in current. This method shouldn't be called if it already exists. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow)) end
        return aUnit
      else
        if debug or self.debug then Debugger("createUnit 6. Enemy unit found in different army. It must have been given out of LOS. Moving it to the new teamID Army and returning the result. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow)) end
        return TeamsManager:moveUnit(unitID,aUnit.defID,aUnit.parent.teamID,unitTeamNow)
      end
    else
      Debugger("createUnit 7. ERROR. Unit found in multiple(" .. tostring(#enemyUnits) .. ") armies. This shouldn't be possible? Could keep the most recently updated one, but is it really worth coding? Screw it, let's just nuke them from orbit to be sure! Making a new after. unitID=" .. tostring(aUnit.ID) .. ", unitDefID=" .. tostring(aUnit.defID) .. ", teamID=".. tostring(aUnit.parent.teamID) .. ", unitTeamNow=".. tostring(unitTeamNow))
      for k, eUnit in pairs(enemyUnits) do
        eUnit:setLost(false)
      end
    end
  else
    aUnit = self:getUnit(unitID)
  end
  if type(aUnit) ~= "nil" then
    Debugger("createUnit 8. ERROR. Already EXISTS in armyManager.units. aUnit.ID=" .. tostring(aUnit.ID) .. ", teamID=".. tostring(self.teamID))
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
    if debug then Debugger("createUnit 9. Has rules for created. Sending to addUnitToAlertQueue(). unitID=" .. type(aUnit.unitID) .. ", unitDefID=" .. type(aUnit.defID) .. ", teamID=" .. type(self.teamID)) end
    TeamsManager:addUnitToAlertQueue(aUnit, eventTble)
  end
  if debug or self.debug then Debugger("createUnit 10. aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[defID].translatedHumanName)) end
  return aUnit
end

function pArmyManager:getUnit(unitID)  -- Get unit by unitID. Returns the unit object or nil if not found
  TeamsManager.funcCounts.numGetUnit = TeamsManager.funcCounts.numGetUnit + 1
  if debug or self.debug then Debugger("getUnit 1. unitID=" .. tostring(unitID) .. ", teamID=".. tostring(self.teamID)) end
  -- if not TeamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then Debugger("pArmyManager:getUnit 2. INVALID input. Returning nil.") return nil end
  local aUnit = self.units[unitID]
  if type(aUnit) == "nil" then
    if debug or self.debug then Debugger("getUnit 3. unitID=" .. tostring(unitID) .. " does not exist in armyManager.units") end
    return nil -- This is expected to happen when this method is used to check if the unit exists in the armyManager
  end
  if debug or self.debug then Debugger("getUnit 4. FOUND unitID=" .. tostring(unitID) .. ", aUnit.ID=" .. tostring(aUnit.ID) .. ", aUnit.defID=" .. tostring(aUnit.defID) .. ", aUnit.teamID=" .. tostring(aUnit.parent.teamID)) end
  return aUnit
end

function pArmyManager:getOrCreateUnit(unitID, defID)
  TeamsManager.funcCounts.numGetOrCreate = TeamsManager.funcCounts.numGetOrCreate + 1
  if debug or self.debug then Debugger("pArmyManager:getOrCreateUnit 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(defID) .. ", teamID=".. tostring(self.teamID)) end
  -- if not TeamsManager:validIDs(true, unitID, true, defID, nil, nil, nil, nil, nil, nil) then Debugger("pArmyManager:getOrCreateUnit 2. INVALID input. Returning nil.") return nil end
  return self:getUnit(unitID) or self:createUnit(unitID, defID)
end

function pArmyManager:getTypesRulesForEvent(defIDOrTypeRules, event, topPriorityOnly, canAlertNow, unitObj) -- mandatory defID | unit["typeRules"] (for efficiency), string event, bool/nil (default false) topPriorityOnly. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}
  TeamsManager.funcCounts.numGetRulesForEvent = TeamsManager.funcCounts.numGetRulesForEvent + 1
  if debug or self.debug then Debugger("getTypesRulesForEvent 1. teamID=" ..tostring(self.teamID).. ", defID=" .. tostring(defIDOrTypeRules) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly).. ", canAlertNow="..tostring(canAlertNow).. ", unitObj="..type(unitObj)) end
  if type(event) ~= "string" or (type(topPriorityOnly) ~= "boolean" and topPriorityOnly ~= nil) or (unitObj ~= nil and type(unitObj) ~= "table") or (canAlertNow and type(unitObj) ~= "table") then
    Debugger("getTypesRulesForEvent 2. ERROR. event not string, not unitObj with canAlertNow. teamID=" ..tostring(self.teamID).. ", defID=" .. tostring(defIDOrTypeRules) .. ", event=" .. tostring(event))
    return nil
  end
  local typesEventRulesTbl
  if type(defIDOrTypeRules) == "table" and next(defIDOrTypeRules) ~= nil then
    typesEventRulesTbl = defIDOrTypeRules
  elseif type(defIDOrTypeRules) == "number" then
    if not IsSpectator then
      typesEventRulesTbl = self.defTypesEventsRules[defIDOrTypeRules] -- {defID = {type = {event = {rules}}}}
      if debug or self.debug then Debugger("getTypesRulesForEvent 3. Is Player.") end
    else
      if debug or self.debug then Debugger("getTypesRulesForEvent 3. IsSpectator.") end
      typesEventRulesTbl = TeamsManager.defTypesEventsRules[defIDOrTypeRules]
    end
  else
    Debugger("getTypesRulesForEvent 3. ERROR. defIDOrTypeRules not table or number. defIDOrTypeRules="..tostring(defIDOrTypeRules)..", event=".. tostring(event) .. ",typeRulesTbl="..type(typesEventRulesTbl) .. ", teamID=".. tostring(self.teamID))
    return nil
  end
  local typesEventsTbl = {}; local matches = 0; local priorityNum = 99999
  for aType, eventsTbl in pairs(typesEventRulesTbl) do -- {type = {event = {rules}}}
    if debug then Debugger("getTypesRulesForEvent 4. aType=" .. tostring(aType) .. ", typesEventRules=" .. type(eventsTbl) .. ", event=" .. tostring(event)) end
    if type(eventsTbl) == "table" and type(aType) == "string" then
      local eventMatch = eventsTbl[event]
      if type(eventMatch) == "table" and next(eventMatch) ~= nil then
        if (not topPriorityOnly or eventMatch["priority"] < priorityNum) and (not canAlertNow or (canAlertNow and self:canAlertNow(unitObj, {[aType] = {[event] = eventMatch}}))) then
          if topPriorityOnly and matches == 1 then
            typesEventsTbl = {}
            matches = 0
          end
          if debug then Debugger("getTypesRulesForEvent 5. Adding match to tmpEventTbl. aType=" .. tostring(aType) .. ", event=" .. tostring(event)) end
          typesEventsTbl[aType] = {[event] = eventMatch}
          matches = matches + 1
        end
      end
    end
  end
  if matches == 0 then
    if debug then Debugger("getTypesRulesForEvent 6. No matches, returning nil. event=" .. tostring(event)) end
    return nil
  end
  if debug then Debugger("getTypesRulesForEvent 7. Returning matches=" .. tostring(matches) .. ", event=" .. tostring(event) .. ", typesEventRules=" .. type(typesEventsTbl)) end
  return typesEventsTbl -- {type = {event = {rules}}}
end

function pArmyManager:canAlertNow(unitObj, typeEventRulesTbl) -- Input can only have 1 Type and 1 Event -- {type = {event = {rules}}}
  TeamsManager.funcCounts.numCanAlert = TeamsManager.funcCounts.numCanAlert + 1
  if debug or self.debug then Debugger("canAlertNow 1. unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl)) end
  if type(unitObj) ~= "table" or type(unitObj.parent.teamID) ~= "number" or type(typeEventRulesTbl) ~= "table" then
    Debugger("canAlertNow 2. ERROR, returning nil. Need unitObj and typeEventRulesTbl. Can't initEventLastAlerts(). unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl))
    return nil
  end
  local aType,anEventTbl = next(typeEventRulesTbl)
  if type(anEventTbl) ~= "table" then
    Debugger("canAlertNow 3. ERROR, returning nil. Not anEventTbl=".. type(anEventTbl))
    return nil
  end
  local anEvent,aRulesTbl = next(anEventTbl)
  if type(aRulesTbl) ~= "table" then
    Debugger("canAlertNow 4. ERROR, returning nil. Not aRulesTbl=".. type(aRulesTbl))
    return nil
  end
  local alertBaseObj = unitObj
  if aRulesTbl["sharedAlerts"] then
    alertBaseObj = alertBaseObj.parent
    if debug then Debugger("canAlertNow 5. Is a sharedAlert.") end
    if IsSpectator then
      alertBaseObj = TeamsManager
    end
  end
  alertBaseObj = alertBaseObj["lastAlerts"][aType][anEvent]
  local gameSecs = Spring.GetGameSeconds()
  if debug then Debugger("canAlertNow 6. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. " < " .. tostring(alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"]) .. ", maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. " / " .. tostring(aRulesTbl["maxAlerts"])..", mark="..tostring(aRulesTbl["mark"])..", ping="..tostring(aRulesTbl["ping"])..", alertSound="..tostring(aRulesTbl["alertSound"])) end
  if ((type(aRulesTbl["mark"]) ~= "string") and (type(aRulesTbl["ping"]) ~= "string") and type(aRulesTbl["alertSound"]) ~= "string") or alertBaseObj["isQueued"] or gameSecs < alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"] or (aRulesTbl["maxAlerts"] ~= 0 and alertBaseObj["alertCount"] >= aRulesTbl["maxAlerts"]) then
    if debug then Debugger("canAlertNow 7. Too soon or no alert rules. isQueued="..tostring(alertBaseObj["isQueued"])..", timing=" .. tostring(gameSecs) .. " < " .. tostring(alertBaseObj["lastNotify"] + aRulesTbl["reAlertSec"]) .. ", or reached maxAlerts=" .. tostring(alertBaseObj["alertCount"]) .. "/" .. tostring(aRulesTbl["maxAlerts"])..", mark="..tostring(aRulesTbl["mark"])..", ping="..tostring(aRulesTbl["ping"])..", alertSound="..tostring(aRulesTbl["alertSound"])) end --  .. ", TableToString=" .. TableToString(aRulesTbl)
    return false
  end
  if debug or self.debug then Debugger("canAlertNow 8. TRUE. unitObj=".. type(unitObj)..", typeEventRulesTbl="..type(typeEventRulesTbl)) end
  return true
end

function pArmyManager:hasTypeEventRules(defIDOrTypeRules, aType, event) -- mandatory defID | unit["typeRules"] (for efficiency)
  TeamsManager.funcCounts.numHasEventRules = TeamsManager.funcCounts.numHasEventRules + 1
  if debug or self.debug then Debugger("hasTypeEventRules 1. defID=".. tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
  local typeRulesTbl
  if type(defIDOrTypeRules) == "table" and next(defIDOrTypeRules) ~= nil then
    typeRulesTbl = defIDOrTypeRules
  elseif type(defIDOrTypeRules) == "number" then
    if not IsSpectator then
      typeRulesTbl = self.defTypesEventsRules[defIDOrTypeRules]
      if debug or self.debug then Debugger("hasTypeEventRules 2. Is Player. defID="..tostring(defIDOrTypeRules)..", type typeRulesTbl="..tostring(typeRulesTbl)) end
    else
      if debug or self.debug then Debugger("hasTypeEventRules 3. IsSpectator. defID="..tostring(defIDOrTypeRules)) end
      typeRulesTbl = TeamsManager.defTypesEventsRules[defIDOrTypeRules]
    end
  else
    Debugger("hasTypeEventRules 4. ERROR. defIDOrTypeRules not table or number defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", typeRulesTbl="..type(typeRulesTbl) .. ", teamID=".. tostring(self.teamID))
    return false
  end
  if type(typeRulesTbl) ~= "table" then
    if debug or self.debug then Debugger("hasTypeEventRules 5. FALSE. Not table defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", typeRulesTbl="..type(typeRulesTbl) .. ", teamID=".. tostring(self.teamID)) end
    return false
  end
  if defIDOrTypeRules and not aType and not event then
    if debug or self.debug then Debugger("hasTypeEventRules 6. TRUE. Found requested defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
    return true
  end
  for kType,evntTbl in pairs(typeRulesTbl) do
    if aType and kType == aType and event and type(evntTbl[event]) == "table" then
      if debug or self.debug then Debugger("hasTypeEventRules 7. TRUE. Found type and event. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
      return true
    elseif not event and aType and kType == aType and type(evntTbl) == "table" then
      if debug or self.debug then Debugger("hasTypeEventRules 8. TRUE. Found type. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
      return true
    elseif not aType and event and type(evntTbl[event]) == "table" then
      if debug or self.debug then Debugger("hasTypeEventRules 9. TRUE. Found event. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
      return true
    end
  end
  if debug or self.debug then Debugger("hasTypeEventRules 10. FALSE. Couldn't find type and/or event. defID="..tostring(defIDOrTypeRules)..", aType="..tostring(aType)..", event=".. tostring(event) .. ", teamID=".. tostring(self.teamID)) end
  return false
end

-- ################################################## Custom/Expanded ArmyManager methods start here #################################################


-- ################################################## Basic Core Unit methods starts here #################################################
function pUnit:setID(unitID)
  if debug or self.debug then Debugger("setID 1. unitID=" .. tostring(unitID)) end
  -- if not TeamsManager:validIDs(true, unitID, nil, nil, nil, nil, nil, nil, nil, nil) then Debugger("pUnit:setID 2. INVALID input. Returning nil.") return nil end
  self.ID = unitID
  if debug or self.debug then Debugger("setID 2. self.ID=" .. tostring(self.ID) .. ", unitID=".. tostring(unitID)) end
  self.lastUpdate = Spring.GetGameSeconds()
  return self.ID
end

function pUnit:setDefID(defID)
  if debug or self.debug then Debugger("setDefID 1. self.ID=" .. tostring(self.ID) .. ", self.defID=".. tostring(self.defID) .. ", unitDefID=".. tostring(defID) .. ", type(self.ID)=".. type(self.ID) .. ", type(self.defID)=".. type(self.defID)) end
  -- if not TeamsManager:validIDs(nil, nil, true, defID, nil, nil, nil, nil, nil, nil) then Debugger("pUnit:setDefID 2. INVALID input. Returning nil.") return nil end
  self.defID = defID
  self.lastUpdate = Spring.GetGameSeconds()
  return self.defID
end

function pUnit:setAllIDs(unitID, unitDefID)
  if debug or self.debug then Debugger("setAllIDs 1. unitID=" .. tostring(unitID) .. ", unitDefID=" .. tostring(unitDefID) .. ", unitTeamID=" .. tostring(self.parent.teamID)) end
  return self:setID(unitID) == unitID and self:setDefID(unitDefID) == unitDefID
end

function pUnit:setIdle()
  TeamsManager.funcCounts.numSetIdle = TeamsManager.funcCounts.numSetIdle + 1
  if debug or self.debug then Debugger("setIdle 1. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if not self.isIdle then
    self.isIdle = true
    if self:hasTypeEventRules(nil, "idle") then
        self.parent["idle"][self.ID] = self
      local typeRules = self:getTypesRulesForEvent("idle", true, true)
      if typeRules then
        if debug or self.debug then Debugger("setIdle 2. Going to addUnitToAlertQueue. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
        TeamsManager:addUnitToAlertQueue(self, typeRules)
      end
    end
    self.lastSetIdle = Spring.GetGameFrame()
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then Debugger("setIdle 3. Has been setIdle. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end

function pUnit:setNotIdle()
  TeamsManager.funcCounts.numSetNotIdle = TeamsManager.funcCounts.numSetNotIdle + 1
  if debug or self.debug then Debugger("setNotIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if self.isIdle then
    self.isIdle = false
      if self.parent["idle"] and self.parent["idle"][self.ID] ~= nil then
        self.parent["idle"][self.ID] = nil
      end
    self.lastUpdate = Spring.GetGameSeconds()
    if debug or self.debug then Debugger("setNotIdle 2. Has been setNotIdle. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  end
end

-- ATTENTION!!! ###### Use "alertDelay" with the "idle" event to prevent false positives. ".1" works well
function pUnit:getIdle()
  TeamsManager.funcCounts.numGetIdle = TeamsManager.funcCounts.numGetIdle + 1
  if debug or self.debug then Debugger("getIdle 1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  if not self.isCompleted then
    local _, _, _, _, buildProgress = self:getHealth() -- return: nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number buildProgress -- -- threshMinPerc=.5
    if buildProgress == nil or buildProgress < 1 then
      if debug or self.debug then Debugger("getIdle 2. Not fully constructed, so returning NOT IDLE. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
      self:setNotIdle()
      return self.isIdle
    else
      self.isCompleted = true
    end
  end
  local count = 0
  if self.isFactory then
    count = Spring.GetFactoryCommands(self.ID, 0) -- GetFactoryCommands(unitID, 0)
    if debug or self.debug then Debugger("getIdle 3. isFactory with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    if count == nil then
      if debug or self.debug then Debugger("getIdle 3.1. count is nil for factory. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      count = 1
    end
  else
    count = Spring.GetUnitCommandCount(self.ID) -- was spGetCommandQueue(self.ID, 0) which is Deprecated
    if debug or self.debug then Debugger("getIdle 4. Builder with count=" .. tostring(count) .. ". isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    if count == nil then
      if debug or self.debug then Debugger("getIdle 4.1. count is nil. This can happen when the commander is dead. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      count = 1
    end
  end
  if debug or self.debug then Debugger("getIdle 5. GameFrame(" .. tostring(Spring.GetGameFrame()) .. ", CommandQueueCount=" .. tostring(count) .. ")-LastIdle(" .. tostring(self.lastSetIdle) .. ")=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if count == nil then
    if debug or self.debug then Debugger("getIdle 4.1. isIdle=" .. tostring(self.isIdle) .. ", ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", isFactory=" .. tostring(self.isFactory) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    count = 0
  end
  if count > 0 then
    if debug or self.debug then Debugger("getIdle 6. Wasn't actually Idle. Calling setNotIdle to correct it. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
    self:setNotIdle()
    return self.isIdle
  elseif self.isIdle == false then
    self:setIdle()
    if debug or self.debug then Debugger("getIdle 7. Was actually Idle, corrected. cmdQueue=" .. tostring(count) .. ", GameFrame-LastIdle=" .. tostring(Spring.GetGameFrame() - self.lastSetIdle) .. ", isIdle=" .. tostring(self.isIdle) .. ",ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  -- IMPORTANT: Only setIdle can initiate alert, else there'll be double alerts due to the alert method checking idle after it was removed from queue but before the alert happens/logged
  end
  return self.isIdle
end

function pUnit:setLost(destroyed) -- destroyed = true default
  TeamsManager.funcCounts.numSetLost = TeamsManager.funcCounts.numSetLost + 1
  if debug or self.debug then Debugger("setLost 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed)) end
  if type(destroyed) ~= "nil" and type(destroyed) ~= "boolean" then
    Debugger("setLost 2. ERROR. destroyed NOT nil or bool. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", destroyed=" .. tostring(destroyed))
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
  if debug or self.debug then Debugger("setLost 4. About to try removing unit from all Type/Event lists in parent army (except Lost). translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)) end
  if type(unitTypes) == "table" then
    for aType, eventTbl in pairs(unitTypes) do
      if type(aType) == "string" and type(self.parent[aType]) == "table" and self.parent[aType][self.ID] ~= nil then
        if debug or self.debug then Debugger("setLost 5. Removed self from parent[" .. tostring(aType) .. "] translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(eventTbl)=" .. type(eventTbl)) end
        self.parent[aType][self.ID] = nil
        if type(eventTbl) == "table" then
          for anEvent, rules in pairs(eventTbl) do
            if type(anEvent) == "string" and type(self.parent[anEvent]) == "table" and self.parent[anEvent][self.ID] ~= nil then
              self.parent[anEvent][self.ID] = nil
              if debug or self.debug then Debugger("setLost 6. Removed self from parent[" .. tostring(anEvent) .. "], translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
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
      if debug or self.debug then Debugger("setLost 7. Unit has rule to alert when destroyed, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
      TeamsManager:addUnitToAlertQueue(self, destroyedEvent) -- {type = {event = {rules}}}
    end
  end
  self.lost = Spring.GetGameSeconds()
  self.lastUpdate = Spring.GetGameSeconds()
  if TeamsManager.config.deleteDestroyed then
    self.parent["unitsLost"][self.ID] = nil
  else
    return self
  end
end

-- Unused method, but could be handy later
function pUnit:getTypeRules(aType)
  if debug or self.debug then Debugger("getTypesRules 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID) .. ", types=" .. tostring(aType) .. ", translatedHumanName=" ..tostring(UnitDefs[self.defID].translatedHumanName)) end
  return self["typeRules"][aType]
end

function pUnit:getTypesRulesForEvent(event, topPriorityOnly, canAlertNow) -- string event. Returns 0 to many types with ONLY their MATCHING EVENTS: {type1 = {event = {rules}}, type2 = {event = {rules}}}, topPriorityOnly returns just their one with best priority
  if debug or self.debug then Debugger("pUnit:getTypesRulesForEvent 1. Returning self.parent:getTypesRulesForEvent(" .. tostring(self.defID) .. ", event=" .. tostring(event) .. ", topPriorityOnly=" .. tostring(topPriorityOnly) .. "), unitID=" .. tostring(self.ID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if type(self["typeRules"]) ~= "table" or next(self["typeRules"]) == nil then
    Debugger("pUnit:getTypesRulesForEvent 2. ERROR. Unit has no rules. Shouldn't happen. event=" .. tostring(event) .. ", teamID="..tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)  .. ", next(self[typeRules])=".. tostring(next(self["typeRules"])).. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName))
    return false
  end
  return self.parent:getTypesRulesForEvent(self["typeRules"], event, topPriorityOnly, canAlertNow, self)
end

function pUnit:setTypes()
  TeamsManager.funcCounts.numSetTypes = TeamsManager.funcCounts.numSetTypes + 1
  if debug or self.debug then Debugger("setTypes 1. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)) end
  if UnitDefs[self.defID].isFactory then
    self.isFactory = true
    self.parent.factories[self.ID] = self
  end
  local unitTypes
  if not IsSpectator then
    unitTypes = self.parent.defTypesEventsRules[self.defID] -- {defID = {type = {event = {rules}}}}
  else
    unitTypes = TeamsManager.defTypesEventsRules[self.defID]
  end
  if debug or self.debug then Debugger("setTypes 2. translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)) end
  if type(unitTypes) ~= "table" or next(unitTypes) == nil then
    Debugger("setTypes 2.1. ERROR. All created units should have rules associated to them. translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes))
  end
  self["typeRules"] = unitTypes; self.hasDamagedEvent = false
  for aType, eventsTbl in pairs(unitTypes) do
    if type(aType) ~= "string" then
      Debugger("setTypes 2.2. ERROR. aType not string. aType="..tostring(aType)..", unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName) .. ", type(unitTypes)=".. type(unitTypes)..", TableToString="..TableToString(aType))
      return nil
    end
    if self.parent[aType] == nil then self.parent[aType] = {} end
    self.parent[aType][self.ID] = self
    if debug or self.debug then Debugger("setTypes 3. Added self to my army's list of=" .. tostring(aType) .. ", translatedHumanName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
    if eventsTbl["damaged"] and TeamsManager.isEnabledDamagedWidget then
      self.hasDamagedEvent = true
    end
    local baseObj = self
    if type(eventsTbl) == "table" and eventsTbl["sharedAlerts"] == true then -- Unnecessary now since below only does non-shared
      baseObj = baseObj.parent
      if IsSpectator then
        baseObj = TeamsManager
      end
    end
    for event,rulesTbl in pairs(eventsTbl) do
      if not rulesTbl["sharedAlerts"] then
        if type(baseObj["lastAlerts"]) ~= "table" then
          if debug then Debugger("setTypes 4. lastAlerts="..type(baseObj["lastAlerts"])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
          baseObj["lastAlerts"] = {}
        end
        local lastAlerts = baseObj["lastAlerts"]
        if type(lastAlerts[aType]) ~= "table" then
          if debug then Debugger("setTypes 5. unitOrArmyObj["..tostring(aType).."]="..type(lastAlerts[aType])..", unitOrArmyObj="..type(baseObj)..", unitType="..tostring(aType)..", event="..tostring(event))end
          lastAlerts[aType] = {}
        end
        if type(lastAlerts[aType][event]) ~= "table" then
          lastAlerts[aType][event] = {}
          lastAlerts[aType][event]["lastNotify"] = 0
          lastAlerts[aType][event]["alertCount"] = 0
          lastAlerts[aType][event]["isQueued"] = false
          if debug then Debugger("setTypes 6. unitOrArmyObj["..tostring(aType).."]["..tostring(event).."]="..type(lastAlerts[aType][event])..", lastNotify="..tostring(lastAlerts[aType][event]["lastNotify"])..", alertCount="..tostring(lastAlerts[aType][event]["alertCount"])..", isQueued="..tostring(lastAlerts[aType][event]["isQueued"])..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        end
      end
      if event == "thresholdHP" and rulesTbl["threshMinPerc"] then -- adding instantiation of persistent events
        if type(self.parent["thresholdHP"]) ~= "table" then
          self.parent["thresholdHP"] = {}
        end
        if not self.hasDamagedEvent then -- if doesn't have damaged event, must manually add
          self.parent["thresholdHP"][self.ID] = self
          if debug or self.debug then Debugger("setTypes 7. Added self to thresholdHP. unitID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        elseif self.hasDamagedEvent and self.parent["thresholdHP"][self.ID] then -- if has damaged event, it is automaticaly added/removed from the thresholdHP table by getHealth()
          self.parent["thresholdHP"][self.ID] = nil
          if debug or self.debug then Debugger("setTypes 8. Removing self from thresholdHP. unitID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        end
      elseif event == "idle" and type(self.parent["idle"]) ~= "table" then
        if debug or self.debug then Debugger("setTypes TEST. About to create idle table. Which now has type=" .. type(self.parent["idle"])) end
        self.parent["idle"] = {}
      end
    end
  end
  self.lastUpdate = Spring.GetGameSeconds()
  return true
end

function pUnit:hasTypeEventRules(aType, event)
  TeamsManager.funcCounts.numHasRules = TeamsManager.funcCounts.numHasRules + 1
  if debug or self.debug then Debugger("pUnit:hasTypeEventRules 1. SHELL. Will return from parent method. ID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
  if type(self["typeRules"]) ~= "table" or next(self["typeRules"]) == nil then
    Debugger("pUnit:hasTypeEventRules 2. ERROR. Unit has no rules. Shouldn't happen. event=" .. tostring(event) .. ", teamID="..tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)  .. ", next(self[typeRules])=".. tostring(next(self["typeRules"])).. ", name=" .. tostring(UnitDefs[self.defID].translatedHumanName))
    return false
  end
  return self.parent:hasTypeEventRules(self["typeRules"], aType, event)
end

function pUnit:getCoords()
  TeamsManager.funcCounts.numGetCoords = TeamsManager.funcCounts.numGetCoords + 1
  if debug or self.debug then Debugger("getCoords 1. Getting unit's current position, else sending back the most recent coords." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
  local x,y,z = Spring.GetUnitPosition( self.ID )
  if type(x) == "number" then
    if debug or self.debug then Debugger("getCoords 2. Returning unit's current position coords="..tostring(x).."-"..tostring(y).."-"..tostring(z)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. ", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
    if self["coords"] == nil then self["coords"] = {} end
    self["coords"]["x"] = x; self["coords"]["y"] = y; self["coords"]["z"] = z
    return x, y, z
  elseif type(self.coords["x"]) == "number" then
    if debug or self.debug then Debugger("getCoords 3. Returning unit's old position because getCoords returned nil. coords="..tostring(x).."-"..tostring(y).."-"..tostring(z)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
    return self.coords["x"], self.coords["y"], self.coords["z"]
  end
  if debug or self.debug then Debugger("getCoords 4. FAIL. Unable to return any coords." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
  return nil, nil, nil
end

function pUnit:getHealth()
  TeamsManager.funcCounts.numGetHealth = TeamsManager.funcCounts.numGetHealth + 1
  if debug or self.debug then Debugger("getHealth 1. Getting unit's current health, else sending back the most recent health." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID).. tostring(UnitDefs[self.defID].translatedHumanName)) end
  local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(self.ID)
  if TeamsManager.isEnabledDamagedWidget and not self.hasDamagedEvent then self.hasDamagedEvent = true end
  if type(health) == "number" then
    if not self.isCompleted and buildProgress == 1 then self.isCompleted = true end
    if self.isCompleted then
      if self["health"]["HP"] and health < self["health"]["HP"] and self:hasTypeEventRules(nil, "damaged") then
        local damagedEvent = self:getTypesRulesForEvent("damaged", true, true)
        if damagedEvent then
          if debug or self.debug then Debugger("getHealth 2. Unit has rule to alert when damaged, unitName=" .. tostring(UnitDefs[self.defID].translatedHumanName)) end
          TeamsManager:addUnitToAlertQueue(self, damagedEvent) -- {type = {event = {rules}}}
        end
      end
      self.health = {["HP"]=health, ["maxHP"]=maxHealth, ["paralyzeDamage"]=paralyzeDamage, ["captureProgress"]=captureProgress, ["buildProgress"]=buildProgress}
      if self:hasTypeEventRules(nil, "thresholdHP") then
        if debug or self.debug then Debugger("getHealth 3. Has thresholdHP. unitID=" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
        local topPriority; local bestPriority = 9999; local thresholdMet = false; local isShared = false
        local healthPerc = self["health"]["HP"] / self["health"]["maxHP"]
        if debug or self.debug then Debugger("getHealth 4. thresholdHP, healthPerc=" .. tostring(healthPerc)) end
        if healthPerc < 1 then
          for aType,eventTbl in pairs(self["typeRules"]) do
            if type(eventTbl["thresholdHP"]) == "table" and type(eventTbl["thresholdHP"]["threshMinPerc"]) == "number" then
              if healthPerc < eventTbl["thresholdHP"]["threshMinPerc"] then
                thresholdMet = true
                if eventTbl["thresholdHP"]["priority"] < bestPriority and self.parent:canAlertNow(self, {[aType] = {["thresholdHP"] = eventTbl["thresholdHP"]}}) then
                  if debug or self.debug then Debugger("getHealth 5. Adding canAlert thresholdHP, healthPerc=" .. tostring(healthPerc)..", threshMinPerc="..eventTbl["thresholdHP"]["threshMinPerc"]..", priority="..tostring(eventTbl["thresholdHP"]["priority"])) end
                  topPriority = {[aType] = {["thresholdHP"] = eventTbl["thresholdHP"]}}
                  bestPriority = eventTbl["thresholdHP"]["priority"]
                  isShared = eventTbl["thresholdHP"]["sharedAlerts"]
                end
              end
            end
          end
        end
        if type(topPriority) == "table" then
          if debug or self.debug then Debugger("getHealth 6. Below thresholdHP. Going to addUnitToAlertQueue.") end
          TeamsManager:addUnitToAlertQueue(self, topPriority)
        end
        if debug or self.debug then Debugger("getHealth TEST1. thresholdMet="..tostring(thresholdMet)..", in thresholdHP="..type(self.parent["thresholdHP"][self.ID])..", isEnabledDamagedWidget="..tostring(TeamsManager.isEnabledDamagedWidget)..", self.hasDamagedEvent="..tostring(self.hasDamagedEvent)) end
        local alertBaseObj = self.parent
        if IsSpectator and isShared then
          alertBaseObj = TeamsManager
        end
        if type(alertBaseObj["thresholdHP"]) ~= "table" then
          alertBaseObj["thresholdHP"] = {}
        end
        if thresholdMet and alertBaseObj["thresholdHP"][self.ID] == nil then
          if debug or self.debug then Debugger("getHealth TEST2. Adding self to thresholdHP table because thresholdMet.") end
          alertBaseObj["thresholdHP"][self.ID] = self
        elseif TeamsManager.isEnabledDamagedWidget and self.hasDamagedEvent and not thresholdMet and alertBaseObj["thresholdHP"][self.ID] then
          if debug or self.debug then Debugger("getHealth TEST3. Removing self from threshold table.") end
          alertBaseObj["thresholdHP"][self.ID] = nil
        end
      end
    end
    if debug or self.debug then Debugger("getHealth 7. Returning unit's current health. health="..tostring(health)..", maxHealth="..tostring(maxHealth)..", paralyzeDamage="..tostring(paralyzeDamage)..", captureProgress="..tostring(captureProgress)..", buildProgress="..tostring(buildProgress)..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
    return health, maxHealth, paralyzeDamage, captureProgress, buildProgress
  elseif type(self.health["HP"]) == "number" then
    if debug or self.debug then Debugger("getHealth 8. Returning unit's old health because GetUnitHealth returned nil. health="..tostring(self.health["HP"])..", maxHealth="..tostring(self.health["maxHealth"])..", paralyzeDamage="..tostring(self.health["paralyzeDamage"])..", captureProgress="..tostring(self.health["captureProgress"])..", buildProgress="..tostring(self.health["buildProgress"])..", unitID" .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
    return self.health["HP"], self.health["maxHealth"], self.health["paralyzeDamage"], self.health["captureProgress"], self.health["buildProgress"]
  end
  if debug or self.debug then Debugger("getHealth 9. FAIL. Unable to return any health attributes." .. tostring(self.ID) .. ", defID=".. tostring(self.defID) .. ", teamID=".. tostring(self.parent.teamID)..", name="..tostring(UnitDefs[self.defID].translatedHumanName)) end
  return nil
end
-- ################################################## Custom/Expanded Unit methods start here #################################################
