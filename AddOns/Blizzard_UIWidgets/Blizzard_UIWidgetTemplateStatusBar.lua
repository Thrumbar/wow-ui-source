local function GetStatusBarVisInfoData(widgetID)
	local widgetInfo = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetID);
	if widgetInfo and widgetInfo.shownState ~= Enum.WidgetShownState.Hidden then
		return widgetInfo;
	end
end

UIWidgetManager:RegisterWidgetVisTypeTemplate(Enum.UIWidgetVisualizationType.StatusBar, {frameType = "FRAME", frameTemplate = "UIWidgetTemplateStatusBar"}, GetStatusBarVisInfoData);

UIWidgetTemplateStatusBarMixin = CreateFromMixins(UIWidgetBaseTemplateMixin);

local textureKitRegionFormatStrings = {
	["BorderLeft"] = "%s-BorderLeft",
	["BorderRight"] = "%s-BorderRight",
	["BorderCenter"] = "%s-BorderCenter",
	["BGLeft"] = "%s-BGLeft",
	["BGRight"] = "%s-BGRight",
	["BGCenter"] = "%s-BGCenter",
	["Spark"] = "%s-Spark",
	["BackgroundGlow"] = "%s-BackgroundGlow";
}

local backgroundGlowTextureKitString = "%s-BackgroundGlow";
local partitionTextureKitString = "%s-BorderTick";

local barColorFromTintValue = {
	[Enum.StatusBarColorTintValue.Black] = BLACK_FONT_COLOR,
	[Enum.StatusBarColorTintValue.White] = WHITE_FONT_COLOR,
	[Enum.StatusBarColorTintValue.Red] = RED_FONT_COLOR,
	[Enum.StatusBarColorTintValue.Yellow] = YELLOW_FONT_COLOR,
	[Enum.StatusBarColorTintValue.Orange] = ORANGE_FONT_COLOR,
	[Enum.StatusBarColorTintValue.Purple] = EPIC_PURPLE_COLOR,
	[Enum.StatusBarColorTintValue.Green] = GREEN_FONT_COLOR,
	[Enum.StatusBarColorTintValue.Blue] = RARE_BLUE_COLOR,
}

local fillTextureKitFormatString = "%s-Fill-%s";
local DEFAULT_BAR_WIDTH = 215;

local textureKitOffsets = {
	["jailerstower-scorebar"] = {sparkXOffset = -14,},
	["jailerstower-scorebar-pause"] = {sparkXOffset = -14, },
	["jailerstower-scorebar-empty"] = {sparkXOffset = -14, },
	["jailerstower-scorebar-full"] = {sparkXOffset = -14, },
	["default"] = {sparkXOffset = 0, },
}

