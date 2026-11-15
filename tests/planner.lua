local wow = FPT_TEST
local equal = wow.equal
local alchemy = { name = "Alchemy", rank = 76, maximum = 150, skillLine = 171 }
local tailoring = { name = "Tailoring", rank = 97, maximum = 150, skillLine = 197 }
wow.professions = { alchemy, tailoring }
ForeverProfessionPlannerSettings = { target = 260, skipWool = false }
local addon = wow.loadAddon()
local settings = ForeverProfessionPlannerSettings
local slash = SlashCmdList.FOREVERPROFESSIONTRAINER
local getPlan, lastPlan = addon.GetPlan
function addon.GetPlan(...)
  lastPlan = getPlan(...)
  return lastPlan
end

slash("")
local frame = assert(ForeverProfessionPlannerFrame)
local slider = assert(wow.slider)

local function clickTab(index, button, inside)
  local tab = frame.tabs[index]
  tab.mouseUp(tab, button or "LeftButton", inside ~= false)
end
local function click(widget)
  assert(widget:GetScript("OnClick"), "Missing click handler")
  widget:RunScript("OnClick")
end
local function event(name, ...)
  wow.event(frame, name, ...)
  wow.flushTimers()
end
local function expectTarget(target)
  equal(settings.target, target, "Stored target")
  equal(slider.value, target, "Displayed slider target")
  equal(lastPlan.cap, target, "Route target")
end

clickTab(1)
expectTarget(150)
equal(slider.minimum, 76, "Exact skill is the slider minimum")
slider:SetValue(260)
expectTarget(260)
clickTab(1, "RightButton")
clickTab(1, "LeftButton", false)
expectTarget(260)
clickTab(1)
expectTarget(150)
clickTab(2)
expectTarget(75)

alchemy.maximum = 300
for _, test in ipairs({ { 74, 75 }, { 75, 150 }, { 149, 150 }, { 150, 225 },
  { 224, 225 }, { 225, 300 }, { 299, 300 }, { 300, 300 } }) do
  alchemy.rank = test[1]
  clickTab(1)
  expectTarget(test[2])
end

clickTab(6)
expectTarget(150)
equal(frame.skipWool:GetChecked(), true, "Tailoring defaults to Skip wool")
assert(not addon.ImportString(lastPlan):find("Wool Cloth", 1, true), "Default route uses wool")
frame.skipWool:SetChecked(false)
click(frame.skipWool)
equal(settings.skipWool, false, "Manual route selection")
assert(addon.ImportString(lastPlan):find("Wool Cloth", 1, true), "Alternate route must use wool")
slider:SetValue(165)
event("BAG_UPDATE_DELAYED")
slash("")
slash("")
expectTarget(165)
equal(frame.skipWool:GetChecked(), false, "Bag refresh and reopening preserve the route selection")
clickTab(6)
expectTarget(150)
equal(frame.skipWool:GetChecked(), true, "Same tab restores Skip wool")
print("PASS profession tab resets, milestone bounds, and Tailoring defaults")

alchemy.rank, alchemy.maximum = 75, 75
clickTab(1)
expectTarget(150)
assert(frame.cappedBanner:IsShown() and not frame.planPage:IsShown(), "Capped tab should open Training")
click(wow.button("View plan"))
assert(frame.planPage:IsShown() and frame.trainingButton:IsShown(), "View plan should permit shopping ahead")
slider:SetValue(200)
click(frame.trainingButton)
expectTarget(200)
clickTab(1)
expectTarget(150)
assert(frame.cappedBanner:IsShown(), "Clicking the same capped tab should return to Training")
print("PASS capped Training and View plan navigation")

tailoring.rank, tailoring.maximum = 215, 300
slash("tailoring")
expectTarget(225)
equal(lastPlan.steps[1].recipe, "Mageweave Bag", "Provisional route while prices are missing")
assert(frame.priceStatus:GetText():find("prices missing", 1, true), "Missing prices should be visible")
wow.defaultPrice = 50
wow.prices[4338] = 10000 -- Mageweave Cloth
wow.prices[4339] = 10000 -- Bolt of Mageweave
slash("")
slash("")
expectTarget(225)
local changedRecipe
for _, step in ipairs(lastPlan.steps) do
  if not step.prep then changedRecipe = step.recipe; break end
end
equal(changedRecipe, "Runecloth Belt", "Late quotes replace the provisional recipe after reopening")
equal(frame.priceStatus:GetText(), "", "Missing-price warning clears")
print("PASS late Auctionator prices replace the provisional recipe")

alchemy.rank, alchemy.maximum = 18, 75
slash("alchemy")
local baseline = frame.displayedCraftingTime
assert(baseline > 0, "Alchemy needs remaining craft time")
wow.cast = { name = "Elixir of Minor Defense", id = "interrupted", startTime = 49000, endTime = 52000, spellID = 123 }
event("UNIT_SPELLCAST_START", "player", wow.cast.id, 123)
assert(frame:GetScript("OnUpdate") and frame.displayedCraftingTime < baseline, "Matching cast starts the countdown")
wow.now = 51
local previousTime = frame.displayedCraftingTime
frame:RunScript("OnUpdate")
assert(frame.displayedCraftingTime < previousTime, "Active cast should tick")
slash("")
assert(not frame:GetScript("OnUpdate"), "Closing the planner stops countdown updates")
slash("")
assert(frame:GetScript("OnUpdate"), "Reopening mid-cast resumes countdown updates")
wow.cast = nil
frame:RunScript("OnUpdate")
equal(frame.displayedCraftingTime, baseline, "Interruption restores the estimate")
assert(not frame:GetScript("OnUpdate"), "Interruption stops countdown updates")

wow.cast = { name = "Elixir of Minor Defense", id = "finished", startTime = 51500, endTime = 54000, spellID = 123 }
wow.now = 52
event("UNIT_SPELLCAST_START", "player", wow.cast.id, 123)
wow.now = 54
event("UNIT_SPELLCAST_SUCCEEDED", "player", wow.cast.id, 123)
equal(frame.craftingFeedback:GetText(), "-2.5 seconds", "Feedback shows actual cast duration")
event("UNIT_SPELLCAST_SUCCEEDED", "player", wow.cast.id, 123)
equal(frame.craftingFeedbackAnimation.plays, 1, "Duplicate success does not replay feedback")
wow.cast, alchemy.rank = nil, 19
event("TRADE_SKILL_ITEM_CRAFTED_RESULT")
assert(frame.displayedCraftingTime < baseline, "Completing a craft updates the remaining estimate")
print("PASS crafting countdown, interruption, reopening, and completed cast feedback")

assert(not frame.debugTab:IsShown(), "Animation Debug stays hidden for other accounts")
local hasDebugAccess = addon.IsAnimationDebugAccount
addon.IsAnimationDebugAccount = function() return true end
event("BN_INFO_CHANGED")
assert(frame.debugTab:IsShown(), "Animation Debug appears when Battle.net access is available")
slash("debug")
assert(frame.debugPage:IsShown() and not frame.guideFooter:IsShown(), "Debug opens without the planner footer")
click(wow.button("Crafting time (-23s)"))
equal(frame.craftingFeedback:GetText(), "-23 seconds", "Debug craft duration preview")
addon.IsAnimationDebugAccount = hasDebugAccess
event("BN_INFO_CHANGED")
assert(not frame.debugTab:IsShown() and frame.planPage:IsShown(), "Losing debug access restores the plan")
print("PASS account-scoped debug navigation and crafting animation preview")
