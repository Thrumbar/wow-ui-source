AdventureMap_QuestChoiceDataProviderMixin = CreateFromMixins(AdventureMapDataProviderMixin);

function AdventureMap_QuestChoiceDataProviderMixin:OnAdded(adventureMap)
	AdventureMapDataProviderMixin.OnAdded(self, adventureMap);

	self:RegisterEvent("ADVENTURE_MAP_UPDATE_POIS");
	self:RegisterEvent("ADVENTURE_MAP_QUEST_UPDATE");
	self:RegisterEvent("QUEST_ACCEPTED");
end

function AdventureMap_QuestChoiceDataProviderMixin:OnEvent(event, ...)
	if event == "ADVENTURE_MAP_QUEST_UPDATE" then
		self:RefreshAllData();
	elseif event == "ADVENTURE_MAP_UPDATE_POIS" then
		self:RefreshAllData();
	elseif event == "QUEST_ACCEPTED" then
		if self:GetAdventureMap():IsVisible() then
			local questIndex, questID = ...;
			for pin in self:GetAdventureMap():EnumeratePinsByTemplate("AdventureMap_QuestChoicePinTemplate") do
				if pin.questID == questID then
					self:OnQuestAccepted(pin);
					break;
				end
			end
		end
	end
end

function AdventureMap_QuestChoiceDataProviderMixin:RemoveAllData()
	self:GetAdventureMap():RemoveAllPinsByTemplate("AdventureMap_QuestChoicePinTemplate");
	self:GetAdventureMap():RemoveAllPinsByTemplate("AdventureMap_FogPinTemplate");

	self:GetAdventureMap():ReleaseAreaTriggers("AdventureMap_QuestChoice");

	self.enclosedPin = nil;
end

function AdventureMap_QuestChoiceDataProviderMixin:RefreshAllData(fromOnShow)
	self:RemoveAllData();
	if fromOnShow then
		-- We have to wait until the server sends us quest data before we can continue
		self.playRevealAnims = true;
		return;
	end

	for choiceIndex = 1, C_AdventureMap.GetNumZoneChoices() do
		local questID, name, zoneDescription, normalizedX, normalizedY = C_AdventureMap.GetZoneChoiceInfo(choiceIndex);
		if AdventureMap_IsQuestValid(questID, normalizedX, normalizedY) then
			self:AddQuest(questID, name, zoneDescription, normalizedX, normalizedY);
		end
	end

	self.playRevealAnims = false;
end

function AdventureMap_QuestChoiceDataProviderMixin:AddQuest(questID, name, zoneDescription, normalizedX, normalizedY)
	local choicePin = self:AddChoicePin(questID, name, zoneDescription, normalizedX, normalizedY);
	choicePin.fogPin = self:AddFogPin(questID, normalizedX, normalizedY);
end

local function OnQuestPinAreaEnclosedChanged(areaTrigger, areaEnclosed)
	areaTrigger.owner:OnQuestPinAreaEnclosedChanged(areaTrigger.pin, areaEnclosed);
end

local APPEAR_PERCENT = .85;
local function QuestPinAreaTriggerPredicate(areaTrigger)
	local adventureMap = areaTrigger.owner.adventureMap;
	return not adventureMap:IsZoomingOut() and adventureMap:GetCanvasZoomPercent() > APPEAR_PERCENT;
end

function AdventureMap_QuestChoiceDataProviderMixin:AddChoicePin(questID, name, zoneDescription, normalizedX, normalizedY)
	local pin = self:GetAdventureMap():AcquirePin("AdventureMap_QuestChoicePinTemplate", self.playRevealAnims);
	pin.questID = questID;
	pin.Text:SetText(name);
	pin.zoneDescription = zoneDescription;
	pin:SetPosition(normalizedX, normalizedY);
	pin:Show();

	local areaTrigger = self:GetAdventureMap():AcquireAreaTrigger("AdventureMap_QuestChoice");
	areaTrigger.owner = self;
	areaTrigger.pin = pin;

	self:GetAdventureMap():SetAreaTriggerEnclosedCallback(areaTrigger, OnQuestPinAreaEnclosedChanged);
	self:GetAdventureMap():SetAreaTriggerPredicate(areaTrigger, QuestPinAreaTriggerPredicate);

	areaTrigger:SetCenter(normalizedX, normalizedY);
	areaTrigger:Stretch(.1, .1);

	pin.areaTrigger = areaTrigger;

	return pin;
end

