local addonName, addon = ...
local media = "Interface\\AddOns\\" .. addonName .. "\\BaltoTheme\\"
local playEntrance

local function createEntrance(window)
  local overlay = CreateFrame("Frame", nil, UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("TOOLTIP")
  overlay:EnableMouse(false)
  overlay:Hide()

  local car = overlay:CreateTexture(nil, "ARTWORK")
  -- Disney/Pixar character render, https://www.pngfind.com/mpng/ihwhJ_disney-cars-png-lightning-mcqueen-disney-cars-clipart/
  car:SetTexture(media .. "McQueenDriveBy.tga")

  local function positionCar(progress)
    local width, height = UIParent:GetSize()
    local carWidth = math.min(width * 0.24, height * 0.34)
    car:SetSize(carWidth, carWidth / 2)
    local x = (width + carWidth) * progress - carWidth / 2
    car:SetPoint("CENTER", overlay, "BOTTOMLEFT", x, height * 0.32)
  end

  local duration = 2.8
  local elapsed = 0
  overlay:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed >= duration then
      self:Hide()
      return
    end
    positionCar(elapsed / duration)
  end)

  local sound
  local function stopSound()
    if sound then StopSound(sound) end
    sound = nil
  end
  window:HookScript("OnHide", function()
    overlay:Hide()
    stopSound()
  end)

  return function()
    stopSound()
    elapsed = 0
    positionCar(0)
    overlay:Show()
    -- Lightning McQueen in Cars (2006), https://www.101soundboards.com/sounds/9606776-ka-chow
    local _, handle = PlaySoundFile(media .. "KaChow.mp3", "SFX")
    sound = handle
  end
end

function addon.PlayBaltoEntrance(window)
  if not playEntrance then playEntrance = createEntrance(window) end
  playEntrance()
end

function addon.ApplyBaltoTheme(window)
  window:HookScript("OnShow", addon.PlayBaltoEntrance)
  if window:IsVisible() then addon.PlayBaltoEntrance(window) end
end
