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
assert(lowWoolExport:find("Bolt of Woolen Cloth", 1, true), "Default route buys bolts to finish the wool stage")
assert(not lowWoolExport:find("Elixir of Wisdom", 1, true), "Default route switches to silk at 100")
frame.skipWool:SetChecked(false)
click(frame.skipWool)
equal(settings.skipWool, false, "Manual route selection")
assert(addon.ImportString(lastPlan):find("Mageweave Cloth", 1, true), "Standard route starts Mageweave at 140")
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

expectWoolStep(37)
tailoring.rank = 75
event("SKILL_LINES_CHANGED")
assert(frame.cappedBanner:IsShown(), "Training is still required at the rank cap")
click(wow.button("View plan"))
expectWoolStep(17)
tailoring.maximum = 150
event("SKILL_LINES_CHANGED")
expectWoolStep(17)
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
equal(lastPlan.steps[1].recipe, "Red Mageweave Bag", "Start with the skill-up recipe")
assert(addon.ImportString(lastPlan):find('"Bolt of Mageweave"', 1, true), "Export finished bolts for prep-only materials")
assert(not addon.ImportString(lastPlan):find('"Mageweave Cloth"', 1, true), "Skip raw cloth for prep")
for _, row in ipairs(frame.steps) do
  assert(not row:IsShown() or row.skill:GetText() ~= "Prep", "Prep stays out of the Recipe list")
