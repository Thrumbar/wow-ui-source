---------------
--NOTE - Please do not change this section
local _, tbl, secureCapsuleGet = ...;
assertsafe(secureCapsuleGet ~= nil, "SecureCapsuleGet not provided to secure environment.");
tbl.SecureCapsuleGet = secureCapsuleGet;
tbl.setfenv = tbl.SecureCapsuleGet("setfenv");
tbl.getfenv = tbl.SecureCapsuleGet("getfenv");
tbl.type = tbl.SecureCapsuleGet("type");
tbl.unpack = tbl.SecureCapsuleGet("unpack");
tbl.error = tbl.SecureCapsuleGet("error");
tbl.pcall = tbl.SecureCapsuleGet("pcall");
tbl.pairs = tbl.SecureCapsuleGet("pairs");
tbl.setmetatable = tbl.SecureCapsuleGet("setmetatable");
tbl.getmetatable = tbl.SecureCapsuleGet("getmetatable");
tbl.pcallwithenv = tbl.SecureCapsuleGet("pcallwithenv");

local function CleanFunction(f)
	return function(...)
		local function HandleCleanFunctionCallArgs(success, ...)
			if success then
				return ...;
			else
				tbl.error("Error in secure capsule function execution: "..(...));
			end
		end
		return HandleCleanFunctionCallArgs(tbl.pcallwithenv(f, tbl, ...));
	end
end

local function CleanTable(t, tableCopies)
	if not tableCopies then
		tableCopies = {};
	end

	local cleaned = {};
	tableCopies[t] = cleaned;

	for k, v in tbl.pairs(t) do
		if tbl.type(v) == "table" then
			if ( tableCopies[v] ) then
				cleaned[k] = tableCopies[v];
			else
				cleaned[k] = CleanTable(v, tableCopies);
			end
		elseif tbl.type(v) == "function" then
			cleaned[k] = CleanFunction(v);
		else
			cleaned[k] = v;
		end
	end
	return cleaned;
end

local function Import(name)
	local skipTableCopy = true;
	local val = tbl.SecureCapsuleGet(name, skipTableCopy);
	if tbl.type(val) == "function" then
		tbl[name] = CleanFunction(val);
	elseif tbl.type(val) == "table" then
		tbl[name] = CleanTable(val);
	else
		tbl[name] = val;
	end
end

if tbl.getmetatable(tbl) == nil then
	local secureEnvMetatable =
	{
		__metatable = false,
		__environment = false,
	}
	tbl.setmetatable(tbl, secureEnvMetatable);
end

setfenv(1, tbl);
----------------

Import("assert");
Import("math");
Import("max");
Import("ceil");
Import("floor");
Import("ipairs");
Import("table");
Import("format");
Import("tInvert");
Import("TableUtil");
Import("AuraUtil");
Import("GetTime");
Import("CreateFromMixins");
Import("SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD");
Import("SMALLER_AURA_DURATION_FONT_MAX_THRESHOLD");
Import("SMALLER_AURA_DURATION_FONT");
Import("SMALLER_AURA_DURATION_OFFSET_Y");
Import("DEFAULT_AURA_DURATION_FONT");
Import("SECONDS_PER_DAY");
Import("DAY_ONELETTER_ABBR");
Import("SECONDS_PER_HOUR");
Import("HOUR_ONELETTER_ABBR");
Import("SECONDS_PER_MIN");
Import("MINUTE_ONELETTER_ABBR");
Import("SECOND_ONELETTER_ABBR");
Import("SecondsToTimeAbbrev");
Import("DebuffTypeColor");
Import("DebuffTypeSymbol");
Import("UnitIsUnit");
Import("GetCVarBool");
Import("PlaySound");
Import("SOUNDKIT");
Import("BUFF_DURATION_WARNING_TIME");
Import("HIGHLIGHT_FONT_COLOR");
Import("NORMAL_FONT_COLOR");
Import("C_CVar");
Import("C_FunctionContainers");
Import("C_UnitAuras");
Import("C_UnitAurasPrivate");
Import("C_Timer");
Import("C_ChatInfo");

----------------

-- This is largely a modified copy of AuraButtonMixin
PrivateAuraMixin = {};