function AdventureMap_QuestChoiceDataProviderMixin:OnQuestPinAreaEnclosedChanged(pin, areaEnclosed)
	if areaEnclosed then
		if self.enclosedPin then
			self.enclosedPin:SetSelected(false);
		end

		local function OnClosedCallback(result)
			if self.enclosedPin then
				if result == QUEST_CHOICE_DIALOG_RESULT_ACCEPTED then
					self:OnQuestAccepted(self.enclosedPin);
				elseif result == QUEST_CHOICE_DIALOG_RESULT_DECLINED or result == QUEST_CHOICE_DIALOG_RESULT_ABSTAIN then
					self.enclosedPin:SetSelected(false);
				end
			end
			self.enclosedPin = nil;
			if result == QUEST_CHOICE_DIALOG_RESULT_DECLINED then
				self:GetAdventureMap():ZoomOut();
			end
		end

		AdventureMapQuestChoiceDialog:ShowWithQuest(self:GetAdventureMap(), pin, pin.questID, OnClosedCallback);
		AdventureMapQuestChoiceDialog:SetPortraitAtlas("QuestPortraitIcon-SandboxQuest", 38, 63, 0, 12);
		
		pin:SetSelected(true);

		self.enclosedPin = pin;
	elseif self.enclosedPin == pin then
		AdventureMapQuestChoiceDialog:DeclineQuest(true);
	end
end

function AdventureMap_QuestChoiceDataProviderMixin:AddFogPin(questID, normalizedX, normalizedY)
	local pin = self:GetAdventureMap():AcquirePin("AdventureMap_FogPinTemplate", self.playRevealAnims);
	pin:SetPosition(normalizedX, normalizedY);
	pin:Show();
	return pin;
end

function AdventureMap_QuestChoiceDataProviderMixin:OnQuestAccepted(pin)
	local fogPin = pin.fogPin;
	fogPin.OnQuestAcceptedAnim:SetScript("OnFinished", function()
		self:GetAdventureMap():RemovePin(fogPin);
	end);

	fogPin.OnQuestAcceptedAnim:Play();

	pin.fogPin = nil;
	self:GetAdventureMap():ReleaseAreaTrigger("AdventureMap_QuestChoice", pin.areaTrigger);
	self:GetAdventureMap():RemovePin(pin);
end

--[[ Quest Choice Pin ]]--
AdventureMap_QuestChoicePinMixin = CreateFromMixins(AdventureMapPinMixin);

function AdventureMap_QuestChoicePinMixin:OnLoad()
	self:SetScalingLimits(1.25, 3.0, 1.5);
end

function AdventureMap_QuestChoicePinMixin:OnAcquired(playAnim)
	self.selectedCurrentOffset = nil;
	self.selectedTargetOffset = 0;
	self.selectedAnimDelay = 0;

	if playAnim then
		self.OnAddAnim:Play();
	end
end

function AdventureMap_QuestChoicePinMixin:OnClick(button)
	if button == "LeftButton" then
		self:PanAndZoomTo();
	end
end

function AdventureMap_QuestChoicePinMixin:OnUpdate(elapsed)
	if self.selectedTargetOffset then
		self.selectedAnimDelay = self.selectedAnimDelay - elapsed;
		if self.selectedAnimDelay > 0 then
			return;
		end

		self.selectedCurrentOffset = FrameDeltaLerp(self.selectedCurrentOffset or 0, self.selectedTargetOffset, .12);
		local smoothedPercent = -math.cos(math.pi * .5 * (self.selectedCurrentOffset + 1.0));
		self.Icon:SetPoint("CENTER", 0, smoothedPercent * 152);

		if math.abs(self.selectedCurrentOffset - self.selectedTargetOffset) < .001 then
			self.selectedTargetOffset = nil;
		end
	end
end

function AdventureMap_QuestChoicePinMixin:SetSelected(selected)
	self.selectedTargetOffset = selected and 1 or 0;
	self.selectedAnimDelay = selected and 0 or .2;
end

function AdventureMap_QuestChoicePinMixin:OnMouseEnter()
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE");
	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 20, 0);

	GameTooltip:AddLine(self.Text:GetText(), 1, 1, 1);
	GameTooltip:AddLine(self.zoneDescription, nil, nil, nil, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine(ADVENTURE_MAP_VIEW_ZONE_TOOLTIP, 0, 1, 0, true);
	GameTooltip:Show();
end

function AdventureMap_QuestChoicePinMixin:OnMouseLeave()
	GameTooltip_Hide();
end

--[[ Fog Pin ]]--
AdventureMap_FogPinMixin = CreateFromMixins(AdventureMapPinMixin);

function AdventureMap_FogPinMixin:OnLoad()
	self:SetAlphaStyle(AM_PIN_ALPHA_STYLE_VISIBLE_WHEN_ZOOMED_IN);
	self:SetScale(2.5);
end

function AdventureMap_FogPinMixin:OnAcquired(playAnim)
	if playAnim and self:GetAdventureMap():IsZoomedIn() then
		self.OnAddAnim:Play();
	end
end

function AdventureMap_FogPinMixin:OnReleased()
	self.OnQuestAcceptedAnim:Stop();
end