local _, addon = ...
local routes = addon.routes
local professionSkillLines = {
  Alchemy = 171, Blacksmithing = 164, Enchanting = 333,
  Engineering = 202, Leatherworking = 165, Tailoring = 197,
}
local professionIcons = {
  Alchemy = "Trade_Alchemy", Blacksmithing = "Trade_BlackSmithing", Enchanting = "Trade_Engraving",
  Engineering = "Trade_Engineering", Leatherworking = "Trade_LeatherWorking", Tailoring = "Trade_Tailoring",
}
-- Trainer locations come from the WoW Professions Forever guides.
local nextRanks = {
  [75] = { name = "Journeyman", skill = 50, level = 10 },
  [150] = { name = "Expert", skill = 125, level = 20 },
  [225] = { name = "Artisan", skill = 200, level = 35 },
}
local expertTrainers = {
  Alchemy = { Horde = "Doctor Herbert Halsey, Undercity", Alliance = "Ainethil, Darnassus" },
  Blacksmithing = { Horde = "Saru Steelfury, Orgrimmar", Alliance = "Bengus Deepforge, Ironforge" },
  Enchanting = { Horde = "Hgarth, Sun Rock Retreat, Stonetalon Mountains", Alliance = "Kitta Firewind, Tower of Azora, Elwynn Forest" },
  Engineering = { Horde = "Roxxik, Orgrimmar", Alliance = "Springspindle Fizzlegear, Ironforge" },
  Leatherworking = { Horde = "Una, Thunder Bluff", Alliance = "Telonis, Darnassus" },
  Tailoring = { Horde = "Josef Gregorian, Undercity", Alliance = "Georgio Bolero, Stormwind" },
}
local artisanTrainers = {
  Alchemy = { Horde = "Rogvar, Stonard, Swamp of Sorrows", Alliance = "Kylanna Windwhisper, Feathermoon Stronghold, Feralas" },
  Blacksmithing = "Brikk Keencraft, Booty Bay, Stranglethorn Vale",
  Enchanting = "Annora, Uldaman, Badlands",
  Engineering = "Buzzek Bracketswing, Gadgetzan, Tanaris",
  Leatherworking = { Horde = "Hahrana Ironhide, Camp Mojache, Feralas", Alliance = "Drakk Stonehand, Aerie Peak, The Hinterlands" },
  Tailoring = { Horde = "Daryl Stack, Tarren Mill, Hillsbrad Foothills", Alliance = "Timothy Worthington, Theramore, Dustwallow Marsh" },
}

local frame
local active
local stepRowHeight = 36
local targetStep = 5
local rushSkillCap = 150
local shoppingListTop = 128
local startingSkills = {}
local anchoredPlans = {}
local rushPlans = {}
local selectedPlan
local settings
local colors = {
  text = { 0.97, 0.92, 0.82 },
  gold = { 1.00, 0.82, 0.30 },
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

local function snapTarget(value, maximum)
  return math.min(maximum, math.max(targetStep, math.floor(value / targetStep + 0.5) * targetStep))
end

local function paint(region, color)
  region:SetTextColor(unpack(color))
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
  body = plannerFont("Body", 15, colors.text),
  note = plannerFont("Note", 12, colors.text),
  disabledHeading = plannerFont("DisabledHeading", 17, colors.text),
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
  local sign = value < 0 and "-" or ""
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper / 100) % 100
  if gold > 0 then
    return string.format("%s%dg %02ds %02dc", sign, gold, silver, copper % 100)
  elseif silver > 0 then
    return string.format("%s%ds %02dc", sign, silver, copper % 100)
  end
  return string.format("%s%dc", sign, copper)
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

local function showGuideInfo(plan)
  local defaultCost = plan.defaultGuideCost
  frame.guidePrices:SetShown(defaultCost ~= nil)
  if defaultCost then
    local custom = plan.cost.gross and money(plan.cost.gross) or "unpriced"
    local default = defaultCost.gross and money(defaultCost.gross) or "unpriced"
    frame.guidePrices:SetText(string.format("Materials for %d–%d: FPT %s  ·  WoW Professions %s",
      plan.from, plan.cap, custom, default))
  end