function PrivateAuraMixin:OnLoad()
	self.Symbol:Hide();
	local color = DebuffTypeColor["none"];
	self.DebuffBorder:SetVertexColor(color.r, color.g, color.b);
	self.DebuffBorder:ClearAllPoints();
	self.DebuffBorder:SetPoint("TOPLEFT", self.Icon, "TOPLEFT", -1, 0);
	self.DebuffBorder:SetPoint("BOTTOMRIGHT", self.Icon, "BOTTOMRIGHT", 1, 0);
	self.DebuffBorder:Show();
	self.TempEnchantBorder:Hide();
end

function PrivateAuraMixin:OnEnter()
	PrivateAurasTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
	PrivateAurasTooltip:SetFrameLevel(self:GetFrameLevel() + 2);
	PrivateAurasTooltip:SetUnitPrivateAura(self.unit, self.auraInfo.auraInstanceID);
end

function PrivateAuraMixin:OnLeave()
	PrivateAurasTooltip:Hide();
end

function PrivateAuraMixin:OnUpdate()
	-- Update duration
	self:UpdateDuration(self.timeLeft);

	-- Update our timeLeft
	local timeLeft = self.auraInfo.expirationTime - GetTime();
	if self.auraInfo.timeMod and self.auraInfo.timeMod > 0 then
		timeLeft = timeLeft / self.auraInfo.timeMod;
	end
	self.timeLeft = math.max(timeLeft, 0);
	if SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD then
		local aboveMinThreshold = self.timeLeft > SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD;
		local belowMaxThreshold = not SMALLER_AURA_DURATION_FONT_MAX_THRESHOLD or self.timeLeft < SMALLER_AURA_DURATION_FONT_MAX_THRESHOLD;
		if aboveMinThreshold and belowMaxThreshold then
			self.Duration:SetFontObject(SMALLER_AURA_DURATION_FONT);
			self.Duration:SetPoint("TOP", self, "BOTTOM", 0, SMALLER_AURA_DURATION_OFFSET_Y);
		else
			self.Duration:SetFontObject(DEFAULT_AURA_DURATION_FONT);
			self.Duration:SetPoint("TOP", self, "BOTTOM");
		end
	end

	if self:IsMouseMotionFocus() then
		PrivateAurasTooltip:SetUnitPrivateAura(self.unit, self.auraInfo.auraInstanceID);
	end
end

function PrivateAuraMixin:UpdateExpirationTime(auraInfo)
	if auraInfo.expirationTime and auraInfo.expirationTime > 0 then
		self.Duration:SetShown(GetCVarBool("buffDurations"));

		local timeLeft = (auraInfo.expirationTime - GetTime());
		if auraInfo.timeMod and auraInfo.timeMod > 0 then
			self.timeMod = auraInfo.timeMod;
			timeLeft = timeLeft / auraInfo.timeMod;
		end

		if not self.timeLeft then
			self.timeLeft = timeLeft;
			self:SetScript("OnUpdate", self.OnUpdate);
		else
			self.timeLeft = timeLeft;
		end
	else
		self.Duration:Hide();
		self:SetScript("OnUpdate", nil);
		self.timeLeft = nil;
	end
end

function PrivateAuraMixin:Update(auraInfo, unit, anchorInfo)
	self.auraInfo = auraInfo;
	self.unit = unit;
	self.anchorInfo = anchorInfo;

	local color;
	if auraInfo.dispelName then
		color = DebuffTypeColor[auraInfo.dispelName];
		if GetCVarBool("colorblindMode") then
			self.Symbol:Show();
			self.Symbol:SetText(DebuffTypeSymbol[auraInfo.dispelName] or "");
		else
			self.Symbol:Hide();
		end
	else
		self.Symbol:Hide();
		color = DebuffTypeColor["none"];
	end
	self.DebuffBorder:SetVertexColor(color.r, color.g, color.b);

	self:UpdateExpirationTime(auraInfo);
	self.Icon:SetTexture(auraInfo.icon);

	if auraInfo.applications > 1 then
		self.Count:SetText(auraInfo.applications);
		self.Count:Show();
	else
		self.Count:Hide();
	end

	if anchorInfo.showCountdownFrame and auraInfo.expirationTime and auraInfo.expirationTime ~= 0 then
		local startTime = auraInfo.expirationTime - auraInfo.duration;
		CooldownFrame_Set(self.Cooldown, startTime, auraInfo.duration, true);
		self.Cooldown:SetHideCountdownNumbers(not anchorInfo.showCountdownNumbers);
	else
		CooldownFrame_Clear(self.Cooldown);
	end

	if self:IsMouseMotionFocus() then
		PrivateAurasTooltip:SetUnitPrivateAura(self.unit, self.auraInfo.auraInstanceID);
	end
