-- ============================================================= --
-- BULK FILL MOD
-- ============================================================= --
BulkFill = {};

addModEventListener(BulkFill);
source(g_currentModDirectory.."StopFillingEvent.lua")
source(g_currentModDirectory.."ChangeFillOrderEvent.lua")
source(g_currentModDirectory.."RemoveTriggerFromListEvent.lua")

function BulkFill.prerequisitesPresent(specializations)
	return  SpecializationUtil.hasSpecialization(FillUnit, specializations) and
			SpecializationUtil.hasSpecialization(FillVolume, specializations) and
			SpecializationUtil.hasSpecialization(Cover, specializations)
end

function BulkFill.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", BulkFill)
end

function BulkFill.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "toggleBulkFill", BulkFill["toggleBulkFill"])
	SpecializationUtil.registerFunction(vehicleType, "stopFilling", BulkFill["stopFilling"])
	SpecializationUtil.registerFunction(vehicleType, "changeFillOrder", BulkFill["changeFillOrder"])
	SpecializationUtil.registerFunction(vehicleType, "RemoveTriggerFromList", BulkFill["RemoveTriggerFromList"])
	SpecializationUtil.registerFunction(vehicleType, "toggleFillSelection", BulkFill["toggleFillSelection"])
	SpecializationUtil.registerFunction(vehicleType, "cycleFillTriggers", BulkFill["cycleFillTriggers"])
end

-- SAVE AND RETRIEVE TOGGLED STATE TO/FROM VEHICLES.XML
function BulkFill:onLoad(savegame)
	self.isFilling = false
	self.selectedIndex = 1

	if 	self.typeName == 'tractor' or
		self.typeName == 'locomotive' or
		self.typeName == 'trainTimberTrailer' or
		self.typeName == 'pallet' or
		self.typeName == 'baler' or
		self.typeName == 'tedder'
	then
		self.spec_bulkFill.isValid = false
		--print("BULK FILL NOT LOADED: " .. self.typeDesc .. ", " .. self.typeName)
	else
		-- set saved bulk fill state or default to true
		self.spec_bulkFill.isValid = true
		--print("BULK FILL LOADED: " .. self.typeDesc .. ", " .. self.typeName)
	end
	
	if savegame ~= nil and self.spec_bulkFill.isValid then
		-- set saved bulk fill state or default to true
		self.spec_bulkFill.isEnabled = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key..".bulkFill#isEnabled"), true)
		self.spec_bulkFill.isSelectEnabled = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key..".bulkFill#isSelectEnabled"), true)
	else
		self.spec_bulkFill.isEnabled = true
		self.spec_bulkFill.isSelectEnabled = true
	end
end
function BulkFill:saveToXMLFile(xmlFile, key, usedModNames)
	if self.spec_bulkFill.isValid then
		setXMLBool(xmlFile, key ..".bulkFill#isEnabled", self.spec_bulkFill.isEnabled)
		setXMLBool(xmlFile, key ..".bulkFill#isSelectEnabled", self.spec_bulkFill.isSelectEnabled)
	end
end

-- MULTIPLAYER
function BulkFill:onReadStream(streamId, connection)
	if connection:getIsServer() then
		local spec = self.spec_bulkFill
		if spec.isValid then
			spec.isFilling = streamReadBool(streamId)
		end
	end
end

function BulkFill:onWriteStream(streamId, connection)
	if not connection:getIsServer() then
		local spec = self.spec_bulkFill
		if spec.isValid then
			streamWriteBool(streamId, spec.isFilling)
		end
	end
end

