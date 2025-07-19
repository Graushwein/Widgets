local widgetName = "Easy_Alerts_Replay"
function widget:GetInfo()
	return {
		name = widgetName,
		desc = "Alerts for upcoming events when watching replays using event log from the Easy Alerts (other widget) that pre-watched the replay.",
		author = "Graushwein",
		date = "July 18, 2025",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = false,
	}
end
VFS.Include("LuaUI/Widgets/easy_alerts_utils/ea_teams_mgr_lib.lua")




-- VFS.Include(LUAUI_DIRNAME .. "utils.lua")
-- local anInclude = VFS.Include("LuaUI/Widgets/easy_alerts_debug.lua")
local anotherInclude = {}
-- VFS.Include("LuaUI/Widgets/easy_alerts_debug.lua")
-- local anInclude = VFS.Include("LuaUI/Widgets/easy_alerts_debug.lua")
-- debugger("test")
-- local utilitiesFiles = VFS.DirList('LuaUI/Widgets/', "*.lua")
-- for i,aFile in pairs(utilitiesFiles) do
-- 	Spring.Echo("Filename="..tostring(aFile))
-- end

-- Spring.Echo("anotherInclude="..tostring(anotherInclude)..", LuaUIDir="..tostring(LUAUI_DIRNAME))
-- Trying these and getting "attempt to call global 'require' (a nil value)"
-- local mymodule = anInclude.require("LuaUI/Widgets/easy_alerts_debug.lua")
-- require("LuaUI/Widgets/easy_alerts_debug.lua")
-- require "LuaUI/Widgets/easy_alerts_debug.lua"


-- normal widget stuff
-- local my_lib = VFS.Include("LuaUI/Widgets/easy_alerts_debug.lua")
-- my_lib.teamsManager:makeAllArmies()
-- my_lib.debugger("test")
-- normal widget stuff

-- local libFuncs = VFS.Include("LuaUI/Widgets/easy_alerts_debug.lua")

-- libFuncs.teamsManager:makeAllArmies()

-- libFuncs.debugger("teamsManager.myArmyManager.teamID="..tostring(libFuncs.teamsManager.myArmyManager.teamID))


-- local libFuncs2 = {message="aMessage"}
-- VFS.Include("LuaUI/Widgets/easy_alerts_utils/ea_general_lib.lua")

-- debugger("AllyID="..tostring(Spring.GetMyAllyTeamID()))


local warnFrame = 0
local isSpectator

-- tableToString(tbl, indent)







