local wow = FPT_TEST
local equal = wow.equal
local addon = wow.loadAddon()
local alchemy, tailoring = 1, 6
equal(addon.routes[alchemy].name, "Alchemy", "Alchemy fixture")
equal(addon.routes[tailoring].name, "Tailoring", "Tailoring fixture")

wow.defaultPrice = 100
local baseline = addon.GetPlan(7, 300, true, 225, nil, nil, 225)
local auctionItem, vendorItem = baseline.auction[1], baseline.vendor[1]
assert(auctionItem and vendorItem, "Owned-material fixture requires auction and vendor items")
wow.bags[auctionItem.id] = math.floor(auctionItem.quantity / 2)
wow.bags[vendorItem.id] = vendorItem.quantity
local withOwned = addon.GetPlan(7, 300, true, 225, baseline, nil, 225)
equal(withOwned.cost.owned, wow.bags[auctionItem.id] * 100 + vendorItem.quantity * vendorItem.price,
  "Owned materials include auction and vendor value")
equal(withOwned.cost.toBuy + withOwned.cost.owned, withOwned.cost.gross, "Material breakdown balances")
equal(withOwned.cost.gross, baseline.cost.gross, "Owned supplies retain their cost")
equal(withOwned.cost.net, withOwned.cost.gross - withOwned.revenue, "Net includes owned supplies")
wow.defaultPrice = nil
local unpriced = addon.GetPlan(7, 300, true, 225, baseline, nil, 225)
assert(unpriced.cost.gross == nil and unpriced.cost.owned == nil and unpriced.cost.toBuy == nil,
  "Missing prices leave the material breakdown unknown")
wow.bags[auctionItem.id], wow.bags[vendorItem.id] = nil, nil
print("PASS owned-material value and cost breakdown")

local linen = addon.GetPlan(tailoring, 30, true, 1)
equal(linen.steps[1].recipe, "Bolt of Linen Cloth", "Short Tailoring route")
equal(linen.revenue, 1200, "Sell all 30 bolts when stopping at skill 30")

local later = addon.GetPlan(alchemy, 165, false, 130)
equal(later.steps[1].recipe, "Fire Oil", "Alchemy intermediate")
equal(later.steps[1].keep, 30, "Reserve Fire Oil for later crafts")
equal(later.revenue, 10 * 12 + later.steps[2].crafts * 35, "Proceeds exclude the reserved oil")
print("PASS vendor proceeds for a short target and an intermediate reservation")