-- TOGGLE ENABLE/DISABLE BULK FILL
function BulkFill:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	if isOnActiveVehicle and self.spec_bulkFill.isValid then
		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'TOGGLE_BULK_FILL', self, BulkFill.actionEventHandler, false, true, false, true)
		if self.spec_bulkFill.isEnabled then
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_ENABLED"))
		else
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_DISABLED"))
		end
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, true)
		g_inputBinding:setActionEventActive(actionEventId, true)
		self.spec_bulkFill.toggleActionEventId = actionEventId

		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'TOGGLE_FILL_SELECT', self, BulkFill.actionEventHandler, false, true, false, true)
		if self.spec_bulkFill.isSelectEnabled then
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_FILL_SELECT_ENABLED"))
		else
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_FILL_SELECT_DISABLED"))
		end
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, true)
		g_inputBinding:setActionEventActive(actionEventId, true)
		self.spec_bulkFill.showActionEventId = actionEventId
		
		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'BULK_FILL_CYCLE_FW', self, BulkFill.actionEventHandler, false, true, false, true)
		g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_CYCLE_FW"))
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
		g_inputBinding:setActionEventActive(actionEventId, false)
		self.spec_bulkFill.cycleFwActionEventId = actionEventId
		
		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'BULK_FILL_CYCLE_BW', self, BulkFill.actionEventHandler, false, true, false, true)
		g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_CYCLE_BW"))
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
		g_inputBinding:setActionEventActive(actionEventId, false)
		self.spec_bulkFill.cycleBwActionEventId = actionEventId
	end
end
function BulkFill:onUpdate(dt, isActiveForInput, isSelected)
	if isActiveForInput and self.spec_bulkFill.isValid then
		local bf = self.spec_bulkFill
		local spec = self.spec_fillUnit
		
		if #spec.fillTrigger.triggers == 0 then
			--print("NO TRIGGERS AVAILABLE")
			bf.selectedIndex = 1
			g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, false)
			g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, false)
			g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, false)
			g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, false)
			
			if spec.fillTrigger.currentTrigger ~= nil then
				--print("STOP FILLING")
				self:stopFilling(false)
			end
			
		else
			--print("TRIGGERS AVAILABLE")
			bf.selectedIndex = MathUtil.clamp(bf.selectedIndex, 1, #spec.fillTrigger.triggers)
	
			if spec.fillTrigger.currentTrigger ~= nil then
				if spec.fillTrigger.triggers[bf.selectedIndex]~=nil and spec.fillTrigger.triggers[bf.selectedIndex]~=spec.fillTrigger.currentTrigger then
					--print("CURRENT TRIGGER HAS CHANGED")
					if spec.fillTrigger.currentTrigger.sourceObject.isDeleted then
						--print("DELETED: "..tostring(spec.fillTrigger.currentTrigger.sourceObject.id))
						
						if bf.isEnabled then

							local nextFillType = spec.fillTrigger.triggers[bf.selectedIndex].sourceObject.spec_fillUnit.fillUnits[1].lastValidFillType
							local previousFillType = spec.fillTrigger.currentTrigger.sourceObject.spec_fillUnit.fillUnits[1].lastValidFillType
							if nextFillType == previousFillType then
								--print("FILL FROM NEXT: "..tostring(spec.fillTrigger.triggers[1].sourceObject.id))
								spec.fillTrigger.activatable:onActivateObject()
							else
								if #spec.fillTrigger.triggers > 0 then
									--print("FILL TYPES ARE DIFFERENT")
									self:RemoveTriggerFromList(false)
								end
							end
						else
							--print("STOP FILLING 2")
							self:stopFilling(false)
						end
					end
				end
			end

			if bf.isSelectEnabled and not g_gui:getIsGuiVisible() then
				if bf.isFilling then
					g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, false)
					g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, false)
					g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, false)
					g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, false)
				else
					g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, true)
					g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, true)
					g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, true)
					g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, true)
				end

				for i = 1, #spec.fillTrigger.triggers do
					local colour = {}
					if i==bf.selectedIndex then
						colour = {1.0,1.0,0.1,1.0}
					else
						colour = {1.0,1.0,1.0,0.3}
					end

					if spec.fillTrigger.triggers[i] ~= nil then
						local trigger = spec.fillTrigger.triggers[i]
						
						if trigger.sourceObject.numComponents == 1 then
							local sourceObject = trigger.sourceObject

							--value = fillLevelInformation.fillLevel / fillLevelInformation.capacity
							if sourceObject.isAddedToPhysics and not sourceObject.isDeleted then
								local fillLevelBuffer = {}
								sourceObject:getFillLevelInformation(fillLevelBuffer)
								local fillLevelInformation = fillLevelBuffer[1]
								local fillLevel = string.format("%.0f", fillLevelInformation.fillLevel)
								local x, y, z = getWorldTranslation(sourceObject.rootNode)
								Utils.renderTextAtWorldPosition(x, y+1, z, "#"..i.."\n[ "..fillLevel.." ]", getCorrectTextSize(0.02), 0, colour)
							end
						end
					end
				end
			else
				bf.selectedIndex = 1
				g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, false)
				g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, false)
				g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, false)
				g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, false)
			end
		end
	end
