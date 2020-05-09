--
-- InteractiveControl v2.0
-- Specialization for an interactive control
--
-- SFM-Modding
-- @author:  	Manuel Leithner
-- @date:		17/10/10
-- @version:	v2.0
-- @history:	v1.0 - initial implementation
--				v2.0 - convert to LS2011 and some bugfixes
--
-- free for noncommerical-usage
--

InteractiveControl = {};

local ICModName = g_currentModName

function InteractiveControl.prerequisitesPresent(specializations)
    return true
end;

function InteractiveControl.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", InteractiveControl)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", InteractiveControl)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", InteractiveControl)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", InteractiveControl)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", InteractiveControl)
	SpecializationUtil.registerEventListener(vehicleType, "onAIEnd", InteractiveControl)
end

function InteractiveControl:onLoad(vehicle)
	self.actionEventScript = {};
	self.actionEventScript.actionEvents = {};	
	source(Utils.getFilename("Scripts/InteractiveComponentInterface.lua", self.baseDirectory));
	self.doActionOnObject = InteractiveControl.doActionOnObject
	self.setPanelOverlay = InteractiveControl.setPanelOverlay
	self.interactiveObjects = {};	
	self.indoorCamIndex = 2;
	self.outdoorCamIndex = 1;
	self.lastMouseXPos = 0;
	self.lastMouseYPos = 0;					
	self.panelOverlay = nil;
	self.foundInteractiveObject = nil;
	self.isMouseActive = false;
end;

function InteractiveControl:onReadStream(streamId, connection)
	local icCount = streamReadInt8(streamId);
	for i=1, icCount do
		local isOpen = streamReadBool(streamId);
		if self.interactiveObjects[i] ~= nil then
			if self.interactiveObjects[i].synch then
				self.interactiveObjects[i]:doAction(true, isOpen);	
			end;
		end;
	end;
end;

function InteractiveControl:onWriteStream(streamId, connection)
	streamWriteInt8(streamId, table.getn(self.interactiveObjects));
	for k,v in pairs(self.interactiveObjects) do
		streamWriteBool(streamId, v.isOpen);
	end;
end;

function InteractiveControl:doActionOnObject(id, noEventSend)
	if self.interactiveObjects[id].isLocalOnly == nil or not self.interactiveObjects[id].isLocalOnly then
		InteractiveControlEvent.sendEvent(self, id, noEventSend);	
	end;
	self.interactiveObjects[id]:doAction(noEventSend);	
end;

function InteractiveControl.onLeaveVehicleAnimationsHandler(self)
	if not self:getIsAIActive() then
		local icCount = 0;
		for _,v in pairs(self.interactiveObjects) do
			if ((icCount == 1 or icCount == 3) or ((icCount == 0 or icCount == 5) and not self:getIsMotorStarted())) and v.isOpen then
				v:doAction(true);
			end;
			icCount = icCount + 1;
		end;
	end;
end;

function InteractiveControl:onAIEnd()
	InteractiveControl.onLeaveVehicleAnimationsHandler(self);
end;

function InteractiveControl:onLeaveVehicle()
	InteractiveControl.onLeaveVehicleAnimationsHandler(self);
end;

function InteractiveControl:onEnterVehicle()
	if not self:getIsAIActive() then
		local icCount = 0;
		for _,v in pairs(self.interactiveObjects) do
			if (icCount == 0 or icCount == 5 or icCount == 1  or icCount == 3) and not v.isOpen then
				v:doAction(true);	
			end;
			icCount = icCount + 1;
		end;
		self.notLoaded = false;
	end;
end;

--
-- InteractiveControlEvent 
-- Specialization for an interactive control
--
-- SFM-Modding
-- @author:  	Manuel Leithner
-- @date:		14/12/11
-- @version:	v2.0
-- @history:	v1.0 - initial implementation
--				v2.0 - convert to LS2011 and some bugfixes
--
InteractiveControlEvent = {};
InteractiveControlEvent_mt = Class(InteractiveControlEvent, Event);

InitEventClass(InteractiveControlEvent, "InteractiveControlEvent");

function InteractiveControlEvent:emptyNew()
    local self = Event:new(InteractiveControlEvent_mt);
    return self;
end;

function InteractiveControlEvent:new(vehicle, interactiveControlID)
    local self = InteractiveControlEvent:emptyNew()
    self.vehicle = vehicle;
	self.interactiveControlID = interactiveControlID;
    return self;
end;

function InteractiveControlEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.interactiveControlID = streamReadInt8(streamId);
    self.vehicle = NetworkUtil.getObject(id);
    self:run(connection);
end;

function InteractiveControlEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));	
	streamWriteInt8(streamId, self.interactiveControlID);
end;

function InteractiveControlEvent:run(connection)
	self.vehicle:doActionOnObject(self.interactiveControlID, true);
	if not connection:getIsServer() then
		g_server:broadcastEvent(InteractiveControlEvent:new(self.vehicle, self.interactiveControlID), nil, connection, self.vehicle);
	end;
end;

function InteractiveControlEvent.sendEvent(vehicle, icObject, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(InteractiveControlEvent:new(vehicle, icObject), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(InteractiveControlEvent:new(vehicle, icObject));
		end;
	end;
end;