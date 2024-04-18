PlayerSpellsFrameMixin = {};

local PlayerSpellsFrameEvents = {
};

local PlayerSpellsFrameUnitEvents = {
	"PLAYER_SPECIALIZATION_CHANGED",
};

function PlayerSpellsFrameMixin:OnLoad()
	TabSystemOwnerMixin.OnLoad(self);
	self:SetTabSystem(self.TabSystem);
	self.specTabID = self:AddNamedTab(TALENT_FRAME_TAB_LABEL_SPEC, self.SpecFrame);
	self.talentTabID = self:AddNamedTab(TALENT_FRAME_TAB_LABEL_TALENTS, self.TalentsFrame);
	self.spellBookTabID = self:AddNamedTab(TALENT_FRAME_TAB_LABEL_SPELLBOOK, self.SpellBookFrame);

	self.frameTabsToTabID = {
		[PlayerSpellsUtil.FrameTabs.ClassSpecializations] = self.specTabID,
		[PlayerSpellsUtil.FrameTabs.ClassTalents] = self.talentTabID,
		[PlayerSpellsUtil.FrameTabs.SpellBook] = self.spellBookTabID,
	};

	self.CloseButton:SetScript("OnClick", GenerateClosure(self.CheckConfirmClose, self));

	self.autoMinimizeEnabled = true;

	self:SetFrameLevelsFromBaseLevel(5000);

	self:UpdatePortrait();
end

function PlayerSpellsFrameMixin:OnShow()
	PlayerSpellsMicroButton:EvaluateAlertVisibility();

	FrameUtil.RegisterFrameForEvents(self, PlayerSpellsFrameEvents);
	FrameUtil.RegisterFrameForUnitEvents(self, PlayerSpellsFrameUnitEvents, "player");

	self:UpdateTabs();

	MultiActionBar_ShowAllGrids(ACTION_BUTTON_SHOW_GRID_REASON_SPELLCOLLECTION);
	UpdateMicroButtons();
	EventRegistry:TriggerEvent("PlayerSpellsFrame.OpenFrame");
	PlaySound(SOUNDKIT.UI_CLASS_TALENT_OPEN_WINDOW);
end

function PlayerSpellsFrameMixin:OnHide()
	PlayerSpellsMicroButton:EvaluateAlertVisibility();

	FrameUtil.UnregisterFrameForEvents(self, PlayerSpellsFrameEvents);
	FrameUtil.UnregisterFrameForEvents(self, PlayerSpellsFrameUnitEvents);

	PlaySound(SOUNDKIT.UI_CLASS_TALENT_CLOSE_WINDOW);

	self:ClearInspectUnit();

	MultiActionBar_HideAllGrids(ACTION_BUTTON_SHOW_GRID_REASON_SPELLCOLLECTION);
	UpdateMicroButtons();
	self.lockInspect = false;
end

function PlayerSpellsFrameMixin:OnEvent(event)
	if event == "PLAYER_SPECIALIZATION_CHANGED" then
		self:UpdateTabs();
		self:UpdatePortrait();
	end
end

function PlayerSpellsFrameMixin:GetTalentsTabButton()
	return self:GetTabButton(self.talentTabID);
end

function PlayerSpellsFrameMixin:UpdateTabs()
	local specTabAvailable = self:IsTabAvailable(self.specTabID);
	local spellBookTabAvailable = self:IsTabAvailable(self.spellBookTabID);
	self.TabSystem:SetTabShown(self.specTabID, specTabAvailable);
	self.TabSystem:SetTabShown(self.spellBookTabID, spellBookTabAvailable);

	if self:IsInspecting() then
		self.TabSystem:SetTabShown(self.talentTabID, false);
	else
		local talentTabAvailable = self:IsTabAvailable(self.talentTabID);
		self.TabSystem:SetTabShown(self.talentTabID, talentTabAvailable);
	end

	local currentTab = self:GetTab();
	if not currentTab or not self:IsTabAvailable(currentTab) then
		self:SetToDefaultAvailableTab();
	end
end

function PlayerSpellsFrameMixin:SetToDefaultAvailableTab()
	if(self:IsTabAvailable(self.talentTabID)) then
		self:SetTab(self.talentTabID);
	elseif (self:IsTabAvailable(self.specTabID)) then
		self:SetTab(self.specTabID);
	else
		self:SetTab(self.spellBookTabID);
	end
end

function PlayerSpellsFrameMixin:UpdateFrameTitle()
	local tabID = self:GetTab();
	if self:IsInspecting() then
		local inspectUnit = self:GetInspectUnit();
		if inspectUnit then
			self:SetTitle(TALENTS_INSPECT_FORMAT:format(UnitName(self:GetInspectUnit())));
		else
			self:SetTitle(TALENTS_LINK_FORMAT:format(self:GetSpecName(), self:GetClassName()));
		end
	elseif tabID == self.specTabID then
		self:SetTitle(SPECIALIZATION);
	elseif tabID == self.talentTabID then
		self:SetTitle(TALENTS);
	else --if tabID == self.spellBookTabID
		self:SetTitle(SPELLBOOK);
	end