function UIWidgetTemplateStatusBarMixin:Setup(widgetInfo, widgetContainer)
	UIWidgetBaseTemplateMixin.Setup(self, widgetInfo, widgetContainer);

	local frameTextureKit = widgetInfo.frameTextureKit;
	local fillTextureKit = widgetInfo.textureKit;
	local offsets = textureKitOffsets[frameTextureKit] or textureKitOffsets["default"];
	if frameTextureKit and fillTextureKit then
		local fillAtlas = fillTextureKitFormatString:format(frameTextureKit, fillTextureKit);
		self.Bar:SetStatusBarAtlas(fillAtlas);
	end

	local overrideHeight = nil;
	local barColor = barColorFromTintValue[widgetInfo.colorTint];
	if(barColor) then 
		self.Bar:SetStatusBarColor(barColor:GetRGB());
		self.Bar.Spark:SetVertexColor(barColor:GetRGB());
	end 

	SetupTextureKitOnRegions(frameTextureKit, self.Bar, textureKitRegionFormatStrings, TextureKitConstants.SetVisibility, TextureKitConstants.UseAtlasSize);
	self.Bar.BorderCenter:SetAtlas("jailstower-scorebar-pause-bordercenter", true)
	if(not self.Bar.BorderLeft:IsShown() and not self.Bar.BorderRight:IsShown()) then 
		self.Bar.BorderCenter:ClearAllPoints(); 
		self.Bar.BorderCenter:SetPoint("CENTER", 0);
		local barInfo = C_Texture.GetAtlasInfo(self.Bar:GetStatusBarAtlas());
		if(useBarAtlasSizeHeight) then 
			overrideHeight = self.Bar.BorderCenter:GetHeight(); 
		end
	else 
		self.Bar.BorderCenter:ClearAllPoints();
		self.Bar.BorderCenter:SetPoint("TOPLEFT", self.Bar.BorderLeft, "TOPRIGHT");
		self.Bar.BorderCenter:SetPoint("BOTTOMRIGHT", self.Bar.BorderRight, "BOTTOMLEFT");
	end		
	local barWidth = (widgetInfo.widgetSizeSetting > 0) and widgetInfo.widgetSizeSetting or DEFAULT_BAR_WIDTH;
	self.Bar:SetWidth(barWidth);

	local minVal, maxVal, barVal = widgetInfo.barMin, widgetInfo.barMax, widgetInfo.barValue;
	if minVal > 0 and minVal == maxVal and barVal == maxVal then
		-- If all 3 values are the same and greater than 0, show the bar as full
		minVal, maxVal, barVal = 0, 1, 1;
	end

	self.Bar:Setup(widgetContainer, minVal, maxVal, barVal, widgetInfo.barValueTextType, widgetInfo.tooltip, widgetInfo.overrideBarText, widgetInfo.overrideBarTextShownType);

	local showSpark = widgetInfo.barValue > widgetInfo.barMin and widgetInfo.barValue < widgetInfo.barMax;
	self.Bar.Spark:SetShown(showSpark);
	if showSpark then
		self.Bar.Spark:ClearAllPoints();
		self.Bar.Spark:SetPoint("CENTER", self.Bar:GetStatusBarTexture(), "RIGHT", offsets.sparkXOffset, 0);
	end

	self.Label:SetText(widgetInfo.text);

	local labelWidth = 0;
	local labelHeight = 0;
	self.Bar:ClearAllPoints();
	if widgetInfo.text ~= "" then
		labelWidth = self.Label:GetWidth();
		labelHeight = self.Label:GetHeight() + 3;
		self.Bar:SetPoint("TOP", self.Label, "BOTTOM", 0, -8);
	else
		self.Bar:SetPoint("TOP", self, "TOP", 0, -8);
	end

	self.partitionPool:ReleaseAll();
	local backgroundGlowAtlas = backgroundGlowTextureKitString:format(frameTextureKit);
	local backgroundGlowAtlasInfo = C_Texture.GetAtlasInfo(backgroundGlowAtlas);

	if(backgroundGlowAtlasInfo) then 
		self.Bar.BackgroundGlow:SetAtlas(backgroundGlowAtlas, TextureKitConstants.UseAtlasSize)
	end	

	local paritionAtlas = partitionTextureKitString:format(frameTextureKit);
	local partitionAtlasInfo =  C_Texture.GetAtlasInfo(paritionAtlas);
	for _, partitionValue in ipairs(widgetInfo.partitionValues) do
		if partitionAtlasInfo then
			local partitionTexture = self.partitionPool:Acquire();

			local useAtlasSize = true;
			partitionTexture:SetAtlas(paritionAtlas, useAtlasSize);

			local partitionPercent = ClampedPercentageBetween(partitionValue, minVal, maxVal);
			local xOffset = barWidth * partitionPercent;

			partitionTexture:SetPoint("CENTER", self.Bar:GetStatusBarTexture(), "LEFT", xOffset, 0)
			partitionTexture:Show();
		end
		self.Bar.BackgroundGlow:SetShown(backgroundGlowAtlasInfo and barVal >= partitionValue)	
	end

	local totalWidth = math.max(self.Bar:GetWidth() + 16, labelWidth);
	self:SetWidth(totalWidth);

	local barHeight = overrideHeight ~= nil and overrideHeight or (self.Bar:GetHeight() + 16);

	local totalHeight = barHeight + labelHeight;
	self:SetHeight(totalHeight);
end

function UIWidgetTemplateStatusBarMixin:OnLoad()
	UIWidgetBaseTemplateMixin.OnLoad(self);
	self.partitionPool = CreateTexturePool(self.Bar, "OVERLAY");
end

function UIWidgetTemplateStatusBarMixin:OnReset()
	UIWidgetBaseTemplateMixin.OnReset(self);
	self.partitionPool:ReleaseAll();
end
