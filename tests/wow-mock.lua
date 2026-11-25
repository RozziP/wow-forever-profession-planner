-- Model the UI and game state needed to drive the planner's public entry points.
local wow = { addon = {}, professions = {}, prices = {}, bags = {}, now = 50 }
FPT_TEST = wow

local addonName = "ForeverProfessionPlanner"
local function noop() end
local methods = {}
local widgetMetatable = {
  __index = function(_, key)
    -- Visual setters are outside the scope of the host tests.
    return methods[key] or (key:match("^Set") and noop) or nil
  end,
}

local function widget(name, parent)
  return setmetatable({
    name = name, parent = parent, shown = true, width = 200, height = 40,
    scale = 1, scroll = 0, level = 1, scripts = {}, hooks = {}, events = {},
  }, widgetMetatable)
end

function methods:CreateFontString() return widget(nil, self) end
methods.CreateTexture = methods.CreateFontString
methods.CreateAnimationGroup = methods.CreateFontString
methods.CreateAnimation = methods.CreateFontString
function methods:Play() self.plays = (self.plays or 0) + 1; self.playing = true end
function methods:Stop() self.playing = false end
function methods:IsPlaying() return self.playing end
methods.Raise = noop
methods.EnableMouse = noop
methods.EnableMouseWheel = noop
methods.RegisterForDrag = noop
methods.RegisterForClicks = noop
methods.UpdateScrollChildRect = noop
methods.ClearAllPoints = noop
methods.ClearFocus = noop
methods.HighlightText = noop
methods.AddLine = noop
function methods:SetOwner(owner)
  assert(type(owner) == "table", "Tooltip owner must be a frame")
  self.owner = owner
end
function methods:IsOwned(owner)
  assert(type(owner) == "table", "Tooltip ownership check requires a frame")
  return self.owner == owner
end

function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, callback)
  self.hooks[event] = self.hooks[event] or {}
  table.insert(self.hooks[event], callback)
end
function methods:RunScript(event, ...)
  if self.scripts[event] then self.scripts[event](self, ...) end
  for _, hook in ipairs(self.hooks[event] or {}) do hook(self, ...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:RegisterUnitEvent(event, unit) self.events[event] = unit end
function methods:UnregisterEvent(event) self.events[event] = nil end

function methods:SetShown(shown)
  if self.shown == shown then return end
  self.shown = shown
  self:RunScript(shown and "OnShow" or "OnHide")
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetSize() return self.width, self.height end
function methods:SetWidth(width) self.width = width end
function methods:GetWidth() return self.width end
function methods:SetHeight(height) self.height = height end
function methods:GetHeight() return self.height end
function methods:SetScale(scale) self.scale = scale end
function methods:GetScale() return self.scale end
methods.GetEffectiveScale = methods.GetScale
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:GetFont() return "mock.ttf", 12, "" end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text or "" end
function methods:SetFormattedText(format, ...) self:SetText(format:format(...)) end
function methods:GetStringWidth() return #self:GetText() * 6 end
methods.GetUnboundedStringWidth = methods.GetStringWidth
function methods:GetStringHeight() return 12 end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll end
function methods:GetVerticalScrollRange() return 1000 end
function methods:SetChecked(checked) self.checked = checked end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetCustomOnMouseUpHandler(callback) self.mouseUp = callback end

function methods:SetValue(value)
  if self.minimum then value = math.max(self.minimum, math.min(self.maximum, value)) end
  if self.value == value then return end
  self.value = value
  self:RunScript("OnValueChanged", value)
end
function methods:SetMinMaxValues(minimum, maximum)
  self.minimum, self.maximum = minimum, maximum
  self:SetValue(self.value or minimum)
end

local buttons = {}
function CreateFrame(kind, name, parent, template)
  local frame = widget(name, parent)
  if name then _G[name] = frame end
  if template == "PortraitFrameTemplate" then
    frame.Bg = widget(nil, frame)
    frame.PortraitContainer = { portrait = widget(nil, frame) }
    frame.TitleContainer = widget(nil, frame)
    frame.TitleContainer.TitleText = widget(nil, frame.TitleContainer)
    frame.CloseButton = widget(nil, frame)
  elseif template == "UIPanelScrollFrameTemplate" then
    frame.ScrollBar = widget(nil, frame)
  elseif template == "LargeSideTabButtonTemplate" then
    frame.Icon, frame.Background = widget(nil, frame), widget(nil, frame)
  end
  if kind == "Slider" then wow.slider = frame end
  if kind == "Button" then buttons[#buttons + 1] = frame end
  return frame
end

function wow.button(text)
  for _, button in ipairs(buttons) do
    if button:GetText() == text then return button end
  end
  error("Missing button " .. text)
end

function wow.event(frame, event, ...)
  assert(frame.events[event], "Planner did not register " .. event)
  frame:RunScript("OnEvent", event, ...)
end

local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
function wow.flushTimers()
  local pending = timers
  timers = {}
  for _, callback in ipairs(pending) do callback() end
end

unpack = table.unpack or unpack
CreateFont = widget
GameFontHighlight = widget()
GameTooltip = widget()
UIParent = widget()
UIParent:SetSize(1920, 1080)
UISpecialFrames, SlashCmdList = {}, {}
SidePanelTabButtonMixin = { CalculateTabSizeBasedOnTabArt = function() return 60 end }
EventUtil = { ContinueOnAddOnLoaded = noop }
BNGetInfo = noop
ChatTypeInfo = { SKILL = { r = 0.33, g = 0.67, b = 1 } }
function UnitFactionGroup() return "Alliance" end
function GetTime() return wow.now end
function UnitCastingInfo()
  local cast = wow.cast
  if cast then return cast.name, nil, nil, cast.startTime, cast.endTime, true, cast.id, nil, cast.spellID end
end
function GetProfessions()
  return wow.professions[1] and 1, wow.professions[2] and 2, nil, wow.professions[4] and 4
end
function GetProfessionInfo(index)
  local profession = wow.professions[index]
  return profession.name, nil, profession.rank, profession.maximum, nil, nil, profession.skillLine
end
C_Item = { GetItemCount = function(id) return wow.bags[id] or 0 end }
Auctionator = { API = { v1 = {
  GetAuctionPriceByItemID = function(_, id) return wow.prices[id] or wow.defaultPrice end,
} } }

function wow.equal(actual, expected, description)
  if actual ~= expected then
    error(description .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function wow.loadAddon()
  for _, file in ipairs(FPT_ADDON_FILES) do
    assert(loadfile(file))(addonName, wow.addon)
  end
  return wow.addon
end
