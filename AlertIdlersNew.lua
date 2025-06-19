local widgetName = "AlertIdlersNew"
function widget:GetInfo()
    return {
        name = widgetName,
        desc = "Makes a sound whenever you have a worker idling",
        author = "LiliumAtratum",
        date = "2025-3-21",
        license = "MIT",
        layer = 0,
        enabled = true
    }
end
-- require ("Test")
-- local Test = require("Test")
-- include("Test.lua")

--  https://springrts.com/wiki/Lua_VFS#Files
-- VFS.Include( string "filename" [, table enviroment = nil [, number mode ] ] )
-- EXAMPLES:
-- local wavFileLengths = VFS.Include('sounds/sound_file_lengths.lua')
-- VFS.Include('common/wav.lua')


local showRez = true	-- make false if you don't want to be alerted to idle rezbots

local spGetCommandQueue     = Spring.GetCommandQueue
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitHealth = Spring.GetUnitHealth

local UpdateInterval = 30
local TestSound = 'sounds/commands/cmd-selfd.wav'

local myTeamID
local isSpectator
local warnFrame = 0

local BuilderUnitDefIDs = {} -- unitDefID (key), builderType
local BuilderUnits = {} -- unitID (key), unitDefID
local FactoryDefIDs = {}

local idlingUnits = {}
local idlingUnitCount = 0

local idleUnits = {
	com = {},
	con = {},
	fac = {},
}
local lastNotificationTime = {
	com = Spring.GetGameSeconds(),
	con = Spring.GetGameSeconds(),
	fac = Spring.GetGameSeconds(),
}
--[[
-- table.insert(idleUnits[unitType], unitID)
function idleUnitHealhCheckService()
	for unitType, unitList in pairs(idleUnits) do
		local newList = {}
		for index, unitId in pairs(unitList) do
			if Spring.ValidUnitID(unitId) then
				table.insert(newList, unitId)
			end
		end
		idleUnits[unitType] = newList
	end
end
]]--

function widget:PlayerChanged(playerID)
    myTeamID = Spring.GetMyTeamID()
	isSpectator = Spring.GetSpectatingState()
	if isSpectator then
		widgetHandler:RemoveWidget()
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1] or (showRez and unitDef.canResurrect)) and not unitDef.customParams.isairbase then
		if unitDef.customParams.iscommander then 
			BuilderUnitDefIDs[unitDefID] = 1 
			-- Spring.Echo("Assigning Commander BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName-" .. UnitDefs[unitDefID].translatedHumanName)
		elseif unitDef.canAssist or unitDef.canAssist then     -- check is this constructor was: unitDef.canConstruct and unitDef.canAssist 
			BuilderUnitDefIDs[unitDefID] = 2 
			-- Spring.Echo("Assigning Constructor BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName-" .. UnitDefs[unitDefID].translatedHumanName)
		elseif unitDef.isFactory then  -- check is this factory
			-- Spring.Echo("Assigning Factory BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName-" .. UnitDefs[unitDefID].translatedHumanName)
			BuilderUnitDefIDs[unitDefID] = 3 
			table.insert(FactoryDefIDs, unitDefID)
		elseif showRez and unitDef.canResurrect then -- RezBot optional using showRez
			-- Spring.Echo("Assigning RezBot BuilderUnitDefIDs, unitDefID[" .. unitDefID .. "].translatedHumanName-" .. UnitDefs[unitDefID].translatedHumanName)
			BuilderUnitDefIDs[unitDefID] = 4
		else end
	end
end

local function isBuilder(unitDefID)
    return BuilderUnitDefIDs[unitDefID] ~= nil
end

local function isUnitRelevant(unitDefID, unitTeam)
--Spring.Echo("isUnitRelevant UnitDefs[" .. unitDefID .. "].translatedHumanName-" .. UnitDefs[unitDefID].translatedHumanName .. ", unitTeam-" .. unitTeam .. ", myTeamID-" .. myTeamID .. ", isBuilder(unitDefID)-" .. tostring(isBuilder(unitDefID)))
	return unitTeam == myTeamID and isBuilder(unitDefID)
end

local function isUnitIdle(unitID)
	if unitID == nil and Spring.GetUnitDefID(unitID) == nil then 
