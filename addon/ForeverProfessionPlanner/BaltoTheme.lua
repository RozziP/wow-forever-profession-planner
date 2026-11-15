local addonName, addon = ...
local media = "Interface\\AddOns\\" .. addonName .. "\\BaltoTheme\\"
local backgroundAspect = 1500 / 1112
local carAspect = 1942 / 809

local function cropBackground(window)
  local width, height = window.Bg:GetSize()
  if width <= 0 or height <= 0 then return end

  local aspect = width / height
  local cropX = (1 - math.min(1, aspect / backgroundAspect)) / 2
  local cropY = (1 - math.min(1, backgroundAspect / aspect)) / 2
  window.Bg:SetTexCoord(cropX, 1 - cropX, cropY, 1 - cropY)
end

local function createTraffic(window)
  local overlay = CreateFrame("Frame", nil, window)
  overlay:SetAllPoints(window.Bg)
  overlay:SetUsingParentLevel(true)
  overlay:SetClipsChildren(true)
  overlay:EnableMouse(false)
  overlay:Hide()

  local cars = {
    { lane = 0.27, width = 212, delay = 0, duration = 2.6, direction = 1 },
    { lane = 0.68, width = 178, delay = 0.24, duration = 2.9, direction = -1 },
    { lane = 0.44, width = 194, delay = 0.69, duration = 2.4, direction = 1 },
  }
  for _, car in ipairs(cars) do
    local texture = overlay:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(media .. "HotRod.tga")
    texture:SetSize(car.width, car.width / carAspect)
    if car.direction < 0 then texture:SetTexCoord(1, 0, 0, 1) end
    texture:Hide()
    car.texture = texture
  end

  local elapsed = 0
  local function update(self, delta)
    elapsed = elapsed + delta
    local width, height = self:GetSize()
    local pending = false
    for _, car in ipairs(cars) do
      local progress = (elapsed - car.delay) / car.duration
      local visible = progress >= 0 and progress < 1
      if visible then
        local distance = (width + car.width) * progress - car.width / 2
        local x = car.direction == 1 and distance or width - distance
        car.texture:SetPoint("CENTER", self, "BOTTOMLEFT", x, height * car.lane)
      end
      car.texture:SetShown(visible)
      pending = pending or progress < 1
    end
    if not pending then self:Hide() end
  end
  overlay:SetScript("OnUpdate", update)

  local function start()
    elapsed = 0
    update(overlay, 0)
    overlay:Show()
  end

  return overlay, start
end

function addon.ApplyBaltoTheme(window)
  -- Lightning McQueen film still from Pixar's Cars gallery (https://www.pixar.com/cars).
  window.Bg:SetTexture(media .. "LightningMcQueen.tga")
  window.Bg:SetVertexColor(0.76, 0.63, 0.51)
  cropBackground(window)
  window:HookScript("OnSizeChanged", cropBackground)
  for _, inset in ipairs(window.themeInsets) do
    inset:SetBackdropColor(0.08, 0.043, 0.028, 0.36)
    inset.shading:SetAlpha(0.35)
    inset:SetBackdropBorderColor(1, 0.72, 0.30, 1)
  end

  local overlay, startTraffic = createTraffic(window)
  local horn
  local function playEntrance()
    startTraffic()
    -- Car Horn Beeps by hsaunier10 (CC0), https://freesound.org/people/hsaunier10/sounds/254678/
    local _, handle = PlaySoundFile(media .. "CarHorns.mp3", "SFX")
    horn = handle
  end

  window:HookScript("OnShow", playEntrance)
  window:HookScript("OnHide", function()
    overlay:Hide()
    if horn then StopSound(horn) end
    horn = nil
  end)
  if window:IsVisible() then playEntrance() end
end
