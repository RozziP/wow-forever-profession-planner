local wow = FPT_TEST
local equal = wow.equal
local addon = wow.loadAddon()
local alchemy, tailoring = 1, 6
equal(addon.routes[alchemy].name, "Alchemy", "Alchemy fixture")
equal(addon.routes[tailoring].name, "Tailoring", "Tailoring fixture")

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
print(string.format("PASS %d plans and shopping exports across all six professions", planCount))
