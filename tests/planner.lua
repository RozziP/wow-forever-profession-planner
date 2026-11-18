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
equal(frame.skipWool:GetChecked(), true, "Tailoring defaults to Less wool")
local lowWoolExport = addon.ImportString(lastPlan)
assert(lowWoolExport:find("Wool Cloth", 1, true), "Default route finishes the wool stage")
assert(not lowWoolExport:find("Elixir of Wisdom", 1, true), "Default route switches to silk at 100")
frame.skipWool:SetChecked(false)
click(frame.skipWool)
equal(settings.skipWool, false, "Manual route selection")
assert(addon.ImportString(lastPlan):find("Elixir of Wisdom", 1, true), "Normal route uses Gloves of Meditation")
slider:SetValue(165)
event("TRADE_SKILL_DETAILS_UPDATE")
slash("")
slash("")
expectTarget(165)
equal(frame.skipWool:GetChecked(), false, "Passive refresh and reopening preserve the route selection")
clickTab(6)
expectTarget(150)
equal(frame.skipWool:GetChecked(), true, "Same tab restores Less wool")
print("PASS profession tab resets, milestone bounds, and Tailoring defaults")

tailoring.rank, tailoring.maximum = 55, 75
slash("tailoring")
slider:SetValue(150)
frame.skipWool:SetChecked(false)
click(frame.skipWool)
local function expectWoolStep(crafts)
  local wool
  for _, row in ipairs(frame.steps) do
    if row:IsShown() and row.recipe:GetText() == "Bolt of Woolen Cloth" and row.skill:GetText() ~= "Prep" then
      assert(not wool, "The wool leveling step should appear once")
      wool = row
    end
  end
  assert(wool and wool.marker:IsShown(), "The wool leveling step should be current")
  equal(wool.skill:GetText(), "55–80", "Wool step spans the training break")
  equal(wool.crafts:GetText(), "×" .. crafts, "Wool craft count")
  equal(wool.keep:GetText(), "Keep ×" .. crafts, "Wool keep count")
end

expectWoolStep(45)
tailoring.rank = 75
event("SKILL_LINES_CHANGED")
assert(frame.cappedBanner:IsShown(), "Training is still required at the rank cap")
click(wow.button("View plan"))
expectWoolStep(45)
tailoring.maximum = 150
event("SKILL_LINES_CHANGED")
click(wow.button("Update plan"))
expectWoolStep(14)
print("PASS one wool leveling row across training and after recalculation")

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
local function nextLevelingRecipe()
  for _, step in ipairs(lastPlan.steps) do
    if not step.prep then return step.recipe end
  end
end
equal(lastPlan.steps[1].recipe, "Bolt of Mageweave", "Less wool can prep Mageweave for later recipes")
assert(lastPlan.steps[1].prep, "Mageweave bolts at 215 should be prep")
equal(nextLevelingRecipe(), "Mageweave Bag", "Provisional route while prices are missing")
assert(frame.priceStatus:GetText():find("prices missing", 1, true), "Missing prices should be visible")
wow.defaultPrice = 50
wow.prices[4338] = 10000 -- Mageweave Cloth
wow.prices[4339] = 10000 -- Bolt of Mageweave
slash("")
slash("")
expectTarget(225)
equal(nextLevelingRecipe(), "Mageweave Bag", "Reopening preserves the provisional plan")
click(wow.button("Update plan"))
equal(nextLevelingRecipe(), "Runecloth Belt", "Updating the plan applies late quotes")
equal(frame.priceStatus:GetText(), "", "Missing-price warning clears")
print("PASS explicit plan update applies late Auctionator quotes")

tailoring.rank, tailoring.maximum = 117, 150
wow.bags[4306], wow.bags[4305] = 92, 59
NUM_BAG_SLOTS = 0
wow.freeBagSlots = 24
C_Container = {
  GetContainerNumFreeSlots = function() return wow.freeBagSlots, 0 end,
  GetContainerNumSlots = function() return 0 end,
}
C_Item.GetItemInfo = function() return nil, nil, nil, nil, nil, nil, nil, 20 end
slash("tailoring")
local originalPlan = lastPlan