end
function BulkFill:actionEventHandler(actionName, inputValue, callbackState, isAnalog)
	if actionName=='TOGGLE_BULK_FILL' then
		self:toggleBulkFill()
	elseif actionName=='TOGGLE_FILL_SELECT' then
		self:toggleFillSelection()
	elseif actionName=='BULK_FILL_CYCLE_FW' then
		self:cycleFillTriggers('FW')
	elseif actionName=='BULK_FILL_CYCLE_BW' then
		self:cycleFillTriggers('BW')
	end
end
function BulkFill:toggleBulkFill()
	if not self.spec_bulkFill.isEnabled then
		--print("ENABLE")
		self.spec_bulkFill.isEnabled = true
		g_inputBinding:setActionEventText(self.spec_bulkFill.toggleActionEventId, g_i18n:getText("action_BULK_FILL_ENABLED"))
						
		if self.spec_fillUnit.fillTrigger.isFilling then
			self.spec_bulkFill.isFilling = true
		end
	else
		--print("DISABLE")
		self.spec_bulkFill.isEnabled = false
		self.spec_bulkFill.isFilling = false
		g_inputBinding:setActionEventText(self.spec_bulkFill.toggleActionEventId, g_i18n:getText("action_BULK_FILL_DISABLED"))
	end
end
function BulkFill:toggleFillSelection()
	if not self.spec_bulkFill.isSelectEnabled then
		--print("SHOW")
		self.spec_bulkFill.isSelectEnabled = true
		g_inputBinding:setActionEventText(self.spec_bulkFill.showActionEventId, g_i18n:getText("action_FILL_SELECT_ENABLED"))
	else
		--print("HIDE")
		self.spec_bulkFill.isSelectEnabled = false
		g_inputBinding:setActionEventText(self.spec_bulkFill.showActionEventId, g_i18n:getText("action_FILL_SELECT_DISABLED"))
	end
end
function BulkFill:cycleFillTriggers(direction)
	local bf = self.spec_bulkFill
	local spec = self.spec_fillUnit
	
	if direction == 'FW' then
		--print("CYCLE_FORWARDS")
		bf.selectedIndex = bf.selectedIndex + 1
	else
		--print("CYCLE_BACKWARDS")
		bf.selectedIndex = bf.selectedIndex - 1
	end
	
	if bf.selectedIndex < 1 then
		bf.selectedIndex = #spec.fillTrigger.triggers
	end
	if bf.selectedIndex > #spec.fillTrigger.triggers then
		bf.selectedIndex = 1
	end
end

-- AUTO FILLING:
function BulkFill.FillActivatableOnActivateObject(self, superFunc)
	local bf = self.vehicle.spec_bulkFill
	local spec = self.vehicle.spec_fillUnit
	
	if bf.isValid then
		if bf.selectedIndex ~= 1 then
			--print("CHANGE FILL ORDER")
			self.vehicle:changeFillOrder(false)
			bf.selectedIndex = 1
		end
	end
	
	superFunc(self)
	
	if bf.isValid then
		if spec.fillTrigger.isFilling then
			--print("START FILLING: " .. tostring(spec.fillTrigger.currentTrigger.sourceObject.id))
			bf.isFilling = true
		else
			--print("CANCEL FILLING")
			bf.isFilling = false
		end
	end