end

function PlayerSpellsFrameMixin:SetTab(tabID)
	if self.isMinimized and not self:DoesTabSupportMinimizedMode(tabID) then
		self:ForceMaximize();
	end

	self:SetTabMinimized(tabID, self.isMinimized);

	TabSystemOwnerMixin.SetTab(self, tabID);

	self:UpdateFrameTitle();
	EventRegistry:TriggerEvent("PlayerSpellsFrame.TabSet", PlayerSpellsFrame, tabID);
	return true; -- Don't show the tab as selected yet.
end

-- Expects a PlayerSpellsUtil.FrameTabs value
function PlayerSpellsFrameMixin:IsFrameTabActive(frameTab)
	local tabID = self.frameTabsToTabID[frameTab];
	if not tabID then
		return false;
	end
	return self:GetTab() == tabID;
end

-- Expects a PlayerSpellsUtil.FrameTabs value
function PlayerSpellsFrameMixin:TrySetTab(frameTab)
	local tabID = self.frameTabsToTabID[frameTab];
	if not tabID then
		return false;
	end

	local isTabAvailable = self:IsTabAvailable(tabID);
	if isTabAvailable then
		self:SetTab(tabID);
	end

	return isTabAvailable;
end

function PlayerSpellsFrameMixin:IsTabAvailable(tabID)
	local canUseTalentSpecUI = C_SpecializationInfo.CanPlayerUseTalentSpecUI();
	local isInspecting = self:IsInspecting();

	if tabID == self.specTabID then
		return not isInspecting and canUseTalentSpecUI;
	elseif tabID == self.talentTabID then
		return isInspecting or (PlayerUtil.CanUseClassTalents() and canUseTalentSpecUI);
	elseif tabID == self.spellBookTabID then
		return not isInspecting;
	end

	return false;
end

function PlayerSpellsFrameMixin:ClearInspectUnit()
	if not self:IsInspecting() then
		return;
	end

	ClearInspectPlayer();

	self:SetInspectString(nil);
end

function PlayerSpellsFrameMixin:SetInspectUnit(inspectUnit)
	local inspectString = nil;
	local inspectStringLevel = nil;
	self:SetInspecting(inspectUnit, inspectString, inspectStringLevel);
end

function PlayerSpellsFrameMixin:SetInspectString(inspectString, inspectStringLevel)
	local inspectUnit = nil;
	self:SetInspecting(inspectUnit, inspectString, inspectStringLevel);
end

function PlayerSpellsFrameMixin:SetInspecting(inspectUnit, inspectString, inspectStringLevel)
	if (inspectUnit or inspectString) and self:IsMinimized() then
		-- Force us out of minimize mode ahead of processing data so that we're in a clean state to inspect
		-- Otherwise the Hide involved will clear out the inspect unit.
		-- If Talent tab ever supports minimized mode in the future, we may be able to remove this.
		self:ForceMaximize();
	end

	self.inspectUnit = inspectUnit;
	self.inspectString = inspectString;

	if inspectString then
		local success, specID = self.TalentsFrame:ViewLoadout(inspectString, inspectStringLevel);
		if not success then
			self:SetInspecting(nil, nil, nil);
			return;
		end

		self.inspectStringSpecID = specID;
		self.inspectStringClassID = C_SpecializationInfo.GetClassIDFromSpecID(specID);
	else
		self.inspectStringSpecID = nil;
		self.inspectStringClassID = nil;
	end

	self:SetAutoMinimizeEnabled(not self:IsInspecting());

	self:UpdateTabs();
	self.TalentsFrame:UpdateInspecting();

	if inspectUnit or inspectString then
		self:SetTab(self.talentTabID);
	else
		self:UpdateFrameTitle();
	end

	self:UpdatePortrait();
end

function PlayerSpellsFrameMixin:IsInspecting()
	return (self.inspectUnit ~= nil) or (self.inspectString ~= nil);
end

function PlayerSpellsFrameMixin:GetInspectUnit()
	return self.inspectUnit;
end

function PlayerSpellsFrameMixin:GetInspectString()
	return self.inspectString, self.inspectStringClassID, self.inspectStringSpecID;
end

function PlayerSpellsFrameMixin:GetClassID()
	if self:IsInspecting() then
		local inspectUnit = self:GetInspectUnit();
		if inspectUnit then
			return select(3, UnitClass(inspectUnit));
		else
			return select(2, self:GetInspectString());
		end
	end

	return PlayerUtil.GetClassID();
end

function PlayerSpellsFrameMixin:GetSpecID()
	if self:IsInspecting() then
		local inspectUnit = self:GetInspectUnit();
		if inspectUnit then
			return GetInspectSpecialization(inspectUnit);
		else
			return select(3, self:GetInspectString());
		end
	end

	return PlayerUtil.GetCurrentSpecID();
end

function PlayerSpellsFrameMixin:GetUnitSex()
	-- If we're inspecting via string, use the player's sex.
	local unit = (self:IsInspecting() and self:GetInspectUnit()) or "player";
	return UnitSex(unit);