end

local function addStepRow()
  local y = 5 + #frame.steps * stepRowHeight
  local marker = surface(frame.stepContent, 7, y + 1, 2, 17, 0.84, 0.65, 0.34)
  marker:Hide()
  local skill = label(frame.stepContent, fonts.body, 18, y, 66)
  local icon = frame.stepContent:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 87, -y)
  icon:SetSize(24, 24)
  local recipe = label(frame.stepContent, fonts.body, 118, y, 215)
  local keep = label(frame.stepContent, fonts.note, 118, y + 18, 215)
  recipe:SetPoint("TOPRIGHT", -65, -y)
  keep:SetPoint("TOPRIGHT", -65, -(y + 18))
  recipe:SetMaxLines(1)
  local crafts = label(frame.stepContent, fonts.body, 0, y, 57)
  crafts:ClearAllPoints()
  crafts:SetPoint("TOPRIGHT", -4, -y)
  crafts:SetJustifyH("RIGHT")
  local check = frame.stepContent:CreateTexture(nil, "ARTWORK")
  check:SetPoint("TOPRIGHT", -4, 4 - y)
  check:SetSize(24, 24)
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetDesaturated(true)
  check:SetVertexColor(unpack(colors.complete))
  check:Hide()
  frame.steps[#frame.steps + 1] = {
    skill = skill, recipe = recipe, crafts = crafts, keep = keep, icon = icon, marker = marker, check = check,
  }
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
  for _, index in pairs({ GetProfessions() }) do
    local _, icon, rank, maximum, _, _, skillLine = GetProfessionInfo(index)
    if skillLine and type(rank) == "number" and rank > 0 then
      learned[skillLine] = { rank = rank, maximum = maximum, icon = icon }
    end
  end
  return learned
end

local function updateScrollAreas()
  local stepWidth, stepHeight = frame.stepScroll:GetSize()
  local itemWidth, itemHeight = frame.itemScroll:GetSize()
  frame.stepContent:SetSize(stepWidth, math.max(stepHeight, (frame.stepCount or 0) * stepRowHeight + 5))
  frame.itemContent:SetWidth(itemWidth)
  local y = 0
  for _, group in ipairs(frame.shoppingGroups) do
    group.heading:SetWidth(itemWidth - 4)
    group.items:SetWidth(itemWidth - 4)
    if group.items:IsShown() then
      group.heading:SetPoint("TOPLEFT", 0, -y)
      if group.heading:IsShown() then y = y + group.heading:GetStringHeight() + 8 end
      group.items:SetPoint("TOPLEFT", 0, -y)
      y = y + group.items:GetStringHeight() + 12
    end
  end
  frame.itemContent:SetHeight(math.max(itemHeight, y))
  for _, scroll in ipairs({ frame.stepScroll, frame.itemScroll }) do
    scroll:UpdateScrollChildRect()
    local maximum = scroll:GetVerticalScrollRange()
    if scroll:GetVerticalScroll() > maximum then scroll:SetVerticalScroll(maximum) end
  end
end

local function nextTrainer(profession, maximum)
  local trainer = (maximum == 150 and expertTrainers[profession]) or (maximum == 225 and artisanTrainers[profession])
  if type(trainer) == "table" then
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return trainer[faction]
  end
  return trainer
end

local function showNextTrainer(profession, rank, maximum)
  local training = nextRanks[maximum]
  if training then
    local status = rank >= training.skill
      and string.format("Train %s (character level %d)", training.name, training.level)
      or string.format("Train %s at skill %d (character level %d)", training.name, training.skill, training.level)
    frame.trainerStatus:SetText(status)
    frame.trainerLocation:SetText(nextTrainer(profession, maximum)
      or ("Ask a capital-city guard for the " .. profession .. " trainer."))
  else
    frame.trainerStatus:SetText("Highest rank in this guide learned")
    frame.trainerLocation:SetText("")
  end
