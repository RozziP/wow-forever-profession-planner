local _, addon = ...
local routes = addon.routes
local plannerTitle = "Forever Profession Trainer"
local professionSlotCount = 7
local secondaryTabOrder = { Cooking = 1, ["First Aid"] = 2 }
local professionSkillLines = {
  Alchemy = 171, Blacksmithing = 164, Enchanting = 333,
  Engineering = 202, Leatherworking = 165, Tailoring = 197, Cooking = 185, ["First Aid"] = 129,
}
local professionIcons = {
  Alchemy = "Trade_Alchemy", Blacksmithing = "Trade_BlackSmithing", Enchanting = "Trade_Engraving",
  Engineering = "Trade_Engineering", Leatherworking = "Trade_LeatherWorking", Tailoring = "Trade_Tailoring",
  Cooking = "INV_Misc_Food_15",
  ["First Aid"] = "Spell_Holy_SealOfSacrifice",
}
local gameIconPath = "Interface\\Icons\\"
local plannerIcon = gameIconPath .. "INV_Misc_Book_09"
-- Trainer locations and outdoor map coordinates follow the WoW Professions, Method, and Icy Veins Forever guides.
local nextRanks = {
  [75] = { name = "Journeyman", skill = 50, level = 10 },
  [150] = { name = "Expert", skill = 125, level = 20 },
  [225] = { name = "Artisan", skill = 200, level = 35 },
}
local cookingRanks = {
  [75] = { name = "Journeyman", skill = 50 },
  [150] = {
    name = "Expert", skill = 125, action = "Read Expert Cookbook",
    instructions = "Buy and read Expert Cookbook to unlock Cooking 225.",
  },
  [225] = {
    name = "Artisan", skill = 225, level = 35, action = "Complete Clamlette Surprise",
    instructions = "Bring 12 Giant Eggs, 10 Zesty Clam Meat,\nand 20 Alterac Swiss to Dirge Quikcleave.",
  },
}
local expertCookingVendors = {
  Horde = { name = "Wulan", location = "Shadowprey Village, Desolace", mapID = 1443, x = 26.1, y = 69.7 },
  Alliance = { name = "Shandrina", location = "Silverwind Refuge, Ashenvale", mapID = 1440, x = 49.5, y = 67.1 },
}
local firstAidRanks = {
  [75] = { name = "Journeyman", skill = 50 },
  [150] = {
    name = "Expert", skill = 125, action = "Read Expert First Aid - Under Wraps",
    instructions = "Buy and read Expert First Aid - Under Wraps to unlock First Aid 225.",
  },
  [225] = {
    name = "Artisan", skill = 225, level = 35, action = "Complete Triage",
    instructions = "Use the doctor's triage bandages to save 15 patients and unlock First Aid 300.",
  },
}
local specialRanks = { Cooking = cookingRanks, ["First Aid"] = firstAidRanks }
local expertFirstAidVendors = {
  Horde = { name = "Balai Lok'Wein", location = "Brackenwall Village, Dustwallow Marsh", mapID = 1445, x = 36.5, y = 30.4 },
  Alliance = { name = "Deneb Walker", location = "Stromgarde Keep, Arathi Highlands", mapID = 1417, x = 27.1, y = 58.8 },
}
local expertTrainingCities = {
  Alchemy = { Horde = "Undercity", Alliance = "Darnassus" },
  Blacksmithing = { Horde = "Orgrimmar", Alliance = "Ironforge" },
  Engineering = { Horde = "Orgrimmar", Alliance = "Ironforge" },
  Leatherworking = { Horde = "Thunder Bluff", Alliance = "Darnassus" },
  Tailoring = { Horde = "Undercity", Alliance = "Stormwind" },
}
local expertEnchantingTrainers = {
  Horde = { name = "Hgarth", location = "Sun Rock Retreat, Stonetalon Mountains", mapID = 1442, x = 49.2, y = 57.2 },
  Alliance = { name = "Kitta Firewind", location = "Tower of Azora, Elwynn Forest", mapID = 1429, x = 64.8, y = 70.6 },
}
local artisanTrainers = {
  Alchemy = {
    Horde = { name = "Rogvar", location = "Stonard, Swamp of Sorrows", mapID = 1435, x = 48.5, y = 55.8 },
    Alliance = { name = "Kylanna Windwhisper", location = "Feathermoon Stronghold, Feralas", mapID = 1444, x = 32.6, y = 43.8 },
  },
  Blacksmithing = { name = "Brikk Keencraft", location = "Booty Bay, Stranglethorn Vale", mapID = 1434, x = 29.0, y = 75.6 },
  Cooking = { name = "Dirge Quikcleave", location = "Gadgetzan, Tanaris", mapID = 1446, x = 52.6, y = 28.1 },
  ["First Aid"] = {
    Horde = { name = "Doctor Gregory Victor", location = "Hammerfall, Arathi Highlands", mapID = 1417, x = 73.4, y = 36.8 },
    Alliance = { name = "Doctor Gustaf VanHowzen", location = "Foothold Citadel, Theramore", mapID = 1445, x = 67.8, y = 49.0 },
  },
  Enchanting = {
    name = "Annora", location = "Inside Uldaman, Badlands", mapID = 1418, x = 65.3, y = 42.6,
    waypointLabel = "Uldaman's rear entrance",
  },
  Engineering = { name = "Buzzek Bracketswing", location = "Gadgetzan, Tanaris", mapID = 1446, x = 52.2, y = 27.6 },
  Leatherworking = {
    Horde = { name = "Hahrana Ironhide", location = "Camp Mojache, Feralas", mapID = 1444, x = 74.4, y = 43.0 },
    Alliance = { name = "Drakk Stonehand", location = "Aerie Peak, The Hinterlands", mapID = 1425, x = 13.4, y = 43.3 },
  },
  Tailoring = {
    Horde = { name = "Daryl Stack", location = "Tarren Mill, Hillsbrad Foothills", mapID = 1424, x = 63.6, y = 20.8 },
    Alliance = { name = "Timothy Worthington", location = "Theramore Isle, Dustwallow Marsh", mapID = 1445, x = 66.2, y = 51.6 },
  },
}

local frame
local plannerTheme
local active
local debugSelected
local stepRowHeight = 36
local targetStep = 5
local defaultTarget, maxTarget = 75, 300
local skillMilestones = { defaultTarget, 150, 225, maxTarget }
local defaultWindowWidth, defaultWindowHeight = 750, 620
local stepColumns = { skill = 12, icon = 79, recipe = 109, crafts = 60 }
local anchoredPlans = {}
local selectedPlan
local settings
local colors = {
  text = { 0.97, 0.92, 0.82 },
  gold = { 1.00, 0.82, 0.30 },
  muted = { 0.76, 0.69, 0.57 },
  tabNeutral = { 1, 1, 1 },
  current = { 0.95, 0.79, 0.47 },
  red = { 1.00, 0.45, 0.42 },
  green = { 0.56, 0.86, 0.68 },
  complete = { 0.57, 0.77, 0.59 },
  recipeComplete = { 0.57, 0.86, 0.62 },
  recipeCurrent = { 1.00, 0.85, 0.51 },
  window = { 0.105, 0.079, 0.054, 1 },
  windowBorder = { 0.94, 0.73, 0.43, 1 },
  panelBorder = { 0.72, 0.54, 0.31, 1 },
}
local copyText
local windowBackdrop = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  edgeSize = 24,
  insets = { left = 5, right = 5, top = 5, bottom = 5 },
}
local insetBackdrop = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function nextSkillTarget(rank)
  for _, milestone in ipairs(skillMilestones) do
    if milestone > rank then return milestone end
  end
  return maxTarget
end

local function snapTarget(value, minimum)
  local snapped = math.min(maxTarget, math.floor(value / targetStep + 0.5) * targetStep)
  -- The first drag interval may be shorter than a full step.
  if value - minimum < snapped - value then return minimum end
  return math.max(minimum, snapped)
end

local function paint(region, color)
  region:SetTextColor(unpack(color))
end

local function hideTooltip(owner)
  if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function createSideTab(parent, icon, onClick)
  local tab = CreateFrame("Frame", nil, parent, "LargeSideTabButtonTemplate")
  tab:EnableMouse(true)
  tab:SetFillToInterior(true)
  tab:SetChecked(false)
  tab.Icon:SetTexture(icon)
  tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
    if button == "LeftButton" and upInside then onClick(self) end
  end)
  tab:HookScript("OnHide", hideTooltip)
  return tab
end

local function plannerFont(name, size, color)
  local font = CreateFont("ForeverProfessionPlanner" .. name .. "Font")
  font:SetFontObject(GameFontHighlight)
  local face, _, flags = GameFontHighlight:GetFont()
  font:SetFont(face, size, flags)
  paint(font, color)
  return font
end

local fonts = {
  title = plannerFont("Title", 19, colors.gold),
  heading = plannerFont("Heading", 17, colors.gold),
  trainingWarning = plannerFont("TrainingWarning", 22, colors.current),
  body = plannerFont("Body", 15, colors.text),
  note = plannerFont("Note", 12, colors.text),
  caption = plannerFont("Caption", 13, colors.muted),
}

local function label(parent, font, x, y, width)
  local region = parent:CreateFontString(nil, "OVERLAY")
  region:SetFontObject(font)
  region:SetPoint("TOPLEFT", x, -y)
  region:SetWidth(width)
  region:SetJustifyH("LEFT")
  region:SetJustifyV("TOP")
  return region
end

local function footerCheckButton(parent, caption, tooltip, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  local title = check:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(fonts.caption)
  title:SetPoint("LEFT", check, "RIGHT", 3, 0)
  title:SetWordWrap(false)
  title:SetText(caption)
  local labelWidth = math.ceil(title:GetUnboundedStringWidth()) + 2
  title:SetWidth(labelWidth)
  check:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(labelWidth + 3), -1)
  check:SetHitRectInsets(0, -(labelWidth + 3), 0, 0)
  check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(tooltip)
    GameTooltip:Show()
  end)
  check:SetScript("OnLeave", hideTooltip)
  check:SetScript("OnHide", hideTooltip)
  check:SetScript("OnClick", onClick)
  return check
end

local function floatAndFade(region, height, duration, fadeDelay)
  local animation = region:CreateAnimationGroup()
  local rise = animation:CreateAnimation("Translation")
  rise:SetOffset(0, height)
  rise:SetDuration(duration)
  rise:SetSmoothing("OUT")
  local fade = animation:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0)
  fade:SetStartDelay(fadeDelay)
  fade:SetDuration(duration - fadeDelay)
  animation:SetScript("OnFinished", function() region:Hide() end)
  return animation
end

local function openTrainerMap(link)
  local trainer = link.trainer
  if not trainer then return end
  hideTooltip(link)
  if InCombatLockdown and InCombatLockdown() then
    UIErrorsFrame:AddMessage("Open the trainer map after combat.", unpack(colors.red))
    return
  end
  if not (C_Map and C_Map.OpenWorldMap) then
    UIErrorsFrame:AddMessage("The world map is unavailable.", unpack(colors.red))
    return
  end
  local mapID = trainer.mapID
  if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID)
    and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, trainer.x / 100, trainer.y / 100))
  else
    UIErrorsFrame:AddMessage("Waypoints are unavailable for this map.", unpack(colors.red))
  end
  C_Map.OpenWorldMap(mapID)
  -- The planner can cover the windowed world map.
  if WorldMapFrame and WorldMapFrame:IsShown() then frame:Hide() end
end