end

-- NETWORK EVENTS:
function BulkFill:stopFilling(noEventSend)
	self.spec_fillUnit.fillTrigger.currentTrigger = nil
	self.spec_bulkFill.isFilling = false
	
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("g_server:broadcastEvent: stopFilling")
			g_server:broadcastEvent(StopFillingEvent:new(self), nil, nil, self)
		else
			--print("g_client:sendEvent: stopFilling")
			g_client:getServerConnection():sendEvent(StopFillingEvent:new(self))
		end
	end
end

function BulkFill:changeFillOrder(noEventSend)
	local newIndex = self.spec_bulkFill.selectedIndex
	local spec = self.spec_fillUnit
	table.insert(spec.fillTrigger.triggers, 1, spec.fillTrigger.triggers[newIndex])
	table.remove(spec.fillTrigger.triggers, newIndex+1)
	spec.fillTrigger.currentTrigger = spec.fillTrigger.triggers[1]
	self.spec_bulkFill.selectedIndex = 1
	
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("g_server:broadcastEvent: changeFillOrder")
			g_server:broadcastEvent(ChangeFillOrderEvent:new(self), nil, nil, self)
		else
			--print("g_client:sendEvent: changeFillOrder")
			g_client:getServerConnection():sendEvent(ChangeFillOrderEvent:new(self))
		end
	end
end
	
function BulkFill:RemoveTriggerFromList(noEventSend)
	--print("REMOVE FROM LIST: "..tostring(self.spec_fillUnit.fillTrigger.triggers[1].sourceObject.id))
	table.remove(self.spec_fillUnit.fillTrigger.triggers, 1)
	self.spec_bulkFill.selectedIndex = 1
	
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("g_server:broadcastEvent: RemoveTriggerFromList")
			g_server:broadcastEvent(RemoveTriggerFromListEvent:new(self), nil, nil, self)
		else
			--print("g_client:sendEvent: RemoveTriggerFromList")
			g_client:getServerConnection():sendEvent(RemoveTriggerFromListEvent:new(self))
		end
	end
end

-- STOP FILLING WHEN UNLOADING
function BulkFill.FillUnitActionEventUnload(self, actionName, inputValue, callbackState, isAnalog)
	--print("UNLOADING")
	local spec = self.spec_fillUnit
	if spec.fillTrigger.isFilling then
		--print("CANCEL LOADING")
		self:setFillUnitIsFilling(false)
		self.spec_bulkFill.isFilling = false
	end
end

-- BULK FILL FUNCTIONS
function BulkFill:loadMap(name)
	--print("Load Mod: 'BULK FILL'")
	FillActivatable.onActivateObject = Utils.overwrittenFunction(FillActivatable.onActivateObject, BulkFill.FillActivatableOnActivateObject)
	FillUnit.actionEventUnload = Utils.prependedFunction(FillUnit.actionEventUnload, BulkFill.FillUnitActionEventUnload)

	BulkFill.initialised = false
end

function BulkFill:deleteMap()
end

function BulkFill:mouseEvent(posX, posY, isDown, isUp, button)
end

function BulkFill:keyEvent(unicode, sym, modifier, isDown)
end

function BulkFill:draw()
end

function BulkFill:update(dt)
	if not BulkFill.initialised then
		--print("g_server: "..tostring(g_server))
		--print("self.isServer: "..tostring(self.isServer))
		BulkFill.initialised = true
	end
end

-- ADD custom strings from ModDesc.xml to g_i18n
local i = 0
local xmlFile = loadXMLFile("modDesc", g_currentModDirectory.."modDesc.xml")
while true do
	local key = string.format("modDesc.l10n.text(%d)", i)
	
	if not hasXMLProperty(xmlFile, key) then
		break
	end
	
	local name = getXMLString(xmlFile, key.."#name")
	local text = getXMLString(xmlFile, key.."."..g_languageShort)
	
	if name ~= nil then
		g_i18n:setText(name, text)
	end
	
	i = i + 1
end