local _, addon = ...
local routes = addon.routes
local professionSkillLines = {
  Alchemy = 171, Blacksmithing = 164, Enchanting = 333,
  Engineering = 202, Leatherworking = 165, Tailoring = 197,
}

local frame
local active = 1
local activeStretch = 0
local displayedSkill
local selectedPlan
local settings
local colors = {
  text = { 0.94, 0.95, 0.96 },
  muted = { 0.69, 0.73, 0.77 },
  gold = { 0.98, 0.79, 0.45 },
  red = { 1.00, 0.45, 0.42 },
  green = { 0.56, 0.86, 0.68 },
}
local copyText

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

local function scrollArea(parent, x, y, width, height)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", x, -y)
  scroll:SetSize(width, height)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width, height)
  scroll:SetScrollChild(content)
  return scroll, content
end

local function signedNet(cost)
  if cost < 0 then return "+" .. money(-cost) end
  return money(cost)
end

local function patternEstimate(choice)
  local cost = choice.cost
  local partial = #cost.missing > 0
  local amount = signedNet(cost.net)
  if cost.net > 0 then
    amount = "|cffff736b" .. amount .. "|r"
  elseif cost.net < 0 and not partial then
    amount = "|cff8fdbad" .. amount .. "|r"
  end
  local suffix = ""
  if partial then
    suffix = #cost.missing == 1 and cost.missing[1]:find("^Pattern:") and ", pattern unpriced" or ", missing prices"
  end
  return choice.name .. " (" .. amount .. suffix .. ")"
end

