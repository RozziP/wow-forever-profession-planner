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

local later = addon.GetPlan(alchemy, 165, true, 130)
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
equal(quantity(normal150.auction, "Wool Cloth"), 459, "Normal guide uses wool")
equal(quantity(skip150.auction, "Wool Cloth"), 78, "Less wool budgets 26 wool bolts")
equal(quantity(skip150.auction, "Elixir of Wisdom"), 0, "Less wool avoids Gloves of Meditation")
local woolExport = '^"Wool Cloth"' .. string.rep(";", 11) .. "#;;78^"
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
equal(resumed.steps[1].recipe, "Bolt of Mageweave", "Known Mageweave recipe can supply prep")
equal(resumed.steps[1].keep, 38, "Reserve the bolts for leggings")
wow.bags[4339] = 8
local withBolts = addon.GetPlan(tailoring, 200, true, 190, skip200)
equal(withBolts.steps[1].crafts, 30, "Existing Mageweave bolts replace prep")
equal(quantity(withBolts.auction, "Mageweave Cloth"), 150, "Export only remaining Mageweave cloth")
wow.bags[4339] = nil

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

local cooking = 7
local plan = addon.GetPlan(cooking, 300, false, 1)
local materials = {}
for _, items in ipairs({ plan.auction, plan.vendor }) do
  for _, item in ipairs(items) do materials[item.name] = item.quantity end
end
for name, quantity in pairs({
  ["Raw Brilliant Smallfish"] = 55, ["Raw Longjaw Mud Snapper"] = 55, ["Raw Bristle Whisker Catfish"] = 55,
  ["Tangy Clam Meat"] = 30, ["Raptor Flesh"] = 55, ["Raw Spotted Yellowtail"] = 140,
  ["Hot Spices"] = 85, ["Expert Cookbook"] = 1, ["Giant Egg"] = 12, ["Zesty Clam Meat"] = 10, ["Alterac Swiss"] = 20,
}) do
  equal(materials[name], quantity, "Full Cooking route quantity for " .. name)
end
wow.bags[12207], wow.bags[8932] = 5, 20
local capped = addon.GetPlan(cooking, 300, true, 225, plan, nil, 225)
equal(capped.auction[1].quantity, 7, "Count Giant Eggs already in bags")
equal(#capped.vendor, 0, "Count Alterac Swiss already in bags")
assert(not addon.ImportString(addon.GetPlan(cooking, 225, true, 1)):find("Giant Egg", 1, true),
  "A target of 225 should omit Artisan turn-in items")
print("PASS published Cooking materials and bag-aware Artisan shopping")