local function createTrainerMapLink(parent, text, textColor)
  local link = CreateFrame("Button", nil, parent)
  link:SetPoint("TOPLEFT", text, "TOPLEFT")
  link:SetHeight(20)
  link.label, link.textColor = text, textColor
  link:SetScript("OnClick", openTrainerMap)
  link:SetScript("OnEnter", function(self)
    local trainer = self.trainer
    if not trainer then return end
    paint(self.label, colors.gold)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(trainer.waypointLabel or trainer.name)
    GameTooltip:AddLine("Click to open the map and place a pin.")
    GameTooltip:Show()
  end)
  link:SetScript("OnLeave", function(self)
    paint(self.label, self.trainer and colors.current or self.textColor)
    hideTooltip(self)
  end)
  link:SetScript("OnHide", hideTooltip)
  link:Hide()
  return link
end

local function setTrainerMapLink(link, trainer, caption)
  link.trainer = trainer
  link.label:SetText(trainer and (caption .. "  |A:Waypoint-MapPin-Untracked:14:14|a") or caption)
  paint(link.label, trainer and colors.current or link.textColor)
  if trainer then link:SetWidth(math.ceil(link.label:GetUnboundedStringWidth()) + 2) end
  link:SetShown(trainer ~= nil)
end

local function surface(parent, x, y, width, height, r, g, b)
  local region = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
  region:SetPoint("TOPLEFT", x, -y)
  region:SetSize(width, height)
  region:SetColorTexture(r, g, b, 1)
  return region
end

local function tintGradient(texture, bottom, top)
  if texture.SetGradient and CreateColor then
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient("VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top)))
  end
end

local function styleWindow(window)
  window:SetBackdrop(windowBackdrop)
  window:SetBackdropColor(unpack(colors.window))
  window:SetBackdropBorderColor(unpack(colors.windowBorder))
end

local function button(parent, caption, x, y, width)
  local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  control:SetPoint("TOPLEFT", x, -y)
  control:SetSize(width, 24)
  control:SetNormalFontObject(fonts.body)
  control:SetHighlightFontObject(fonts.body)
  control:SetText(caption)
  return control
end

local function insetPanel(parent, point, x, y)
  local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  panel:SetPoint(point, x, -y)
  panel:SetBackdrop(insetBackdrop)
  panel:SetBackdropColor(0.085, 0.061, 0.041, 1)
  panel:SetBackdropBorderColor(unpack(colors.panelBorder))
  local shading = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
  shading:SetPoint("TOPLEFT", 5, -5)
  shading:SetPoint("BOTTOMRIGHT", -5, 5)
  shading:SetColorTexture(0.10, 0.074, 0.051, 1)
  tintGradient(shading, { 0.16, 0.115, 0.078, 1 }, { 0.085, 0.061, 0.041, 1 })
  panel.shading = shading
  return panel
end

local function money(value)
  local copper = math.floor(math.abs(value) + 0.5)
  local sign = value < 0 and "-" or (value > 0 and "+" or "")
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper / 100) % 100
  if gold > 0 then
    return string.format("%s%dg %02ds %02dc", sign, gold, silver, copper % 100)
  elseif silver > 0 then
    return string.format("%s%ds %02dc", sign, silver, copper % 100)
  end
  return string.format("%s%dc", sign, copper)
end

local function showMoney(region, value, net, component)
  local text = value and money(value) or "—"
  if component then text = text:gsub("^%+", "") end
  if value and C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    local sign = value < 0 and "−" or (value > 0 and not component and "+" or "")
    text = sign .. C_CurrencyInfo.GetCoinTextureString(math.floor(math.abs(value) + 0.5), component and 10 or 12)
  end
  region:SetText(text)
  paint(region, (not value or component) and colors.muted or (net and value < 0 and colors.red)
    or (value > 0 and colors.green) or colors.text)
end

local function formatDuration(milliseconds)
  local seconds = math.ceil(milliseconds / 1000)
  return seconds >= 60 and string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
    or string.format("%ds", seconds)
end

local function showCraftingFeedback(self, milliseconds)
  local seconds = string.format("%.1f", milliseconds / 1000):gsub("%.0$", "")
  local unit = seconds == "1" and "second" or "seconds"
  self.craftingFeedbackAnimation:Stop()
  self.craftingFeedback:SetText(string.format("-%s %s", seconds, unit))
  self.craftingFeedback:Show()
  self.craftingFeedbackAnimation:Play()
end

local function clearCraftingFeedback(self)
  self.craftingFeedbackAnimation:Stop()
  self.craftingFeedback:Hide()
end

local function showShoppingBagSpace(space)
  frame.bagSpace:SetShown(space ~= nil)
  if not space then return end

  local text
  if space.needed > space.free then
    local shortage = space.needed - space.free
    local minimum = space.incomplete and "+" or ""
    local slots = shortage == 1 and not space.incomplete and "slot" or "slots"
    text = string.format("Free %d%s bag %s", shortage, minimum, slots)
  elseif space.incomplete then
    local slots = space.free == 1 and "slot" or "slots"
    text = string.format("%d bag %s free · Check space", space.free, slots)
  else
    text = string.format("Bag slots: %d free / %d needed", space.free, space.needed)
  end
  frame.bagSpace:SetText(text)
  paint(frame.bagSpace, space.needed > space.free and colors.red or (space.incomplete and colors.gold or colors.muted))
end

local function stopWheelScroll(scroll)
  scroll.wheelTarget = nil
  scroll:SetScript("OnUpdate", nil)
end

local function animateWheelScroll(scroll, elapsed)
  local offset = scroll:GetVerticalScroll()
  local pixel = scroll.wheelPixel
  if math.abs(offset - scroll.wheelOffset) > pixel then
    stopWheelScroll(scroll)
    return
  end

  local maximum = scroll:GetVerticalScrollRange()
  scroll.wheelTarget = math.min(scroll.wheelTarget, maximum)
  local target = scroll.wheelTarget
  local position = math.min(scroll.wheelPosition, maximum)
  local distance = target - position
  local nextOffset
  if math.abs(distance) <= pixel then
    stopWheelScroll(scroll)
    nextOffset = target
  else
    position = position + distance * (1 - math.exp(-elapsed * 24))
    scroll.wheelPosition = position
    nextOffset = position
  end

  -- Keep the animation position fractional, but render on physical pixels.
  if nextOffset < maximum then nextOffset = math.min(maximum, math.floor(nextOffset / pixel + 0.5) * pixel) end
  if math.abs(nextOffset - offset) > 0.001 then scroll:SetVerticalScroll(nextOffset) end
  scroll.wheelOffset = scroll:GetVerticalScroll()
end

local function scrollArea(parent, x, y, width, height)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", x, -y)
  scroll:SetSize(width, height)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width, height)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local offset = self:GetVerticalScroll()
    local target = self.wheelTarget
    if not target or math.abs(offset - self.wheelOffset) > self.wheelPixel then
      local _, screenHeight = GetPhysicalScreenSize()
      self.wheelPixel = UIParent:GetHeight() * UIParent:GetEffectiveScale() / (screenHeight * self:GetEffectiveScale())
      target = offset
      self.wheelPosition = offset
    end
    self.wheelTarget = math.max(0, math.min(target - delta * 18, self:GetVerticalScrollRange()))
    self.wheelOffset = offset
    self:SetScript("OnUpdate", animateWheelScroll)
  end)
  scroll:HookScript("OnHide", stopWheelScroll)
  return scroll, content
end

local searchRecipe, showRoute

local function addStepRow()
  local index = #frame.steps + 1
  local y = (index - 1) * stepRowHeight
  local row = CreateFrame("Button", nil, frame.stepContent)
  row:SetPoint("TOPLEFT", 0, -y)
  row:SetPoint("TOPRIGHT", 0, -y)
  row:SetHeight(stepRowHeight)
  local background = surface(row, 0, 0, 1, stepRowHeight, 1, 1, 1)
  background:SetPoint("BOTTOMRIGHT")
  row.background = background
  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 0.82, 0.52, 0.09)
  row:SetHighlightTexture(highlight)

  local marker = surface(row, 3, 6, 2, stepRowHeight - 12, 0.84, 0.65, 0.34)
  marker:Hide()
  local skill = label(row, fonts.caption, stepColumns.skill, 0, stepColumns.icon - stepColumns.skill - 4)
  skill:SetHeight(stepRowHeight)
  skill:SetJustifyV("MIDDLE")
  skill:SetWordWrap(false)
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("LEFT", stepColumns.icon, 0)
  icon:SetSize(24, 24)
  local recipe = label(row, fonts.body, stepColumns.recipe, 0, 1)
  recipe:SetJustifyV("MIDDLE")
  recipe:SetWordWrap(true)
  local keep = label(row, fonts.note, stepColumns.recipe, 21, 1)
  keep:SetHeight(14)
  keep:SetJustifyV("MIDDLE")
  paint(keep, colors.muted)
  local crafts = label(row, fonts.body, 0, 0, stepColumns.crafts - 24)
  crafts:ClearAllPoints()
  crafts:SetPoint("TOPRIGHT", -6, 0)
  crafts:SetHeight(stepRowHeight)
  crafts:SetJustifyV("MIDDLE")
  crafts:SetJustifyH("RIGHT")
  local made = label(row, fonts.note, 0, 0, stepColumns.crafts - 6)
  made:ClearAllPoints()
  made:SetPoint("BOTTOMRIGHT", -6, 3)
  made:SetJustifyH("RIGHT")
  made:SetWordWrap(false)
  paint(made, colors.complete)
  local check = row:CreateTexture(nil, "ARTWORK")
  check:SetPoint("RIGHT", crafts, "LEFT", -2, 0)
  check:SetSize(16, 16)
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetDesaturated(true)
  check:SetVertexColor(unpack(colors.complete))
  check:Hide()
  row.skill, row.recipe, row.crafts, row.keep, row.made = skill, recipe, crafts, keep, made
  row.icon, row.marker, row.check = icon, marker, check
  row.choicePanels = {}
  for option = 1, 2 do
    local panel = CreateFrame("Button", nil, row)
    panel:SetHeight(stepRowHeight - 4)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    panel.fill = fill
    local selection = panel:CreateTexture(nil, "ARTWORK")
    selection:SetPoint("BOTTOMLEFT", 1, 0)
    selection:SetPoint("BOTTOMRIGHT", -1, 0)
    selection:SetHeight(2)
    selection:SetColorTexture(0.95, 0.73, 0.34, 1)
    panel.selection = selection
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 5, 0)
    icon:SetSize(20, 20)
    panel.icon = icon
    local name = label(panel, fonts.note, 30, 1, 1)
    name:SetHeight(stepRowHeight - 6)
    name:SetJustifyV("MIDDLE")
    name:SetWordWrap(true)
    name:SetMaxLines(2)
    panel.name = name
    local count = label(panel, fonts.note, 0, 0, 28)
    count:ClearAllPoints()
    count:SetPoint("RIGHT", -4, 0)
    count:SetJustifyH("RIGHT")
    panel.count = count
    local completedCheck = panel:CreateTexture(nil, "ARTWORK")
    completedCheck:SetPoint("RIGHT", -5, 0)
    completedCheck:SetSize(14, 14)
    completedCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    completedCheck:SetDesaturated(true)
    completedCheck:SetVertexColor(unpack(colors.complete))
    panel.completedCheck = completedCheck
    panel:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.optionName)
      if self.isSelected then GameTooltip:AddLine("Selected for this plan", 1, 0.82, 0.52, true) end
      if self.completed then
        if self.made then GameTooltip:AddLine("Made ×" .. self.made) end
      else
        GameTooltip:AddLine("Left-click to select this recipe and update the plan.", 1, 0.82, 0.52, true)
      end
      if self.optionName == "Mithril Spurs" then
        GameTooltip:AddLine("Requires Plans: Mithril Spurs. Craft counts are estimates.", 1, 1, 1, true)
      end
      GameTooltip:AddLine("Right-click to search your profession recipes.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    panel:SetScript("OnLeave", hideTooltip)
    panel:SetScript("OnHide", hideTooltip)
    panel:SetScript("OnClick", function(self, mouseButton)
      hideTooltip(self)
      if mouseButton == "RightButton" then
        searchRecipe(row.profession, self.optionName)
      elseif not self.completed then
        settings.recipeChoices[row.profession] = settings.recipeChoices[row.profession] or {}
        settings.recipeChoices[row.profession][self.choiceId] = self.optionName
        if self.optionName ~= self.selectedName then
          anchoredPlans[active] = nil
          showRoute(active, true)
        end
      end
    end)
    row.choicePanels[option] = panel
  end
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.recipe:GetText())
    if self.keep:IsShown() then GameTooltip:AddLine(self.keep:GetText()) end
    GameTooltip:AddLine(self.professionLearned and ("Click to search in " .. self.profession .. ".")
      or ("Learn " .. self.profession .. " to search its recipes."), 1, 0.82, 0.52, true)
    GameTooltip:Show()
  end)
  row:SetScript("OnClick", function(self)
    hideTooltip(self)
    searchRecipe(self.profession, self.recipe:GetText())
  end)
  row:SetScript("OnLeave", hideTooltip)
  row:SetScript("OnHide", hideTooltip)
  frame.steps[index] = row
