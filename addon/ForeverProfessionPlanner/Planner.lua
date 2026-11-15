local _, addon = ...
local routes = addon.routes
local plannerTitle = "Forever Profession Trainer"
local professionSlotCount = 7
local professionSkillLines = {
  Alchemy = 171, Blacksmithing = 164, Enchanting = 333,
  Engineering = 202, Leatherworking = 165, Tailoring = 197,
}
local professionIcons = {
  Alchemy = "Trade_Alchemy", Blacksmithing = "Trade_BlackSmithing", Enchanting = "Trade_Engraving",
  Engineering = "Trade_Engineering", Leatherworking = "Trade_LeatherWorking", Tailoring = "Trade_Tailoring",
}
local plannerIcon = "INV_Misc_Book_09"
-- Trainer locations and outdoor map coordinates follow the WoW Professions, Method, and Icy Veins Forever guides.
local nextRanks = {
  [75] = { name = "Journeyman", skill = 50, level = 10 },
  [150] = { name = "Expert", skill = 125, level = 20 },
  [225] = { name = "Artisan", skill = 200, level = 35 },
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
local active
local stepRowHeight = 36
local targetStep = 5
local defaultTarget, maxTarget = 75, 300
local defaultWindowWidth, defaultWindowHeight = 750, 620
local stepColumns = { skill = 12, icon = 79, recipe = 109, crafts = 42 }
local startingSkills = {}
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
  tab.Icon:SetTexture("Interface\\Icons\\" .. icon)
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
  local placed = C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID)
    and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
    and C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, trainer.x / 100, trainer.y / 100))
  if not placed then
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

local function showMoney(region, value, net)
  local text = value and money(value) or "—"
  if value and C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    local sign = value < 0 and "−" or (value > 0 and "+" or "")
    text = sign .. C_CurrencyInfo.GetCoinTextureString(math.floor(math.abs(value) + 0.5), 12)
  end
  region:SetText(text)
  paint(region, not value and colors.muted or (net and value < 0 and colors.red)
    or (value > 0 and colors.green) or colors.text)
end

local function formatDuration(milliseconds)
  local seconds = math.ceil(milliseconds / 1000)
  return seconds >= 60 and string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
    or string.format("%ds", seconds)
end

local function updateCraftingTime(self)
  local remaining = self.craftingEstimate or 0
  local countingDown
  if remaining > 0 then
    local name, _, _, startTime, endTime, isTradeSkill, castID, _, spellID = UnitCastingInfo("player")
    if isTradeSkill and (not issecretvalue
      or not (issecretvalue(name) or issecretvalue(startTime) or issecretvalue(endTime)
        or issecretvalue(castID) or issecretvalue(spellID))) then
      local estimatedCast = self.craftingDurations[spellID] or self.craftingDurations[name]
      if estimatedCast then
        if castID and startTime and (not self.craftingCast or self.craftingCast.id ~= castID) then
          self.craftingCast = { id = castID, startTime = startTime }
        end
        -- Substitute the live time left for the copy of this craft in the route estimate.
        local castRemaining = math.max(0, endTime - math.floor(GetTime() * 1000 + 0.5))
        remaining = remaining - estimatedCast + castRemaining
        countingDown = true
      end
    end
  end

  local onUpdate = countingDown and updateCraftingTime or nil
  if self:GetScript("OnUpdate") ~= onUpdate then self:SetScript("OnUpdate", onUpdate) end
  local seconds = math.ceil(remaining / 1000)
  if seconds == self.displayedCraftingTime then return end
  self.displayedCraftingTime = seconds
  self.craftingTime:SetText("Est. crafting  |cfff7ead1" .. formatDuration(remaining) .. "|r")
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
  self.craftingCast = nil
  self.craftingFeedbackAnimation:Stop()
  self.craftingFeedback:Hide()
end

local function showShoppingBagSpace(plan)
  local space = addon.GetShoppingBagSpace(plan)
  frame.bagSpace:SetShown(space ~= nil)
  frame.pendingBagItems = space and space.pending
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

