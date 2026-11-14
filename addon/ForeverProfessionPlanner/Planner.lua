local _, addon = ...
local routes = addon.routes
local professionSkillLines = {
  Alchemy = 171, Blacksmithing = 164, Enchanting = 333,
  Engineering = 202, Leatherworking = 165, Tailoring = 197,
}

local frame
local active = 1
local activeStretch = 0
local displayedSkill, displayedSkillCap
local startingSkills = {}
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
  if cost.net == nil then return choice.name .. " (unpriced)" end
  local amount = signedNet(cost.net)
  if cost.net > 0 then
    amount = "|cffff736b" .. amount .. "|r"
  elseif cost.net < 0 then
    amount = "|cff8fdbad" .. amount .. "|r"
  end
  return choice.name .. " (" .. amount .. ")"
end

local function addStepRow()
  local y = 3 + #frame.steps * 27
  local highlight = surface(frame.stepContent, 0, y - 2, 1, 26, 0.22, 0.19, 0.13)
  highlight:SetPoint("TOPRIGHT", 0, -(y - 2))
  highlight:Hide()
  local skill = label(frame.stepContent, "GameFontHighlight", 0, y, 59)
  local recipe = label(frame.stepContent, "GameFontHighlight", 68, y, 215)
  local keep = label(frame.stepContent, "GameFontHighlightSmall", 68, y + 14, 215)
  recipe:SetPoint("TOPRIGHT", -52, -y)
  keep:SetPoint("TOPRIGHT", -52, -(y + 14))
  recipe:SetMaxLines(1)
  paint(keep, colors.green)
  local crafts = label(frame.stepContent, "GameFontHighlight", 0, y, 44)
  crafts:ClearAllPoints()
  crafts:SetPoint("TOPRIGHT", -4, -y)
  paint(skill, colors.gold)
  crafts:SetJustifyH("RIGHT")
  frame.steps[#frame.steps + 1] = { skill = skill, recipe = recipe, crafts = crafts, keep = keep, highlight = highlight }
end

local function playerSkill(profession)
  if not GetProfessions or not GetProfessionInfo then return end
  local wanted = professionSkillLines[profession]
  for _, index in pairs({ GetProfessions() }) do
    local _, _, rank, maximum, _, _, skillLine = GetProfessionInfo(index)
    if skillLine == wanted and type(rank) == "number" and rank > 0 then return rank, maximum end
  end
end

local function updateScrollAreas()
  local stepWidth, stepHeight = frame.stepScroll:GetSize()
  local itemWidth, itemHeight = frame.itemScroll:GetSize()
  frame.stepContent:SetSize(stepWidth, math.max(stepHeight, (frame.stepCount or 0) * 27 + 3))
  frame.itemContent:SetWidth(itemWidth)
  frame.items:SetWidth(itemWidth - 4)
  frame.itemContent:SetHeight(math.max(itemHeight, frame.items:GetStringHeight() + 10))
  for _, scroll in ipairs({ frame.stepScroll, frame.itemScroll }) do
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
  end
end

local function showProgress(plan, rank, maximum)
  local startingSkill = startingSkills[active]
  local remaining = rank and math.max(0, plan.cap - rank)
  local progress = rank and string.format("Skill %d  |  Target %d", rank, plan.cap) or "Planning from skill 1"
  if remaining and remaining > 0 then progress = progress .. string.format("  |  %d to target", remaining) end
  if rank and startingSkill and rank > startingSkill then
    progress = progress .. string.format("  |cff8fdbad+%d this session|r", rank - startingSkill)
  end
  frame.progressText:SetText(progress)
  frame.progressBar:SetMinMaxValues(0, plan.cap)
  frame.progressBar:SetValue(rank and math.min(rank, plan.cap) or 0)

  local nextStep
  for _, step in ipairs(plan.steps) do
    if not step.prep then
      nextStep = step
      break
    end
  end
  if remaining == 0 then
    frame.nextAction:SetText("Target reached")
    frame.actionDetail:SetText("Raise the target to see more steps.")
  elseif not rank then
    frame.nextAction:SetText("Learn " .. plan.name .. " to track your skill")
    frame.actionDetail:SetText("The route and materials below are for planning.")
  elseif type(maximum) == "number" and maximum > 0 and rank >= maximum then
    frame.nextAction:SetText("Train the next " .. plan.name .. " rank")
    frame.actionDetail:SetText(string.format("You've reached your trained cap of %d.", maximum))
  elseif nextStep then
    frame.nextAction:SetText("Next: " .. nextStep.recipe)
    local untilSkill = type(maximum) == "number" and maximum > 0 and math.min(maximum, nextStep.to) or nextStep.to
    local detail = string.format("Until skill %d  |  ~%d crafts for this step", untilSkill, nextStep.crafts)
    if untilSkill < nextStep.to then detail = string.format("Craft to skill %d, then train to continue.", untilSkill) end
    if nextStep.keep then detail = detail .. string.format("  |  Keep x%d", nextStep.keep) end
    local sharedRange
    for _, step in ipairs(plan.steps) do
      if step ~= nextStep and step.from == nextStep.from and step.to == nextStep.to then
        sharedRange = step
        break
      end
    end
    if sharedRange then
      frame.nextAction:SetText("Next: " .. nextStep.recipe .. " and " .. sharedRange.recipe)
      detail = string.format("Use both recipes until skill %d  |  See estimates in the recipe list", untilSkill)
      if untilSkill < nextStep.to then detail = string.format("Craft to skill %d, then train to continue.", untilSkill) end
    elseif nextStep ~= plan.steps[1] then
      detail = detail .. "  |  Check prep rows for components"
    end
    frame.actionDetail:SetText(detail)
    return nextStep, sharedRange
  else
    frame.nextAction:SetText("No crafting step available")
    frame.actionDetail:SetText("Check the profession guide for this skill range.")
  end
end

local function showRoute(index, keepScroll, stretchCap)
  if active ~= index then activeStretch = 0 end
  active = index
  local rank, maximum = playerSkill(routes[index].name)
  displayedSkill, displayedSkillCap = rank, maximum
  if not rank or not startingSkills[index] or rank < startingSkills[index] then startingSkills[index] = rank end
  local target = settings.rush150 and settings.rushTarget or settings.target
  local plan = addon.GetPlan(index, settings.rush150, target, settings.preferBuying, rank)
  if stretchCap then
    activeStretch = 0
    for i, stretch in ipairs(plan.sections) do
      if stretch.cap == stretchCap then
        activeStretch = i
        break
      end
    end
    if activeStretch == 0 then keepScroll = false end
  end
  if activeStretch > #plan.sections then activeStretch = #plan.sections end
  local route = plan.sections[activeStretch] or plan
  selectedPlan = route
  if not keepScroll and frame.copyPanel then frame.copyPanel:Hide() end
  local reached = plan.from >= plan.cap
  if reached then
    frame.routeTitle:SetText(string.format("%s - Target %d", plan.name, plan.cap))
  else
    frame.routeTitle:SetText(string.format("%s %d-%d", route.name, route.from, route.cap))
  end
  local nextStep, sharedStep = showProgress(plan, rank, maximum)
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
  local source = ""
  local netColor = colors.muted
  if cost.net ~= nil then
    source = "Auctionator cached prices  |  Training and vendor recipe fees separate"
    netColor = cost.net > 0 and colors.red or (cost.net < 0 and colors.green or colors.text)
  elseif #route.auction > 0 then
    if cost.available then
      local missing = #cost.missing == 1 and cost.missing[1] or (#cost.missing .. " items")
      source = "Missing Auctionator prices: " .. missing .. "  |  Scan the Auction House, then refresh"
    else
      source = "Auctionator required for prices"
    end
  end
  local routeLabel = plan.comparison and plan.comparison.route or plan.tailoringRoute
  if routeLabel and not reached then
    source = source ~= "" and (routeLabel .. "  |  " .. source) or routeLabel
  end
  frame.priceSource:SetText(source)
  frame.costs[1]:SetText(cost.gross and money(cost.gross) or "—")
  frame.costs[2]:SetText(cost.net and signedNet(cost.net) or "—")
  paint(frame.costs[1], cost.gross and colors.red or colors.muted)
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
      return cost.net and signedNet(cost.net) or "unpriced"
    end
    frame.patterns:SetText("Net to " .. plan.cap .. "  |  Optimized: " .. amount(comparison.optimized) ..
      "  |  WoW Professions: " .. amount(comparison.guide))
  elseif route.alternative then
    local net, alternativeNet = route.selected.cost.net, route.alternative.cost.net
    local reason = net and alternativeNet and net < alternativeNet and "Lower net cost" or "Selected route"
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
    row.highlight:SetShown(step ~= nil and (step == nextStep or step == sharedStep))
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
  frame.stepCount = #route.steps
  updateScrollAreas()
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
  local minWidth, minHeight = 750, 620
  local maxWidth = math.max(minWidth, UIParent:GetWidth() - 24)
  local maxHeight = math.max(minHeight, UIParent:GetHeight() - 24)
  frame = CreateFrame("Frame", "ForeverProfessionPlannerFrame", UIParent, "BackdropTemplate")
  frame:SetSize(math.min(maxWidth, math.max(minWidth, tonumber(settings.windowWidth) or 790)),
    math.min(maxHeight, math.max(minHeight, tonumber(settings.windowHeight) or 706)))
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
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
  title:SetText("Forever Profession Trainer")
  paint(title, colors.gold)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -3, -3)
  close:SetScript("OnClick", function() frame:Hide() end)
  local body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", 0, 0)
  body:SetPoint("BOTTOMRIGHT", 0, 0)
  local targetBackground = surface(body, 1, 80, 788, 48, 0.13, 0.15, 0.18)
  targetBackground:SetPoint("TOPRIGHT", -1, -80)

  frame.tabs = {}
  for i, route in ipairs(routes) do
    local index = i
    local tab = button(body, route.name, 18, 47, 110)
    tab:SetScript("OnClick", function() showRoute(index) end)
    frame.tabs[i] = tab
  end

  label(body, "GameFontNormal", 18, 97, 82):SetText("Target skill")
  local targetInput = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
  targetInput:SetPoint("TOPRIGHT", -249, -87)
  targetInput:SetSize(56, 31)
  targetInput:SetAutoFocus(false)
  targetInput:SetNumeric(true)
  targetInput:SetMaxLetters(3)
  targetInput:SetJustifyH("CENTER")
  local targetSlider = CreateFrame("Slider", "ForeverProfessionPlannerTargetSlider", body, "OptionsSliderTemplate")
  targetSlider:SetPoint("TOPLEFT", 110, -84)
  targetSlider:SetPoint("TOPRIGHT", -325, -84)
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
  local function settingTooltip(control, caption, detail)
    control:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(caption)
      GameTooltip:AddLine(detail, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local rush = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  rush:SetPoint("TOPRIGHT", -205, -91)
  rush:SetSize(24, 24)
  rush:SetChecked(settings.rush150)
  local rushLabel = button(body, "Rush 150", 0, 91, 79)
  rushLabel:ClearAllPoints()
  rushLabel:SetPoint("LEFT", rush, "RIGHT", 2, 0)
  settingTooltip(rush, "Rush 150", "Compare priced routes to skill 150.")
  settingTooltip(rushLabel, "Rush 150", "Compare priced routes to skill 150.")
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
  buy:SetPoint("TOPRIGHT", -105, -91)
  buy:SetSize(24, 24)
  buy:SetChecked(settings.preferBuying)
  local buyLabel = button(body, "Buy extras", 0, 91, 85)
  buyLabel:ClearAllPoints()
  buyLabel:SetPoint("LEFT", buy, "RIGHT", 2, 0)
  settingTooltip(buy, "Buy extras", "Allow up to 10% above ingredient cost.")
  settingTooltip(buyLabel, "Buy extras", "Allow up to 10% above ingredient cost.")
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
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:RegisterEvent("CHAT_MSG_SKILL")
  frame:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
  local refreshPending
  frame:SetScript("OnEvent", function(self)
    if not self:IsShown() or refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
      refreshPending = nil
      if not self:IsShown() then return end
      local rank, maximum = playerSkill(routes[active].name)
      if rank ~= displayedSkill or maximum ~= displayedSkillCap then
        showRoute(active, true, activeStretch ~= 0 and selectedPlan.cap or nil)
      end
    end)
  end)

  frame.overview = button(body, "Overview", 18, 135, 92)
  frame.overview:SetScript("OnClick", function()
    activeStretch = 0
    showRoute(active)
  end)
  frame.stretches = {}
  for i = 1, 4 do
    local stretchIndex = i
    local tab = button(body, "", 116 + (i - 1) * 83, 135, 77)
    tab:SetScript("OnClick", function()
      activeStretch = stretchIndex
      showRoute(active)
    end)
    frame.stretches[i] = tab
  end
  frame.routeTitle = label(body, "GameFontNormalLarge", 456, 139, 262)
  frame.routeTitle:SetPoint("TOPRIGHT", -18, -139)
  frame.routeTitle:SetJustifyH("RIGHT")
  local progressBackground = surface(body, 18, 166, 754, 64, 0.13, 0.15, 0.18)
  progressBackground:SetPoint("TOPRIGHT", -18, -166)
  frame.progressText = label(body, "GameFontNormal", 29, 172, 732)
  frame.progressText:SetPoint("TOPRIGHT", -29, -172)
  frame.progressBar = CreateFrame("StatusBar", nil, body)
  frame.progressBar:SetPoint("TOPLEFT", 29, -188)
  frame.progressBar:SetPoint("TOPRIGHT", -29, -188)
  frame.progressBar:SetHeight(4)
  frame.progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  frame.progressBar:SetStatusBarColor(unpack(colors.green))
  local track = frame.progressBar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0.24, 0.27, 0.30, 1)
  frame.nextAction = label(body, "GameFontNormalLarge", 29, 197, 732)
  frame.nextAction:SetPoint("TOPRIGHT", -29, -197)
  frame.actionDetail = label(body, "GameFontHighlightSmall", 29, 215, 732)
  frame.actionDetail:SetPoint("TOPRIGHT", -29, -215)

  local stepPanel = CreateFrame("Frame", nil, body)
  stepPanel:SetPoint("TOPLEFT", 18, -240)
  local stepBackground = surface(stepPanel, 0, 0, 1, 1, 0.12, 0.14, 0.17)
  stepBackground:SetAllPoints()
  local itemPanel = CreateFrame("Frame", nil, body)
  itemPanel:SetPoint("TOPRIGHT", -18, -240)
  local itemBackground = surface(itemPanel, 0, 0, 1, 1, 0.10, 0.12, 0.14)
  itemBackground:SetAllPoints()
  label(stepPanel, "GameFontNormalLarge", 12, 10, 220):SetText("Recipe list")
  label(stepPanel, "GameFontNormal", 12, 34, 59):SetText("Skill")
  label(stepPanel, "GameFontNormal", 80, 34, 180):SetText("Recipe")
  local craftsHeading = label(stepPanel, "GameFontNormal", 0, 34, 65)
  craftsHeading:ClearAllPoints()
  craftsHeading:SetPoint("TOPRIGHT", -42, -34)
  craftsHeading:SetJustifyH("RIGHT")
  craftsHeading:SetText("Est. crafts")
  frame.stepScroll, frame.stepContent = scrollArea(stepPanel, 12, 51, 1, 1)
  frame.itemScroll, frame.itemContent = scrollArea(itemPanel, 12, 127, 1, 1)
  frame.steps = {}

  frame.items = label(frame.itemContent, "GameFontHighlightSmall", 0, 0, 1)
  frame.items:SetSpacing(3)

  label(itemPanel, "GameFontNormal", 12, 10, 170):SetText("Shopping list")
  frame.costs = {}
  for i, caption in ipairs({ "Shopping cost", "After vendor sales" }) do
    local y = 72 + (i - 1) * 16
    local heading = label(itemPanel, "GameFontHighlightSmall", 12, y, 100)
    heading:SetText(caption)
    paint(heading, colors.muted)
    local value = label(itemPanel, "GameFontHighlightSmall", 0, y, 76)
    value:ClearAllPoints()
    value:SetPoint("TOPRIGHT", -12, -y)
    value:SetJustifyH("RIGHT")
    frame.costs[i] = value
  end
  local refresh = button(itemPanel, "Refresh prices", 12, 101, 112)
  refresh:SetHeight(21)
  refresh:SetScript("OnClick", function() showRoute(active, true) end)

  frame.priceSource = label(body, "GameFontHighlightSmall", 18, 0, 754)
  frame.priceSource:ClearAllPoints()
  frame.priceSource:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 18, 120)
  frame.priceSource:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", -18, 120)
  paint(frame.priceSource, colors.muted)
  frame.notes = label(body, "GameFontHighlightSmall", 18, 0, 754)
  frame.notes:ClearAllPoints()
  frame.notes:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 18, 91)
  frame.notes:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", -18, 91)
  paint(frame.notes, colors.muted)
  frame.patterns = label(body, "GameFontHighlightSmall", 18, 0, 754)
  frame.patterns:ClearAllPoints()
  frame.patterns:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 18, 57)
  frame.patterns:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", -18, 57)
  frame.patterns:SetSpacing(2)
  local inventoryNote = label(body, "GameFontHighlightSmall", 18, 0, 280)
  inventoryNote:ClearAllPoints()
  inventoryNote:SetPoint("BOTTOMLEFT", 18, 15)
  inventoryNote:SetText("Check your bags before buying materials.")
  paint(inventoryNote, colors.muted)
  local guideSource = label(body, "GameFontHighlightSmall", 18, 0, 245)
  guideSource:SetJustifyH("RIGHT")
  guideSource:SetText("Default guides from WoW Professions")
  paint(guideSource, colors.muted)
  local guide = button(body, "Copy guide link", 0, 0, 126)
  guide:ClearAllPoints()
  guide:SetPoint("BOTTOMRIGHT", -18, 10)
  guideSource:ClearAllPoints()
  guideSource:SetPoint("RIGHT", guide, "LEFT", -12, 0)
  guide:SetScript("OnClick", function()
    showCopy(selectedPlan.url, "Copy this WoW Professions guide link with Ctrl+C.")
  end)
  local copy = CreateFrame("Button", nil, itemPanel, "BackdropTemplate")
  copy:SetPoint("TOPLEFT", 12, -27)
  copy:SetPoint("TOPRIGHT", -12, -27)
  copy:SetHeight(37)
  copy:SetBackdrop(backdrop)
  local copyLabel = copy:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  copyLabel:SetPoint("CENTER")
  copy:SetFontString(copyLabel)
  copy:SetNormalFontObject(GameFontHighlightLarge)
  copy:SetDisabledFontObject(GameFontDisable)
  copy:SetText("Export shopping list")
  local function styleExport(self)
    if self:IsEnabled() then
      if self:IsMouseOver() then
        self:SetBackdropColor(0.56, 0.34, 0.11, 1)
      else
        self:SetBackdropColor(0.42, 0.25, 0.08, 1)
      end
      self:SetBackdropBorderColor(unpack(colors.gold))
    else
      self:SetBackdropColor(0.16, 0.17, 0.19, 1)
      self:SetBackdropBorderColor(0.30, 0.31, 0.33, 1)
    end
  end
  for _, event in ipairs({ "OnEnter", "OnLeave", "OnEnable", "OnDisable" }) do
    copy:SetScript(event, styleExport)
  end
  styleExport(copy)
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
    local tabWidth = (contentWidth - (#frame.tabs - 1) * 6) / #frame.tabs
    for i, tab in ipairs(frame.tabs) do
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", 18 + (i - 1) * (tabWidth + 6), -47)
      tab:SetWidth(tabWidth)
    end
    local itemWidth = math.min(266, math.max(205, math.floor(contentWidth * 0.28)))
    local stepWidth = contentWidth - 10 - itemWidth
    local panelHeight = height - 367
    stepPanel:SetSize(stepWidth, panelHeight)
    itemPanel:SetSize(itemWidth, panelHeight)
    frame.stepScroll:SetSize(stepWidth - 40, panelHeight - 59)
    frame.itemScroll:SetSize(itemWidth - 40, panelHeight - 135)
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
