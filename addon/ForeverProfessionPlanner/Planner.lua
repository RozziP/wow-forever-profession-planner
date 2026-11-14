local _, addon = ...
local routes = addon.routes
local professionSkillLines = {
  Alchemy = 171, Blacksmithing = 164, Enchanting = 333,
  Engineering = 202, Leatherworking = 165, Tailoring = 197,
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
local active = 1
local stepRowHeight = 36
local targetStep = 5
local rushSkillCap = 150
local shoppingListTop = 128
local displayedSkill, displayedSkillCap
local startingSkills = {}
local anchoredPlans = {}
local rushPlans = {}
local selectedPlan
local settings
local colors = {
  text = { 1.00, 0.97, 0.90 },
  muted = { 0.72, 0.69, 0.62 },
  gold = { 1.00, 0.82, 0.30 },
  current = { 0.89, 0.81, 0.65 },
  upcoming = { 0.80, 0.76, 0.70 },
  red = { 1.00, 0.45, 0.42 },
  green = { 0.56, 0.86, 0.68 },
  complete = { 0.60, 0.68, 0.59 },
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

local function label(parent, font, x, y, width)
  local region = parent:CreateFontString(nil, "OVERLAY", font)
  region:SetPoint("TOPLEFT", x, -y)
  region:SetWidth(width)
  region:SetJustifyH("LEFT")
  region:SetJustifyV("TOP")
  paint(region, colors.text)
  return region
end

local function surface(parent, x, y, width, height, r, g, b)
  local region = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
  region:SetPoint("TOPLEFT", x, -y)
  region:SetSize(width, height)
  region:SetColorTexture(r, g, b, 1)
  return region
end

local function button(parent, caption, x, y, width)
  local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  control:SetPoint("TOPLEFT", x, -y)
  control:SetSize(width, 24)
  control:SetText(caption)
  return control
end

local function insetPanel(parent, point, x, y)
  local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  panel:SetPoint(point, x, -y)
  panel:SetBackdrop(insetBackdrop)
  panel:SetBackdropColor(0.07, 0.055, 0.045, 1)
  panel:SetBackdropBorderColor(0.54, 0.45, 0.32, 0.9)
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
  if scroll:GetVerticalScroll() ~= scroll.wheelOffset then
    stopWheelScroll(scroll)
    return
  end

  scroll.wheelTarget = math.min(scroll.wheelTarget, scroll:GetVerticalScrollRange())
  local target = scroll.wheelTarget
  local distance = target - scroll.wheelPosition
  if math.abs(distance) <= 0.5 then
    stopWheelScroll(scroll)
    scroll:SetVerticalScroll(target)
    return
  end

  scroll.wheelPosition = scroll.wheelPosition + distance * (1 - math.exp(-elapsed * 28))
  scroll:SetVerticalScroll(scroll.wheelPosition)
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
    if not target or offset ~= self.wheelOffset then
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

local function signedNet(cost)
  if cost < 0 then return "+" .. money(-cost) end
  return money(cost)
end

local function showGuideInfo(plan)
  local defaultCost = plan.defaultGuideCost
  frame.guideName:SetText(defaultCost and "Custom FPT guide" or "Default guides from WoW Professions")
  frame.guidePrices:SetShown(defaultCost ~= nil)
  if defaultCost then
    local custom = plan.cost.gross and money(plan.cost.gross) or "unpriced"
    local default = defaultCost.gross and money(defaultCost.gross) or "unpriced"
    frame.guidePrices:SetText(string.format("Material cost (%d-%d)  |  FPT: %s  |  WoW Professions: %s",
      plan.from, plan.cap, custom, default))
  end
end

local function addStepRow()
  local y = 5 + #frame.steps * stepRowHeight
  local marker = surface(frame.stepContent, 7, y + 1, 2, 17, 0.66, 0.55, 0.38)
  marker:Hide()
  local skill = label(frame.stepContent, "GameFontHighlightLarge", 18, y, 66)
  local icon = frame.stepContent:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 87, -y)
  icon:SetSize(24, 24)
  local recipe = label(frame.stepContent, "GameFontHighlightLarge", 118, y, 215)
  local keep = label(frame.stepContent, "GameFontHighlight", 118, y + 18, 215)
  recipe:SetPoint("TOPRIGHT", -65, -y)
  keep:SetPoint("TOPRIGHT", -65, -(y + 18))
  recipe:SetMaxLines(1)
  paint(keep, colors.muted)
  local crafts = label(frame.stepContent, "GameFontHighlightLarge", 0, y, 57)
  crafts:ClearAllPoints()
  crafts:SetPoint("TOPRIGHT", -4, -y)
  crafts:SetJustifyH("RIGHT")
  local check = frame.stepContent:CreateTexture(nil, "ARTWORK")
  check:SetPoint("TOPRIGHT", -4, -y)
  check:SetSize(16, 16)
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

local function playerSkill(profession)
  if not GetProfessions or not GetProfessionInfo then return end
  local wanted = professionSkillLines[profession]
  for _, index in pairs({ GetProfessions() }) do
    local _, icon, rank, maximum, _, _, skillLine = GetProfessionInfo(index)
    if skillLine == wanted and type(rank) == "number" and rank > 0 then return rank, maximum, icon end
  end
end

local function updateScrollAreas()
  local stepWidth, stepHeight = frame.stepScroll:GetSize()
  local itemWidth, itemHeight = frame.itemScroll:GetSize()
  frame.stepContent:SetSize(stepWidth, math.max(stepHeight, (frame.stepCount or 0) * stepRowHeight + 5))
  frame.itemContent:SetWidth(itemWidth)
  frame.items:SetWidth(itemWidth - 4)
  frame.itemContent:SetHeight(math.max(itemHeight, frame.items:GetStringHeight() + 10))
  for _, scroll in ipairs({ frame.stepScroll, frame.itemScroll }) do
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
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

local function showProgress(plan, rank, maximum)
  local startingSkill = startingSkills[active]
  local remaining = math.max(0, plan.cap - rank)
  local progress = string.format("Skill %d", rank)
  if startingSkill and rank > startingSkill then
    progress = progress .. string.format("  |cff8fdbad+%d this session|r", rank - startingSkill)
  end
  frame.progressText:SetText(progress)
  frame.progressBar:SetMinMaxValues(0, plan.cap)
  frame.progressBar:SetValue(math.min(rank, plan.cap))

  local status = ""
  local location = ""
  local training = nextRanks[maximum]
  if remaining == 0 then
    status = "Target reached"
  elseif training and plan.cap > maximum then
    status = string.format("Train %s at skill %d (level %d)", training.name, training.skill, training.level)
    location = nextTrainer(plan.name, maximum) or ""
  end
  frame.progressStatus:SetText(status)
  frame.trainerLocation:SetText(location)
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
  active = index
  local rank, maximum, icon = playerSkill(routes[index].name)
  displayedSkill, displayedSkillCap = rank, maximum
  local learned = rank ~= nil
  local training = nextRanks[maximum]
  local capped = learned and training ~= nil and rank == maximum
  frame.planPage:SetShown(learned and not capped)
  frame.trainPage:SetShown(not learned or capped)
  frame.trainPrompt:SetShown(not learned)
  frame.cappedBanner:SetShown(capped)
  for i, control in ipairs(frame.tabs) do
    control:SetEnabled(i ~= index)
  end
  if not rank or not startingSkills[index] or rank < startingSkills[index] then
    startingSkills[index] = rank
    anchoredPlans[index], rushPlans[index] = nil, nil
  end
  if not learned then
    selectedPlan = nil
    frame.copyPanel:Hide()
    frame.trainPrompt:SetText("Train " .. routes[index].name .. " to get started")
    return
  end
  if capped then
    selectedPlan = nil
    frame.copyPanel:Hide()
    local profession = routes[index].name
    local trainer = nextTrainer(profession, maximum)
      or ("Ask a capital-city guard for the " .. profession .. " trainer.")
    frame.cappedIcon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Book_09")
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
  showProgress(route, rank, maximum)
  local cost = route.cost
  local source = ""
  local netColor = colors.muted
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
  frame.costs[2]:SetText(cost.net and signedNet(cost.net) or "—")
  paint(frame.costs[1], cost.gross and colors.red or colors.muted)
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
        or (step.from >= target and colors.muted or colors.upcoming)
      paint(row.recipe, stepColor)
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

  local items = {}
  local function addShoppingItems(heading, rows)
    if #rows == 0 then return end
    if #items > 0 then items[#items + 1] = "" end
    items[#items + 1] = "|cffffd37a" .. heading .. "|r"
    for _, item in ipairs(rows) do
      local counts = string.format("%d/%d", item.inBags, item.quantity)
      if item.remaining == 0 then
        counts = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t |cff8fdbad" .. counts .. "|r"
      end
      local note = item.keep and "  |cff8fdbadKeep|r" or ""
      items[#items + 1] = counts .. "  " .. item.name .. note
    end
  end
  addShoppingItems("Auction House", route.shoppingAuction)
  addShoppingItems("Vendor supplies", route.shoppingVendor)
  if #items == 0 then items[1] = "No materials needed" end
  frame.items:SetText(table.concat(items, "\n"))
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
  local maxWidth = math.max(minWidth, UIParent:GetWidth() - 24)
  local maxHeight = math.max(minHeight, UIParent:GetHeight() - 24)
  frame = CreateFrame("Frame", "ForeverProfessionPlannerFrame", UIParent, "BackdropTemplate")
  frame:SetSize(math.min(maxWidth, math.max(minWidth, tonumber(settings.windowWidth) or minWidth)),
    math.min(maxHeight, math.max(minHeight, tonumber(settings.windowHeight) or minHeight)))
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  frame:EnableMouse(true)
  frame:SetBackdrop(windowBackdrop)
  frame:SetBackdropColor(0.10, 0.085, 0.07, 1)
  frame:SetBackdropBorderColor(0.75, 0.70, 0.61, 1)
  table.insert(UISpecialFrames, frame:GetName())

  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -32, -1)
  header:SetHeight(43)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() frame:StartMoving() end)
  header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  local title = label(header, "GameFontNormalLarge", 0, 0, 420)
  title:ClearAllPoints()
  title:SetPoint("CENTER", header, "CENTER", 15, 0)
  title:SetJustifyH("CENTER")
  title:SetText("Forever Profession Trainer")
  paint(title, colors.gold)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -7, -7)
  close:SetScript("OnClick", function() frame:Hide() end)
  frame.tabs = {}
  for i, route in ipairs(routes) do
    local index = i
    local tab = button(frame, route.name, 18, 47, 110)
    tab:SetDisabledFontObject(GameFontNormal)
    tab:SetScript("OnClick", function() showRoute(index) end)
    frame.tabs[i] = tab
  end

  local trainPage = CreateFrame("Frame", nil, frame)
  trainPage:SetPoint("TOPLEFT", 18, -80)
  trainPage:SetPoint("BOTTOMRIGHT", -18, 18)
  frame.trainPage = trainPage
  frame.trainPrompt = label(trainPage, "GameFontNormalLarge", 0, 0, 440)
  frame.trainPrompt:ClearAllPoints()
  frame.trainPrompt:SetPoint("CENTER")
  frame.trainPrompt:SetJustifyH("CENTER")
  paint(frame.trainPrompt, colors.gold)

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

  local cappedTitle = label(cappedBanner, "GameFontNormalLarge", 68, 9, 555)
  local font, _, flags = cappedTitle:GetFont()
  cappedTitle:SetFont(font, 24, flags)
  cappedTitle:SetText("You're Capped. Go train!")
  paint(cappedTitle, colors.red)

  frame.cappedDetails = label(cappedBanner, "GameFontHighlight", 68, 38, 555)
  frame.cappedDetails:SetSpacing(2)

  local body = CreateFrame("Frame", nil, frame)
  body:SetAllPoints()
  frame.planPage = body
  local targetBackground = surface(body, 16, 80, 1, 44, 0.11, 0.085, 0.06)
  targetBackground:SetPoint("TOPRIGHT", -16, -80)

  label(body, "GameFontNormal", 116, 84, 82):SetText("Target skill")
  frame.targetValue = label(body, "GameFontNormalLarge", 292, 82, 42)
  frame.targetValue:SetJustifyH("RIGHT")
  local targetSlider = CreateFrame("Slider", nil, body)
  targetSlider:SetPoint("TOPLEFT", 110, -99)
  targetSlider:SetSize(230, 24)
  targetSlider:SetOrientation("HORIZONTAL")
  targetSlider:EnableMouse(true)
  targetSlider:SetValueStep(targetStep)
  targetSlider:SetObeyStepOnDrag(true)

  local sliderTrack = targetSlider:CreateTexture(nil, "BACKGROUND")
  sliderTrack:SetPoint("LEFT", 6, 0)
  sliderTrack:SetPoint("RIGHT", -6, 0)
  sliderTrack:SetHeight(4)
  sliderTrack:SetColorTexture(0.32, 0.25, 0.16, 1)
  local thumb = targetSlider:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(12, 16)
  thumb:SetColorTexture(0.83, 0.64, 0.30, 1)
  targetSlider:SetThumbTexture(thumb)

  local rush = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  rush:SetPoint("TOPLEFT", 413, -92)
  rush:SetSize(24, 24)
  rush:SetHitRectInsets(0, -73, 0, 0)
  label(rush, "GameFontNormal", 27, 5, 70):SetText("Rush 150")
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
    frame.targetValue:SetText(target)
    updatingTarget = false
  end

  targetSlider:SetScript("OnValueChanged", function(_, value)
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
  local refreshPending, bagsChanged
  frame:SetScript("OnEvent", function(self, event)
    if not self:IsShown() then return end
    if event == "BAG_UPDATE_DELAYED" then bagsChanged = true end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
      local refreshBags = bagsChanged
      refreshPending, bagsChanged = nil, nil
      if not self:IsShown() then return end
      local rank, maximum = playerSkill(routes[active].name)
      if refreshBags or rank ~= displayedSkill or maximum ~= displayedSkillCap then
        showRoute(active, true)
      end
    end)
  end)

  local progressBackground = surface(body, 18, 138, 1, 57, 0.10, 0.077, 0.053)
  progressBackground:SetPoint("TOPRIGHT", -18, -138)
  frame.progressText = label(body, "GameFontNormal", 29, 145, 240)
  frame.progressStatus = label(body, "GameFontNormal", 294, 145, 427)
  frame.progressStatus:SetPoint("TOPRIGHT", -29, -145)
  paint(frame.progressStatus, colors.gold)
  frame.trainerLocation = label(body, "GameFontHighlight", 294, 163, 427)
  frame.trainerLocation:SetPoint("TOPRIGHT", -29, -163)
  frame.progressBar = CreateFrame("StatusBar", nil, body)
  frame.progressBar:SetPoint("TOPLEFT", 29, -162)
  frame.progressBar:SetWidth(240)
  frame.progressBar:SetHeight(4)
  frame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  frame.progressBar:SetStatusBarColor(0.81, 0.60, 0.22)
  local track = frame.progressBar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0.24, 0.19, 0.12, 1)
  local stepPanel = insetPanel(body, "TOPLEFT", 18, 205)
  local itemPanel = insetPanel(body, "TOPRIGHT", -18, 205)
  local columnRule = surface(stepPanel, 12, 28, 1, 1, 0.38, 0.28, 0.15)
  columnRule:SetPoint("TOPRIGHT", -12, -28)
  label(stepPanel, "GameFontNormalLarge", 30, 10, 66):SetText("Level")
  label(stepPanel, "GameFontNormalLarge", 130, 10, 180):SetText("Recipe")
  local craftsHeading = label(stepPanel, "GameFontNormalLarge", 0, 10, 110)
  craftsHeading:ClearAllPoints()
  craftsHeading:SetPoint("TOPRIGHT", -44, -10)
  craftsHeading:SetJustifyH("RIGHT")
  craftsHeading:SetText("Amount")
  frame.emptySteps = label(stepPanel, "GameFontHighlight", 12, 36, 295)
  frame.emptySteps:SetText("No recipes for this skill range.")
  paint(frame.emptySteps, colors.muted)
  frame.stepScroll, frame.stepContent = scrollArea(stepPanel, 12, 30, 1, 1)
  frame.itemScroll, frame.itemContent = scrollArea(itemPanel, 16, shoppingListTop, 1, 1)
  frame.steps = {}

  frame.items = label(frame.itemContent, "GameFontHighlightLarge", 0, 0, 1)
  frame.items:SetSpacing(8)

  frame.costs = {}
  for i, caption in ipairs({ "Shopping cost", "Net after sales" }) do
    local y = 52 + (i - 1) * 23
    local heading = label(itemPanel, "GameFontHighlightLarge", 12, y, 122)
    heading:SetMaxLines(1)
    heading:SetText(caption)
    paint(heading, colors.muted)
    local value = label(itemPanel, "GameFontHighlightLarge", 138, y, 110)
    value:SetPoint("TOPRIGHT", -12, -y)
    value:SetJustifyH("RIGHT")
    value:SetMaxLines(1)
    frame.costs[i] = value
  end
  frame.priceStatus = label(itemPanel, "GameFontHighlight", 12, 100, 240)
  frame.priceStatus:SetPoint("TOPRIGHT", -12, -100)
  paint(frame.priceStatus, colors.muted)

  local guideLink = button(body, "Copy guide link", 0, 0, 126)
  guideLink:ClearAllPoints()
  guideLink:SetPoint("BOTTOMLEFT", 18, 10)
  guideLink:SetScript("OnClick", function()
    if selectedPlan then showCopy(selectedPlan.url, "WoW Professions link (Ctrl+C)") end
  end)

  frame.guideName = label(body, "GameFontNormal", 0, 0, 1)
  frame.guideName:ClearAllPoints()
  frame.guideName:SetPoint("BOTTOMLEFT", 18, 40)

  frame.guidePrices = label(body, "GameFontHighlight", 0, 0, 1)
  frame.guidePrices:ClearAllPoints()
  frame.guidePrices:SetPoint("LEFT", guideLink, "RIGHT", 12, 0)
  paint(frame.guidePrices, colors.muted)

  local copy = button(itemPanel, "Export shopping list", 12, 10, 1)
  copy:SetPoint("TOPRIGHT", -12, -10)
  copy:SetHeight(34)
  copy:SetNormalFontObject(GameFontHighlightLarge)
  copy:SetHighlightFontObject(GameFontHighlightLarge)
  copy:SetDisabledFontObject(GameFontDisable)
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
  frame.copyPanel:SetBackdrop(windowBackdrop)
  frame.copyPanel:SetBackdropColor(0.10, 0.085, 0.07, 1)
  frame.copyPanel:SetBackdropBorderColor(0.75, 0.70, 0.61, 1)
  frame.copyHeading = label(frame.copyPanel, "GameFontNormal", 14, 14, 526)
  frame.copyInstructions = label(frame.copyPanel, "GameFontHighlight", 14, 76, 550)
  frame.copyInstructions:SetSpacing(4)
  local dismiss = button(frame.copyPanel, "Close", 502, 72, 68)
  dismiss:ClearAllPoints()
  dismiss:SetPoint("BOTTOMRIGHT", -14, 14)
  dismiss:SetScript("OnClick", function() frame.copyPanel:Hide() end)
  local box = CreateFrame("EditBox", nil, frame.copyPanel, "InputBoxTemplate")
  box:SetPoint("TOPLEFT", 17, -42)
  box:SetSize(550, 25)
  box:SetAutoFocus(false)
  box:SetFontObject(GameFontHighlight)
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
    frame.guideName:SetWidth(contentWidth)
    frame.guidePrices:SetWidth(width - 174)
    local tabWidth = (contentWidth - (#frame.tabs - 1) * 6) / #frame.tabs
    for i, tab in ipairs(frame.tabs) do
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", 18 + (i - 1) * (tabWidth + 6), -47)
      tab:SetWidth(tabWidth)
    end
    local itemWidth = math.min(330, math.max(264, math.floor(contentWidth * 0.35)))
    local stepWidth = contentWidth - 10 - itemWidth
    local panelHeight = height - 269
    stepPanel:SetSize(stepWidth, panelHeight)
    itemPanel:SetSize(itemWidth, panelHeight)
    frame.stepScroll:SetSize(stepWidth - 40, panelHeight - 38)
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