local function showGuideInfo(plan, rank)
  local defaultCost = plan.defaultGuideCost
  local showComparison = defaultCost ~= nil and (plan.woolTimeDifference == nil or rank < 150)
  frame.guidePrices:SetShown(showComparison)
  if showComparison then
    local custom = plan.cost.gross and money(-plan.cost.gross) or "unpriced"
    local default = defaultCost.gross and money(-defaultCost.gross) or "unpriced"
    local difference = plan.woolTimeDifference
    if difference then
      local tradeoff = difference == 0 and "same crafting time"
        or formatDuration(math.abs(difference)) .. (difference > 0 and " longer" or " faster")
      frame.guidePrices:SetText(string.format("Skip wool %d–%d: %s  ·  Materials: %s vs %s",
        plan.from, plan.cap, tradeoff, custom, default))
    else
      frame.guidePrices:SetText(string.format("Materials for %d–%d: FPT %s  ·  WoW Professions %s",
        plan.from, plan.cap, custom, default))
    end
  end
end

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
  local crafts = label(row, fonts.body, 0, 0, stepColumns.crafts - 6)
  crafts:ClearAllPoints()
  crafts:SetPoint("TOPRIGHT", -6, 0)
  crafts:SetHeight(stepRowHeight)
  crafts:SetJustifyV("MIDDLE")
  crafts:SetJustifyH("RIGHT")
  local check = row:CreateTexture(nil, "ARTWORK")
  check:SetPoint("RIGHT", -6, 0)
  check:SetSize(20, 20)
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetDesaturated(true)
  check:SetVertexColor(unpack(colors.complete))
  check:Hide()
  row.skill, row.recipe, row.crafts, row.keep = skill, recipe, crafts, keep
  row.icon, row.marker, row.check = icon, marker, check
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.recipe:GetText())
    if self.keep:IsShown() then GameTooltip:AddLine(self.keep:GetText()) end
    GameTooltip:Show()
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
      row.check = row:CreateTexture(nil, "ARTWORK")
      row.check:SetPoint("TOPRIGHT", row.count, "TOPLEFT", 0, 0)
      row.check:SetSize(14, 14)
      row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      row.check:SetDesaturated(true)
      row.check:SetVertexColor(unpack(colors.complete))
      group.rows[i] = row
    end
    local ready = item.remaining == 0
    row.name:SetText(item.name .. (item.keep and "  |cff91c497Keep|r" or ""))
    row.count:SetText(string.format("%d/%d", item.inBags, item.quantity))
    row.count:SetWidth(math.ceil(row.count:GetUnboundedStringWidth()) + 2)
    paint(row.count, ready and colors.complete or colors.text)
    row.check:SetShown(ready)
    row:Show()
  end
  for i = #items + 1, #group.rows do group.rows[i]:Hide() end
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

local function updateScrollAreas()
  local stepWidth, stepHeight = frame.stepScroll:GetSize()
  local itemWidth, itemHeight = frame.itemScroll:GetSize()
  frame.stepContent:SetSize(stepWidth, math.max(stepHeight, (frame.stepCount or 0) * stepRowHeight))
  local recipeWidth = stepWidth - stepColumns.recipe - stepColumns.crafts
  for _, row in ipairs(frame.steps) do
    row.recipe:SetWidth(recipeWidth)
    row.keep:SetWidth(recipeWidth)
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

local function showNextTrainer(profession, rank, maximum)
  local training = nextRanks[maximum]
  if training then
    local status = rank >= training.skill
      and string.format("Train %s (character level %d)", training.name, training.level)
      or string.format("Train %s at skill %d (character level %d)", training.name, training.skill, training.level)
    frame.trainerStatus:SetText(status)
    local trainer, location = nextTrainer(profession, maximum)
    setTrainerMapLink(frame.trainerMapLink, trainer, trainer and (trainer.name .. " · " .. location) or location)
  else
    frame.trainerStatus:SetText("Highest rank in this guide learned")
    setTrainerMapLink(frame.trainerMapLink, nil, "")
  end
end

local function professionGuide(index, target, skipWool)
  local guide = anchoredPlans[index]
  if not guide or guide.plan.cap ~= target or guide.skipWool ~= skipWool or addon.HasNewPlanPrices(guide.plan) then
    local plan = addon.GetPlan(index, target, true, startingSkills[index] or 1, nil, skipWool)
    guide = { plan = plan, steps = addon.GetGuideSteps(index, plan), skipWool = skipWool }
    anchoredPlans[index] = guide
  end
  return guide
end