end
equal(nextLevelingRecipe(), "Red Mageweave Bag", "Provisional route while prices are missing")
assert(frame.priceStatus:GetText():find("prices missing", 1, true), "Missing prices should be visible")
wow.defaultPrice = 50
wow.prices[4338] = 10000 -- Mageweave Cloth
wow.prices[4339] = 10000 -- Bolt of Mageweave
slash("")
slash("")
expectTarget(225)
equal(nextLevelingRecipe(), "Red Mageweave Bag", "Reopening preserves the provisional plan")
clickTab(6)
equal(nextLevelingRecipe(), "Runecloth Belt", "Reselecting applies late quotes")
equal(frame.priceStatus:GetText(), "", "Missing-price warning clears")
print("PASS profession selection applies late Auctionator quotes")

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
  local values = {}
  for _, row in ipairs(frame.steps) do
    if row:IsShown() then values[#values + 1] = row.recipe:GetText() .. row.crafts:GetText() end
  end
  for _, group in ipairs(frame.shoppingGroups) do
    for _, row in ipairs(group.rows) do
      if row:IsShown() then values[#values + 1] = row.name:GetText() .. row.count:GetText() end
    end
  end
  return table.concat(values, "\n")
end
local tracked = assert(originalPlan.shoppingAuction[1], "Shopping has an auction item")
local itemID, needed = tracked.id, tracked.quantity
wow.bags[itemID] = 0
event("BAG_UPDATE_DELAYED")
local before = tracked.remaining
wow.bags[itemID] = 3
event("BAG_UPDATE_DELAYED")
equal(tracked.inBags, 3, "Bag event updates owned count")
equal(tracked.quantity, needed, "Bag event preserves total need")
equal(tracked.remaining, math.max(0, needed - 3), "Bag event updates remaining purchase")
assert(tracked.remaining <= before, "Buying materials does not increase purchases")
local currentRecipe
for _, step in ipairs(lastPlan.steps) do
  if not step.prep and step.from <= 117 and step.to > 117 then currentRecipe = step.recipe; break end
end
assert(currentRecipe, "Found the tracked recipe")
wow.cast = { name = currentRecipe, id = "no-skill", startTime = wow.now * 1000 }
event("UNIT_SPELLCAST_START", "player")
wow.now = wow.now + 5
wow.bags[itemID] = 1
event("UNIT_SPELLCAST_SUCCEEDED", "player", "no-skill")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "no-skill")
equal(frame.craftingFeedbackAnimation.plays, 1, "Duplicate craft success is ignored")
local lossShown = false
for _, group in ipairs(frame.shoppingGroups) do
  for _, row in ipairs(group.rows) do
    if row.itemKey == itemID and row:IsShown() and row.loss:IsShown() and row.loss:GetText() == "−2" then
      lossShown = true
    end
  end
end
assert(lossShown, "A failed skill-up shows consumed materials")
equal(tracked.quantity, needed, "A failed skill-up keeps material need unchanged")
local priorCrafts
for _, step in ipairs(lastPlan.steps) do
  if not step.prep and step.from <= 117 and step.to > 117 then priorCrafts = step.crafts; break end
end
assert(priorCrafts, "Found current leveling recipe")
tailoring.rank = 118
event("SKILL_LINES_CHANGED")
equal(lastPlan.from, 118, "Skill change refreshes the plan")
local nextCrafts
for _, step in ipairs(lastPlan.steps) do
  if not step.prep and step.to > 118 then nextCrafts = step.crafts; break end
end
equal(nextCrafts, priorCrafts - 1, "One skill gain removes one estimated craft")
for rank = 119, 120 do
  wow.cast = { name = currentRecipe, id = "skill-" .. rank, startTime = wow.now * 1000 }
  event("UNIT_SPELLCAST_START", "player")
  wow.now = wow.now + 5
  tailoring.rank = rank
  event("SKILL_LINES_CHANGED")
  event("UNIT_SPELLCAST_SUCCEEDED", "player", "skill-" .. rank)
end
local completed
for _, row in ipairs(frame.steps) do
  if row:IsShown() and row.recipe:GetText() == currentRecipe and row.check:IsShown() then completed = row end
end
assert(completed and completed.made:IsShown(), "Completed recipe retains successful craft count across skill refreshes")
equal(completed.made:GetText(), "Made ×3", "Count failed and successful skill-ups")
slider:SetValue(125)
tailoring.rank = 126
event("SKILL_LINES_CHANGED")
equal(lastPlan.cap, 125, "Passing the target keeps the selected target")
print("PASS automatic bag counts and skill-up craft estimates")

tailoring.rank = 117
local silkCloth, silkBolt = 4306, 4305
wow.bags[silkCloth], wow.bags[silkBolt] = 92, 0
wow.prices[silkBolt] = 10000
slash("tailoring")
equal(nextLevelingRecipe(), "Bolt of Silk Cloth", "Leveling recipe produces a later reagent")
local function displayedNeed(itemID)
  for _, group in ipairs(frame.shoppingGroups) do
    for _, row in ipairs(group.rows) do
      if row.itemKey == itemID and row:IsShown() then
        return tonumber(row.count:GetText():match("/(%d+)$"))
      end
    end
  end
end
local silkNeeded = assert(displayedNeed(silkCloth), "Shopping lists Silk Cloth")
local function boltsToBuy()
  for _, item in ipairs(lastPlan.auction) do
    if item.id == silkBolt then return item.quantity end
  end
  return 0
end
local boltPurchases = boltsToBuy()
wow.bags[silkCloth], wow.bags[silkBolt] = 88, 1
event("BAG_UPDATE_DELAYED")
equal(displayedNeed(silkCloth), silkNeeded, "A bag update alone preserves Need")
tailoring.rank = 118
event("SKILL_LINES_CHANGED")
equal(displayedNeed(silkCloth), silkNeeded - 4, "Skill-up credits the bolt made and removes its cloth from Need")
equal(boltsToBuy(), boltPurchases, "Skill-up does not add the crafted bolt to purchases")
event("TRADE_SKILL_DETAILS_UPDATE")
equal(displayedNeed(silkCloth), silkNeeded - 4, "Another refresh does not subtract twice")
wow.prices[silkBolt] = nil
print("PASS skill-up credits crafted reagents in the shopping total")

slash("cooking")
expectTarget(75)
equal(lastPlan.steps[1].recipe, "Brilliant Smallfish", "Cooking preview recipe")
assert(not frame.tabs[7].skill, "Cooking starts unlearned")
wow.professions[5] = { name = "Cooking", rank = 150, maximum = 150, skillLine = 185 }
slash("cooking")
expectTarget(225)
equal(frame.tabs[7].skill.slot, 5, "Cooking is read from the Forever Cooking slot")
equal(frame.cappedTitle:GetText(), "Read Expert Cookbook", "Cooking Expert rank action")
equal(frame.cappedMapLink.trainer.name, "Shandrina", "Alliance cookbook vendor")
equal(frame.cappedRequirements:GetText(), "Skill cap reached at 150", "Expert Cooking level requirement")
click(wow.button("View plan"))
equal(lastPlan.vendor[1].name, "Expert Cookbook", "Shopping ahead includes the Expert book")
wow.professions[5].rank, wow.professions[5].maximum = 225, 225
slash("cooking")
expectTarget(300)
equal(frame.cappedTitle:GetText(), "Complete Clamlette Surprise", "Cooking Artisan rank action")
equal(frame.cappedMapLink.trainer.name, "Dirge Quikcleave", "Artisan quest giver")
click(wow.button("View plan"))
assert(addon.ImportString(lastPlan):find("Giant Egg", 1, true), "Shopping ahead includes quest items")
wow.professions[5].maximum = 300
event("SKILL_LINES_CHANGED")
assert(addon.ImportString(lastPlan):find("Giant Egg", 1, true), "Training preserves the selected shopping plan")
clickTab(7)
equal(lastPlan.vendor[1].name, "Refreshing Spring Water", "Only Nightfin Soup's vendor ingredient remains")
equal(#lastPlan.vendor, 1, "Reselecting removes vendor turn-in items")
equal(#lastPlan.auction, 2, "Only the two fish remain after the Artisan unlock")
print("PASS Cooking preview, learned secondary slot, rank directions, and training refresh")

slash("first aid")
expectTarget(75)
equal(lastPlan.steps[1].recipe, "Linen Bandage", "First Aid opens a guide before learning the skill")
assert(not frame.tabs[8].skill, "First Aid starts unlearned")
equal(frame.tabs[8].previousTab, frame.tabs[7], "First Aid is grouped with Cooking")
assert(frame.potionRoute:IsShown() and not frame.potionRoute:GetChecked(), "First Aid defaults to bandages")
frame.potionRoute:SetChecked(true)
click(frame.potionRoute)
expectTarget(75)
equal(lastPlan.steps[1].recipe, "Minor Healing Potion", "Switching routes replaces the recipe")
assert(addon.ImportString(lastPlan):find('"Peacebloom"', 1, true), "Potion route switches the auction export")
slash("cooking")
assert(not frame.potionRoute:IsShown(), "Potion route control is specific to First Aid")
slash("first aid")
assert(frame.potionRoute:GetChecked(), "Returning to First Aid keeps the potion selection")
equal(lastPlan.steps[1].recipe, "Minor Healing Potion", "First Aid remembers the selected route")
frame.potionRoute:SetChecked(false)
click(frame.potionRoute)
equal(lastPlan.steps[1].recipe, "Linen Bandage", "Unchecking returns to bandages")
local firstAid = { name = "First Aid", rank = 75, maximum = 75, skillLine = 129 }
wow.professions[3] = firstAid
slash("first aid")
equal(frame.tabs[8].skill.slot, 3, "First Aid is read from the Forever First Aid slot")
equal(frame.cappedTitle:GetText(), "Train Journeyman First Aid", "Journeyman First Aid uses the trainer")
equal(frame.cappedRequirements:GetText(), "Skill cap reached at 75", "Journeyman First Aid has no character level gate")
firstAid.rank, firstAid.maximum = 150, 150
slash("first aid")
equal(frame.cappedTitle:GetText(), "Read Expert First Aid - Under Wraps", "Expert First Aid uses the book")
equal(frame.cappedMapLink.trainer.name, "Deneb Walker", "Alliance Expert First Aid vendor")
click(wow.button("View plan"))
equal(#lastPlan.vendor, 3, "Shopping ahead includes the Expert book and both manuals")
firstAid.maximum = 225
event("SKILL_LINES_CHANGED")
equal(#lastPlan.vendor, 2, "Learning Expert First Aid removes its book from shopping")

local learnt
C_TradeSkillUI = { GetRecipeInfo = function(spellID) return { learned = spellID == learnt } end }
firstAid.rank = 180
event("SKILL_LINES_CHANGED")
equal(#lastPlan.vendor, 2, "Both recipe manuals are needed before learning them")
learnt = 7929
event("NEW_RECIPE_LEARNED", learnt)
equal(#lastPlan.vendor, 1, "Learning a manual removes it from shopping immediately")
equal(lastPlan.vendor[1].name, "Manual: Mageweave Bandage", "Future manual is still listed")
C_TradeSkillUI = nil
firstAid.rank = 225
slash("first aid")
equal(frame.cappedTitle:GetText(), "Complete Triage", "Artisan First Aid uses Triage")
equal(frame.cappedRequirements:GetText(), "Skill cap reached at 225 · Requires character level 35", "Triage level requirement")
equal(frame.cappedMapLink.trainer.name, "Doctor Gustaf VanHowzen", "Alliance Triage quest giver")
local allianceFaction = UnitFactionGroup
UnitFactionGroup = function() return "Horde" end
event("SKILL_LINES_CHANGED")
equal(frame.cappedMapLink.trainer.name, "Doctor Gregory Victor", "Horde Triage quest giver")
UnitFactionGroup = allianceFaction
firstAid.maximum = 300
event("SKILL_LINES_CHANGED")
assert(frame.planPage:IsShown(), "Completing Triage returns to the plan")
expectTarget(300)
assert(addon.ImportString(lastPlan):find('"Runecloth"', 1, true), "Export includes First Aid cloth")
print("PASS First Aid preview, secondary slot, rank unlocks, and live manual shopping")

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
slash("first aid")
click(firstRecipeRow())
equal(openedSkillLine, 129, "First Aid recipes open the First Aid profession")
readyProfession(129)
wow.flushTimers()
equal(searchBox:GetText(), firstRecipeRow().recipe:GetText(), "First Aid recipe fills the search")
beforeOpen = openCount
slash("blacksmithing")
click(firstRecipeRow())
equal(openCount, beforeOpen, "Unlearned preview cannot search another profession")
OpenProfessionUIToSkillLine = nil
slash("tailoring")
click(firstRecipeRow())
equal(openCount, beforeOpen, "Missing profession API is handled without an error")
print("PASS clickable recipes, delayed loading, profession switches, and unavailable searches")

slash("blacksmithing")
slider:SetValue(245)
local function choiceRow(id)
  for _, row in ipairs(frame.steps) do
    if row:IsShown() and row.choicePanels[1]:IsShown() and row.choicePanels[1].choiceId == id then return row end
  end
  error("Missing choice row " .. id)
end
local row = choiceRow("smith-240")
equal(row.choicePanels[1].optionName, "Imperial Plate Belt", "First panel shows guide recipe")
equal(row.choicePanels[2].optionName, "Mithril Spurs", "Second panel shows alternative")
row.choicePanels[1]:RunScript("OnClick", "LeftButton")
equal(settings.recipeChoices.Blacksmithing["smith-240"], "Imperial Plate Belt", "Clicking the current selection pins it")
row.choicePanels[2]:RunScript("OnClick", "LeftButton")
equal(settings.recipeChoices.Blacksmithing["smith-240"], "Mithril Spurs", "Selection is saved")
equal(choiceRow("smith-240").choicePanels[2].selectedName, "Mithril Spurs", "Selected panel is shown")
local selectedExport = addon.ImportString(lastPlan)
slash("")
slash("")
equal(addon.ImportString(lastPlan), selectedExport, "Reopening keeps the selected plan")
event("BAG_UPDATE_DELAYED")
equal(choiceRow("smith-240").choicePanels[2].selectedName, "Mithril Spurs", "Bag updates keep the choice")
row = choiceRow("smith-240")
row.choicePanels[1]:RunScript("OnClick", "LeftButton")
equal(settings.recipeChoices.Blacksmithing["smith-240"], "Imperial Plate Belt", "Can switch back")
assert(addon.ImportString(lastPlan) ~= selectedExport, "Switching panels changes the export")
wow.professions = { { name = "Blacksmithing", rank = 240, maximum = 300, skillLine = 164 } }
slash("blacksmithing")
slider:SetValue(245)
choiceRow("smith-240").choicePanels[2]:RunScript("OnClick", "LeftButton")
wow.professions[1].rank = 241
event("SKILL_LINES_CHANGED")
equal(choiceRow("smith-240").choicePanels[2].selectedName, "Mithril Spurs", "Skill gains preserve the chosen recipe")
choiceRow("smith-240").choicePanels[1]:RunScript("OnClick", "LeftButton")
wow.professions = { { name = "Blacksmithing", rank = 245, maximum = 300, skillLine = 164 } }
slash("blacksmithing")
local completedBelt
for _, candidate in ipairs(frame.steps) do
  if candidate:IsShown() and candidate.recipe:GetText() == "Imperial Plate Belt" then completedBelt = candidate end
end
assert(completedBelt and completedBelt.choicePanels[1]:IsShown(), "Completed choice keeps both panels")
assert(completedBelt.choicePanels[1].completedCheck:IsShown(), "Completed selection has a check")
print("PASS recipe choice panels, plan refresh, and switching back")

addon.IsAnimationDebugAccount = function() return true end
slash("debug")
local debugPage = assert(frame.debugPage, "Debug page opens")
local previews = assert(debugPage.previewButtons, "Craft previews exist")
click(previews[1])
equal(debugPage.sampleGroup.rows[1].count:GetText(), "16 / 20", "No-skill craft keeps material need")
equal(debugPage.sampleGroup.rows[1].loss:GetText(), "−4", "No-skill craft shows material loss")
click(previews[2])
equal(debugPage.sampleGroup.rows[1].count:GetText(), "16 / 16", "Skill-up craft reduces material need")
click(previews[3])
assert(frame.craftingFeedback:IsShown(), "Craft previews show duration")
print("PASS debug craft previews")
