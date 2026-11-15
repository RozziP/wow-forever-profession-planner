local scripts = {
  -- ["YourCharacter"] = function()
  --   print("Character script ran.")
  -- end,

  -- ["YourCharacter-YourRealm"] = function()
  --   SlashCmdList.FOREVERPROFESSIONTRAINER("alchemy")
  -- end,
}

local battleTagScripts = {
  -- ["YourBattleTag#1234"] = function()
  --   print("Account script ran.")
  -- end,
}

local hasBattleTagScripts = next(battleTagScripts) ~= nil and BNGetInfo ~= nil
if not next(scripts) and not hasBattleTagScripts then return end

local function runCharacterScript()
  local name, realm = UnitFullName("player")
  if not name then return end
  if not realm or realm == "" then realm = GetNormalizedRealmName() end

  local run = (realm and scripts[name .. "-" .. realm]) or scripts[name]
  if run then run() end
end

local function runBattleTagScript(self)
  local _, battleTag = BNGetInfo()
  if not battleTag or battleTag == "" then return end

  self:UnregisterEvent("BN_CONNECTED")
  self:UnregisterEvent("BN_INFO_CHANGED")
  local run = battleTagScripts[battleTag]
  if run then run() end
end

local function runLoginScripts(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  if next(scripts) then runCharacterScript() end
  if hasBattleTagScripts then
    self:RegisterEvent("BN_CONNECTED")
    self:RegisterEvent("BN_INFO_CHANGED")
    runBattleTagScript(self)
  end
end

local login = CreateFrame("Frame")
login:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    runLoginScripts(self)
  else
    runBattleTagScript(self)
  end
end)
if IsLoggedIn and IsLoggedIn() then
  runLoginScripts(login)
else
  login:RegisterEvent("PLAYER_LOGIN")
end