local function updateProfessionTabs(index)
  local learned = learnedProfessions()
  local orderedTabs = {}
  local learnedCount = 0
  for i, tab in ipairs(frame.tabs) do
    tab.skill = learned[professionSkillLines[routes[i].name]]
    if tab.skill then learnedCount = learnedCount + 1 end
    local position = tab.skill and tab.skill.slot or professionSlotCount + i
    orderedTabs[position] = tab
    tab.Background:SetVertexColor(unpack(tab.skill and colors.gold or colors.tabNeutral))
    tab:SetChecked(i == index)
    if not tab.skill and startingSkills[i] then
      startingSkills[i], anchoredPlans[i] = nil, nil
    end
  end

  local compactPreviews = learnedCount >= 2
  local previousTab = frame
  for position = 1, professionSlotCount + #frame.tabs do
    local tab = orderedTabs[position]
    if tab then
      local scale = compactPreviews and not tab.skill and 0.875 or 1
      if tab:GetScale() ~= scale then tab:SetScale(scale) end
      if tab.previousTab ~= previousTab then
        tab:ClearAllPoints()
        if previousTab == frame then
          tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
        else
          tab:SetPoint("TOPLEFT", previousTab, "BOTTOMLEFT", 0, -2)
        end
        tab.previousTab = previousTab
      end
      previousTab = tab
    end
  end
end