end

local function professionGuide(index, rush)
  local plans = rush and rushPlans or anchoredPlans
  local guide = plans[index]
  if not guide then
    local plan = addon.GetPlan(index, rush, rush and rushSkillCap or 300, true, startingSkills[index])
    local steps = addon.GetGuideSteps(index, plan)
    if rush then
      for _, step in ipairs(professionGuide(index, false).steps) do
        if step.from >= rushSkillCap then steps[#steps + 1] = step end
      end
    end
    guide = { plan = plan, steps = steps }
    plans[index] = guide
  end
  return guide
end

local function showRoute(index, keepScroll)
  local learned = learnedProfessions()
  local firstLearned
  local visibleTabs = 0
  for i, tab in ipairs(frame.tabs) do
    local skill = learned[professionSkillLines[routes[i].name]]
    tab:SetShown(skill ~= nil)
    if skill then
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, -44 - visibleTabs * (tab:GetHeight() + 2))
      firstLearned = firstLearned or i
      visibleTabs = visibleTabs + 1
    else
      startingSkills[i], anchoredPlans[i], rushPlans[i] = nil, nil, nil
    end
  end
  if not index or not learned[professionSkillLines[routes[index].name]] then index = firstLearned end
  keepScroll = keepScroll and active == index
  active = index
  for i, tab in ipairs(frame.tabs) do
    tab.selected:SetShown(i == index)
  end
  frame.welcome:SetShown(index == nil)
  if not index then
    frame.planPage:Hide()
    frame.trainPage:Show()
    frame.cappedBanner:Hide()
    selectedPlan = nil
    frame.copyPanel:Hide()
    return
  end
  local profession = routes[index].name
  local skill = learned[professionSkillLines[profession]]
  local rank, maximum = skill.rank, skill.maximum
  local training = nextRanks[maximum]
  local capped = training ~= nil and rank == maximum
  frame.planPage:SetShown(not capped)
  frame.trainPage:SetShown(capped)
  frame.cappedBanner:SetShown(capped)
  if not startingSkills[index] or rank < startingSkills[index] then
    startingSkills[index] = rank
    anchoredPlans[index], rushPlans[index] = nil, nil
  end
  if capped then
    selectedPlan = nil
    frame.copyPanel:Hide()
    local trainer = nextTrainer(profession, maximum)
      or ("Ask a capital-city guard for the " .. profession .. " trainer.")
    frame.cappedIcon:SetTexture(skill.icon or "Interface\\Icons\\" .. professionIcons[profession])
    frame.cappedDetails:SetText(string.format("Train %s %s (character level %d)\n%s",
      training.name, profession, training.level, trainer))
    return
  end
  local canRush = rank <= rushSkillCap
  local rush = canRush and settings.rush150
  local target = rush and settings.rushTarget or settings.target
  frame.syncTarget(canRush, rush, target)
  local guide = professionGuide(index, rush)
  local route = addon.GetPlan(index, rush, target, true, rank, guide.plan)
  selectedPlan = guide.plan
  showGuideInfo(selectedPlan)
  if frame.copyPanel and frame.copyPanel:IsShown() then
    if not keepScroll or (frame.copyingShoppingList and copyText ~= addon.ImportString(route)) then
      frame.copyPanel:Hide()
    end
  end
  showNextTrainer(profession, rank, maximum)
  local cost = route.cost
  local source = ""
  local netColor = colors.text
  if cost.net ~= nil then
    netColor = cost.net > 0 and colors.red or (cost.net < 0 and colors.green or colors.text)
  elseif #route.auction > 0 then
    if cost.available then
      source = string.format("Auctionator prices missing for %d item%s", #cost.missing, #cost.missing == 1 and "" or "s")
    else
      source = "Auctionator required for prices"
    end
  end
  frame.priceStatus:SetText(source)
  frame.costs[1]:SetText(cost.gross and money(cost.gross) or "—")
  frame.costs[2]:SetText(cost.net and money(cost.net) or "—")
  paint(frame.costs[1], cost.gross and colors.red or colors.text)
  paint(frame.costs[2], netColor)
  frame.importButton:SetEnabled(#route.auction > 0)
  local latestCompletedRow
  while #frame.steps < #guide.steps do addStepRow() end
  for i, row in ipairs(frame.steps) do
    local step = guide.steps[i]
    local complete = step and rank >= step.to
    local current = step and rank >= step.from and rank < step.to
    showRecipeIcon(row, step, complete)
    row.marker:SetShown(not not current)
    row.check:SetShown(not not complete)
    if complete then latestCompletedRow = i end
    if step then
      local crafts = step.crafts
      if current and not step.prep and rank < target then
        for _, remainingStep in ipairs(route.steps) do
          if not remainingStep.prep and remainingStep.from == rank
            and remainingStep.recipe == step.recipe and remainingStep.to == math.min(step.to, target) then
            crafts = remainingStep.crafts
            break
          end
        end
      end
      local stepColor = complete and colors.complete or (current and colors.current)
        or colors.text
      local recipeColor = complete and colors.recipeComplete or (current and colors.recipeCurrent)
        or colors.text
      paint(row.recipe, recipeColor)
      paint(row.skill, stepColor)
      paint(row.crafts, stepColor)
      row.skill:SetText(step.prep and "Prep" or string.format("%d-%d", step.from, step.to))
      row.recipe:SetText(step.recipe)
      row.crafts:SetText(complete and "" or ("x" .. crafts))
      row.keep:SetText(step.keep and ("Keep ×" .. step.keep) or "")
    else
      row.skill:SetText("")
      row.recipe:SetText("")
      row.crafts:SetText("")
      row.keep:SetText("")
    end
  end

  local function showShoppingItems(group, rows, empty)
    local items = {}
    for _, item in ipairs(rows) do
      local counts = string.format("%d/%d", item.inBags, item.quantity)
      if item.remaining == 0 then
        counts = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t |cff8fdbad" .. counts .. "|r"
      end
      local note = item.keep and "  |cff8fdbadKeep|r" or ""
      items[#items + 1] = counts .. "  " .. item.name .. note
    end
    group.heading:SetShown(#rows > 0)
    group.items:SetShown(#rows > 0 or empty)
    group.items:SetText(empty and "No materials needed" or table.concat(items, "\n"))
  end
  local noMaterials = #route.shoppingAuction == 0 and #route.shoppingVendor == 0
  showShoppingItems(frame.shoppingGroups[1], route.shoppingAuction, noMaterials)
  showShoppingItems(frame.shoppingGroups[2], route.shoppingVendor, false)
  frame.emptySteps:SetShown(#guide.steps == 0)
  frame.stepCount = #guide.steps
  updateScrollAreas()
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

local function createPlanner()
  local minWidth, minHeight = 750, 620
  local tabSize = 58
  local tabOverhang = tabSize - 1
  local maxWidth = math.max(minWidth, UIParent:GetWidth() - 24 - tabOverhang)
  local maxHeight = math.max(minHeight, UIParent:GetHeight() - 24)
  frame = CreateFrame("Frame", "ForeverProfessionPlannerFrame", UIParent, "BackdropTemplate")
  frame:SetSize(math.min(maxWidth, math.max(minWidth, tonumber(settings.windowWidth) or minWidth)),
    math.min(maxHeight, math.max(minHeight, tonumber(settings.windowHeight) or minHeight)))
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetClampRectInsets(0, tabOverhang, 0, 0)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  frame:EnableMouse(true)
  styleWindow(frame)
  table.insert(UISpecialFrames, frame:GetName())

  local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  header:SetPoint("TOPLEFT", 7, -6)
  header:SetPoint("TOPRIGHT", -7, -6)
  header:SetHeight(27)
  header:SetBackdrop(insetBackdrop)
  header:SetBackdropColor(0.14, 0.092, 0.048, 1)
  header:SetBackdropBorderColor(unpack(colors.windowBorder))
  local headerFill = header:CreateTexture(nil, "BACKGROUND", nil, 1)
  headerFill:SetPoint("TOPLEFT", 4, -4)
  headerFill:SetPoint("BOTTOMRIGHT", -4, 4)
  headerFill:SetColorTexture(0.14, 0.092, 0.048, 1)
  tintGradient(headerFill, { 0.105, 0.065, 0.035, 1 }, { 0.21, 0.141, 0.079, 1 })
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() frame:StartMoving() end)
  header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  local title = label(header, fonts.title, 0, 0, 420)
  title:ClearAllPoints()
  title:SetPoint("CENTER", header)
  title:SetJustifyH("CENTER")
  title:SetText("Forever Profession Trainer")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("CENTER", header, "RIGHT", -12, 0)
  close:SetFrameLevel(header:GetFrameLevel() + 1)
  close:SetScript("OnClick", function() frame:Hide() end)
  frame.tabs = {}
  for i, route in ipairs(routes) do
    local index = i
    local tab = CreateFrame("Button", nil, frame)
    tab:SetSize(tabSize, tabSize)
    tab:Hide()
    local background = tab:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetAtlas("common-sidetab")

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\" .. professionIcons[route.name])
    local mask = tab:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetAtlas("common-sidetab-mask")
    icon:AddMaskTexture(mask)

    tab.selected = tab:CreateTexture(nil, "OVERLAY")
    tab.selected:SetAllPoints()
    tab.selected:SetAtlas("common-sidetab-selected")
    tab.selected:Hide()
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetAtlas("common-sidetab-hover")
    tab:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(routes[index].name)
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:SetScript("OnClick", function()
      if active ~= index then showRoute(index) end
    end)
    frame.tabs[i] = tab
  end

  local trainPage = CreateFrame("Frame", nil, frame)
  trainPage:SetPoint("TOPLEFT", 18, -52)
  trainPage:SetPoint("BOTTOMRIGHT", -18, 18)
  frame.trainPage = trainPage

  local welcome = insetPanel(trainPage, "CENTER", 0, 0)
  welcome:SetSize(476, 200)
  frame.welcome = welcome
  local welcomeIcon = welcome:CreateTexture(nil, "ARTWORK")
  welcomeIcon:SetPoint("TOP", 0, -20)
  welcomeIcon:SetSize(36, 36)
  welcomeIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  local welcomeTitle = label(welcome, fonts.title, 28, 68, 420)
  welcomeTitle:SetJustifyH("CENTER")
  welcomeTitle:SetText("Learn a crafting profession")
  local welcomeText = label(welcome, fonts.body, 28, 98, 420)
  welcomeText:SetJustifyH("CENTER")
  welcomeText:SetSpacing(4)
  welcomeText:SetText("Ask a guard in a capital city to point you to a trainer. Once you learn a supported profession, its guide appears here.")
  local supported = label(welcome, fonts.note, 28, 154, 420)
  supported:SetJustifyH("CENTER")
  supported:SetSpacing(3)
  supported:SetText("Alchemy, Blacksmithing, Enchanting\nEngineering, Leatherworking, Tailoring")

  local cappedBanner = CreateFrame("Frame", nil, trainPage, "BackdropTemplate")
  cappedBanner:SetSize(640, 78)
  cappedBanner:SetPoint("CENTER")
  cappedBanner:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = insetBackdrop.edgeFile,
    edgeSize = insetBackdrop.edgeSize,
    insets = insetBackdrop.insets,
  })
  cappedBanner:SetBackdropColor(0.19, 0.11, 0.09, 1)
  cappedBanner:SetBackdropBorderColor(0.77, 0.58, 0.31, 1)
  frame.cappedBanner = cappedBanner

  frame.cappedIcon = cappedBanner:CreateTexture(nil, "ARTWORK")
  frame.cappedIcon:SetPoint("LEFT", 16, 0)
  frame.cappedIcon:SetSize(40, 40)

  local cappedTitle = label(cappedBanner, fonts.title, 68, 9, 555)
  cappedTitle:SetText("You're Capped. Go train!")
  paint(cappedTitle, colors.red)

  frame.cappedDetails = label(cappedBanner, fonts.body, 68, 38, 555)
  frame.cappedDetails:SetSpacing(2)

  local body = CreateFrame("Frame", nil, frame)
  body:SetAllPoints()
  frame.planPage = body
  local targetBackground = surface(body, 16, 52, 1, 50, 0.135, 0.098, 0.063)
  targetBackground:SetPoint("TOPRIGHT", -16, -52)

  label(body, fonts.heading, 29, 56, 145):SetText("Target skill level:")
  frame.targetValue = label(body, fonts.heading, 182, 56, 42)
  paint(frame.targetValue, colors.text)
  local targetSlider = CreateFrame("Slider", nil, body)
  targetSlider:SetPoint("TOPLEFT", 29, -77)
  targetSlider:SetPoint("TOPRIGHT", -29, -77)
  targetSlider:SetHeight(22)
  targetSlider:SetOrientation("HORIZONTAL")
  targetSlider:EnableMouse(true)
  targetSlider:SetValueStep(targetStep)
  targetSlider:SetObeyStepOnDrag(true)

  local track = targetSlider:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  local trackHeight = 14
  track:SetHeight(trackHeight)
  track:SetColorTexture(0.51, 0.36, 0.19, 1)

  local trough = targetSlider:CreateTexture(nil, "BACKGROUND", nil, 1)
  trough:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
  trough:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 1)
  trough:SetColorTexture(0.075, 0.052, 0.033, 1)

  local thumb = targetSlider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(10, 18)
  thumb:SetColorTexture(0.96, 0.75, 0.37, 1)
  tintGradient(thumb, { 0.64, 0.41, 0.16, 1 }, { 1, 0.86, 0.52, 1 })
  targetSlider:SetThumbTexture(thumb)

  local fill = targetSlider:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", trough, "TOPLEFT")
  fill:SetPoint("BOTTOMRIGHT", thumb, "CENTER", 0, 1 - trackHeight / 2)
  fill:SetColorTexture(0.73, 0.47, 0.18, 1)
  tintGradient(fill, { 0.49, 0.25, 0.07, 1 }, { 0.88, 0.62, 0.25, 1 })

  local rush = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  rush:SetPoint("TOPRIGHT", -99, -53)
  rush:SetSize(24, 24)
  rush:SetHitRectInsets(0, -73, 0, 0)
  label(rush, fonts.body, 27, 5, 70):SetText("Rush 150")
  rush:SetScript("OnClick", function(self)
    settings.rush150 = not not self:GetChecked()
    if settings.rush150 then settings.rushTarget = rushSkillCap end
    showRoute(active)
  end)

  local updatingTarget, rushActive
  frame.syncTarget = function(canRush, useRush, target)
    rush:SetShown(canRush)
    rush:SetChecked(useRush)
    updatingTarget = true
    rushActive = useRush
    targetSlider:SetMinMaxValues(targetStep, rushActive and rushSkillCap or 300)
    targetSlider:SetValue(target)
    fill:SetShown(target > targetStep)
    frame.targetValue:SetText(target)
    updatingTarget = false
  end

  targetSlider:SetScript("OnValueChanged", function(_, value)
    fill:SetShown(value > targetStep)
    if updatingTarget then return end
    local target = snapTarget(value, rushActive and rushSkillCap or 300)
    local key = rushActive and "rushTarget" or "target"
    if settings[key] == target then return end
    settings[key] = target
    frame.targetValue:SetText(target)
    showRoute(active)
  end)
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:RegisterEvent("CHAT_MSG_SKILL")
  frame:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  local refreshPending
  frame:SetScript("OnEvent", function(self, event)
    if not self:IsShown() then return end
    if event == "BAG_UPDATE_DELAYED" and not self.planPage:IsShown() then return end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
      refreshPending = nil
      if self:IsShown() then showRoute(active, true) end
    end)
  end)

  local trainerBackground = surface(body, 18, 110, 1, 49, 0.125, 0.088, 0.055)
  trainerBackground:SetPoint("TOPRIGHT", -18, -110)
  frame.trainerStatus = label(body, fonts.heading, 29, 117, 692)
  frame.trainerStatus:SetPoint("TOPRIGHT", -29, -117)
  frame.trainerLocation = label(body, fonts.body, 29, 138, 692)
  frame.trainerLocation:SetPoint("TOPRIGHT", -29, -138)
  local panelTop = 171
  local stepPanel = insetPanel(body, "TOPLEFT", 18, panelTop)
  local itemPanel = insetPanel(body, "TOPRIGHT", -18, panelTop)
  local stepHeaderTop = 14
  local stepScrollTop = 44
  local columnRule = surface(stepPanel, 12, 36, 1, 1, 0.38, 0.28, 0.15)
  columnRule:SetPoint("TOPRIGHT", -12, -36)
  label(stepPanel, fonts.heading, 30, stepHeaderTop, 66):SetText("Level")
  label(stepPanel, fonts.heading, 130, stepHeaderTop, 180):SetText("Recipe")
  local craftsHeading = label(stepPanel, fonts.heading, 0, stepHeaderTop, 110)
  craftsHeading:ClearAllPoints()
  craftsHeading:SetPoint("TOPRIGHT", -44, -stepHeaderTop)
  craftsHeading:SetJustifyH("RIGHT")
  craftsHeading:SetText("Amount")
  frame.emptySteps = label(stepPanel, fonts.body, 12, stepScrollTop + 5, 295)
  frame.emptySteps:SetText("No recipes for this skill range.")
  frame.stepScroll, frame.stepContent = scrollArea(stepPanel, 12, stepScrollTop, 1, 1)
  frame.itemScroll, frame.itemContent = scrollArea(itemPanel, 16, shoppingListTop, 1, 1)
  frame.steps = {}

  frame.shoppingGroups = {}
  for i, caption in ipairs({ "Auction House", "Vendor supplies" }) do
    local heading = label(frame.itemContent, fonts.heading, 0, 0, 1)
    heading:SetText(caption)
    heading:Hide()
    local items = label(frame.itemContent, fonts.body, 0, 0, 1)
    items:SetSpacing(8)
    items:Hide()
    frame.shoppingGroups[i] = { heading = heading, items = items }
  end

  frame.costs = {}
  for i, caption in ipairs({ "Shopping cost:", "Net after sales:" }) do
    local y = 52 + (i - 1) * 23
    local heading = label(itemPanel, fonts.body, 12, y, 122)
    heading:SetMaxLines(1)
    heading:SetText(caption)
    local value = label(itemPanel, fonts.body, 138, y, 110)
    value:SetPoint("TOPRIGHT", -12, -y)
    value:SetJustifyH("RIGHT")
    value:SetMaxLines(1)
    frame.costs[i] = value
  end
  frame.priceStatus = label(itemPanel, fonts.note, 12, 100, 240)
  frame.priceStatus:SetPoint("TOPRIGHT", -12, -100)

  local footer = CreateFrame("Frame", nil, body)
  footer:SetPoint("BOTTOMLEFT", 18, 10)
  footer:SetPoint("BOTTOMRIGHT", -18, 10)
  footer:SetHeight(48)

  local divider = footer:CreateTexture(nil, "BACKGROUND")
  divider:SetPoint("TOPLEFT")
  divider:SetPoint("TOPRIGHT")
  divider:SetHeight(1)
  divider:SetColorTexture(0.38, 0.30, 0.21, 0.75)

  local footerTextColor = { 0.73, 0.73, 0.73 }
  local credit = footer:CreateFontString(nil, "OVERLAY")
  credit:SetFontObject(fonts.note)
  paint(credit, footerTextColor)
  credit:SetPoint("TOPLEFT", 0, -7)
  credit:SetText("Guide data is from wow-professions.com")

  local affiliation = footer:CreateFontString(nil, "OVERLAY")
  affiliation:SetFontObject(fonts.note)
  paint(affiliation, footerTextColor)
  affiliation:SetPoint("LEFT", credit, "RIGHT", 10, 0)
  affiliation:SetText("·  FPT is not affiliated")

  local guideLink = button(footer, "wow-professions.com", 0, 0, 180)
  guideLink:ClearAllPoints()
  guideLink:SetPoint("TOPLEFT", credit, "BOTTOMLEFT", -3, -4)
  guideLink:SetScript("OnClick", function()
    if selectedPlan then showCopy(selectedPlan.url, "WoW Professions link (Ctrl+C)") end
  end)

  frame.guidePrices = label(footer, fonts.note, 0, 0, 1)
  frame.guidePrices:ClearAllPoints()
  frame.guidePrices:SetPoint("LEFT", guideLink, "RIGHT", 12, 0)
  paint(frame.guidePrices, footerTextColor)

  local copy = button(itemPanel, "Export shopping list", 12, 10, 1)
  copy:SetPoint("TOPRIGHT", -12, -10)
  copy:SetHeight(34)
  copy:SetNormalFontObject(fonts.heading)
  copy:SetHighlightFontObject(fonts.heading)
  copy:SetDisabledFontObject(fonts.disabledHeading)
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

  local function layout(_, width, height)
    local contentWidth = width - 36
    frame.guidePrices:SetWidth(contentWidth - guideLink:GetWidth() - 12)
    local itemWidth = math.min(330, math.max(264, math.floor(contentWidth * 0.35)))
    local stepWidth = contentWidth - 10 - itemWidth
    local panelHeight = height - panelTop - 64
    stepPanel:SetSize(stepWidth, panelHeight)
    itemPanel:SetSize(itemWidth, panelHeight)
    frame.stepScroll:SetSize(stepWidth - 40, panelHeight - stepScrollTop - 8)
    frame.itemScroll:SetSize(itemWidth - 44, panelHeight - shoppingListTop - 12)
    updateScrollAreas()
  end
  frame:SetScript("OnSizeChanged", layout)
  layout(frame, frame:GetSize())
  frame:Hide()
end

SLASH_FOREVERPROFESSIONTRAINER1 = "/fpt"
SLASH_FOREVERPROFESSIONTRAINER2 = "/foreverprofessiontrainer"
SlashCmdList.FOREVERPROFESSIONTRAINER = function(message)
  if not frame then
    if type(ForeverProfessionPlannerSettings) ~= "table" then ForeverProfessionPlannerSettings = {} end
    settings = ForeverProfessionPlannerSettings
    local legacyTarget = settings.stopAt150 == false and settings.fullTarget or settings.shortTarget
    local target = math.floor(tonumber(settings.target) or tonumber(legacyTarget) or 150)
    settings.target = target <= 1 and 150 or snapTarget(target, 300)
    settings.rush150 = settings.rush150 == true
    settings.rushTarget = snapTarget(tonumber(settings.rushTarget) or rushSkillCap, rushSkillCap)
    settings.stopAt150, settings.shortTarget, settings.fullTarget = nil, nil, nil
    settings.preferBuying = nil
    createPlanner()
  end
  local requested = message and message:match("^%s*(.-)%s*$"):lower()
  if requested and requested ~= "" then
    for i, route in ipairs(routes) do
      if route.name:lower() == requested then
        showRoute(i)
        frame:Show()
        return
      end
    end
  end
  if frame:IsShown() then
    frame:Hide()
  else
    showRoute(active)
    frame:Show()
  end
end