end

function PrivateAuraMixin:UpdateDuration(timeLeft)
	if timeLeft and GetCVarBool("buffDurations") then
		self.Duration:SetFormattedText(SecondsToTimeAbbrev(timeLeft));
		if timeLeft < BUFF_DURATION_WARNING_TIME then
			self.Duration:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
		else
			self.Duration:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		end
		self.Duration:Show();
	else
		self.Duration:Hide();
	end
end


local unitWatchers = {};

-- Base private aura watcher for a particular unit
local PrivateAuraUnitWatcher = {};

function PrivateAuraUnitWatcher:Init(unit)
	assert(not unitWatchers[unit], "PrivateAuraUnitWatcher: Tried to instantiate for unit that already has a watcher.");

	self.unit = unit;
	self.anchors = {};
	self.debuffFramePool = CreateFramePool("FRAME", nil, "PrivateAuraTemplate");
	self.callback = C_FunctionContainers.CreateCallback(function(updateInfo)
		if self:HandleUpdateInfo(updateInfo) then
			self:MarkDirty();
		end
	end);
	C_UnitAurasPrivate.AddPrivateAuraUpdateCallback(unit, self.callback);

	self:ParseAllAuras();
	self:MarkDirty();
end

function PrivateAuraUnitWatcher:AddAuras(auras)
	local aurasAdded = false;
	for _, aura in ipairs(auras) do
		if self:ShouldDisplayAura(aura) then
			self.auras[aura.auraInstanceID] = aura;
			aurasAdded = true;
		end
	end
	return aurasAdded;
end

function PrivateAuraUnitWatcher:ParseAllAuras()
	if not self.auras then
		self.auras = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable);
	else
		self.auras:Clear();
	end

	self:AddAuras(C_UnitAurasPrivate.GetAllPrivateAuras(self.unit));
end

function PrivateAuraUnitWatcher:ShouldDisplayAura(auraInfo)
	-- For now, any private aura on the unit should always display
	return true;
end

function PrivateAuraUnitWatcher:HandleUpdateInfo(updateInfo)
	local aurasChanged = false;

	if updateInfo.isFullUpdate then
		self:ParseAllAuras();
		aurasChanged = true;
		return aurasChanged;
	end

	if updateInfo.addedAuras then
		if self:AddAuras(updateInfo.addedAuras) then
			aurasChanged = true;
		end
	end

	if updateInfo.updatedAuraInstanceIDs then
		for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
			if self.auras[auraInstanceID] ~= nil then
				local newAura = C_UnitAurasPrivate.GetAuraDataByAuraInstanceIDPrivate(self.unit, auraInstanceID);
				self.auras[auraInstanceID] = newAura;
				aurasChanged = true;
			end
		end
	end

	if updateInfo.removedAuraInstanceIDs then
		for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
			if self.auras[auraInstanceID] ~= nil then
				self.auras[auraInstanceID] = nil;
				aurasChanged = true;
			end
		end
	end

	return aurasChanged;
end

function PrivateAuraUnitWatcher:GetAuraInfoForIndex(index)
	local auraInfo;
	local curr = 1;
	self.auras:Iterate(function(auraID, currAuraInfo)
		local done = false;
		if curr == index then
			auraInfo = currAuraInfo;
			done = true;
		else
			curr = curr + 1;
		end
		return done;
	end);
	return auraInfo;
end