local function showRoute(index, keepScroll)
  keepScroll = keepScroll and active == index
  if active ~= index then
    clearCraftingFeedback(frame)
    frame.clearSkillFeedback()
    frame.viewingCappedPlan = nil
  end
  active = index
  updateProfessionTabs(index)
  local profession = index and routes[index].name
  local portraitIcon = profession and professionIcons[profession] or plannerIcon
  frame.PortraitContainer.portrait:SetTexture("Interface\\Icons\\" .. portraitIcon)
  frame.TitleContainer.TitleText:SetText(profession and (plannerTitle .. " · " .. profession) or plannerTitle)
  frame.welcome:SetShown(index == nil)
  frame.targetControls:SetShown(index ~= nil)
  local isTailoring = profession == "Tailoring"
  local skipWool = isTailoring and settings.skipWool == true
  frame.skipWool:SetChecked(skipWool)
  if not index then
    frame.skipWool:Hide()
    frame.guideFooter:Hide()
    frame.craftingEstimate, frame.craftingDurations = nil, nil
    updateCraftingTime(frame)
    frame.planPage:Hide()
    frame.trainPage:Show()
    frame.cappedBanner:Hide()
    selectedPlan = nil
    frame.copyPanel:Hide()
    return
  end
  local skill = frame.tabs[index].skill
  local rank, maximum = skill and skill.rank or 1, skill and skill.maximum
  local minimum = skill and math.min(rank, maxTarget) or targetStep
  local target = snapTarget(settings.target, minimum)
  frame.syncTarget(target, minimum, skill and rank)
  local training = nextRanks[maximum]
  local capped = training ~= nil and rank == maximum
  if not capped then frame.viewingCappedPlan = nil end
  local showTraining = capped and not frame.viewingCappedPlan
  frame.planPage:SetShown(not showTraining)
  frame.guideFooter:SetShown(not showTraining)
  frame.skipWool:SetShown(isTailoring and rank < 150 and not showTraining)
  frame.trainPage:SetShown(showTraining)
  frame.cappedBanner:SetShown(showTraining)
  frame.trainingButton:SetShown(capped and not showTraining)
  if skill and (not startingSkills[index] or rank < startingSkills[index]) then
    startingSkills[index] = rank
    anchoredPlans[index] = nil
  end
  local guide = professionGuide(index, target, skipWool)
  local route = addon.GetPlan(index, target, true, rank, guide.plan)
  frame.craftingEstimate, frame.craftingDurations = addon.GetCraftingMilliseconds(route)
  updateCraftingTime(frame)
  if showTraining then
    selectedPlan = nil
    frame.copyPanel:Hide()
    local trainer, location = nextTrainer(profession, maximum)
    frame.cappedIcon:SetTexture(skill.icon or "Interface\\Icons\\" .. professionIcons[profession])
    frame.cappedTitle:SetText(string.format("Train %s %s", training.name, profession))
    frame.cappedWarning:SetText(string.format("You cannot gain more %s skill until you\nlearn %s (%s) from your trainer",
      profession, profession, training.name))
    frame.cappedRequirements:SetText(string.format("Skill cap reached at %d · Requires character level %d",
      maximum, training.level))
    setTrainerMapLink(frame.cappedMapLink, trainer, trainer and trainer.name or "")
    frame.cappedTrainer:SetShown(trainer ~= nil)
    local locationTop = trainer and 100 or 77
    frame.cappedLocation:SetPoint("TOPLEFT", 16, -locationTop)
    frame.cappedLocation:SetText(location)
    frame.cappedBanner:SetHeight(locationTop + math.max(17, frame.cappedLocation:GetStringHeight()) + 16)
    return
  end
  local guideSteps = addon.GetGuideSteps(index, route, guide.steps)
  selectedPlan = guide.plan
  showGuideInfo(selectedPlan, rank)
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
  if cost.gross == nil and #route.auction > 0 then
    if cost.available then
      source = string.format("Auctionator prices missing for %d item%s", #cost.missing, #cost.missing == 1 and "" or "s")
    else
      source = "Auctionator required for prices"
    end
  end
  frame.priceStatus:SetText(source)
  showMoney(frame.costs[1], cost.gross and -cost.gross)
  showMoney(frame.costs[2], route.from < route.cap and route.revenue or nil)
  showMoney(frame.costs[3], cost.net and -cost.net, true)
  showShoppingBagSpace(route)
  frame.importButton:SetEnabled(#route.auction > 0)
  local latestCompletedRow
  while #frame.steps < #guideSteps do addStepRow() end
  for i, row in ipairs(frame.steps) do
    local step = guideSteps[i]
    local complete = step and rank >= step.to
    local current = step and rank >= step.from and rank < step.to
    row:SetShown(step ~= nil)
    showRecipeIcon(row, step, complete)
    row.marker:SetShown(not not current)
    row.check:SetShown(not not complete)
    if complete then latestCompletedRow = i end
    if step then
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
      row.crafts:SetText(complete and "" or ("×" .. step.crafts))
      row.keep:SetText(step.keep and ("Keep ×" .. step.keep) or "")
      row.keep:SetShown(step.keep ~= nil)
      row.recipe:SetPoint("TOPLEFT", stepColumns.recipe, step.keep and -3 or 0)
      row.recipe:SetHeight(step.keep and 18 or stepRowHeight)
      row.recipe:SetMaxLines(step.keep and 1 or 2)
    end
  end

  showShoppingItems(frame.shoppingGroups[1], route.shoppingAuction)
  showShoppingItems(frame.shoppingGroups[2], route.shoppingVendor)
  frame.emptyShopping:SetShown(#route.shoppingAuction == 0 and #route.shoppingVendor == 0)
  frame.emptySteps:SetShown(#guideSteps == 0)
  frame.stepCount = #guideSteps
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
  return route
end

local function selectProfession(index)
  frame.viewingCappedPlan = nil
  showRoute(index)
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

local function setPlannerSize(professions)
  local width, height = tonumber(settings.windowWidth), tonumber(settings.windowHeight)
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
  setPlannerSize(ProfessionsFrame)
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
    local tab = createSideTab(frame, professionIcons[route.name], function()
      if active ~= index or frame.viewingCappedPlan then selectProfession(index) end
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
  welcomeIcon:SetTexture("Interface\\Icons\\" .. plannerIcon)
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
  frame:HookScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
    clearCraftingFeedback(self)
  end)

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
  for _, milestone in ipairs({ 75, 150, 225, maxTarget }) do
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
    if displayedSkill and currentSkill and currentSkill > displayedSkill then
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
    targetSlider:SetValue(target)
    completed:SetShown(hasSkill)
    spark:SetShown(hasSkill)
    fill:SetPoint("TOPLEFT", hasSkill and completed or trough, hasSkill and "TOPRIGHT" or "TOPLEFT")
    fill:SetShown(target > minimum)
    local skillColor = hasSkill and "91c497" or "b7a68b"
    frame.targetValue:SetText(string.format("|cff%s%d|r / |cfff5c173%d|r", skillColor, currentSkill or 0, target))
    for milestone, tick in pairs(ticks) do
      local enabled = milestone >= minimum
      tick:SetEnabled(enabled)
      tick:SetAlpha(enabled and 1 or 0.35)
    end
    updatingTarget = false
  end

  targetSlider:SetMinMaxValues(targetMinimum, maxTarget)
  targetSlider:SetScript("OnValueChanged", function(_, value)
    if updatingTarget then return end
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
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:RegisterEvent("CHAT_MSG_SKILL")
  frame:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  frame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  local refreshPending
  frame:SetScript("OnEvent", function(self, event, ...)
    if not self:IsShown() then return end
    if event == "UNIT_SPELLCAST_START" then
      updateCraftingTime(self)
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      local cast = self.craftingCast
      local _, castID = ...
      if cast and not cast.finished and (not issecretvalue or not issecretvalue(castID)) and castID == cast.id then
        cast.finished = true
        local elapsed = GetTime() * 1000 - cast.startTime
        if elapsed > 0 then showCraftingFeedback(self, elapsed) end
      end
      return
    end
    if event == "BAG_UPDATE_DELAYED" and not active then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
      local itemID, success = ...
      local pending = self.planPage:IsShown() and self.pendingBagItems
      if not success or not pending or not pending[itemID] then return end
    end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
      refreshPending = nil
      if self:IsShown() then showRoute(active, true) end
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

  label(itemPanel, fonts.heading, 12, 12, 160):SetText("Shopping List")
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

  local totalRule = surface(itemPanel, 12, 79, 1, 1, 0.36, 0.26, 0.15)
  totalRule:SetPoint("TOPRIGHT", -12, -79)
  frame.costs = {}
  for i, caption in ipairs({ "Materials", "Vendor sales", "Net cost" }) do
    local y = i == 3 and 85 or 38 + (i - 1) * 20
    label(itemPanel, i == 3 and fonts.body or fonts.caption, 12, y, 98):SetText(caption)
    local value = label(itemPanel, fonts.body, 0, y, 128)
    value:ClearAllPoints()
    value:SetPoint("TOPRIGHT", -12, -y)
    value:SetJustifyH("RIGHT")
    value:SetMaxLines(1)
    frame.costs[i] = value
  end
  frame.priceStatus = label(itemPanel, fonts.note, 12, 106, 1)
  frame.priceStatus:SetWordWrap(true)
  paint(frame.priceStatus, colors.muted)
  frame.bagSpace = label(itemPanel, fonts.note, 12, 106, 1)
  frame.bagSpace:SetWordWrap(true)
  local shoppingRule = surface(itemPanel, 12, 0, 1, 1, 0.38, 0.28, 0.15)

  local footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("BOTTOMLEFT", 18, 10)
  footer:SetPoint("BOTTOMRIGHT", -18, 10)
  footer:SetHeight(37)

  local skipWool = CreateFrame("CheckButton", nil, footer, "UICheckButtonTemplate")
  skipWool:SetPoint("BOTTOMLEFT", -3, -4)
  skipWool:SetSize(24, 24)
  skipWool:SetHitRectInsets(0, -64, 0, 0)
  label(skipWool, fonts.caption, 24, 5, 64):SetText("Skip wool")
  skipWool:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Use the linen-based route through skill 150.")
    GameTooltip:Show()
  end)
  skipWool:SetScript("OnLeave", hideTooltip)
  skipWool:SetScript("OnHide", hideTooltip)
  skipWool:SetScript("OnClick", function(self)
    settings.skipWool = self:GetChecked()
    showRoute(active, true)
  end)
  frame.skipWool = skipWool

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

  frame.guidePrices = label(guideFooter, fonts.note, 94, 21, 1)
  frame.guidePrices:SetPoint("TOPRIGHT", 0, -21)
  frame.guidePrices:SetJustifyH("RIGHT")
  paint(frame.guidePrices, colors.muted)

  local copy = button(itemPanel, "Export to Auctionator", 0, 0, 1)
  copy:ClearAllPoints()
  copy:SetPoint("BOTTOMLEFT", 12, 10)
  copy:SetPoint("BOTTOMRIGHT", -12, 10)
  copy:SetHeight(28)
  frame.importButton = copy
  copy:SetScript("OnClick", function()
    local shopping = showRoute(active, true)
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
    local y = 106
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
    local panelHeight = height - panelTop - 54
    stepPanel:SetSize(stepWidth, panelHeight)
    itemPanel:SetSize(itemWidth, panelHeight)
    frame.stepScroll:SetSize(stepWidth - 36, panelHeight - stepScrollTop - 8)
    frame.layoutShopping()
  end
  frame:SetScript("OnSizeChanged", layout)
  layout(frame, frame:GetSize())
  frame:Hide()
end

local function ensurePlanner()
  if not frame then
    if type(ForeverProfessionPlannerSettings) ~= "table" then ForeverProfessionPlannerSettings = {} end
    settings = ForeverProfessionPlannerSettings
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

local function showPlanner(index)
  selectProfession(index)
  frame:Show()
  frame:Raise()
end

SLASH_FOREVERPROFESSIONTRAINER1 = "/fpt"
SLASH_FOREVERPROFESSIONTRAINER2 = "/foreverprofessiontrainer"
SlashCmdList.FOREVERPROFESSIONTRAINER = function(message)
  local requested = message and message:match("^%s*(.-)%s*$"):lower()
  ensurePlanner()
  if requested and requested ~= "" then
    for i, route in ipairs(routes) do
      if route.name:lower() == requested then
        showPlanner(i)
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