local planCount = 0
for _, pricesAvailable in ipairs({ false, true }) do
  wow.defaultPrice = pricesAvailable and 50 or nil
  for index, profession in ipairs(addon.routes) do
    for _, target in ipairs({ 75, 150, 225, 300 }) do
      for _, skill in ipairs({ 1, target - 1, target }) do
        local plan = addon.GetPlan(index, target, true, skill)
        for _, step in ipairs(plan.steps) do
          assert(not step.prep, "Buy prep-only reagents for " .. profession.name)
        end
        equal(plan.name, profession.name, "Plan profession")
        equal(plan.from, skill, "Plan starts at current skill")
        equal(plan.cap, target, "Plan ends at target")
        if skill == target then
          equal(#plan.steps, 0, "No remaining steps at the target")
        elseif skill == 1 then
          assert(#plan.steps > 0, "No starting route for " .. profession.name)
        end
        if pricesAvailable and skill < target then
          assert(plan.cost.gross, "Fully priced route has no total for " .. profession.name)
          equal(plan.cost.net, plan.cost.gross - plan.revenue, "Net cost accounts for proceeds")
        end
        local export = addon.ImportString(plan)
        local _, terms = export:gsub("%^", "")
        equal(terms, #plan.auction, "Export has one term per remaining Auction House item")
        for _, material in ipairs(plan.auction) do
          local term = '^"' .. material.name .. '"' .. string.rep(";", 11) .. "#;;" .. material.quantity
          assert((export .. "^"):find(term .. "^", 1, true), "Missing exact quantity for " .. material.name)
        end
        planCount = planCount + 1
      end
    end
  end
end
print(string.format("PASS %d plans and shopping exports across all %d professions", planCount, #addon.routes))

local function quantity(items, name)
  for _, item in ipairs(items) do
    if item.name == name then return item.quantity end
  end
  return 0
end

for _, profession in ipairs(addon.routes) do
  for _, source in ipairs({ profession.full, profession.rush }) do
    for _, item in ipairs(source.vendor) do
      assert(item.id, "Vendor item needs an ID for bag accounting: " .. item.name)
    end
  end
end

local emptyBags = addon.GetPlan(alchemy, 75, false, 1)
local neededVials = quantity(emptyBags.vendor, "Empty Vial")
assert(neededVials > 0, "Alchemy needs vendor vials")
wow.bags[3371] = 5
local someVials = addon.GetPlan(alchemy, 75, false, 1)
equal(quantity(someVials.vendor, "Empty Vial"), neededVials - 5, "Subtract owned vendor supplies")
wow.bags[3371] = neededVials
local enoughVials = addon.GetPlan(alchemy, 75, false, 1)
equal(quantity(enoughVials.vendor, "Empty Vial"), 0, "Do not buy vendor supplies already owned")
wow.bags[3371] = nil
print("PASS partial and complete vendor supplies in bags")

wow.defaultPrice = nil
local skipSource = addon.routes[tailoring].rush
local rawSkip150 = addon.GetPlan(tailoring, 150, false, 1, nil, true)
for _, category in ipairs({ "auction", "vendor" }) do
  equal(#rawSkip150[category], #skipSource[category], "Generated Less wool shopping categories")
  for _, item in ipairs(skipSource[category]) do
    equal(quantity(rawSkip150[category], item.name), item.quantity, "Generated quantity for " .. item.name)
  end
end

for _, skip in ipairs({ false, true }) do
  for skill = 1, 149 do
    local plan = addon.GetPlan(tailoring, skill + 1, true, skill, nil, skip)
    local step = plan.steps[#plan.steps]
    assert(step and not step.prep and step.crafts >= 1, "Missing Tailoring skill-up at " .. skill)
    equal(step.from, skill, "Clipped Tailoring step start")
    equal(step.to, skill + 1, "Clipped Tailoring step end")
  end
end

local normal150 = addon.GetPlan(tailoring, 150, true, 1)
local skip150 = addon.GetPlan(tailoring, 150, true, 1, nil, true)
equal(quantity(normal150.auction, "Wool Cloth"), 111, "Updated standard guide needs 37 wool bolts")
equal(quantity(skip150.auction, "Wool Cloth"), 66, "Less wool crafts 22 bolts for skill")
equal(quantity(skip150.auction, "Bolt of Woolen Cloth"), 4, "Buy the four extra bolts even without prices")
equal(quantity(skip150.auction, "Elixir of Wisdom"), 0, "Less wool avoids Gloves of Meditation")
local woolExport = '^"Wool Cloth"' .. string.rep(";", 11) .. "#;;66^"
assert((addon.ImportString(skip150) .. "^"):find(woolExport, 1, true), "Export the limited wool quantity")
equal(quantity(addon.GetPlan(tailoring, 75, true, 1, nil, true).auction, "Wool Cloth"), 0, "Wool starts after 75")
equal(quantity(addon.GetPlan(tailoring, 150, true, 100, skip150).auction, "Wool Cloth"), 0, "Wool ends at 100")
equal(skip150.steps[#skip150.steps].recipe, "Small Silk Pack", "Less wool levels with silk through 150")
equal(quantity(skip150.auction, "Mageweave Cloth"), 0, "Less wool defers Mageweave")
equal(addon.GetPlan(tailoring, 120, true, 119).steps[1].crafts, 13, "Silk bolt estimate spread across the normal range")
equal(addon.GetPlan(tailoring, 150, true, 149, normal150).steps[1].crafts, 7, "Normal Mageweave estimate after resuming")

local skip200 = addon.GetPlan(tailoring, 200, true, 1, nil, true)
local normal200 = addon.GetPlan(tailoring, 200, true, 1)
local resumed = addon.GetPlan(tailoring, 200, true, 190, skip200)
equal(addon.ImportString(resumed), addon.ImportString(addon.GetPlan(tailoring, 200, true, 190, normal200)),
  "Pinned routes have the same Mageweave shopping after 190")
equal(resumed.steps[1].recipe, "Black Mageweave Leggings", "Continue leveling at the current skill")
equal(quantity(resumed.auction, "Bolt of Mageweave"), 32, "Buy the bolts for leggings")
equal(quantity(resumed.auction, "Mageweave Cloth"), 0, "Skip raw cloth for prep")
wow.bags[4339] = 8
local withBolts = addon.GetPlan(tailoring, 200, true, 190, skip200)
equal(quantity(withBolts.auction, "Bolt of Mageweave"), 24, "Subtract owned bolts from purchases")
wow.bags[4339] = nil

wow.prices[4338], wow.prices[4339] = 10, 10000
local expensiveBolts = addon.GetPlan(tailoring, 200, true, 190, skip200)
equal(quantity(expensiveBolts.auction, "Bolt of Mageweave"), 32, "Buy bolts even when crafting would be cheaper")
equal(quantity(expensiveBolts.auction, "Mageweave Cloth"), 0, "Avoid crafting extra bolts for prep")
wow.prices[4338], wow.prices[4339] = nil, nil

wow.defaultPrice = 100
local pricedSkip = addon.GetPlan(tailoring, 150, true, 1, nil, true)
equal(quantity(pricedSkip.auction, "Bolt of Woolen Cloth"), 4, "Buy the remaining four cheap wool bolts")
equal(quantity(pricedSkip.auction, "Wool Cloth"), 66, "Craft the first 22 bolts for skill")
equal(quantity(pricedSkip.auction, "Bolt of Silk Cloth"), 41, "Buy remaining cheap silk bolts")
wow.bags[2997] = 4
local ownedWool = addon.GetPlan(tailoring, 150, true, 1, pricedSkip)
equal(quantity(ownedWool.auction, "Bolt of Woolen Cloth"), 0, "Use owned wool bolts for capes")
equal(quantity(ownedWool.auction, "Wool Cloth"), 66, "Keep raw wool for the skill-up crafts")
wow.bags[2997] = nil
equal(pricedSkip.cost.net, pricedSkip.cost.gross - pricedSkip.revenue, "Less wool quote uses its own materials and proceeds")
wow.defaultPrice = 50
print("PASS Less wool shopping, 298 partial routes, Mageweave handoff, and intermediate buying")

local engineering = 4
wow.prices[2838], wow.prices[4377] = 10, 10000
local sheep = addon.GetPlan(engineering, 175, true, 160)
equal(sheep.steps[1].recipe, "Explosive Sheep", "Engineering resumes with the leveling recipe")
equal(quantity(sheep.auction, "Heavy Blasting Powder"), 30, "Buy the powder used by 15 Explosive Sheep")
equal(quantity(sheep.auction, "Heavy Stone"), 0, "No raw stone for prep-only powder")
assert(addon.ImportString(sheep):find('"Heavy Blasting Powder"', 1, true), "Export finished powder")
local powderLeveling = addon.GetPlan(engineering, 175, true, 135)
equal(powderLeveling.steps[1].recipe, "Heavy Blasting Powder", "Still make powder for skill from 135 to 140")
equal(powderLeveling.steps[1].keep, 30, "Reserve the powder made while leveling")
equal(quantity(powderLeveling.auction, "Heavy Blasting Powder"), 0, "Use leveling output before buying powder")
equal(quantity(powderLeveling.auction, "Heavy Stone"), 40, "Buy stone for the skill-up crafts")
wow.prices[2838], wow.prices[4377] = nil, nil
print("PASS Engineering buys prep powder and reserves powder crafted for skill")

local cooking = 7
local plan = addon.GetPlan(cooking, 300, false, 1)
local materials = {}
for _, items in ipairs({ plan.auction, plan.vendor }) do
  for _, item in ipairs(items) do materials[item.name] = item.quantity end
end
for name, quantity in pairs({
  ["Raw Brilliant Smallfish"] = 55, ["Raw Longjaw Mud Snapper"] = 55, ["Raw Bristle Whisker Catfish"] = 53,
  ["Tangy Clam Meat"] = 28, ["Raptor Flesh"] = 55, ["Raw Spotted Yellowtail"] = 72,
  ["Raw Nightfin Snapper"] = 18, ["Refreshing Spring Water"] = 18, ["Hot Spices"] = 83,
  ["Expert Cookbook"] = 1, ["Giant Egg"] = 12, ["Zesty Clam Meat"] = 10, ["Alterac Swiss"] = 20,
}) do
  equal(materials[name], quantity, "Full Cooking route quantity for " .. name)
end
wow.bags[12207], wow.bags[8932] = 5, 20
local capped = addon.GetPlan(cooking, 300, true, 225, plan, nil, 225)
equal(capped.auction[1].quantity, 7, "Count Giant Eggs already in bags")
equal(quantity(capped.vendor, "Alterac Swiss"), 0, "Count Alterac Swiss already in bags")
assert(not addon.ImportString(addon.GetPlan(cooking, 225, true, 1)):find("Giant Egg", 1, true),
  "A target of 225 should omit Artisan turn-in items")
print("PASS published Cooking materials and bag-aware Artisan shopping")

local firstAid = 8
local firstAidPlan = addon.GetPlan(firstAid, 300, true, 1)
equal(firstAidPlan.name, "First Aid", "First Aid is a selectable guide")
equal(quantity(firstAidPlan.auction, "Linen Cloth"), 180, "First Aid linen rollup")
equal(quantity(firstAidPlan.auction, "Wool Cloth"), 163, "First Aid wool rollup")
equal(quantity(firstAidPlan.auction, "Silk Cloth"), 141, "First Aid silk rollup")
equal(quantity(firstAidPlan.auction, "Mageweave Cloth"), 108, "First Aid mageweave rollup")
equal(quantity(firstAidPlan.auction, "Runecloth"), 71, "First Aid runecloth rollup")
equal(firstAidPlan.vendorSpend, 17200, "First Aid budgets the Expert book and both manuals")
equal(quantity(addon.GetPlan(firstAid, 185, true, 150, nil, nil, 225).vendor, "Expert First Aid - Under Wraps"), 0,
  "A character who knows Expert First Aid needs no Expert book")
local shortFirstAid = addon.GetPlan(firstAid, 210, true, 150, nil, nil, 225)
equal(quantity(shortFirstAid.vendor, "Manual: Heavy Silk Bandage"), 1, "Buy the manual used within the target")
equal(quantity(shortFirstAid.vendor, "Manual: Mageweave Bandage"), 0, "Omit manuals beyond the target")
wow.bags[16112] = 1
local ownedManual = addon.GetPlan(firstAid, 210, true, 150, nil, nil, 225)
equal(#ownedManual.vendor, 0, "A manual in the bags requires no purchase")
wow.bags[16112] = nil
print("PASS First Aid cloth quantities and manual purchases")

-- Branches must change the actual materials, including quest turn-ins and exports.
wow.defaultPrice = nil
local smith = 2
local defaultSmith = addon.GetPlan(smith, 245, true, 235, nil, false, 300)
local spurs = addon.GetPlan(smith, 245, true, 235, nil, false, 300,
  { ["smith-230"] = "Mithril Spurs", ["smith-240"] = "Mithril Spurs" })
equal(quantity(defaultSmith.auction, "Thick Leather"), 44, "Default boots materials")
equal(quantity(spurs.auction, "Thick Leather"), 0, "Spurs replace boots materials")
equal(quantity(spurs.auction, "Thorium Bar"), 0, "Spurs remove belt materials and quest turn-in")
equal(quantity(spurs.auction, "Mithril Bar"), 112, "Both Spurs ranges use the guide's 28 crafts")
equal(quantity(spurs.auction, "Solid Grinding Stone"), 84, "Buy the grinding stones used by Spurs")
equal(quantity(spurs.auction, "Solid Stone"), 0, "Skip raw stone for prep")
assert(addon.ImportString(spurs):find('"Solid Grinding Stone"', 1, true), "Export includes finished grinding stones")
local partial = addon.GetPlan(smith, 245, true, 240, nil, false, 300, { ["smith-240"] = "Mithril Spurs" })
equal(quantity(partial.auction, "Mithril Bar"), 72, "Choice works when starting at the second range")
wow.bags[3860] = 4
partial = addon.GetPlan(smith, 245, true, 240, nil, false, 300, { ["smith-240"] = "Mithril Spurs" })
equal(quantity(partial.auction, "Mithril Bar"), 68, "Choice accounts for owned materials")
wow.bags[3860] = nil
local belt = addon.GetPlan(tailoring, 240, true, 215, nil, false, 300, { ["tailor-215"] = "Runecloth Belt" })
local bag = addon.GetPlan(tailoring, 240, true, 215, nil, false, 300, { ["tailor-215"] = "Mageweave Bag" })
assert(quantity(belt.auction, "Bolt of Runecloth") > quantity(bag.auction, "Bolt of Runecloth"), "Belt choice changes shopping")
local visible = addon.GetGuideSteps(tailoring, belt)
local choicesSeen = 0
for _, step in ipairs(visible) do if step.choice and step.choice.id == "tailor-215" then choicesSeen = choicesSeen + 1 end end
equal(choicesSeen, 1, "Belt choice stays distinct from the next Belt range")
local shoulders = addon.GetPlan(tailoring, 300, true, 280, nil, false, 300, { ["tailor-finish"] = "Runecloth Shoulders" })
local turban = addon.GetPlan(tailoring, 300, true, 280, nil, false, 300, { ["tailor-finish"] = "Wizardweave Turban" })
assert(quantity(shoulders.auction, "Ironweb Spider Silk") > 0, "Shoulders materials")
assert(quantity(turban.auction, "Dream Dust") > 0, "Turban materials")
equal(quantity(turban.auction, "Ironweb Spider Silk"), 0, "Turban excludes Shoulders materials")
local cuffFallback = addon.GetPlan(tailoring, 300, false, 250, nil, false, 300, {
  ["tailor-250"] = "Runecloth Gloves", ["tailor-260"] = "Runecloth Shoulders", ["tailor-finish"] = "Runecloth Shoulders",
})
equal(quantity(cuffFallback.auction, "Pattern: Runecloth Shoulders"), 1, "Repeated recipes need only one pattern")
local redgill = addon.GetPlan(cooking, 300, false, 225, nil, false, 300, { ["cook-225"] = "Filet of Redgill" })
equal(quantity(redgill.auction, "Raw Redgill"), 72, "Redgill option uses its own fish")
equal(quantity(redgill.auction, "Raw Spotted Yellowtail"), 0, "Redgill replaces Yellowtail")
equal(quantity(redgill.auction, "Raw Nightfin Snapper"), 18, "Nightfin still finishes the route")
local oil = addon.GetPlan(alchemy, 300, false, 250)
equal(quantity(oil.auction, "Stonescale Eel"), 47, "Buy the fish used for Stonescale Oil")
equal(oil.steps[1].keep, 88, "Reserve brewed oil for the defense elixirs")
print("PASS selectable recipes, partial ranges, owned materials, and exports")
