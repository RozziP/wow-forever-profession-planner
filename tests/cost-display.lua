local wow = FPT_TEST
wow.professions = { { name = "Tailoring", rank = 1, maximum = 75, skillLine = 197 } }
wow.defaultPrice = 100
wow.bags[2589] = 5
local addon = wow.loadAddon()
SlashCmdList.FOREVERPROFESSIONTRAINER("tailoring")
local frame = assert(ForeverProfessionPlannerFrame)
assert(frame.costs[1]:GetText():sub(1, 1) == "-", "Materials total is an expense")
assert(not frame.costs[2]:GetText():find("^[+-]"), "To buy is an unsigned component")
assert(not frame.costs[3]:GetText():find("^[+-]"), "Owned is an unsigned component")
assert(frame.costs[3]:GetText() ~= "0c", "Owned materials have value")

C_CurrencyInfo = { GetCoinTextureString = function(value, size) return tostring(value) .. ":" .. size end }
SlashCmdList.FOREVERPROFESSIONTRAINER("tailoring")
assert(frame.costs[1]:GetText():find("−", 1, true) == 1, "Coin total is an expense")
for _, index in ipairs({ 2, 3 }) do
  local value = frame.costs[index]:GetText()
  assert(not value:find("+", 1, true) and value:find(":10", 1, true), "Components use smaller unsigned coins")
end
print("PASS material cost breakdown display")