local function addStepRow()
  local y = 3 + #frame.steps * 27
  local skill = label(frame.stepContent, "GameFontHighlight", 0, y, 59)
  local recipe = label(frame.stepContent, "GameFontHighlight", 61, y, 215)
  local keep = label(frame.stepContent, "GameFontHighlightSmall", 61, y + 14, 215)
  paint(keep, colors.green)
  local crafts = label(frame.stepContent, "GameFontHighlight", 281, y, 33)
  paint(skill, colors.gold)
  crafts:SetJustifyH("RIGHT")
  frame.steps[#frame.steps + 1] = { skill = skill, recipe = recipe, crafts = crafts, keep = keep }
end

local function playerSkill(profession)
  if not GetProfessions or not GetProfessionInfo then return end
  local wanted = professionSkillLines[profession]
  for _, index in pairs({ GetProfessions() }) do
    local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
    if skillLine == wanted and type(rank) == "number" and rank > 0 then return rank end
  end
end

local function showRoute(index, keepScroll)
  if active ~= index then activeStretch = 0 end
  active = index
  local rank = playerSkill(routes[index].name)
  displayedSkill = rank
  local target = settings.rush150 and settings.rushTarget or settings.target
  local plan = addon.GetPlan(index, settings.rush150, target, settings.preferBuying, rank)
  if activeStretch > #plan.sections then activeStretch = #plan.sections end
  local route = plan.sections[activeStretch] or plan
  selectedPlan = route
  if frame.copyPanel then frame.copyPanel:Hide() end
  local reached = plan.from >= plan.cap
  if reached then
    frame.routeTitle:SetText(string.format("%s · Target %d", plan.name, plan.cap))
  else
    frame.routeTitle:SetText(string.format("%s %d-%d", route.name, route.from, route.cap))
  end
  frame.currentSkill:SetText(rank and ("Current skill: " .. rank) or "Planning from skill 1")
  frame.overview:SetEnabled(activeStretch ~= 0)
  for i, control in ipairs(frame.stretches) do
    local stretch = plan.sections[i]
    control:SetShown(stretch ~= nil)
    if stretch then
      control:SetText(string.format("%d–%d", stretch.from, stretch.cap))
      control:SetEnabled(i ~= activeStretch)
    end
  end
  local cost = route.cost
  local partial = #cost.missing > 0
  local source = cost.source .. "  |  Training and vendor recipe fees separate"
  if partial then
    local missing = #cost.missing == 1 and cost.missing[1] or (#cost.missing .. " items")
    source = cost.source .. "  |  Unpriced: " .. missing
  end
  if plan.comparison then source = plan.comparison.route .. "  |  " .. source end
  if plan.tailoringRoute and not reached then source = plan.tailoringRoute .. "  |  " .. source end
  frame.priceSource:SetText(source)
  local suffix = partial and " + unpriced items" or ""
  frame.costs[1]:SetText(money(cost.gross) .. suffix)
  frame.costs[2]:SetText(signedNet(cost.net) .. (partial and " before missing costs" or ""))
  local netColor = colors.text
  if cost.net > 0 then
    netColor = colors.red
  elseif cost.net < 0 and not partial then
    netColor = colors.green
  end
  paint(frame.costs[2], netColor)
  if reached then
    frame.notes:SetText(rank and "You’ve reached this target. Raise it to see the next steps."
      or "Skill 1 needs no crafts or materials.")
  elseif activeStretch > 1 then
    frame.notes:SetText("This stretch’s shopping list assumes you kept the parts made in earlier stretches of this plan.")
  elseif plan.published then
    frame.notes:SetText("Published WoW Professions shopping list. Stretch lists use the recipe quantities. " .. plan.notes)
  else
    frame.notes:SetText(plan.notes)
  end
  frame.importButton:SetEnabled(#route.auction > 0)
  if plan.comparison then
    local comparison = plan.comparison
    local function amount(cost)
      return signedNet(cost.net) .. (#cost.missing > 0 and " + unpriced items" or "")
    end
    frame.patterns:SetText("Net to " .. plan.cap .. "  |  Optimized: " .. amount(comparison.optimized) ..
      "  |  WoW Professions: " .. amount(comparison.guide))
  elseif route.alternative then
    local incomplete = #route.selected.cost.missing + #route.alternative.cost.missing > 0
    local reason = incomplete and "Lower cost using known prices" or "Lower net cost"
    frame.patterns:SetText(reason .. " for 265–" .. route.cap .. ": " .. patternEstimate(route.selected) ..
      "\nAlternative: " .. patternEstimate(route.alternative))
  else
    frame.patterns:SetText("")
  end
  for i, control in ipairs(frame.tabs) do
    control:SetEnabled(i ~= index)
  end

  while #frame.steps < #route.steps do addStepRow() end
  for i, row in ipairs(frame.steps) do
    local step = route.steps[i]
    if step then
      row.skill:SetText(step.prep and "Prep" or string.format("%d-%d", step.from, step.to))
      row.recipe:SetText(step.recipe)
      row.crafts:SetText(step.crafts)
      row.keep:SetText(step.keep and ("Keep ×" .. step.keep) or "")
    else
      row.skill:SetText("")
      row.recipe:SetText("")
      row.crafts:SetText("")
      row.keep:SetText("")
    end
  end

  local items = { "|cffffd37aAuction House|r" }
  for _, item in ipairs(route.auction) do items[#items + 1] = item.quantity .. "  " .. item.name end
  items[#items + 1] = ""
  items[#items + 1] = "|cffffd37aVendor supplies|r"
  for _, item in ipairs(route.vendor) do
    local note = item.keep and "  |cff8fdbadKeep|r" or ""
    items[#items + 1] = item.quantity .. "  " .. item.name .. note
  end
  if #route.vendor == 0 then items[#items + 1] = "None" end
  frame.items:SetText(table.concat(items, "\n"))
  frame.stepContent:SetHeight(math.max(228, #route.steps * 27))
  frame.itemContent:SetHeight(math.max(247, frame.items:GetStringHeight() + 10))
  if not keepScroll then
    frame.stepScroll:SetVerticalScroll(0)
    frame.itemScroll:SetVerticalScroll(0)
  end
end

local function showCopy(value, heading, instructions)
  copyText = value
  frame.copyHeading:SetText(heading)
  frame.copyInstructions:SetText(instructions or "")
  frame.copyInstructions:SetShown(instructions ~= nil)
  frame.copyPanel:SetHeight(instructions and 172 or 110)
  frame.copyPanel:Show()
  frame.copyBox:SetText(copyText)
  frame.copyBox:SetFocus()
  frame.copyBox:HighlightText()
end

local function createPlanner()
  frame = CreateFrame("Frame", "ForeverProfessionPlannerFrame", UIParent, "BackdropTemplate")
  frame:SetSize(790, 643)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  }
  frame:SetBackdrop(backdrop)
  frame:SetBackdropColor(0.075, 0.085, 0.1, 1)
  frame:SetBackdropBorderColor(0.31, 0.32, 0.34, 1)
  table.insert(UISpecialFrames, frame:GetName())

  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -32, -1)
  header:SetHeight(43)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() frame:StartMoving() end)
  header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  local title = label(header, "GameFontNormalLarge", 16, 13, 420)
  title:SetText("Forever Profession Planner")
  paint(title, colors.gold)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -3, -3)
  close:SetScript("OnClick", function() frame:Hide() end)
  surface(frame, 1, 44, 788, 61, 0.13, 0.15, 0.18)
  local body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", 0, 0)
  body:SetPoint("BOTTOMRIGHT", 0, 0)
  surface(body, 1, 105, 788, 1, 0.24, 0.26, 0.29)
  surface(body, 1, 106, 146, 536, 0.10, 0.12, 0.15)

  frame.tabs = {}
  for i, route in ipairs(routes) do
    local index = i
    local tab = button(body, route.name, 12, 119 + (i - 1) * 33, 124)
    tab:SetScript("OnClick", function() showRoute(index) end)
    frame.tabs[i] = tab
  end

  label(body, "GameFontNormal", 14, 338, 120):SetText("Settings")
  label(frame, "GameFontNormalLarge", 16, 58, 100):SetText("Target skill")
  local targetInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  targetInput:SetPoint("TOPLEFT", 714, -53)
  targetInput:SetSize(56, 31)
  targetInput:SetAutoFocus(false)
  targetInput:SetNumeric(true)
  targetInput:SetMaxLetters(3)
  targetInput:SetJustifyH("CENTER")
  local targetSlider = CreateFrame("Slider", "ForeverProfessionPlannerTargetSlider", frame, "OptionsSliderTemplate")
  targetSlider:SetPoint("TOPLEFT", 127, -49)
  targetSlider:SetSize(563, 36)
  targetSlider:SetValueStep(1)
  targetSlider:SetObeyStepOnDrag(true)
  local thumb = targetSlider:GetThumbTexture()
  thumb:SetColorTexture(0.18, 0.14, 0.09, 1)
  thumb:SetSize(34, 34)
  local knob = CreateFrame("Frame", nil, targetSlider, "BackdropTemplate")
  knob:SetPoint("CENTER", thumb, "CENTER")
  knob:SetSize(32, 32)
  knob:EnableMouse(false)
  knob:SetBackdrop(backdrop)
  knob:SetBackdropColor(0.34, 0.24, 0.12, 1)
  knob:SetBackdropBorderColor(0.98, 0.79, 0.45, 1)
  for x = 9, 21, 6 do
    local grip = knob:CreateTexture(nil, "ARTWORK")
    grip:SetPoint("TOPLEFT", x, -8)
    grip:SetSize(2, 16)
    grip:SetColorTexture(0.98, 0.79, 0.45, 1)
  end
  targetSlider:HookScript("OnEnter", function() knob:SetBackdropColor(0.47, 0.32, 0.14, 1) end)
  targetSlider:HookScript("OnLeave", function() knob:SetBackdropColor(0.34, 0.24, 0.12, 1) end)
  local sliderLow = targetSlider.Low or ForeverProfessionPlannerTargetSliderLow
  local sliderHigh = targetSlider.High or ForeverProfessionPlannerTargetSliderHigh
  if sliderLow then sliderLow:SetText("1") end
  local updatingTarget = false
  local function syncTarget()
    local target = settings.rush150 and settings.rushTarget or settings.target
    local maximum = settings.rush150 and 150 or 300
    updatingTarget = true
    targetSlider:SetMinMaxValues(1, maximum)
    targetSlider:SetValue(target)
    targetInput:SetNumber(target)
    if sliderHigh then sliderHigh:SetText(maximum) end
    updatingTarget = false
  end
  syncTarget()
  local rush = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  rush:SetPoint("TOPLEFT", 12, -387)
  rush:SetSize(24, 24)
  rush:SetChecked(settings.rush150)
  local rushLabel = button(body, "Rush 150", 37, 387, 98)
  local function toggleRush(value)
    settings.rush150 = value
    if value then
      settings.rushTarget = 150
      activeStretch = 0
    end
    rush:SetChecked(value)
    syncTarget()
    showRoute(active)
  end
  rush:SetScript("OnClick", function(self) toggleRush(not not self:GetChecked()) end)
  rushLabel:SetScript("OnClick", function() toggleRush(not settings.rush150) end)
  local buy = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  buy:SetPoint("TOPLEFT", 12, -357)
  buy:SetSize(24, 24)
  buy:SetChecked(settings.preferBuying)
  local buyLabel = button(body, "Buy extras", 37, 357, 98)
  local function toggleBuying(value)
    settings.preferBuying = value
    buy:SetChecked(value)
    showRoute(active)
  end
  buy:SetScript("OnClick", function(self) toggleBuying(not not self:GetChecked()) end)
  buyLabel:SetScript("OnClick", function() toggleBuying(not settings.preferBuying) end)
  targetSlider:SetScript("OnValueChanged", function(_, value)
    if updatingTarget then return end
    local target = math.floor(value + 0.5)
    local key = settings.rush150 and "rushTarget" or "target"
    if settings[key] == target then return end
    settings[key] = target
    targetInput:SetNumber(target)
    showRoute(active)
  end)
  targetInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  targetInput:SetScript("OnEnterPressed", function(self)
    local maximum = settings.rush150 and 150 or 300
    targetSlider:SetValue(math.min(maximum, math.max(1, self:GetNumber())))
    self:ClearFocus()
  end)
  targetInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  targetInput:SetScript("OnEditFocusLost", function(self) self:SetNumber(targetSlider:GetValue()) end)
  local training = label(body, "GameFontHighlightSmall", 14, 419, 120)
  training:SetText("Rush 150 picks the lower net cost. Buy extras allows up to 10% above ingredient cost.")
  paint(training, colors.muted)
  frame.currentSkill = label(body, "GameFontNormal", 14, 484, 120)
  local inventoryNote = label(body, "GameFontHighlightSmall", 14, 505, 120)
  inventoryNote:SetText("Check your bags before buying materials.")
  paint(inventoryNote, colors.muted)
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
  frame:SetScript("OnEvent", function()
    if frame:IsShown() and playerSkill(routes[active].name) ~= displayedSkill then
      activeStretch = 0
      showRoute(active)
    end
  end)

  frame.overview = button(body, "Overview", 163, 116, 108)
  frame.overview:SetScript("OnClick", function()
    activeStretch = 0
    showRoute(active)
  end)
  frame.stretches = {}
  for i = 1, 4 do
    local stretchIndex = i
    local tab = button(body, "", 277 + (i - 1) * 105, 116, 99)
    tab:SetScript("OnClick", function()
      activeStretch = stretchIndex
      showRoute(active)
    end)
    frame.stretches[i] = tab
  end
  frame.routeTitle = label(body, "GameFontNormalLarge", 163, 150, 385)
  local refresh = button(body, "Refresh prices", 653, 143, 119)
  refresh:SetScript("OnClick", function() showRoute(active, true) end)
  frame.priceSource = label(body, "GameFontHighlightSmall", 163, 177, 609)
  paint(frame.priceSource, colors.muted)

  frame.costs = {}
  for i, caption in ipairs({ "Shopping cost", "After vendor sales" }) do
    local x = 163 + (i - 1) * 309
    surface(body, x, 199, 300, 56, 0.13, 0.15, 0.18)
    local heading = label(body, "GameFontHighlightSmall", x + 10, 208, 280)
    heading:SetText(caption)
    paint(heading, colors.muted)
    frame.costs[i] = label(body, "GameFontNormalLarge", x + 10, 227, 280)
    paint(frame.costs[i], colors.red)
  end

  surface(body, 163, 270, 360, 260, 0.105, 0.12, 0.14)
  surface(body, 533, 270, 239, 260, 0.105, 0.12, 0.14)
  label(body, "GameFontNormal", 173, 279, 65):SetText("Skill")
  label(body, "GameFontNormal", 234, 279, 213):SetText("Recipe")
  label(body, "GameFontNormal", 451, 279, 64):SetText("Crafts ~")
  frame.stepScroll, frame.stepContent = scrollArea(body, 173, 297, 321, 228)
  frame.itemScroll, frame.itemContent = scrollArea(body, 544, 279, 199, 247)
  frame.steps = {}

  frame.items = label(frame.itemContent, "GameFontHighlightSmall", 0, 0, 194)
  frame.items:SetSpacing(3)

  frame.notes = label(body, "GameFontHighlightSmall", 163, 537, 609)
  paint(frame.notes, colors.muted)
  frame.patterns = label(body, "GameFontHighlightSmall", 163, 574, 609)
  frame.patterns:SetSpacing(2)
  local guideSource = label(body, "GameFontHighlightSmall", 163, 616, 302)
  guideSource:SetJustifyH("RIGHT")
  guideSource:SetText("Default guides from WoW Professions")
  paint(guideSource, colors.muted)
  local guide = button(body, "Copy guide link", 477, 609, 126)
  guide:SetScript("OnClick", function()
    showCopy(selectedPlan.url, "Copy this WoW Professions guide link with Ctrl+C.")
  end)
  local copy = button(body, "Export shopping list", 610, 609, 162)
  frame.importButton = copy
  copy:SetScript("OnClick", function()
    showCopy(addon.ImportString(selectedPlan), "Import into Auctionator",
      "1. Press Ctrl+C to copy the selected list.\n" ..
      "2. Open the Auction House, select the Shopping tab, and click Import.\n" ..
      "3. Press Ctrl+V to paste the list, then click Import.")
  end)

  frame.copyPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.copyPanel:SetFrameLevel(frame:GetFrameLevel() + 8)
  frame.copyPanel:SetSize(584, 110)
  frame.copyPanel:SetPoint("CENTER")
  frame.copyPanel:EnableMouse(true)
  frame.copyPanel:SetBackdrop(backdrop)
  frame.copyPanel:SetBackdropColor(0.09, 0.11, 0.13, 1)
  frame.copyPanel:SetBackdropBorderColor(0.48, 0.42, 0.31, 1)
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
  frame:Hide()
end

SLASH_FOREVERPROFESSIONPLANNER1 = "/foreverprof"
SLASH_FOREVERPROFESSIONPLANNER2 = "/fpp"
SlashCmdList.FOREVERPROFESSIONPLANNER = function(message)
  if not frame then
    if type(ForeverProfessionPlannerSettings) ~= "table" then ForeverProfessionPlannerSettings = {} end
    settings = ForeverProfessionPlannerSettings
    if type(settings.preferBuying) ~= "boolean" then settings.preferBuying = true end
    if type(settings.rush150) ~= "boolean" then settings.rush150 = false end
    settings.rushTarget = math.min(150, math.max(1, math.floor(tonumber(settings.rushTarget) or 150)))
    local legacyTarget = settings.stopAt150 == false and settings.fullTarget or settings.shortTarget
    settings.target = math.min(300, math.max(1, math.floor(tonumber(settings.target) or tonumber(legacyTarget) or 150)))
    settings.stopAt150, settings.shortTarget, settings.fullTarget = nil, nil, nil
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