end

local function showShoppingItems(group, items)
  group.heading:SetShown(#items > 0)
  for i, item in ipairs(items) do
    local row = group.rows[i]
    if not row then
      row = CreateFrame("Frame", nil, frame.itemContent)
      row.name = label(row, fonts.body, 0, 0, 1)
      row.name:SetWordWrap(true)
      row.count = label(row, fonts.caption, 0, 1, 1)
      row.count:ClearAllPoints()
      row.count:SetPoint("TOPRIGHT", 0, -1)
      row.count:SetJustifyH("RIGHT")
      row.count:SetWordWrap(false)
      row.loss = label(row, fonts.body, 0, 0, 54)
      row.loss:ClearAllPoints()
      row.loss:SetPoint("TOPRIGHT", row.count, "BOTTOMRIGHT", 0, 0)
      row.loss:SetJustifyH("RIGHT")
      paint(row.loss, colors.red)
      row.loss:Hide()
      row.lossAnimation = floatAndFade(row.loss, -18, 1.1, 0.35)
      row.check = row:CreateTexture(nil, "ARTWORK")
      row.check:SetPoint("TOPRIGHT", row.count, "TOPLEFT", 0, 0)
      row.check:SetSize(14, 14)
      row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      row.check:SetDesaturated(true)
      row.check:SetVertexColor(unpack(colors.complete))
      group.rows[i] = row
    end
    local ready = item.remaining == 0
    if row.itemKey ~= (item.id or item.name) then
      row.lossAnimation:Stop()
      row.loss:Hide()
      row.itemKey = item.id or item.name
    end
    row.name:SetText(item.name .. (item.keep and "  |cff91c497Keep|r" or ""))
    row.count:SetText(string.format("%d/%d", item.inBags, item.quantity))
    row.count:SetWidth(math.ceil(row.count:GetUnboundedStringWidth()) + 2)
    paint(row.count, ready and colors.complete or colors.text)
    row.check:SetShown(ready)
    row:Show()
  end
  for i = #items + 1, #group.rows do group.rows[i]:Hide() end
end

local function showMaterialLosses(losses, groups)
  for _, group in ipairs(groups or frame.shoppingGroups) do
    for _, row in ipairs(group.rows) do
      local quantity = row.itemKey and losses[row.itemKey]
      if quantity and quantity > 0 and row:IsShown() then
        row.lossAnimation:Stop()
        row.loss:SetText("−" .. quantity)
        row.loss:Show()
        row.lossAnimation:Play()
      end
    end
  end
end

local function showRecipeIcon(row, step, complete)
  local icon = step and addon.recipeIcons[step.item or step.recipe]
  if row.iconName ~= icon then
    row.iconName = icon
    if icon then
      row.icon:SetTexture("Interface\\Icons\\" .. icon)
      row.icon:SetTexelSnappingBias(0)
      row.icon:SetSnapToPixelGrid(false)
    end
  end
  row.icon:SetShown(icon ~= nil)
  if icon and row.iconDesaturated ~= complete then
    row.iconDesaturated = complete
    row.icon:SetDesaturated(complete)
  end
end

local function learnedProfessions()
  local learned = {}
  if not GetProfessions or not GetProfessionInfo then return learned end
  -- Match the stock Professions frame's order, including empty slots.
  local slots = { GetProfessions() }
  for slot = 1, professionSlotCount do
    local index = slots[slot]
    if index then
      local _, icon, rank, maximum, _, _, skillLine = GetProfessionInfo(index)
      if skillLine and type(rank) == "number" and rank > 0 then
        learned[skillLine] = { rank = rank, maximum = maximum, icon = icon, slot = slot }
      end
    end
  end
  return learned
end

local recipeSearchRequest = 0
searchRecipe = function(profession, recipe)
  recipeSearchRequest = recipeSearchRequest + 1
  local request = recipeSearchRequest
  local skillLine = professionSkillLines[profession]
  if not skillLine or not learnedProfessions()[skillLine] then
    print(plannerTitle .. ": Learn " .. profession .. " before searching its recipes.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    print(plannerTitle .. ": Wait until combat ends to open the profession window.")
    return
  end
  if not OpenProfessionUIToSkillLine or not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then
    print(plannerTitle .. ": The profession search is unavailable.")
    return
  end

  OpenProfessionUIToSkillLine(skillLine)
  local attempts = 0
  local function applySearch()
    if request ~= recipeSearchRequest then return end
    local professions = ProfessionsFrame
    if not professions or not professions:IsShown() then return end
    local page = professions.CraftingPage
    local info = page and page.professionInfo
    local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    local changing = C_TradeSkillUI.IsDataSourceChanging and C_TradeSkillUI.IsDataSourceChanging()
    -- SetProfessionInfo clears the old search when switching professions. Wait for that refresh.
    if not changing and baseInfo and baseInfo.professionID == skillLine
      and info and (info.parentProfessionID or info.professionID) == skillLine
      and page:IsShown() and page.RecipeList and page.RecipeList.SearchBox then
      page.RecipeList.SearchBox:SetText(recipe)
      page.RecipeList.SearchBox:ClearFocus()
      return
    end
    attempts = attempts + 1
    if attempts < 20 then
      C_Timer.After(0.1, applySearch)
    else
      print(plannerTitle .. ": The profession window is not ready. Click the recipe again.")
    end
  end
  C_Timer.After(0, applySearch)
end

local function trackCraftingCast(self)
  local guide = active and anchoredPlans[active]
  if not guide then return end
  local name, _, _, startTime, _, isTradeSkill, castID = UnitCastingInfo("player")
  if not isTradeSkill or (issecretvalue
    and (issecretvalue(name) or issecretvalue(startTime) or issecretvalue(castID))) then return end
  if not castID or not startTime or not name or (self.craftingCast and self.craftingCast.id == castID) then return end
  local skill = learnedProfessions()[professionSkillLines[guide.plan.name]]
  if not skill or skill.rank >= guide.plan.cap then return end

  local recipe = name:lower()
  local matched, prep
  for _, step in ipairs(guide.steps) do
    if skill.rank < step.to and step.recipe:lower() == recipe then
      if not step.prep and step.from <= skill.rank then
        matched = step
        break
      elseif step.prep and (guide.made[step] or 0) < step.crafts then
        prep = prep or step
      end
    end
  end
  local step = matched or prep
  if step then
    local before = {}
    local getCount = C_Item and C_Item.GetItemCount or GetItemCount
    if matched and getCount then
      for _, items in ipairs({ guide.plan.shoppingAuction, guide.plan.shoppingVendor }) do
        for _, item in ipairs(items) do
          local key = item.id or item.name
          before[key] = getCount(key, false) or 0
        end
      end
    end
    self.craftingCast = { id = castID, startTime = startTime, guide = guide, step = step,
      rank = skill.rank, before = before }
  end
end

local function updateScrollAreas()
  local stepWidth, stepHeight = frame.stepScroll:GetSize()
  local itemWidth, itemHeight = frame.itemScroll:GetSize()
  frame.stepContent:SetSize(stepWidth, math.max(stepHeight, (frame.stepCount or 0) * stepRowHeight))
  local recipeWidth = stepWidth - stepColumns.recipe - stepColumns.crafts
  for _, row in ipairs(frame.steps) do
    row.recipe:SetWidth(recipeWidth)
    row.keep:SetWidth(recipeWidth)
    local panelWidth = math.max(1, (stepWidth - stepColumns.icon - 8) / 2)
    for option, panel in ipairs(row.choicePanels) do
      panel:ClearAllPoints()
      panel:SetPoint("LEFT", row, "LEFT", stepColumns.icon + (option - 1) * panelWidth, 0)
      panel:SetWidth(panelWidth - 3)
      panel.name:SetWidth(math.max(1, panelWidth - (panel.reserveRight and 62 or 35)))
    end
  end
  frame.itemContent:SetWidth(itemWidth)
  local y = 0
  for _, group in ipairs(frame.shoppingGroups) do
    if group.heading:IsShown() then
      if y > 0 then y = y + 7 end
      group.heading:SetPoint("TOPLEFT", 0, -y)
      y = y + math.max(16, math.ceil(group.heading:GetStringHeight())) + 6
      for _, row in ipairs(group.rows) do
        if not row:IsShown() then break end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        local countWidth = row.count:GetWidth() + (row.check:IsShown() and 14 or 0)
        row.name:SetWidth(math.max(1, itemWidth - countWidth - 8))
        local height = math.max(18, math.ceil(row.name:GetStringHeight()))
        row:SetHeight(height)
        y = y + height + 6
      end
    end
  end
  frame.shoppingCountHeading:SetShown(y > 0)
  frame.itemContent:SetHeight(math.max(itemHeight, y))
  for _, scroll in ipairs({ frame.stepScroll, frame.itemScroll }) do
    scroll:UpdateScrollChildRect()
    local maximum = scroll:GetVerticalScrollRange()
    if scroll:GetVerticalScroll() > maximum then scroll:SetVerticalScroll(maximum) end
  end
end

local function guardDirections(profession, city)
  return string.format("Ask a guard in %s for the %s trainer.", city or "a capital city", profession)
end

local function nextTrainer(profession, maximum)
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local trainers = (maximum == 225 and artisanTrainers[profession])
    or (maximum == 150 and profession == "Enchanting" and expertEnchantingTrainers)
    or (maximum == 150 and profession == "Cooking" and expertCookingVendors)
    or (maximum == 150 and profession == "First Aid" and expertFirstAidVendors)
  if trainers then
    local trainer = trainers.name and trainers or trainers[faction]
    if trainer then return trainer, trainer.location end
    return nil, string.format("%s · %s / %s · %s", trainers.Horde.name, trainers.Horde.location,
      trainers.Alliance.name, trainers.Alliance.location)
  end
  local cities = maximum == 150 and expertTrainingCities[profession]
  local city = cities and (cities[faction] or (cities.Horde .. " or " .. cities.Alliance))
  return nil, guardDirections(profession, city)
end

local function nextTraining(profession, maximum)
  local ranks = specialRanks[profession] or nextRanks
  return ranks[maximum]
end

local function showNextTrainer(profession, rank, maximum)
  local training = nextTraining(profession, maximum)
  if training then
    local status = training.action or ("Train " .. training.name)
    if rank < training.skill then status = string.format("%s at skill %d", status, training.skill) end
    if training.level then status = string.format("%s (character level %d)", status, training.level) end
    frame.trainerStatus:SetText(status)
    local trainer, location = nextTrainer(profession, maximum)
    setTrainerMapLink(frame.trainerMapLink, trainer, trainer and (trainer.name .. " · " .. location) or location)
  else
    frame.trainerStatus:SetText("Highest rank in this guide learned")
    setTrainerMapLink(frame.trainerMapLink, nil, "")
  end
end

local function professionGuide(index, minimum, skill, skipWool, resetPlan)
  local rank, maximum = skill and skill.rank or 1, skill and skill.maximum
  local guide = anchoredPlans[index]
  if not guide or resetPlan or guide.requestedTarget ~= settings.target or guide.skipWool ~= skipWool
    or guide.learned ~= (skill ~= nil) or rank < guide.plan.from then
    local target = snapTarget(settings.target, minimum)
    local plan = addon.GetPlan(index, target, true, rank, nil, skipWool, maximum,
      settings.recipeChoices[routes[index].name])
    guide = {
      plan = plan, steps = addon.GetGuideSteps(index, plan), skipWool = skipWool, made = {},
      anchorSkill = rank,
      requestedTarget = settings.target, learned = skill ~= nil, maximum = maximum,
      craftingTime = formatDuration(addon.GetCraftingMilliseconds(plan)), bagSpace = addon.GetShoppingBagSpace(plan),
    }
    anchoredPlans[index] = guide
  elseif rank > guide.plan.from or (routes[index].name == "First Aid" and maximum ~= guide.maximum) then
    local oldSteps, oldMade = guide.steps, guide.made
    guide.maximum = maximum
    -- A skill-up craft can put a reagent for later steps into the bags.
    guide.plan = addon.GetPlan(index, guide.plan.cap, true, rank, guide.plan, skipWool, maximum,
      nil, guide.anchorSkill)
    guide.steps, guide.made = addon.GetGuideSteps(index, guide.plan), {}
    for _, step in ipairs(guide.steps) do
      for _, old in ipairs(oldSteps) do
        if old.recipe == step.recipe and old.from == step.from and old.to == step.to and old.prep == step.prep then
          guide.made[step] = oldMade[old]
          if frame.craftingCast and frame.craftingCast.guide == guide and frame.craftingCast.step == old then
            frame.craftingCast.step = step
          end
          break
        end
      end
    end
  end
  addon.RefreshShopping(guide.plan)
  guide.craftingTime = formatDuration(addon.GetCraftingMilliseconds(guide.plan))
  guide.bagSpace = addon.GetShoppingBagSpace(guide.plan)
  return guide
end

local function updateProfessionTabs(index)
  local learned = learnedProfessions()
  local orderedTabs = {}
  local primaryEnd = professionSlotCount + #frame.tabs
  for i, tab in ipairs(frame.tabs) do
    tab.skill = learned[professionSkillLines[routes[i].name]]
    local secondary = secondaryTabOrder[routes[i].name]
    local position = secondary and primaryEnd + secondary
      or (tab.skill and tab.skill.slot or professionSlotCount + i)
    orderedTabs[position] = tab
    tab.Background:SetVertexColor(unpack(tab.skill and colors.gold or colors.tabNeutral))
    tab:SetChecked(i == index)
    if not tab.skill and anchoredPlans[i] and anchoredPlans[i].learned then
      anchoredPlans[i] = nil
    end
  end

  local previousTab = frame
  for position = 1, primaryEnd + 2 do
    local tab = orderedTabs[position]
    if tab then
      local scale = tab.skill and 1 or 0.7
      if tab:GetScale() ~= scale then tab:SetScale(scale) end
      if tab.previousTab ~= previousTab then
        tab:ClearAllPoints()
        if previousTab == frame then
          tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
        else
          local gap = position == primaryEnd + 1 and 18 or 2
          tab:SetPoint("TOPLEFT", previousTab, "BOTTOMLEFT", 0, -gap)
        end
        tab.previousTab = previousTab
      end
      previousTab = tab
    end
  end
end

showRoute = function(index, keepScroll, resetPlan)
  keepScroll = keepScroll and active == index
  if debugSelected then
    debugSelected = nil
    frame.debugPage:Hide()
    frame.debugTab:SetChecked(false)
    clearCraftingFeedback(frame)
    frame.clearSkillFeedback()
  end
  if active ~= index or resetPlan then
    clearCraftingFeedback(frame)
    frame.clearSkillFeedback()
    frame.viewingCappedPlan = nil
  end
  active = index
  updateProfessionTabs(index)
  local skill = index and frame.tabs[index].skill
  local rank, maximum = skill and skill.rank or 1, skill and skill.maximum
  if resetPlan then
    settings.target = nextSkillTarget(rank)
    settings.skipWool = nil
  end
  local profession = index and routes[index].name
  local portraitIcon = profession and gameIconPath .. professionIcons[profession] or plannerIcon
  frame.PortraitContainer.portrait:SetTexture(portraitIcon)
  frame.TitleContainer.TitleText:SetText(profession and (plannerTitle .. " · " .. profession) or plannerTitle)
  frame.welcome:SetShown(index == nil)
  frame.targetControls:SetShown(index ~= nil)
  frame.applyEnchant:SetShown(profession == "Enchanting")
  local isTailoring = profession == "Tailoring"
  local skipWool = isTailoring and settings.skipWool ~= false
  frame.skipWool:SetChecked(skipWool)
  if not index then
    frame.skipWool:Hide()
    frame.potionRoute:Hide()
    frame.guideFooter:Hide()
    frame.planPage:Hide()
    frame.trainPage:Show()
    frame.cappedBanner:Hide()
    selectedPlan = nil
    frame.copyPanel:Hide()
    return
  end
  frame.skipWool:SetShown(isTailoring and rank < 150)
  local minimum = skill and math.min(rank, maxTarget) or targetStep
  local guide = professionGuide(index, minimum, skill, skipWool, resetPlan)
  local route = guide.plan
  local target = route.cap
  frame.syncTarget(target, minimum, skill and rank)
  local training = nextTraining(profession, maximum)
  local capped = training ~= nil and rank == maximum
  if not capped then frame.viewingCappedPlan = nil end
  local showTraining = capped and not frame.viewingCappedPlan
  local choices = settings.recipeChoices[profession]
  frame.potionRoute:SetChecked(choices ~= nil and choices.potions == true)
  frame.potionRoute:SetShown(profession == "First Aid" and not showTraining)
  frame.planPage:SetShown(not showTraining)
  frame.guideFooter:SetShown(not showTraining)
  frame.trainPage:SetShown(showTraining)
  frame.cappedBanner:SetShown(showTraining)
  frame.trainingButton:SetShown(capped and not showTraining)
  frame.craftingTime:SetText("Est. crafting  |cfff7ead1" .. guide.craftingTime .. "|r")
  trackCraftingCast(frame)
  if showTraining then
    selectedPlan = nil
    frame.copyPanel:Hide()
    local trainer, location = nextTrainer(profession, maximum)
    frame.cappedIcon:SetTexture(skill.icon or gameIconPath .. professionIcons[profession])
    frame.cappedTitle:SetText(training.action or string.format("Train %s %s", training.name, profession))
    frame.cappedWarning:SetText(training.instructions or string.format(
      "You cannot gain more %s skill until you\nlearn %s (%s) from your trainer", profession, profession, training.name))
    local requirements = string.format("Skill cap reached at %d", maximum)
    if training.level then
      requirements = string.format("%s · Requires character level %d", requirements, training.level)
    end
    frame.cappedRequirements:SetText(requirements)
    setTrainerMapLink(frame.cappedMapLink, trainer, trainer and trainer.name or "")
    frame.cappedTrainer:SetShown(trainer ~= nil)
    local locationTop = trainer and 100 or 77
    frame.cappedLocation:SetPoint("TOPLEFT", 16, -locationTop)
    frame.cappedLocation:SetText(location)
    frame.cappedBanner:SetHeight(locationTop + math.max(17, frame.cappedLocation:GetStringHeight()) + 16)
    return
  end
  selectedPlan = route
  if frame.copyPanel and frame.copyPanel:IsShown() then
    if not keepScroll or (frame.copyingShoppingList and copyText ~= addon.ImportString(route)) then
      frame.copyPanel:Hide()
    end
  end
  if capped then
    showNextTrainer(profession, rank, maximum)
  elseif rank >= target then
    frame.trainerStatus:SetText(string.format("Target reached at skill %d", rank))
    setTrainerMapLink(frame.trainerMapLink, nil, "")
  elseif skill then
    showNextTrainer(profession, rank, maximum)
  else
    frame.trainerStatus:SetText("Learn " .. profession)
    setTrainerMapLink(frame.trainerMapLink, nil, guardDirections(profession))
  end
  local cost = route.cost
  local source = ""
  if cost.gross == nil and #route.shoppingAuction > 0 then
    if cost.available then
      source = string.format("Auctionator prices missing for %d item%s", #cost.missing, #cost.missing == 1 and "" or "s")
    else
      source = "Auctionator required for prices"
    end
  end
  frame.priceStatus:SetText(source)
  showMoney(frame.costs[1], cost.gross and -cost.gross)
  showMoney(frame.costs[2], cost.toBuy, false, true)
  showMoney(frame.costs[3], cost.owned, false, true)
  showMoney(frame.costs[4], route.from < route.cap and route.revenue or nil)
  showMoney(frame.costs[5], cost.net and -cost.net, true)
  showShoppingBagSpace(guide.bagSpace)
  frame.importButton:SetEnabled(#route.auction > 0)
  local latestCompletedRow
  while #frame.steps < #guide.steps do addStepRow() end
  for i, row in ipairs(frame.steps) do
    local step = guide.steps[i]
    local made = step and guide.made[step]
    local complete = step and (rank >= step.to or (step.prep and made and made >= step.crafts))
    local current = step and not complete and rank >= step.from and rank < step.to
    row:SetShown(step ~= nil)
    showRecipeIcon(row, step, complete)
    row.marker:SetShown(not not current)
    row.check:SetShown(not not complete)
    row.made:SetShown(not not (complete and made))
    if step and rank >= step.to then latestCompletedRow = i end
    if step then
      row.profession, row.professionLearned = profession, skill ~= nil
      local hasChoice = not step.prep and step.choice ~= nil
      row.icon:SetShown(not hasChoice and row.iconName ~= nil)
      row.recipe:SetShown(not hasChoice)
      row.crafts:SetShown(not hasChoice)
      row.check:SetShown(not hasChoice and not not complete)
      row.made:SetShown(not hasChoice and not not (complete and made))
      for option, panel in ipairs(row.choicePanels) do
        panel:SetShown(hasChoice)
        if hasChoice then
          local name = step.choice.options[option]
          local selected = name == step.recipe
          panel.optionName, panel.selectedName, panel.choiceId = name, step.recipe, step.choice.id
          panel.completed, panel.isSelected = complete, selected
          panel.made = selected and made
          panel.fill:SetColorTexture(selected and 0.38 or 0.16, selected and 0.27 or 0.12,
            selected and 0.14 or 0.08, selected and 0.55 or 0.40)
          panel.selection:SetShown(selected)
          panel.selection:SetColorTexture(complete and 0.57 or 0.95, complete and 0.77 or 0.73,
            complete and 0.59 or 0.34, 1)
          local icon = addon.recipeIcons[name] or (name == "Mithril Spurs" and "ability_rogue_sprint")
          panel.icon:SetTexture(icon and ("Interface\\Icons\\" .. icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
          panel.icon:SetDesaturated(not not complete)
          panel.name:SetText(name)
          local showCount = selected and not complete and step.to > route.from
          panel.reserveRight = showCount or (selected and complete)
          panel.count:SetShown(showCount)
          panel.completedCheck:SetShown(selected and complete)
          if showCount then panel.count:SetText("×" .. step.crafts) end
          paint(panel.name, complete and colors.recipeComplete or (selected and colors.recipeCurrent or colors.text))
        end
      end
      if current then
        row.background:SetColorTexture(0.78, 0.52, 0.20, 0.16)
      else
        row.background:SetColorTexture(0.94, 0.76, 0.54, i % 2 == 1 and 0.035 or 0)
      end
      local stepColor = complete and colors.complete or (current and colors.current)
        or colors.text
      local recipeColor = complete and colors.recipeComplete or (current and colors.recipeCurrent)
        or colors.text
      paint(row.recipe, recipeColor)
      paint(row.skill, stepColor)
      paint(row.crafts, stepColor)
      row.skill:SetText(step.prep and "Prep" or string.format("%d–%d", step.from, step.to))
      row.recipe:SetText(step.recipe)
      local showMade = complete and made
      row.crafts:SetPoint("TOPRIGHT", -6, showMade and -3 or 0)
      row.crafts:SetHeight(showMade and 17 or stepRowHeight)
      row.crafts:SetText(step.to <= route.from and "" or ("×" .. step.crafts))
      if showMade then row.made:SetText("Made ×" .. made) end
      row.keep:SetText(step.keep and ("Keep ×" .. step.keep) or "")
      row.keep:SetShown(not hasChoice and step.keep ~= nil)
      row.recipe:SetPoint("TOPLEFT", stepColumns.recipe, step.keep and -3 or 0)
      row.recipe:SetHeight(step.keep and 18 or stepRowHeight)
      row.recipe:SetMaxLines(step.keep and 1 or 2)
    end
  end

  showShoppingItems(frame.shoppingGroups[1], route.shoppingAuction)
  showShoppingItems(frame.shoppingGroups[2], route.shoppingVendor)
  frame.emptyShopping:SetShown(#route.shoppingAuction == 0 and #route.shoppingVendor == 0)
  frame.emptySteps:SetShown(#guide.steps == 0)
  frame.stepCount = #guide.steps
  frame.layoutShopping()
  if not keepScroll or latestCompletedRow ~= frame.latestCompletedRow then
    local scroll = frame.stepScroll
    local offset = latestCompletedRow and (latestCompletedRow - 1) * stepRowHeight or 0
    stopWheelScroll(scroll)
    scroll:SetVerticalScroll(math.min(offset, scroll:GetVerticalScrollRange()))
  end
  frame.latestCompletedRow = latestCompletedRow
  if not keepScroll then
    stopWheelScroll(frame.itemScroll)
    frame.itemScroll:SetVerticalScroll(0)
  end
end

local function canUseDebug()
  return addon.IsAnimationDebugAccount and addon.IsAnimationDebugAccount()
end

local function refreshDebugTab(self)
  local allowed = canUseDebug()
  if not allowed and debugSelected then showRoute(active, true) end
  self.debugTab:SetShown(not not allowed)
end

local function showDebugPage()
  if debugSelected or not canUseDebug() then return end
  if not frame.debugPage then
    local page = insetPanel(frame, "TOPLEFT", 0, 0)
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", frame.targetControls, "BOTTOMLEFT", 0, -10)
    page:SetPoint("TOPRIGHT", frame.targetControls, "BOTTOMRIGHT", 0, -10)
    page:SetHeight(290)
    local skill = button(page, "Skill up (+1)", 14, 12, 174)
    skill:SetScript("OnClick", function() frame.previewSkillFeedback(true, false) end)
    local milestone = button(page, "Slider slide and splash", 196, 12, 174)
    milestone:SetScript("OnClick", function() frame.previewSkillFeedback(false, true) end)
    local both = button(page, "Both skill-up effects", 14, 44, 174)
    both:SetScript("OnClick", function() frame.previewSkillFeedback(true, true) end)
    local craft = button(page, "Crafting time (-23s)", 196, 44, 174)
    craft:SetScript("OnClick", function() showCraftingFeedback(frame, 23000) end)
    local balto = button(page, "Play Balto entrance", 14, 76, 174)
    balto:SetScript("OnClick", function() addon.PlayBaltoEntrance(frame) end)
    local heading = label(page, fonts.heading, 14, 148, 350)
    heading:SetText("Sample materials  ·  Have / Need")
    local sampleGroup = { rows = {} }
    for i, name in ipairs({ "Cloth", "Thread" }) do
      local row = CreateFrame("Frame", nil, page)
      row:SetPoint("TOPLEFT", 14, -172 - (i - 1) * 32)
      row:SetSize(350, 28)
      row.itemKey = name
      row.name = label(row, fonts.body, 0, 0, 180)
      row.name:SetText(name)
      row.count = label(row, fonts.caption, 190, 0, 80)
      row.count:SetText("20 / 20")
      row.loss = label(row, fonts.body, 285, 0, 54)
      paint(row.loss, colors.red)
      row.loss:Hide()
      row.lossAnimation = floatAndFade(row.loss, -18, 1.1, 0.35)
      sampleGroup.rows[i] = row
    end
    local function previewCraft(skillUp, milestone)
      for i, row in ipairs(sampleGroup.rows) do
        row.lossAnimation:Stop()
        row.loss:Hide()
        local used = i == 1 and 4 or 1
        row.count:SetText(string.format("%d / %d", 20 - used, skillUp and 20 - used or 20))
      end
      showCraftingFeedback(frame, 23000)
      if skillUp then
        frame.previewSkillFeedback(true, milestone)
      else
        frame.clearSkillFeedback()
        frame.syncTarget(100, 74, 74)
        showMaterialLosses({ Cloth = 4, Thread = 1 }, { sampleGroup })
      end
    end
    local noSkill = button(page, "Craft: no skill up", 196, 76, 174)
    noSkill:SetScript("OnClick", function() previewCraft(false, false) end)
    local withSkill = button(page, "Craft: skill up", 14, 108, 174)
    withSkill:SetScript("OnClick", function() previewCraft(true, false) end)
    local milestoneCraft = button(page, "Craft: milestone", 196, 108, 174)
    milestoneCraft:SetScript("OnClick", function() previewCraft(true, true) end)
    page.previewButtons = { noSkill, withSkill, milestoneCraft }
    page.sampleGroup = sampleGroup
    frame.debugPage = page
  end

  debugSelected = true
  for _, tab in ipairs(frame.tabs) do tab:SetChecked(false) end
  frame.debugTab:SetChecked(true)
  frame.PortraitContainer.portrait:SetTexture(gameIconPath .. "INV_Misc_Gear_01")
  frame.TitleContainer.TitleText:SetText(plannerTitle .. " · Animation Debug")
  frame.welcome:Hide()
  frame.planPage:Hide()
  frame.trainPage:Hide()
  frame.copyPanel:Hide()
  frame.skipWool:Hide()
  frame.potionRoute:Hide()
  frame.applyEnchant:Hide()
  clearCraftingFeedback(frame)
  frame.craftingTime:SetText("Est. crafting  |cfff7ead11m 00s|r")
  frame.clearSkillFeedback()
  frame.targetControls:Show()
  frame.syncTarget(100, 74, 74)
  frame.debugPage:Show()
end

local function selectProfession(index, resetPlan)
  frame.viewingCappedPlan = nil
  showRoute(index, nil, resetPlan)
end

local function showCopy(value, heading, instructions)
  copyText = value
  frame.copyingShoppingList = instructions ~= nil
  frame.copyHeading:SetText(heading)
  frame.copyInstructions:SetText(instructions or "")
  frame.copyInstructions:SetShown(instructions ~= nil)
  frame.copyPanel:SetHeight(instructions and 132 or 110)
  frame.copyPanel:Show()
  frame.copyBox:SetText(copyText)
  frame.copyBox:SetFocus()
  frame.copyBox:HighlightText()
end

local function plannerScreenSize()
  local scale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
  return UIParent:GetWidth() * scale, UIParent:GetHeight() * scale
end

local function setPlannerSize(professions, width, height)
  local stockWidth, stockHeight
  if professions and professions.ProfessionsOverviewTab then
    frame:SetScale(professions:GetEffectiveScale() / UIParent:GetEffectiveScale())
    stockWidth, stockHeight = professions:GetSize()
  end
  local minWidth, minHeight = 640, 560
  local screenWidth, screenHeight = plannerScreenSize()
  local tabOverhang = SidePanelTabButtonMixin.CalculateTabSizeBasedOnTabArt()
  local maxWidth = math.max(minWidth, screenWidth - 24 - tabOverhang)
  local maxHeight = math.max(minHeight, screenHeight - 24)
  frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  frame:SetSize(math.min(maxWidth, math.max(minWidth, width or stockWidth or defaultWindowWidth)),
    math.min(maxHeight, math.max(minHeight, height or stockHeight or defaultWindowHeight)))
end

local function createPlanner()
  local tabOverhang = SidePanelTabButtonMixin.CalculateTabSizeBasedOnTabArt()
  frame = CreateFrame("Frame", "ForeverProfessionPlannerFrame", UIParent, "PortraitFrameTemplate")
  frame:SetPoint("CENTER")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetClampRectInsets(-13, tabOverhang, 16, -3)
  frame:SetMovable(true)
  frame:SetResizable(true)
  setPlannerSize(ProfessionsFrame, tonumber(settings.windowWidth), tonumber(settings.windowHeight))
  frame:EnableMouse(true)
  frame.Bg:SetColorTexture(unpack(colors.window))
  table.insert(UISpecialFrames, frame:GetName())

  local header = frame.TitleContainer
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() frame:StartMoving() end)
  header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  local title = header.TitleText
  title:SetFontObject(fonts.title)
  title:ClearAllPoints()
  title:SetPoint("CENTER", frame, "TOP", 0, -12)
  title:SetJustifyH("CENTER")

  frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
  frame.tabs = {}
  for i, route in ipairs(routes) do
    local index = i
    local tab = createSideTab(frame, gameIconPath .. professionIcons[route.name], function()
      selectProfession(index, true)
    end)
    tab.Background:SetDesaturated(true)
    tab:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(route.name)
      if self.skill then
        GameTooltip:AddLine("Skill " .. self.skill.rank)
      else
        GameTooltip:AddLine("Preview from skill 1")
      end
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", hideTooltip)
    frame.tabs[i] = tab
  end
  local debugTab = createSideTab(frame, gameIconPath .. "INV_Misc_Gear_01", function()
    if debugSelected then showRoute(active, true) else showDebugPage() end
  end)
  debugTab:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 8)
  debugTab.Background:SetDesaturated(true)
  debugTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Animation Debug")
    GameTooltip:Show()
  end)
  debugTab:SetScript("OnLeave", hideTooltip)
  debugTab:Hide()
  frame.debugTab = debugTab
  frame:HookScript("OnShow", refreshDebugTab)

  local contentTop = 56
  local targetControlsHeight = 68
  local trainPage = CreateFrame("Frame", nil, frame)
  trainPage:SetPoint("TOPLEFT", 18, -contentTop)
  trainPage:SetPoint("BOTTOMRIGHT", -18, 18)
  frame.trainPage = trainPage

  local welcome = insetPanel(trainPage, "CENTER", 0, 0)
  welcome:SetSize(476, 160)
  frame.welcome = welcome
  local welcomeIcon = welcome:CreateTexture(nil, "ARTWORK")
  welcomeIcon:SetPoint("TOP", 0, -20)
  welcomeIcon:SetSize(36, 36)
  welcomeIcon:SetTexture(plannerIcon)
  local welcomeTitle = label(welcome, fonts.title, 28, 68, 420)
  welcomeTitle:SetJustifyH("CENTER")
  welcomeTitle:SetText("Choose a profession")
  local welcomeText = label(welcome, fonts.body, 28, 98, 420)
  welcomeText:SetJustifyH("CENTER")
  welcomeText:SetSpacing(4)
  welcomeText:SetText("Select a tab to open its guide. Gold borders mark learned professions.")

  local cappedBanner = insetPanel(trainPage, "TOP", 0, targetControlsHeight + 14)
  cappedBanner:SetWidth(604)
  frame.cappedBanner = cappedBanner

  frame.cappedIcon = cappedBanner:CreateTexture(nil, "ARTWORK")
  frame.cappedIcon:SetPoint("TOPLEFT", 16, -13)
  frame.cappedIcon:SetSize(40, 40)

  frame.cappedTitle = label(cappedBanner, fonts.title, 68, 12, 520)
  frame.cappedRequirements = label(cappedBanner, fonts.caption, 68, 36, 520)
  surface(cappedBanner, 16, 63, 572, 1, 0.38, 0.28, 0.15)
  frame.cappedTrainer = label(cappedBanner, fonts.heading, 16, 77, 572)
  frame.cappedMapLink = createTrainerMapLink(cappedBanner, frame.cappedTrainer, colors.gold)
  frame.cappedLocation = label(cappedBanner, fonts.body, 16, 100, 572)
  frame.cappedLocation:SetWordWrap(true)

  local cappedWarning = cappedBanner:CreateFontString(nil, "OVERLAY")
  cappedWarning:SetFontObject(fonts.trainingWarning)
  cappedWarning:SetPoint("TOP", cappedBanner, "BOTTOM", 0, -26)
  cappedWarning:SetWidth(588)
  cappedWarning:SetJustifyH("CENTER")
  cappedWarning:SetSpacing(4)
  frame.cappedWarning = cappedWarning

  local viewPlan = button(trainPage, "View plan", 0, 0, 144)
  viewPlan:ClearAllPoints()
  viewPlan:SetPoint("TOP", cappedWarning, "BOTTOM", 0, -20)
  viewPlan:SetScript("OnClick", function()
    frame.viewingCappedPlan = true
    showRoute(active)
  end)

  local body = CreateFrame("Frame", nil, frame)
  body:SetAllPoints()
  frame.planPage = body
  local targetControls = insetPanel(frame, "TOPLEFT", 18, contentTop)
  targetControls:SetPoint("TOPRIGHT", -18, -contentTop)
  targetControls:SetHeight(targetControlsHeight)
  frame.targetControls = targetControls
  label(targetControls, fonts.caption, 13, 8, 110):SetText("Skill target")

  frame.targetValue = targetControls:CreateFontString(nil, "OVERLAY")
  frame.targetValue:SetFontObject(fonts.heading)
  frame.targetValue:SetPoint("TOP", 0, -6)
  paint(frame.targetValue, colors.text)

  local skillGain = targetControls:CreateFontString(nil, "OVERLAY")
  skillGain:SetFontObject(fonts.body)
  skillGain:SetPoint("BOTTOMLEFT", frame.targetValue, "TOPLEFT", 0, -2)
  skillGain:Hide()
  local skillGainAnimation = floatAndFade(skillGain, 18, 0.85, 0.20)

  frame.craftingTime = targetControls:CreateFontString(nil, "OVERLAY")
  frame.craftingTime:SetFontObject(fonts.caption)
  frame.craftingTime:SetPoint("TOPRIGHT", -13, -8)

  frame.craftingFeedback = targetControls:CreateFontString(nil, "OVERLAY")
  frame.craftingFeedback:SetFontObject(fonts.body)
  frame.craftingFeedback:SetPoint("BOTTOMRIGHT", frame.craftingTime, "TOPRIGHT", 0, 2)
  paint(frame.craftingFeedback, colors.green)
  frame.craftingFeedback:Hide()

  frame.craftingFeedbackAnimation = floatAndFade(frame.craftingFeedback, 24, 1.2, 0.35)
  frame:HookScript("OnHide", clearCraftingFeedback)

  local targetBar = CreateFrame("Frame", nil, targetControls)
  targetBar:SetPoint("TOPLEFT", 13, -27)
  targetBar:SetPoint("TOPRIGHT", -13, -27)
  targetBar:SetHeight(22)

  local targetSlider = CreateFrame("Slider", nil, targetBar)
  targetSlider:SetPoint("TOPRIGHT")
  targetSlider:SetHeight(22)
  targetSlider:SetOrientation("HORIZONTAL")
  targetSlider:EnableMouse(true)
  targetSlider:SetValueStep(1)
  targetSlider:SetObeyStepOnDrag(true)

  local track = targetBar:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  local trackHeight = 14
  track:SetHeight(trackHeight)
  track:SetColorTexture(0.51, 0.36, 0.19, 1)

  local trough = targetBar:CreateTexture(nil, "BACKGROUND", nil, 1)
  trough:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
  trough:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 1)
  trough:SetColorTexture(0.075, 0.052, 0.033, 1)

  local thumbWidth = 10
  local thumb = targetSlider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(thumbWidth, 18)
  thumb:SetColorTexture(0.96, 0.75, 0.37, 1)
  tintGradient(thumb, { 0.64, 0.41, 0.16, 1 }, { 1, 0.86, 0.52, 1 })
  targetSlider:SetThumbTexture(thumb)

  local completed = targetBar:CreateTexture(nil, "ARTWORK")
  completed:SetPoint("TOPLEFT", trough)
  completed:SetPoint("BOTTOMLEFT", trough)
  completed:SetColorTexture(0.36, 0.62, 0.40, 1)
  tintGradient(completed, { 0.22, 0.41, 0.24, 1 }, { 0.57, 0.77, 0.59, 1 })

  local fill = targetBar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("BOTTOMRIGHT", thumb, "CENTER", 0, 1 - trackHeight / 2)
  fill:SetColorTexture(0.73, 0.47, 0.18, 1)
  tintGradient(fill, { 0.49, 0.25, 0.07, 1 }, { 0.88, 0.62, 0.25, 1 })

  local sparkLayer = CreateFrame("Frame", nil, targetBar)
  sparkLayer:SetAllPoints()
  sparkLayer:SetFrameLevel(targetSlider:GetFrameLevel() + 1)
  local spark = sparkLayer:CreateTexture(nil, "OVERLAY")
  spark:SetAtlas("ui-castingbar-pip")
  spark:SetBlendMode("ADD")
  spark:SetSize(9, 22)
  spark:SetPoint("CENTER", completed, "RIGHT")

  local splash = sparkLayer:CreateTexture(nil, "OVERLAY", nil, 1)
  splash:SetAtlas("ui-castingbar-pip")
  splash:SetBlendMode("ADD")
  splash:SetVertexColor(0.66, 1, 0.78)
  splash:SetPoint("CENTER", spark, "CENTER")
  splash:Hide()

  local ticks = {}
  for _, milestone in ipairs(skillMilestones) do
    local tick = CreateFrame("Button", nil, targetBar)
    tick:SetSize(34, 18)
    tick:SetFrameLevel(targetSlider:GetFrameLevel() + 1)

    local mark = tick:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("CENTER")
    mark:SetSize(17, 14)
    mark:SetAtlas("ui-hud-actionbar-pageuparrow-up")

    local highlight = tick:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("ui-hud-actionbar-pageuparrow-mouseover")
    tick:SetHighlightTexture(highlight)
    highlight:SetAllPoints(mark)

    tick:SetScript("OnClick", function() targetSlider:SetValue(milestone) end)
    tick:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Plan to skill " .. milestone)
      GameTooltip:Show()
    end)
    tick:SetScript("OnLeave", hideTooltip)
    tick:SetScript("OnHide", hideTooltip)
    ticks[milestone] = tick
  end

  local targetMinimum, trackMinimum = targetStep, targetStep
  local visualMinimum, displayedSkill = targetStep, nil
  local slideFrom, slideElapsed
  local slideDuration, splashDuration = 0.22, 0.32
  local pixelsPerSkill
  local updatingTarget

  local function layoutEarnedSkill()
    local edge = thumbWidth / 2 + (visualMinimum - trackMinimum) * pixelsPerSkill
    -- The last point of skill fills the remaining half-thumb of track.
    local endPadding = (thumbWidth / 2 - 1) * math.max(0, visualMinimum - (maxTarget - 1))
    completed:SetWidth(math.max(0, math.min(edge - 1 + endPadding, targetBar:GetWidth() - 2)))
  end

  local function stopSkillSlide()
    slideElapsed = nil
    sparkLayer:SetScript("OnUpdate", nil)
    splash:Hide()
  end

  local function animateSkillSlide(_, elapsed)
    slideElapsed = slideElapsed + elapsed
    local remaining = 1 - math.min(1, slideElapsed / slideDuration)
    visualMinimum = targetMinimum - (targetMinimum - slideFrom) * remaining ^ 2
    layoutEarnedSkill()

    local splashProgress = (slideElapsed - slideDuration) / splashDuration
    if splashProgress >= 1 then
      stopSkillSlide()
    elseif splashProgress >= 0 then
      splash:SetSize(14 + 28 * splashProgress, 20 + 8 * splashProgress)
      splash:SetAlpha(0.85 * (1 - splashProgress) ^ 2)
      splash:Show()
    end
  end

  local function playSkillGain(amount)
    local color = ChatTypeInfo.SKILL
    skillGainAnimation:Stop()
    skillGain:SetTextColor(color.r, color.g, color.b)
    skillGain:SetFormattedText("+%d", amount)
    skillGain:Show()
    skillGainAnimation:Play()
  end

  local function startSkillSlide()
    slideFrom, slideElapsed = visualMinimum, 0
    splash:Hide()
    sparkLayer:SetScript("OnUpdate", animateSkillSlide)
  end

  frame.clearSkillFeedback = function()
    displayedSkill = nil
    skillGainAnimation:Stop()
    skillGain:Hide()
    stopSkillSlide()
  end
  targetControls:HookScript("OnHide", frame.clearSkillFeedback)

  local function layoutTargetBar(bar)
    local width = bar:GetWidth()
    pixelsPerSkill = math.max(0, width - thumbWidth) / (maxTarget - trackMinimum)
    -- The slider's interactive range follows the earned skill immediately.
    local offset = (targetMinimum - trackMinimum) * pixelsPerSkill
    targetSlider:SetPoint("TOPLEFT", offset, 0)
    layoutEarnedSkill()
    for milestone, tick in pairs(ticks) do
      local x = thumbWidth / 2 + (milestone - trackMinimum) * pixelsPerSkill
      tick:SetPoint("TOP", bar, "BOTTOMLEFT", x, 0)
    end
  end
  targetBar:SetScript("OnSizeChanged", layoutTargetBar)

  frame.syncTarget = function(target, minimum, currentSkill)
    updatingTarget = true
    if not debugSelected and displayedSkill and currentSkill and currentSkill > displayedSkill then
      playSkillGain(currentSkill - displayedSkill)
      if minimum > targetMinimum and math.floor(minimum / targetStep) > math.floor(targetMinimum / targetStep) then
        startSkillSlide()
      end
    elseif displayedSkill and (not currentSkill or currentSkill < displayedSkill) then
      frame.clearSkillFeedback()
    end
    displayedSkill = currentSkill

    if targetMinimum ~= minimum and minimum < maxTarget then
      targetSlider:SetMinMaxValues(minimum, maxTarget)
    end
    targetMinimum = minimum
    if not slideElapsed then visualMinimum = minimum end
    local hasSkill = currentSkill ~= nil
    trackMinimum = hasSkill and 0 or targetStep
    layoutTargetBar(targetBar)
    targetSlider:SetShown(minimum < maxTarget)
    targetSlider:EnableMouse(not debugSelected)
    targetSlider:SetValue(target)
    completed:SetShown(hasSkill)
    spark:SetShown(hasSkill)
    fill:SetPoint("TOPLEFT", hasSkill and completed or trough, hasSkill and "TOPRIGHT" or "TOPLEFT")
    fill:SetShown(target > minimum)
    local skillColor = hasSkill and "91c497" or "b7a68b"
    frame.targetValue:SetText(string.format("|cff%s%d|r / |cfff5c173%d|r", skillColor, currentSkill or 0, target))
    for milestone, tick in pairs(ticks) do
      local enabled = not debugSelected and milestone >= minimum
      tick:SetEnabled(enabled)
      tick:SetAlpha(enabled and 1 or 0.35)
    end
    updatingTarget = false
  end

  frame.previewSkillFeedback = function(showGain, showMilestone)
    local rank = showMilestone and 75 or 73
    frame.clearSkillFeedback()
    frame.syncTarget(100, rank - 1, rank - 1)
    if showMilestone then startSkillSlide() end
    frame.syncTarget(100, rank, rank)
    if showGain then playSkillGain(1) end
  end

  targetSlider:SetMinMaxValues(targetMinimum, maxTarget)
  targetSlider:SetScript("OnValueChanged", function(_, value)
    if updatingTarget or debugSelected then return end
    local target = snapTarget(value, targetMinimum)
    if target ~= snapTarget(settings.target, targetMinimum) then
      settings.target = target
      showRoute(active)
    elseif value ~= target then
      updatingTarget = true
      targetSlider:SetValue(target)
      updatingTarget = false
    end
  end)
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:RegisterEvent("CHAT_MSG_SKILL")
  frame:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
  frame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
  frame:RegisterEvent("NEW_RECIPE_LEARNED")
  frame:RegisterEvent("BN_CONNECTED")
  frame:RegisterEvent("BN_INFO_CHANGED")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  local refreshPending
  frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_START" then
      trackCraftingCast(self)
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      local cast = self.craftingCast
      local _, castID = ...
      if not cast or cast.finished or (issecretvalue and issecretvalue(castID)) or castID ~= cast.id then return end
      cast.finished = true
      local made = cast.guide.made
      made[cast.step] = (made[cast.step] or 0) + 1
      local elapsed = GetTime() * 1000 - cast.startTime
      if elapsed > 0 and self:IsShown() and not debugSelected and anchoredPlans[active] == cast.guide then
        showCraftingFeedback(self, elapsed)
      end
      if not cast.step.prep and next(cast.before) then
        C_Timer.After(0.5, function()
          if not self:IsShown() or debugSelected or anchoredPlans[active] ~= cast.guide then return end
          local current = learnedProfessions()[professionSkillLines[cast.guide.plan.name]]
          if not current or current.rank ~= cast.rank then return end
          local getCount = C_Item and C_Item.GetItemCount or GetItemCount
          if not getCount then return end
          local losses = {}
          for key, count in pairs(cast.before) do
            local difference = count - (getCount(key, false) or 0)
            if difference > 0 then losses[key] = difference end
          end
          showRoute(active, true)
          showMaterialLosses(losses)
        end)
      end
    end
    if not self:IsShown() then return end
    if event == "BN_CONNECTED" or event == "BN_INFO_CHANGED" then
      refreshDebugTab(self)
      return
    end
    if debugSelected then return end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
      refreshPending = nil
      if self:IsShown() and not debugSelected then showRoute(active, true) end
    end)
  end)

  local trainerTop = contentTop + targetControlsHeight + 10
  frame.trainerStatus = label(body, fonts.heading, 30, trainerTop, 1)
  frame.trainerStatus:SetPoint("TOPRIGHT", -168, -trainerTop)
  frame.trainingButton = button(body, "Training", 0, 0, 128)
  frame.trainingButton:ClearAllPoints()
  frame.trainingButton:SetPoint("TOPRIGHT", -30, -trainerTop)
  frame.trainingButton:SetScript("OnClick", function() selectProfession(active) end)
  frame.trainerLocation = label(body, fonts.caption, 30, trainerTop + 20, 1)
  frame.trainerLocation:SetWordWrap(true)
  frame.trainerMapLink = createTrainerMapLink(body, frame.trainerLocation, colors.muted)
  local panelTop = trainerTop + 49
  local stepPanel = insetPanel(body, "TOPLEFT", 18, panelTop)
  local itemPanel = insetPanel(body, "TOPRIGHT", -18, panelTop)
  local stepHeaderTop = 12
  local stepScrollTop = 37
  local stepInset = 9
  local columnRule = surface(stepPanel, stepInset, 33, 1, 1, 0.38, 0.28, 0.15)
  columnRule:SetPoint("TOPRIGHT", -12, -33)
  label(stepPanel, fonts.heading, stepInset + stepColumns.skill, stepHeaderTop, 66):SetText("Skill")
  label(stepPanel, fonts.heading, stepInset + stepColumns.icon, stepHeaderTop, 180):SetText("Recipe")
  frame.emptySteps = label(stepPanel, fonts.body, stepInset + stepColumns.skill, stepScrollTop + 8, 295)
  frame.emptySteps:SetText("No recipes for this skill range.")
  frame.stepScroll, frame.stepContent = scrollArea(stepPanel, stepInset, stepScrollTop, 1, 1)
  local craftsHeading = label(stepPanel, fonts.heading, 0, stepHeaderTop, 90)
  craftsHeading:ClearAllPoints()
  craftsHeading:SetPoint("TOPRIGHT", frame.stepScroll, "TOPRIGHT", -6, stepScrollTop - stepHeaderTop)
  craftsHeading:SetJustifyH("RIGHT")
  craftsHeading:SetText("Crafts")
  frame.steps = {}

  label(itemPanel, fonts.heading, 12, 12, 124):SetText("Shopping List")
  local updatePlan = button(itemPanel, "Update plan", 0, 0, 100)
  updatePlan:ClearAllPoints()
  updatePlan:SetPoint("TOPRIGHT", -12, -9)
  updatePlan:SetScript("OnClick", function()
    if active then
      anchoredPlans[active] = nil
      showRoute(active, true)
    end
  end)
  updatePlan:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Recalculate using your current skill, bags, and Auctionator prices.")
    GameTooltip:Show()
  end)
  updatePlan:SetScript("OnLeave", hideTooltip)
  updatePlan:SetScript("OnHide", hideTooltip)
  frame.itemScroll, frame.itemContent = scrollArea(itemPanel, 12, 1, 1, 1)
  frame.emptyShopping = label(frame.itemContent, fonts.caption, 0, 0, 180)
  frame.emptyShopping:SetText("No materials needed")
  frame.emptyShopping:Hide()
  frame.shoppingCountHeading = label(frame.itemContent, fonts.caption, 0, 1, 1)
  frame.shoppingCountHeading:ClearAllPoints()
  frame.shoppingCountHeading:SetPoint("TOPRIGHT", 0, -1)
  frame.shoppingCountHeading:SetJustifyH("RIGHT")
  frame.shoppingCountHeading:SetWordWrap(false)
  frame.shoppingCountHeading:SetText("Have / Need")
  frame.shoppingCountHeading:SetWidth(math.ceil(frame.shoppingCountHeading:GetUnboundedStringWidth()) + 2)

  frame.shoppingGroups = {}
  for i, caption in ipairs({ "Auction House", "Vendor supplies" }) do
    local heading = label(frame.itemContent, fonts.body, 0, 0, 130)
    paint(heading, colors.current)
    heading:SetText(caption)
    heading:Hide()
    frame.shoppingGroups[i] = { heading = heading, rows = {} }
  end

  local totalRule = surface(itemPanel, 12, 119, 1, 1, 0.36, 0.26, 0.15)
  totalRule:SetPoint("TOPRIGHT", -12, -119)
  frame.costs = {}
  for i, caption in ipairs({ "All materials", "To buy", "Already owned", "Vendor sales", "Net cost" }) do
    local y = i == 5 and 125 or 38 + (i - 1) * 20
    local component = i == 2 or i == 3
    label(itemPanel, component and fonts.note or (i == 5 and fonts.body or fonts.caption),
      component and 24 or 12, y, 98):SetText(caption)
    local value = label(itemPanel, component and fonts.note or fonts.body, 0, y, component and 110 or 128)
    value:ClearAllPoints()
    value:SetPoint("TOPRIGHT", -12, -y)
    value:SetJustifyH("RIGHT")
    value:SetMaxLines(1)
    frame.costs[i] = value
  end
  frame.priceStatus = label(itemPanel, fonts.note, 12, 146, 1)
  frame.priceStatus:SetWordWrap(true)
  paint(frame.priceStatus, colors.muted)
  frame.bagSpace = label(itemPanel, fonts.note, 12, 146, 1)
  frame.bagSpace:SetWordWrap(true)
  local shoppingRule = surface(itemPanel, 12, 0, 1, 1, 0.38, 0.28, 0.15)

  local footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("BOTTOMLEFT", 18, 10)
  footer:SetPoint("BOTTOMRIGHT", -18, 10)
  footer:SetHeight(25)

  frame.skipWool = footerCheckButton(footer, "Less wool",
    "Use wool only from skill 75 to 100. Switch to silk until skill 150.", function(self)
      settings.skipWool = not not self:GetChecked()
      showRoute(active, true)
    end)
  frame.potionRoute = footerCheckButton(footer, "Potion route",
    "Use potions and poultices at skill 1–75, 90–150, and 275–300.", function(self)
      local choices = settings.recipeChoices["First Aid"] or {}
      settings.recipeChoices["First Aid"] = choices
      choices.potions = not not self:GetChecked()
      anchoredPlans[active] = nil
      showRoute(active, true)
    end)

  local applyEnchant = button(footer, "Apply enchant", 0, 0, 128)
  applyEnchant:ClearAllPoints()
  applyEnchant:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, -1)
  applyEnchant:Hide()
  applyEnchant:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Apply selected enchant")
    GameTooltip:AddLine("In the Enchanting window, select an enchant and put an item in its target slot.", 1, 1, 1, true)
    GameTooltip:AddLine("Replaces the existing enchant on that item.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  applyEnchant:SetScript("OnLeave", hideTooltip)
  applyEnchant:SetScript("OnHide", hideTooltip)
  applyEnchant:SetScript("OnClick", function()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local info = page and page:IsVisible() and page.professionInfo
    local transaction = info and (info.parentProfessionID or info.professionID) == professionSkillLines.Enchanting
      and page.SchematicForm:GetTransaction()
    if not transaction or not transaction:GetEnchantAllocation() then
      print(plannerTitle .. ": Select an enchant and place an item in the Enchanting window's target slot.")
      return
    end
    local create = page.CreateButton
    if not create:IsVisible() or not create:IsEnabled() or StaticPopup_FindVisible("REPLACE_ENCHANT") then return end
    -- Based on the WoW Professions macro. Accept only the overwrite prompt from this craft.
    create:Click()
    local overwrite = StaticPopup_FindVisible("REPLACE_ENCHANT")
    if overwrite then overwrite:GetButton1():Click() end
  end)
  frame.applyEnchant = applyEnchant

  local guideFooter = CreateFrame("Frame", nil, footer)
  guideFooter:SetAllPoints()
  frame.guideFooter = guideFooter
  local divider = guideFooter:CreateTexture(nil, "BACKGROUND")
  divider:SetPoint("TOPLEFT")
  divider:SetPoint("TOPRIGHT")
  divider:SetHeight(1)
  divider:SetColorTexture(0.38, 0.30, 0.21, 0.75)

  local credit = guideFooter:CreateFontString(nil, "OVERLAY")
  credit:SetFontObject(fonts.note)
  paint(credit, colors.muted)
  credit:SetPoint("TOPLEFT", 0, -5)
  credit:SetText("Guide data from")

  local guideLink = CreateFrame("Button", nil, guideFooter)
  guideLink:SetPoint("LEFT", credit, "RIGHT", 4, 0)
  local linkText = guideLink:CreateFontString(nil, "OVERLAY")
  linkText:SetFontObject(fonts.note)
  linkText:SetPoint("LEFT")
  linkText:SetText("WoW Professions")
  paint(linkText, colors.current)
  guideLink:SetSize(linkText:GetStringWidth() + 2, 18)
  guideLink:SetScript("OnEnter", function(self)
    paint(linkText, colors.gold)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Copy guide link")
    if selectedPlan and selectedPlan.notes then
      GameTooltip:AddLine(selectedPlan.notes, 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  guideLink:SetScript("OnLeave", function(self)
    paint(linkText, colors.current)
    hideTooltip(self)
  end)
  guideLink:SetScript("OnHide", hideTooltip)
  guideLink:SetScript("OnClick", function()
    if selectedPlan then showCopy(selectedPlan.url, "Copy guide link (Ctrl+C)") end
  end)

  local affiliation = guideFooter:CreateFontString(nil, "OVERLAY")
  affiliation:SetFontObject(fonts.note)
  paint(affiliation, colors.muted)
  affiliation:SetPoint("LEFT", guideLink, "RIGHT", 4, 0)
  affiliation:SetText("·  FPT is not affiliated")

  local copy = button(itemPanel, "Export to Auctionator", 0, 0, 1)
  copy:ClearAllPoints()
  copy:SetPoint("BOTTOMLEFT", 12, 10)
  copy:SetPoint("BOTTOMRIGHT", -12, 10)
  copy:SetHeight(28)
  frame.importButton = copy
  copy:SetScript("OnClick", function()
    local shopping = selectedPlan
    if not shopping or #shopping.auction == 0 then return end
    showCopy(addon.ImportString(shopping), "Copy shopping list (Ctrl+C)",
      "Paste into Auctionator's Shopping tab using Import.")
  end)

  frame.copyPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.copyPanel:SetFrameLevel(frame:GetFrameLevel() + 8)
  frame.copyPanel:SetSize(584, 110)
  frame.copyPanel:SetPoint("CENTER")
  frame.copyPanel:EnableMouse(true)
  styleWindow(frame.copyPanel)
  frame.copyHeading = label(frame.copyPanel, fonts.heading, 14, 14, 526)
  frame.copyInstructions = label(frame.copyPanel, fonts.body, 14, 76, 550)
  frame.copyInstructions:SetSpacing(4)
  local dismiss = button(frame.copyPanel, "Close", 502, 72, 68)
  dismiss:ClearAllPoints()
  dismiss:SetPoint("BOTTOMRIGHT", -14, 14)
  dismiss:SetScript("OnClick", function() frame.copyPanel:Hide() end)
  local box = CreateFrame("EditBox", nil, frame.copyPanel, "InputBoxTemplate")
  box:SetPoint("TOPLEFT", 17, -42)
  box:SetSize(550, 25)
  box:SetAutoFocus(false)
  box:SetFontObject(fonts.body)
  box:SetScript("OnEscapePressed", function() frame.copyPanel:Hide() end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(copyText)
      self:HighlightText()
    end
  end)
  frame.copyBox = box
  frame.copyPanel:SetScript("OnHide", function() box:ClearFocus() end)
  frame.copyPanel:Hide()

  local resize = CreateFrame("Button", nil, frame)
  resize:SetSize(18, 18)
  resize:SetPoint("BOTTOMRIGHT", -1, 1)
  resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  local resizing
  local function stopResizing()
    if not resizing then return end
    frame:StopMovingOrSizing()
    settings.windowWidth, settings.windowHeight = frame:GetSize()
    resizing = nil
  end
  resize:SetScript("OnMouseDown", function(_, mouseButton)
    if mouseButton == "LeftButton" then
      resizing = true
      frame:StartSizing("BOTTOMRIGHT")
    end
  end)
  resize:SetScript("OnMouseUp", stopResizing)
  frame:HookScript("OnHide", stopResizing)

  frame.layoutShopping = function()
    local itemWidth, panelHeight = itemPanel:GetSize()
    frame.priceStatus:SetWidth(itemWidth - 24)
    frame.bagSpace:SetWidth(itemWidth - 24)
    local y = 146
    local priceStatus = frame.priceStatus:GetText()
    if priceStatus and priceStatus ~= "" then
      y = y + math.max(12, math.ceil(frame.priceStatus:GetStringHeight())) + 5
    end
    if frame.bagSpace:IsShown() then
      frame.bagSpace:SetPoint("TOPLEFT", 12, -y)
      y = y + math.max(12, math.ceil(frame.bagSpace:GetStringHeight())) + 8
    end
    shoppingRule:SetPoint("TOPLEFT", 12, -y)
    shoppingRule:SetPoint("TOPRIGHT", -12, -y)
    local top = y + 9
    frame.itemScroll:SetPoint("TOPLEFT", 12, -top)
    frame.itemScroll:SetSize(itemWidth - 39, math.max(1, panelHeight - top - 47))
    updateScrollAreas()
  end

  local function layout(_, width, height)
    local contentWidth = width - 36
    frame.trainerLocation:SetWidth(width - 60)
    local itemWidth = math.min(330, math.max(248, math.floor(contentWidth * 0.34)))
    local stepWidth = contentWidth - 10 - itemWidth
    local panelHeight = height - panelTop - footer:GetHeight() - 17
    stepPanel:SetSize(stepWidth, panelHeight)
    itemPanel:SetSize(itemWidth, panelHeight)
    frame.stepScroll:SetSize(stepWidth - 36, panelHeight - stepScrollTop - 8)
    frame.layoutShopping()
  end
  frame:SetScript("OnSizeChanged", layout)
  layout(frame, frame:GetSize())
  frame:Hide()
  if plannerTheme then plannerTheme(frame) end
end

function addon.SetPlannerTheme(applyTheme)
  if plannerTheme == applyTheme then return end
  plannerTheme = applyTheme
  if frame then plannerTheme(frame) end
end

local function ensurePlanner()
  if not frame then
    if type(ForeverProfessionPlannerSettings) ~= "table" then ForeverProfessionPlannerSettings = {} end
    settings = ForeverProfessionPlannerSettings
    if type(settings.recipeChoices) ~= "table" then settings.recipeChoices = {} end
    for profession, choices in pairs(settings.recipeChoices) do
      if type(choices) ~= "table" then settings.recipeChoices[profession] = nil end
    end
    local legacyTarget = settings.stopAt150 == false and settings.fullTarget or settings.shortTarget
    local target = tonumber(settings.target) or tonumber(legacyTarget) or defaultTarget
    if settings.rush150 == true then
      target = math.min(150, tonumber(settings.rushTarget) or 150)
    elseif settings.rush150 == false and target == 150 then
      -- The old default was saved even before the player moved the slider.
      target = defaultTarget
    end
    if tonumber(settings.target) and target >= 1 and settings.rush150 == nil then
      settings.target = math.min(maxTarget, math.max(1, math.floor(target + 0.5)))
    else
      settings.target = target <= 1 and defaultTarget or snapTarget(target, targetStep)
    end
    settings.rush150, settings.rushTarget = nil, nil
    settings.stopAt150, settings.shortTarget, settings.fullTarget = nil, nil, nil
    settings.preferBuying = nil
    createPlanner()
  end
end

local function showPlanner(index, resetPlan)
  selectProfession(index, resetPlan)
  frame:Show()
  frame:Raise()
end

SLASH_FOREVERPROFESSIONTRAINER1 = "/fpt"
SLASH_FOREVERPROFESSIONTRAINER2 = "/foreverprofessiontrainer"
SlashCmdList.FOREVERPROFESSIONTRAINER = function(message)
  local requested = message and message:match("^%s*(.-)%s*$"):lower()
  if requested == "debug" then
    if not canUseDebug() then
      print(plannerTitle .. ": Animation Debug is unavailable on this account.")
      return
    end
    ensurePlanner()
    if not frame:IsShown() then showPlanner(active) end
    showDebugPage()
    frame:Raise()
    return
  end
  ensurePlanner()
  if requested and requested ~= "" then
    for i, route in ipairs(routes) do
      if route.name:lower() == requested then
        showPlanner(i, true)
        return
      end
    end
  end
  if frame:IsShown() then
    frame:Hide()
  else
    showPlanner(active)
  end
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
  local professions = ProfessionsFrame
  if not professions or not professions.ProfessionsOverviewTab then return end

  local launcher = createSideTab(professions, plannerIcon, function(tab)
    ensurePlanner()
    setPlannerSize(professions)

    local right, top = tab:GetRight(), professions:GetTop()
    if right and top then
      local left = right + 16
      local screenWidth = plannerScreenSize()
      if left + frame:GetWidth() + frame.tabs[1]:GetWidth() + 12 <= screenWidth then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
      end
    end
    if frame:IsShown() then
      frame:Raise()
    else
      showPlanner(active)
    end
  end)
  launcher.tooltipText = plannerTitle
  launcher.smartNavigationIgnored = true

  local function positionLauncher()
    local overview = professions.ProfessionsOverviewTab
    local last = overview
    for _, tab in ipairs(professions.rightProfessionTabs) do
      if tab:IsShown() then last = tab end
    end
    launcher:ClearAllPoints()
    local tabBottom, panelBottom = last:GetBottom(), professions:GetBottom()
    -- Leave room for buttons attached to the bottom of the side rail.
    if tabBottom and panelBottom and tabBottom - panelBottom < 2 * launcher:GetHeight() + 14 then
      launcher:SetPoint("BOTTOMLEFT", overview, "TOPLEFT", 0, 2)
    else
      launcher:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
    end
  end
  hooksecurefunc(professions, "RefreshRightTabs", positionLauncher)
  positionLauncher()
end)