-- local function checkPersistentEvents() -- Checks all of the events that BAR widgets don't cover
--   funcCounts.numCkPrst = funcCounts.numCkPrst + 1
--   if debug then debugger("checkPersistentEvents 1.") end
--   local armiesToCheck
--   if isSpectator then
--     if debug then debugger("checkPersistentEvents 2. isSpectator, using all armies.") end
--     armiesToCheck = teamsManager.armies
--   else
--     if debug then debugger("checkPersistentEvents 2. Is Player, using myArmyManager.") end
--     armiesToCheck = {myTeamID = teamsManager.myArmyManager}
--   end
--   local deadUnits = {} -- ensure dead units get removed from persistently checked tables
--   for _, anArmyManager in pairs(armiesToCheck) do
--     if not anArmyManager.isGaia then
--       if type(anArmyManager["idle"]) == "table" then
--         for unitID, unit in pairs(anArmyManager["idle"]) do
--           if Spring.GetUnitIsDead(unitID) then
--             if debug then debugger("checkPersistentEvents 3. Dead Unit found.") end
--             deadUnits[unitID] = unit
--           elseif not teamsManager:getQueuedEvents(unit,nil,nil,"idle") and unit:getIdle() == true then
--             if debug then debugger("checkPersistentEvents 4. Builder idle. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", teamID=" .. tostring(unit.parent.teamID)) end
--             local typeRules = unit:getTypesRulesForEvent("idle", true, true)
--             if typeRules then
--               if debug then debugger("checkPersistentEvents 5. CanAlertNow for idle. Going to addUnitToAlertQueue.") end
--               teamsManager:addUnitToAlertQueue(unit, typeRules)
--             end
--           end
--         end
--       end
--       if type(anArmyManager["thresholdHP"]) == "table" then
--         for unitID, unit in pairs(anArmyManager["thresholdHP"]) do
--           if Spring.GetUnitIsDead(unitID) then
--             if debug then debugger("checkPersistentEvents 5. Removing Dead Unit.") end
--             deadUnits[unitID] = unit
--           else
--             if debug then debugger("checkPersistentEvents 5. Checking thresholdHP. unitID=" ..tostring(unitID) .. ", defID=" ..tostring(unit.defID) .. ", teamID=" .. tostring(unit.parent.teamID) .. ", translatedHumanName=" .. tostring(UnitDefs[unit.defID].translatedHumanName)) end
--             if not teamsManager:getQueuedEvents(unit,nil,nil,"thresholdHP") then
--               unit:getHealth() -- automatically alerts
--             end
--           end
--         end
--       end
--       -- Next phase - non-unit events
--       -- anArmyManager.resources["metal"]["currentLevel"], anArmyManager.resources["metal"]["storage"], anArmyManager.resources["metal"]["pull"], anArmyManager.resources["metal"]["income"], anArmyManager.resources["metal"]["expense"], anArmyManager.resources["metal"]["share"], anArmyManager.resources["metal"]["sent"], anArmyManager.resources["metal"]["received"] = Spring.GetTeamResources (anArmyManager.teamID, "metal")
--       -- if debug then debugger("checkPersistentEvents 6. Checking Metal. teamID=" ..tostring(anArmyManager.teamID)..", currentLevel="..anArmyManager.resources["metal"]["currentLevel"]..", storage="..anArmyManager.resources["metal"]["storage"]..", pull="..anArmyManager.resources["metal"]["pull"]..", income="..anArmyManager.resources["metal"]["income"]..", expense="..anArmyManager.resources["metal"]["expense"]..", share="..anArmyManager.resources["metal"]["share"]..", sent="..anArmyManager.resources["metal"]["sent"]..", received="..anArmyManager.resources["metal"]["received"]) end
--       -- anArmyManager.resources["energy"]["currentLevel"], anArmyManager.resources["energy"]["storage"], anArmyManager.resources["energy"]["pull"], anArmyManager.resources["energy"]["income"], anArmyManager.resources["energy"]["expense"], anArmyManager.resources["energy"]["share"], anArmyManager.resources["energy"]["sent"], anArmyManager.resources["energy"]["received"] = Spring.GetTeamResources (anArmyManager.teamID, "metal")
--       -- if debug then debugger("checkPersistentEvents 7. Checking Energy. teamID=" ..tostring(anArmyManager.teamID)..", currentLevel="..anArmyManager.resources["energy"]["currentLevel"]..", storage="..anArmyManager.resources["energy"]["storage"]..", pull="..anArmyManager.resources["energy"]["pull"]..", income="..anArmyManager.resources["energy"]["income"]..", expense="..anArmyManager.resources["energy"]["expense"]..", share="..anArmyManager.resources["energy"]["share"]..", sent="..anArmyManager.resources["energy"]["sent"]..", received="..anArmyManager.resources["energy"]["received"]) end
--     end
--   end
--   if next(deadUnits) ~= nil then
--     for _, unit in pairs(deadUnits) do
--       unit:setLost()
--     end
--   end
-- end

-- function widget:GameFrame(frame)
--   if warnFrame == 1 then -- with 30 updateInterval, run roughlys every half second
--     -- checkPersistentEvents()
--     -- if alertQueue:getSize() > 0 then
--     --   teamsManager:alert()
--     -- end
--   end
--   warnFrame = (warnFrame + 1) % updateInterval
-- end

function widget:PlayerChanged(playerID)
	isSpectator = Spring.GetSpectatingState()
end

function widget:Initialize()
	widget:PlayerChanged()
-- 	if not loadCustomGroups() or not makeRelTeamDefsRules() then
-- 		debugger("makeRelTeamDefsRules() or loadCustomGroups() returned FALSE. Fix trackMyTypesRules, trackAllyTypesRules, trackEnemyTypesRules, or custom group tables tables.")
-- 		widgetHandler:RemoveWidget()
-- 	end
--   teamsManager:makeAllArmies() -- Build all teams/armies
	Spring.Echo("Starting " .. widgetName)
  local gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
	if true then Spring.Echo("widget:Initialize 1. isSpectator="..tostring(isSpectator)..", gameID="..tostring(gameID)) end
  -- doTesting()
  -- debug = true
  return
  --   -- TODO: Maybe. Load All Units if replay or starting mid-game ########## 
end

function widget:Shutdown()
	-- if true then debugger("FunctionRunCounts:\n numArmies="..tostring(funcCounts.numArmies).."\n numCreateUnit="..tostring(funcCounts.numCreateUnit)..", numStockpile="..tostring(funcCounts.numStockpile).."\n numLoaded="..tostring(funcCounts.numLoaded).."\n numCommands="..tostring(funcCounts.numCommands).."\n numCkPrst="..tostring(funcCounts.numCkPrst).."\n numLOS="..tostring(funcCounts.numLOS).."\n numFinished="..tostring(funcCounts.numFinished).."\n numCreated="..tostring(funcCounts.numCreated).."\n numTaken="..tostring(funcCounts.numTaken).."\n numIdle="..tostring(funcCounts.numIdle).."\n numDestroyed="..tostring(funcCounts.numDestroyed).."\n numGetHealth="..tostring(funcCounts.numGetHealth).."\n numGetCoords="..tostring(funcCounts.numGetCoords).."\n numHasRules="..tostring(funcCounts.numHasRules).."\n numSetTypes="..tostring(funcCounts.numSetTypes).."\n numDamaged="..tostring(funcCounts.numDamaged).."\n numSetLost="..tostring(funcCounts.numSetLost).."\n numGetIdle="..tostring(funcCounts.numGetIdle).."\n numSetNotIdle="..tostring(funcCounts.numSetNotIdle).."\n numSetIdle="..tostring(funcCounts.numSetIdle).."\n numHasEventRules="..tostring(funcCounts.numHasEventRules).."\n numCanAlert="..tostring(funcCounts.numCanAlert).."\n numGetRulesForEvent="..tostring(funcCounts.numGetRulesForEvent).."\n numGetOrCreate="..tostring(funcCounts.numGetOrCreate).."\n numGetUnit="..tostring(funcCounts.numGetUnit).."\n numValidRules="..tostring(funcCounts.numValidRules).."\n numGetQueued="..tostring(funcCounts.numGetQueued).."\n numGetNextAlert="..tostring(funcCounts.numGetNextAlert).."\n numGetNotifyVars="..tostring(funcCounts.numGetNotifyVars).."\n numAddAlert="..tostring(funcCounts.numAddAlert).."\n numAlert="..tostring(funcCounts.numAlert).."\n numValidIDs="..tostring(funcCounts.numValidIDs).."\n numMoveUnit="..tostring(funcCounts.numMoveUnit).."\n numIsAllied="..tostring(funcCounts.numIsAllied).."\n numIfInitialized="..tostring(funcCounts.numIfInitialized).."\n numGetArmy="..tostring(funcCounts.numGetArmy)) end
--   if logEvents then
--     local gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")
--     saveTable("myData", logEventsTbl, ("ea"..gameID..".lua"))
--     -- local my_table = VFS.Include("data.lua") -- works
--     -- debugger("String: " .. tableToString(my_table)) -- works
--   end
  Spring.Echo(widgetName .. " widget disabled")
end

function widget:GameOver()
	widget:Shutdown()
end