end

function PlayerSpellsFrameMixin:GetClassName()
	if self:IsInspecting() then
		local inspectUnit = self:GetInspectUnit();
		if inspectUnit then
			local className = UnitClass(inspectUnit);
			return className;
		else
			local classID = select(2, self:GetInspectString());
			local classInfo = C_CreatureInfo.GetClassInfo(classID);
			return classInfo.className;
		end
	end

	return PlayerUtil.GetClassName();
end

function PlayerSpellsFrameMixin:GetSpecName()
	local unitSex = self:GetUnitSex();
	local specID = self:GetSpecID();
	return select(2, GetSpecializationInfoByID(specID, unitSex));
end

function PlayerSpellsFrameMixin:UpdatePortrait()
	local specID = self:GetSpecID();
	local specIcon = specID and PlayerUtil.GetSpecIconBySpecID(specID, self:GetInspectUnit() or "player") or nil;
	if specIcon then
		self:SetPortraitTexCoord(0, 1, 0, 1);
		self:SetPortraitToAsset(specIcon);
	else
		local classID = self:GetClassID();
		self:SetPortraitToClassIcon(C_CreatureInfo.GetClassInfo(classID).classFile);
	end
end

function PlayerSpellsFrameMixin:CheckConfirmClose()
	-- No need to check before closing anymore.
	HideUIPanel(self);
	EventRegistry:TriggerEvent("PlayerSpellsFrame.CloseFrame");
end

function PlayerSpellsFrameMixin:CheckConfirmResetAction(callback, cancelCallback)
	if (self:GetTab() == self.talentTabID) and self.TalentsFrame:HasAnyConfigChanges() then
		local referenceKey = self;
		if not StaticPopup_IsCustomGenericConfirmationShown(referenceKey) then
			local customData = {
				text = TALENT_FRAME_CONFIRM_CLOSE,
				callback = callback,
				cancelCallback = cancelCallback,
				acceptText = CONTINUE,
				cancelText = CANCEL,
				referenceKey = referenceKey,
			};

			StaticPopup_ShowCustomGenericConfirmation(customData);
		end
	else
		callback();
	end
end

function PlayerSpellsFrameMixin:IsMinimized()
	return self.isMinimized;
end

function PlayerSpellsFrameMixin:IsMinimizeEnabled()
	return self.autoMinimizeEnabled;
end

function PlayerSpellsFrameMixin:DoesTabSupportMinimizedMode(tabID)
	-- Check should be updated if/when support for minimized mode is added to additional tabs
	return tabID == self.spellBookTabID;
end

function PlayerSpellsFrameMixin:GetDefaultMinimizableTab()
	-- Logic should be updated if/when support for minimized mode is added to additional tabs
	return self.spellBookTabID;
end

function PlayerSpellsFrameMixin:SetMinimized(shouldBeMinimized)
	if not self.isMinimized and shouldBeMinimized then
		-- Prevent non-UIParent code manually calling SetMinimized when auto behavior intentionally disabled
		assert(self.autoMinimizeEnabled);
		self.isMinimized = true;
		local minimizableTabID = self:GetDefaultMinimizableTab();
		self:SetTab(minimizableTabID); -- SetTab will call SetTabMaximized
		self:SetWidth(self.minimizedWidth);
	elseif self.isMinimized and not shouldBeMinimized then
		self.isMinimized = false;
		self:SetWidth(self.maximizedWidth);
		self:SetTabMinimized(self:GetTab(), false);
	end
end

function PlayerSpellsFrameMixin:SetTabMinimized(tabID, shouldBeMinimized)
	if not tabID or not self:DoesTabSupportMinimizedMode(tabID) then
		return;
	end

	local tabPage = self:GetElementsForTab(tabID)[1];
	tabPage:SetMinimized(shouldBeMinimized);
end

function PlayerSpellsFrameMixin:ForceMaximize()
	self:SetMinimized(false);
	if self:IsShown() then
		-- Close and re-show with minimize attributes temporarily disabled to ensure this frame stays maximized and other frames get closed
		-- Only calling UpdateUIPanelPositions isn't enough as we need to run through all the area evaluation logic within ShowUIPanel
		HideUIPanel(self, true);
		self:SetAutoMinimizeEnabled(false);
		ShowUIPanel(self);
		-- Now re-enable minimizing so that, if another frame gets opened later, we can be re-minimized and pop back to a supporting tab as usual
		self:SetAutoMinimizeEnabled(true);
	end
end

function PlayerSpellsFrameMixin:SetAutoMinimizeEnabled(enabled)
	self.autoMinimizeEnabled = enabled;
	if enabled then
		SetUIPanelAttribute(self, "autoMinimizeWithOtherPanels", true);
		SetUIPanelAttribute(self, "area", "centerOrLeft");
	else
		SetUIPanelAttribute(self, "autoMinimizeWithOtherPanels", false);
		SetUIPanelAttribute(self, "area", "center");
	end
end