Spring.Echo("isUnitIdle. Somehow no unitID=" .. tostring(unitID) .. ", or not Spring.GetUnitDefID(unitID)?")
		return false
	end
	local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
	if buildProgress < 1 then 
		Spring.Echo("isUnitIdle NOT BUILT. buildProgress=" .. buildProgress .. ", Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName-" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)])
		return false 
	end
Spring.Echo("isUnitIdle Spring.GetUnitDefID(" .. Spring.GetUnitDefID(unitID) .. "), translatedHumanName-" .. UnitDefs[Spring.GetUnitDefID(unitID)].translatedHumanName .. ", BuilderUnitDefIDs[Spring.GetUnitDefID(" .. unitID .. ")]=" .. BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)])
	local builderType = BuilderUnitDefIDs[Spring.GetUnitDefID(unitID)]
	if builderType == 3 then -- Factory
--Spring.Echo("isUnitIdle FACTORY unitID[" .. unitID .. "], count-" .. spGetFactoryCommands(unitID, 0))
		return spGetFactoryCommands(unitID, 0) == 0
	end
--Spring.Echo("isUnitIdle unitID[" .. unitID .. "], count-" .. spGetCommandQueue(unitID, 0))
	return spGetCommandQueue(unitID, 0) == 0
end

local function markUnitAsIdle(unitID)
	if idlingUnits[unitID] == nil then
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

local function maybeMarkUnitAsIdle(unitID, unitDefID, unitTeam)
	if isUnitRelevant(unitDefID, unitTeam) and isUnitIdle(unitID) then
		markUnitAsIdle(unitID)
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	-- Spring.Echo("UnitIdle. Check Botlab spGetFactoryCommands(26761,0)=" .. spGetFactoryCommands(26761, 0) .. ", translatedHumanName=" .. UnitDefs[362].translatedHumanName)
	if isUnitRelevant(unitDefID, unitTeam) then
--Spring.Echo("UnitIdle UnitDefs[" .. unitDefID .. "].translatedHumanName-" .. UnitDefs[unitDefID].translatedHumanName .. ", unitID-" .. unitID .. ", unitTeam-" .. unitTeam)
		markUnitAsIdle(unitID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	-- Triggered when unit dies or construction canceled while being built
	Spring.Echo("UnitDestroyed unitID=" .. unitID .. ", translatedHumanName=" .. UnitDefs[unitDefID].translatedHumanName)
	markUnitAsNotIdle(unitID)
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
    markUnitAsNotIdle(unitID)
	maybeMarkUnitAsIdle(unitID, unitDefID, newTeamID)
end

function widget:UnitFinished(unitID, unitDefID, teamID, builderID)
	-- Spring.Echo("UnitFinished being constructed. unitID-" .. unitID .. ", unitDefID-" .. unitDefID .. ", teamID-" .. teamID)
	maybeMarkUnitAsIdle(unitID, unitDefID, teamID)
end

function widget:Initialize()
	Spring.Echo("Starting AlertIdlersNew")
    widget:PlayerChanged()
	if isSpectator then
		return
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
	Spring.Echo("checkQueuesOfFactories " .. tostring(myFactories[1]))
	for v, unitID in pairs(myFactories) do
	Spring.Echo("checkQueuesOfFactories unitID=" .. unitID .. ", v=" .. v)
		if isUnitRelevant(Spring.GetUnitDefID(unitID), myTeamID) and isUnitIdle(unitID) then
			markUnitAsIdle(unitID)
		else 
			markUnitAsNotIdle(unitID)
		end
	end
end

function widget:CommandsChanged(chgd)
	-- Called when the command descriptions changed, e.g. when selecting or deselecting a unit. Because widget:UnitIdle doesn't happen when factory queue is removed by player
	-- Spring.Echo("CommandsChanged. Called when the command descriptions changed, e.g. when selecting or deselecting a unit. chgd=" .. tostring(chgd))
	checkQueuesOfFactories()
end

function widget:GameFrame(frame)
    if idlingUnitCount > 0 then
		if warnFrame >= 0 then
			checkQueuesOfInactiveUnits()
			if idlingUnitCount > 0 then -- still idling after we checked the queues
				Spring.PlaySoundFile(TestSound, 1.0, 'ui')
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


-- local protoUnit = pUnit:clone()
-- protoUnit.parent = pUnit
-- protoUnit:setAllIDs(26761)
-- Spring.Echo("protoUnit 1. ID=" .. tostring(protoUnit.ID) .. ", defID=".. tostring(protoUnit.defID) .. ", teamID=".. tostring(protoUnit.teamID))