local function displayedNumbers()
  local values = { frame.craftingTime:GetText(), frame.bagSpace:GetText() }
  for _, cost in ipairs(frame.costs) do values[#values + 1] = cost:GetText() end
  for _, row in ipairs(frame.steps) do
    if row:IsShown() then
      values[#values + 1] = row.recipe:GetText() .. row.crafts:GetText() .. row.keep:GetText()
    end
  end
  for _, group in ipairs(frame.shoppingGroups) do
    for _, row in ipairs(group.rows) do
      if row:IsShown() then values[#values + 1] = row.name:GetText() .. row.count:GetText() end
    end
  end
  return table.concat(values, "\n")
end

local silkStep
for _, row in ipairs(frame.steps) do
  if row:IsShown() and row.recipe:GetText() == "Bolt of Silk Cloth" and row.marker:IsShown() then
    silkStep = row
    break
  end
end
assert(silkStep and silkStep.keep:IsShown(), "Select the current silk step with its keep count")
local originalNumbers = displayedNumbers()
local originalExport = addon.ImportString(originalPlan)
click(frame.importButton)
equal(frame.copyBox:GetText(), originalExport, "Export contains the displayed plan")

local function startSilk(id)
  wow.cast = { name = "Bolt of Silk Cloth", id = id, startTime = wow.now * 1000, spellID = 3839 }
  event("UNIT_SPELLCAST_START", "player")
  equal(displayedNumbers(), originalNumbers, "Numbers stay fixed during casts")
end
local function finishSilk(newRank)
  local id = wow.cast.id
  wow.now = wow.now + 5.125
  wow.cast, tailoring.rank = nil, newRank
  event("SKILL_LINES_CHANGED")
  event("UNIT_SPELLCAST_SUCCEEDED", "player", id, 3839)
end

startSilk("interrupted")
wow.cast = nil
event("TRADE_SKILL_DETAILS_UPDATE")

startSilk("no-skill-up")
finishSilk(117)
equal(frame.craftingFeedback:GetText(), "-5.1 seconds", "Feedback shows the actual cast duration")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "no-skill-up", 3839)
equal(frame.craftingFeedbackAnimation.plays, 1, "Duplicate success is ignored")
assert(not silkStep.made:IsShown(), "Made count stays hidden on the active step")

startSilk("skill-118")
finishSilk(118)
wow.bags[4306], wow.bags[4305], wow.freeBagSlots = 84, 61, 23
event("TRADE_SKILL_ITEM_CRAFTED_RESULT")
equal(displayedNumbers(), originalNumbers, "Skill, bag, and craft refreshes preserve all plan numbers")
equal(lastPlan, originalPlan, "Passive refresh retains the plan")
equal(frame.copyBox:GetText(), originalExport, "Shopping payload stays fixed")

slash("")
startSilk("skill-119")
finishSilk(119)
slash("")
equal(displayedNumbers(), originalNumbers, "Reopening preserves the snapshot")
startSilk("skill-120")
finishSilk(120)
assert(silkStep.check:IsShown() and silkStep.made:IsShown(), "Show Made on the completed row")
equal(silkStep.made:GetText(), "Made ×4", "Count successful crafts across skill-ups and while hidden")
equal(displayedNumbers(), originalNumbers, "Completion adds Made and keeps the estimates")

wow.prices[4305] = 5000
click(wow.button("Update plan"))
equal(lastPlan.from, 120, "Updating starts at current skill")
assert(displayedNumbers() ~= originalNumbers, "Updating recalculates the estimates and shopping list")
originalNumbers = displayedNumbers()

local silkPrep, prepCrafts
for i, row in ipairs(frame.steps) do
  if row:IsShown() and row.skill:GetText() == "Prep" and row.recipe:GetText() == "Bolt of Silk Cloth" then
    silkPrep = row
    prepCrafts = tonumber(row.crafts:GetText():match("%d+"))
    break
  end
end
assert(silkPrep and prepCrafts, "Remaining route has silk prep")
for i = 1, prepCrafts do
  startSilk("prep-" .. i)
  finishSilk(120)
end
assert(silkPrep.check:IsShown() and silkPrep.made:IsShown(), "Prep can finish ahead of its skill range")
equal(silkPrep.made:GetText(), "Made ×" .. prepCrafts, "Extra bolts are counted on the prep row")
equal(displayedNumbers(), originalNumbers, "Finishing prep preserves the plan numbers")

slider:SetValue(125)
local finalNumbers = displayedNumbers()
tailoring.rank = 126
event("SKILL_LINES_CHANGED")
equal(lastPlan.cap, 125, "A skill-up past the target keeps the selected plan target")
equal(displayedNumbers(), finalNumbers, "Passing the target leaves its plan numbers visible")
print("PASS fixed plan numbers, stable export, and successful crafts on completed rows")

slash("cooking")
expectTarget(75)
equal(lastPlan.steps[1].recipe, "Brilliant Smallfish", "Cooking preview recipe")
assert(not frame.tabs[7].skill, "Cooking starts unlearned")
wow.professions[4] = { name = "Cooking", rank = 150, maximum = 150, skillLine = 185 }
slash("cooking")
expectTarget(225)
equal(frame.tabs[7].skill.slot, 4, "Cooking is read from a secondary slot")
equal(frame.cappedTitle:GetText(), "Read Expert Cookbook", "Cooking Expert rank action")
equal(frame.cappedMapLink.trainer.name, "Shandrina", "Alliance cookbook vendor")
equal(frame.cappedRequirements:GetText(), "Skill cap reached at 150", "Expert Cooking level requirement")
click(wow.button("View plan"))
equal(lastPlan.vendor[1].name, "Expert Cookbook", "Shopping ahead includes the Expert book")
wow.professions[4].rank, wow.professions[4].maximum = 225, 225
slash("cooking")
expectTarget(300)
equal(frame.cappedTitle:GetText(), "Complete Clamlette Surprise", "Cooking Artisan rank action")
equal(frame.cappedMapLink.trainer.name, "Dirge Quikcleave", "Artisan quest giver")
click(wow.button("View plan"))
assert(addon.ImportString(lastPlan):find("Giant Egg", 1, true), "Shopping ahead includes quest items")
wow.professions[4].maximum = 300
event("SKILL_LINES_CHANGED")
assert(addon.ImportString(lastPlan):find("Giant Egg", 1, true), "Training preserves the selected shopping plan")
click(wow.button("Update plan"))
equal(#lastPlan.vendor, 0, "Updating after Artisan unlock removes vendor turn-in items")
equal(#lastPlan.auction, 1, "Artisan unlock removes Auction House turn-in items at the same skill")
print("PASS Cooking preview, learned secondary slot, rank directions, and training refresh")

-- Exercise real row clicks with a profession UI that loads and switches asynchronously.
local openCount, openedSkillLine, baseInfo, changing = 0, nil, nil, false
local searchBox = CreateFrame("EditBox")
local searchChanges = 0
function searchBox:SetText(text)
  self.text = text
  searchChanges = searchChanges + 1
end
C_TradeSkillUI = {
  GetBaseProfessionInfo = function() return baseInfo end,
  IsDataSourceChanging = function() return changing end,
}
OpenProfessionUIToSkillLine = function(skillLine)
  openCount, openedSkillLine = openCount + 1, skillLine
  if not ProfessionsFrame then
    ProfessionsFrame = CreateFrame("Frame")
    ProfessionsFrame.CraftingPage = CreateFrame("Frame", nil, ProfessionsFrame)
    ProfessionsFrame.CraftingPage.RecipeList = { SearchBox = searchBox }
  end
  ProfessionsFrame:Show()
end
local function readyProfession(skillLine)
  baseInfo = { professionID = skillLine }
  ProfessionsFrame.CraftingPage.professionInfo = { professionID = skillLine }
  changing = false
end
local function firstRecipeRow()
  for _, row in ipairs(frame.steps) do
    if row:IsShown() then return row end
  end
  error("No recipe row to click")
end
slash("tailoring")
local recipeRow = firstRecipeRow()
local expectedRecipe = recipeRow.recipe:GetText()
local beforeSearch = displayedNumbers()
recipeRow:RunScript("OnEnter")
assert(GameTooltip:IsOwned(recipeRow) and GameTooltip:IsShown(), "Hover owns the recipe tooltip")
click(recipeRow)
assert(not GameTooltip:IsShown(), "Click dismisses its recipe tooltip before opening the profession")
equal(openedSkillLine, 197, "Recipe click opens its profession")
wow.flushTimers()
equal(searchChanges, 0, "Wait for first profession load before searching")
readyProfession(197)
wow.flushTimers()
equal(searchBox:GetText(), expectedRecipe, "Loaded profession searches the clicked recipe")
equal(displayedNumbers(), beforeSearch, "Searching preserves plan values")

slash("cooking")
recipeRow = firstRecipeRow()
click(recipeRow)
equal(openedSkillLine, 185, "Reused row opens Cooking instead of Tailoring")
wow.flushTimers()
equal(searchChanges, 1, "Do not search the previous profession while switching")
readyProfession(185)
changing = true
wow.flushTimers()
equal(searchChanges, 1, "Wait for Blizzard to finish replacing its data source")
changing = false
wow.flushTimers()
equal(searchBox:GetText(), recipeRow.recipe:GetText(), "Search after profession switch completes")

local beforeChanges = searchChanges
click(recipeRow)
local secondRow = assert(frame.steps[2])
assert(secondRow:IsShown(), "Cooking has a second recipe")
click(secondRow)
wow.flushTimers()
equal(searchChanges, beforeChanges + 1, "Only the newest pending click searches")
equal(searchBox:GetText(), secondRow.recipe:GetText(), "Newest clicked recipe wins")

click(recipeRow)
ProfessionsFrame:Hide()
wow.flushTimers()
equal(searchChanges, beforeChanges + 1, "Closing the profession window cancels the search")
local beforeOpen = openCount
InCombatLockdown = function() return true end
click(recipeRow)
equal(openCount, beforeOpen, "Do not open professions in combat")
InCombatLockdown = nil
slash("blacksmithing")
click(firstRecipeRow())
equal(openCount, beforeOpen, "Unlearned preview cannot search another profession")
OpenProfessionUIToSkillLine = nil
slash("tailoring")
click(firstRecipeRow())
equal(openCount, beforeOpen, "Missing profession API is handled without an error")
print("PASS clickable recipes, delayed loading, profession switches, and unavailable searches")