function PrivateAuraUnitWatcher:SetUpAnchor(privateAnchor)
	local auraInfo = self:GetAuraInfoForIndex(privateAnchor.auraIndex);
	if auraInfo then
		local debuffFrame = self.debuffFramePool:Acquire();
		C_UnitAurasPrivate.AnchorPrivateAura(debuffFrame, debuffFrame.Icon, debuffFrame.Duration, privateAnchor.anchorID);
		if privateAnchor.iconWidth and privateAnchor.iconHeight then
			debuffFrame.Icon:SetSize(privateAnchor.iconWidth, privateAnchor.iconHeight);
		end
		debuffFrame:Show();
		debuffFrame:Update(auraInfo, self.unit, privateAnchor);
	end
end

function PrivateAuraUnitWatcher:UpdateAllAnchors()
	self.debuffFramePool:ReleaseAll();
	for _, anchor in pairs(self.anchors) do
		self:SetUpAnchor(anchor);
	end
end

function PrivateAuraUnitWatcher:MarkDirty()
	if not self.isDirty then
		self.isDirty = true;
		C_Timer.After(0, function()
			self.isDirty = false;
			self:UpdateAllAnchors();
		end);
	end
end

function PrivateAuraUnitWatcher:AddAnchor(anchor)
	if anchor.unitToken ~= self.unit then
		return;
	end

	self.anchors[anchor.anchorID] = anchor;
	-- Can't immediately instantiate because aura template may not be loaded yet
	self:MarkDirty();
end

function PrivateAuraUnitWatcher:RemoveAnchor(anchorID)
	if not self.anchors[anchorID] then
		return false;
	end

	self.anchors[anchorID] = nil;
	self:MarkDirty();
	return true;
end


local function AddPrivateAnchor(anchor)
	local unit = anchor.unitToken;
	if not unitWatchers[unit] then
		local newWatcher = CreateFromMixins(PrivateAuraUnitWatcher);
		newWatcher:Init(unit)
		unitWatchers[unit] = newWatcher;
	end
	unitWatchers[unit]:AddAnchor(anchor);
end
C_UnitAurasPrivate.SetPrivateAuraAnchorAddedCallback(AddPrivateAnchor);

local function RemovePrivateAnchor(anchorID)
	for _, watcher in pairs(unitWatchers) do
		if watcher:RemoveAnchor(anchorID) then
			return;
		end
	end
end
C_UnitAurasPrivate.SetPrivateAuraAnchorRemovedCallback(RemovePrivateAnchor);

-- Anchors may have been added before this file was loaded
do
	local existingAnchors = C_UnitAurasPrivate.GetPrivateAuraAnchors();
	for _, anchor in ipairs(existingAnchors) do
		AddPrivateAnchor(anchor);
	end
end


function RaidBossEmoteFrame_OnLoad(self) -- Private version override
	RaidNotice_FadeInit(self.slot1);
	RaidNotice_FadeInit(self.slot2);
	self.timings = { };
	self.timings["RAID_NOTICE_MIN_HEIGHT"] = 20.0;
	self.timings["RAID_NOTICE_MAX_HEIGHT"] = 30.0;
	self.timings["RAID_NOTICE_SCALE_UP_TIME"] = 0.2;
	self.timings["RAID_NOTICE_SCALE_DOWN_TIME"] = 0.4;
	
	self:RegisterEvent("CLEAR_BOSS_EMOTES");

	C_UnitAurasPrivate.SetPrivateWarningTextFrame(self);

	self.privateRaidBossMessageCallback = C_FunctionContainers.CreateCallback(function(chatType, text, playerName, displayTime, playSound)
		local body = format(text, playerName, playerName);	--No need for pflag, monsters can't be afk, dnd, or GMs.
		local color = C_ChatInfo.GetColorForChatType(chatType);
		RaidNotice_AddMessage(self, body, color, displayTime);
		if playSound then
			if chatType == "RAID_BOSS_WHISPER" then
				PlaySound(SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING);
			else
				PlaySound(SOUNDKIT.RAID_BOSS_EMOTE_WARNING);
			end
		end
	end);
	C_UnitAurasPrivate.SetPrivateRaidBossMessageCallback(self.privateRaidBossMessageCallback);
end

function RaidBossEmoteFrame_OnEvent(self, event, ...)  -- Private version override
	if event == "CLEAR_BOSS_EMOTES" then
		RaidNotice_Clear(self);
	end
end