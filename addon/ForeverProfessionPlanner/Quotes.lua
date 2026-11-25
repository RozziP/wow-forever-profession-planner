local addonName, addon = ...

local function makeBagReader()
  local getCount = C_Item and C_Item.GetItemCount or GetItemCount
  local counts = {}
  return function(item)
    local key = item.id or item.name
    if counts[key] == nil then counts[key] = getCount and getCount(key, false) or 0 end
    return counts[key]
  end
end

local function useBags(bags, used, item, quantity, vendor, costRoute)
  if not item then return quantity end
  local key = item.id or item.name
  local alreadyUsed = used[key] and used[key].quantity or 0
  local available = math.max(0, bags(item) - alreadyUsed)
  local taken = math.min(quantity, available)
  if taken > 0 then used[key] = { item = item, quantity = alreadyUsed + taken, vendor = vendor } end
  if taken > 0 and costRoute then
    if vendor then
      costRoute.ownedVendorSpend = (costRoute.ownedVendorSpend or 0) + taken * item.price
    else
      costRoute.ownedAuction = costRoute.ownedAuction or {}
      costRoute.ownedAuction[#costRoute.ownedAuction + 1] = { name = item.name, id = item.id, quantity = taken }
    end
  end
  return quantity - taken
end

local function makePriceReader()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local getPrice = api and api.GetAuctionPriceByItemID
  local available = type(getPrice) == "function"
  local cache, missing = {}, {}
  local function readPrice(item)
    if cache[item.id] == nil then
      local ok, price
      if available then ok, price = pcall(getPrice, addonName, item.id) end
      cache[item.id] = ok and type(price) == "number" and price > 0 and price or false
      if not cache[item.id] then missing[item.id] = true end
    end
    return cache[item.id] or nil
  end
  return { get = readPrice, available = available, missing = missing }
end

local function quote(route, market)
  local cost = { missing = {}, available = market.available }
  if route.from and route.from >= route.cap then return cost end
  local gross = route.vendorSpend + (route.ownedVendorSpend or 0)
  local missing = {}
  for _, items in ipairs({ route.auction, route.ownedAuction or {} }) do
    for _, item in ipairs(items) do
      local price = market.get(item)
      if price then
        gross = gross + price * item.quantity
      elseif not missing[item.name] then
        missing[item.name] = true
        cost.missing[#cost.missing + 1] = item.name
      end
    end
  end
  if #cost.missing == 0 then
    cost.gross, cost.net = gross, gross - route.revenue
  end
  return cost
end

local function mergeItems(base, extra)
  local items, byName = {}, {}
  local function add(item)
    local row = byName[item.name]
    if row then
      row.quantity = row.quantity + item.quantity
      row.keep = row.keep or item.keep
    else
      row = { name = item.name, id = item.id, price = item.price, quantity = item.quantity, keep = item.keep }
      items[#items + 1] = row
      byName[row.name] = row
    end
  end
  for _, item in ipairs(base) do add(item) end
  for _, item in ipairs(extra or {}) do add(item) end
  table.sort(items, function(a, b) return a.name < b.name end)
  return items
end

local function craftEstimate(from, to, yellow, gray)
  local crafts = 0
  for skill = from, to - 1 do
    crafts = crafts + (skill <= yellow and 1 or (gray - yellow) / (gray - skill))
  end
  return crafts
end

local function newSection(from, cap)
  return { from = from, cap = cap, steps = {}, auction = {}, vendor = {}, vendorSpend = 0, revenue = 0 }
end

local function lowerCost(candidate, reference)
  return candidate.net ~= nil and (reference.net == nil or candidate.net < reference.net)
end

local buyExtraLeather = { ["Light Leather"] = true, ["Medium Leather"] = true, ["Heavy Leather"] = true }
local keepTools = {
  ["Runed Copper Rod"] = true, ["Runed Silver Rod"] = true, ["Runed Golden Rod"] = true,
  ["Runed Truesilver Rod"] = true, ["Runed Arcanite Rod"] = true,
  ["Arclight Spanner"] = true, ["Gyromatic Micro-Adjustor"] = true,
}

local function selectableStep(primary, alternate, id, selection)
  local selected = selection == alternate.recipe and alternate or primary
  local step = {}
  for key, value in pairs(selected) do step[key] = value end
  step.choice = { id = id, options = { primary.recipe, alternate.recipe } }
  return step
end

local function choiceSource(source, choices)
  if not source.choices then return source end
  local result = {}
  for key, value in pairs(source) do result[key] = value end
  result.steps = {}
  for _, step in ipairs(source.steps) do
    for id, alternate in pairs(source.choices) do
      if step.from == alternate.from and step.to == alternate.to then
        step = selectableStep(step, alternate, id, choices and choices[id])
        break
      end
    end
    result.steps[#result.steps + 1] = step
  end
  return result
end

local function sectionPlans(base, start, target, market, preferBuying, bags, used, currentMaximum, anchorSkill)
  local sections, prices, vendorPrices = {}, {}, {}
  local recipes, stock, patterns = {}, {}, {}
  for _, item in ipairs(base.intermediates) do prices[item.name] = item end
  for _, item in ipairs(base.auction) do prices[item.name] = item end
  for _, item in ipairs(base.vendor) do vendorPrices[item.name] = item end
  -- Earlier recipes can supply materials, but the player's previous outputs are unknown.
  for _, step in ipairs(base.steps) do
    if step.from >= start then break end
    recipes[step.recipe] = step
  end

  local function priceOf(name)
    if vendorPrices[name] then return vendorPrices[name].price end
    return (prices[name] and market.get(prices[name])) or math.huge
  end

  local section, shopping
  local function prepFor(name)
    if buyExtraLeather[name] then return end
    local recipe = recipes[name] or (base.prep and base.prep[name])
    if recipe then return recipe.mat, recipe.yield, recipe.action end
  end

  local function unitCost(name)
    local ingredients, yield = prepFor(name)
    local buying = priceOf(name)
    if not ingredients then return buying end
    local making = 0
    for material, units in pairs(ingredients) do making = making + units * unitCost(material) end
    return math.min(buying, making / yield)
  end

  local function addStock(name, step, quantity, sellPrice)
    local lots = stock[name] or {}
    lots[#lots + 1] = { step = step, quantity = quantity, sellPrice = sellPrice or 0, section = section }
    stock[name] = lots
  end

  local function consume(name, remaining)
    for _, lot in ipairs(stock[name] or {}) do
      local used = math.min(lot.quantity, remaining)
      if used > 0 then
        lot.quantity = lot.quantity - used
        lot.step.keep = (lot.step.keep or 0) + used
        remaining = remaining - used
      end
      if remaining <= 0 then return end
    end

    local vendor = vendorPrices[name]
    remaining = useBags(bags, used, vendor or prices[name], remaining, vendor ~= nil, section)
    if remaining <= 0 then return end

    local ingredients, yield, action = prepFor(name)
    local buying = priceOf(name)
    local making = 0
    if ingredients then
      for material, units in pairs(ingredients) do making = making + units * unitCost(material) end
    end
    local crafts = ingredients and math.ceil(remaining / yield)
    if not ingredients or (preferBuying and buying < math.huge and buying * math.ceil(remaining) <= making * crafts * 1.10) then
      shopping[name] = (shopping[name] or 0) + remaining
      return
    end
    for material, units in pairs(ingredients) do consume(material, units * crafts) end
    local previous = section.steps[#section.steps]
    local prep
    local caption = action or name
    if previous and previous.prep and not previous.from and previous.recipe == caption then
      previous.crafts = previous.crafts + crafts
      previous.keep = previous.keep + remaining
      prep = previous
    else
      prep = { recipe = caption, item = name, crafts = crafts, prep = true, keep = remaining }
      section.steps[#section.steps + 1] = prep
    end
    addStock(name, prep, crafts * yield - remaining, recipes[name] and recipes[name].sellPrice)
  end

  local function craftsTo(step, targetSkill)
    if targetSkill <= step.from then return 0 end
    if targetSkill >= step.to then return step.crafts end
    local progress = targetSkill - step.from
    local range = step.to - step.from
    local fraction = progress / range
    if step.yellow then
      fraction = craftEstimate(step.from, targetSkill, step.yellow, step.gray)
        / craftEstimate(step.from, step.to, step.yellow, step.gray)
    end
    -- Spread the guide estimate across the range and budget at least one craft per skill point.
    return math.max(progress, math.min(step.crafts - (range - progress), math.ceil(step.crafts * fraction - 1e-9)))
  end

  for _, bounds in ipairs({ { 1, 75 }, { 75, 150 }, { 150, 225 }, { 225, 300 } }) do
    local from, to = math.max(bounds[1], start), math.min(bounds[2], target)
    if to > from then
      section, shopping = newSection(from, to), {}
      sections[#sections + 1] = section
      local rankCap = bounds[1]
      if base.rankMaterials and from == rankCap and (not currentMaximum or currentMaximum <= rankCap) then
        for material, units in pairs(base.rankMaterials[rankCap] or {}) do consume(material, units) end
      end
      for _, step in ipairs(base.steps) do
        if step.from < to and step.to > from then
          local crafts = craftsTo(step, to) - craftsTo(step, from)
          if anchorSkill and from == start and step.from < start then
            local anchor = math.max(step.from, anchorSkill)
            crafts = math.max(0, craftsTo(step, to) - craftsTo(step, anchor) - (start - anchor))
          end
          local stepFrom, stepTo = math.max(from, step.from), math.min(to, step.to)
          if crafts > 0 then
            local firstPrep = #section.steps + 1
            if step.pattern and not patterns[step.pattern] then
              consume(step.pattern, 1)
              patterns[step.pattern] = true
            end
            for material, units in pairs(step.mat) do consume(material, units * crafts) end
            if step.from >= from or from == start then
              for material, units in pairs(step.turnIn or {}) do consume(material, units) end
            end
            for i = firstPrep, #section.steps do
              section.steps[i].from, section.steps[i].to = stepFrom, stepTo
            end
            local row = { from = stepFrom, to = stepTo, recipe = step.recipe, crafts = crafts, choice = step.choice }
            if keepTools[step.recipe] then row.keep = crafts end
            addStock(step.recipe, row, crafts * step.yield, step.sellPrice)
            recipes[step.recipe] = step
            section.steps[#section.steps + 1] = row
          end
        end
      end
      local hammer = vendorPrices["Blacksmith Hammer"]
      if from == 1 and hammer and useBags(bags, used, hammer, 1, true, section) > 0 then shopping[hammer.name] = 1 end
      for name, quantity in pairs(shopping) do
        local item = vendorPrices[name] or prices[name]
        assert(item, "Missing shopping-list item: " .. name)
        local count = math.ceil(quantity - 1e-9)
        local row = { name = name, id = item.id, price = item.price, quantity = count }
        if name == "Blacksmith Hammer" then row.keep = count end
        if vendorPrices[name] then
          section.vendor[#section.vendor + 1] = row
          section.vendorSpend = section.vendorSpend + count * row.price
        else
          section.auction[#section.auction + 1] = row
        end
      end
      section.auction = mergeItems(section.auction)
      section.vendor = mergeItems(section.vendor)
    end
    if to == target then break end
  end
  for name, lots in pairs(stock) do
    if not keepTools[name] then
      for _, lot in ipairs(lots) do
        lot.section.revenue = lot.section.revenue + math.floor(lot.quantity + 1e-9) * lot.sellPrice
      end
    end
  end
  return sections
end

local function shoppingProgress(purchases, matsInUse, bags)
  local rows = mergeItems(purchases, matsInUse)
  local needed = {}
  for _, item in ipairs(purchases) do needed[item.name] = item.quantity end
  for _, row in ipairs(rows) do
    row.inBags = bags(row)
    row.remaining = needed[row.name] or 0
    -- A bought stack can cover the last fraction of a planned reagent.
    row.quantity = math.ceil(row.quantity - 1e-9)
  end
  return rows
end

local function shoppingQuote(plan, market)
  local vendorValue, ownedValue = 0, 0
  for _, item in ipairs(plan.shoppingVendor) do
    vendorValue = vendorValue + item.quantity * item.price
    ownedValue = ownedValue + math.min(item.quantity, item.inBags) * item.price
  end
  local cost = quote({ from = plan.from, cap = plan.cap, auction = plan.shoppingAuction,
    vendorSpend = vendorValue, revenue = plan.revenue }, market)
  if cost.gross then
    for _, item in ipairs(plan.shoppingAuction) do
      ownedValue = ownedValue + math.min(item.quantity, item.inBags) * market.get(item)
    end
    cost.owned, cost.toBuy = ownedValue, cost.gross - ownedValue
  end
  return cost
end

local function buildPlan(profession, source, start, cap, market, bags, preferBuying, currentMaximum, anchorSkill)
  local used = {}
  local sections = sectionPlans(source, start, cap, market, preferBuying, bags, used, currentMaximum, anchorSkill)
  local plan = newSection(start, cap)
  plan.source = source
  plan.name, plan.url, plan.notes, plan.sections = profession.name, profession.url, source.notes, sections
  for _, section in ipairs(sections) do
    section.name, section.url = profession.name, profession.url
    section.cost = quote(section, market)
    for _, step in ipairs(section.steps) do plan.steps[#plan.steps + 1] = step end
    plan.auction = mergeItems(plan.auction, section.auction)
    plan.vendor = mergeItems(plan.vendor, section.vendor)
    plan.vendorSpend = plan.vendorSpend + section.vendorSpend
    plan.revenue = plan.revenue + section.revenue
  end
  local ownedAuction, ownedVendor = {}, {}
  for _, entry in pairs(used) do
    local rows = entry.vendor and ownedVendor or ownedAuction
    local item = entry.item
    rows[#rows + 1] = { name = item.name, id = item.id, price = item.price, quantity = entry.quantity, keep = item.name == "Blacksmith Hammer" }
  end
  plan.shoppingAuction = shoppingProgress(plan.auction, ownedAuction, bags)
  plan.shoppingVendor = shoppingProgress(plan.vendor, ownedVendor, bags)
  plan.cost = shoppingQuote(plan, market)
  return plan
end

local function tailoringSource(full, rush, finishName)
  local route = {
    steps = {}, notes = full.notes, choices = full.choices,
    auction = rush and mergeItems(full.auction, rush.auction) or full.auction,
    vendor = rush and mergeItems(full.vendor, rush.vendor) or full.vendor,
    intermediates = rush and mergeItems(full.intermediates, rush.intermediates) or full.intermediates,
    prep = rush and rush.prep or full.prep,
  }
  local handoff = 1
  if rush then
    for _, step in ipairs(rush.steps) do route.steps[#route.steps + 1] = step end
    handoff = rush.steps[#rush.steps].to
  end
  for _, step in ipairs(full.steps) do
    if step.from >= handoff then route.steps[#route.steps + 1] = step end
  end
  route.steps[#route.steps + 1] = selectableStep(full.finishes[1], full.finishes[2], "tailor-finish", finishName)
  return route
end

local function tailoringPlan(profession, start, cap, market, bags, preferBuying, skipWool, currentMaximum, choices)
  local full = profession.full
  local belt = full.choices["tailor-215"]
  local rush = skipWool and start < 150 and start < cap and profession.rush
  local finishName = choices and choices["tailor-finish"]
  local function bestFinish(beltChoices)
    local source = choiceSource(tailoringSource(full, rush, finishName), beltChoices)
    local plan = buildPlan(profession, source, start, cap, market, bags, preferBuying, currentMaximum)
    if not finishName and cap > full.finishes[1].from and start < cap then
      source = choiceSource(tailoringSource(full, rush, full.finishes[2].recipe), beltChoices)
      local candidate = buildPlan(profession, source, start, cap, market, bags, preferBuying, currentMaximum)
      if lowerCost(candidate.cost, plan.cost) then return candidate end
    end
    return plan
  end
  local plan = bestFinish(choices)
  if start < belt.to and cap > belt.from and start < cap and not (choices and choices["tailor-215"]) then
    local beltChoices = {}
    for id, recipe in pairs(choices or {}) do beltChoices[id] = recipe end
    beltChoices["tailor-215"] = belt.recipe
    local candidate = bestFinish(beltChoices)
    if lowerCost(candidate.cost, plan.cost) then return candidate end
  end
  return plan
end

function addon.GetPlan(index, target, preferBuying, currentSkill, pinnedPlan, skipWool, currentMaximum, choices, anchorSkill, bagSnapshot)
  local profession = addon.routes[index]
  local maximum = 300
  local cap = math.min(maximum, math.max(1, math.floor(target or maximum)))
  local start = math.max(1, math.floor(currentSkill or 1))
  local market = makePriceReader()
  local bags = bagSnapshot or makeBagReader()
  if pinnedPlan then
    return buildPlan(profession, pinnedPlan.source, start, cap, market, bags, preferBuying, currentMaximum, anchorSkill)
  end
  local plan
  if profession.full.finishes then
    plan = tailoringPlan(profession, start, cap, market, bags, preferBuying, skipWool, currentMaximum, choices)
  else
    local source = choiceSource(profession.full, choices)
    plan = buildPlan(profession, source, start, cap, market, bags, preferBuying, currentMaximum)
  end
  plan.missingPrices = market.missing
  return plan
end

function addon.MakeBagSnapshot()
  return makeBagReader()
end

function addon.RefreshShopping(plan)
  local bags = makeBagReader()
  local function refresh(rows)
    local purchases = {}
    for _, row in ipairs(rows) do
      row.inBags = bags(row)
      row.remaining = math.max(0, row.quantity - row.inBags)
      if row.remaining > 0 then
        purchases[#purchases + 1] = { name = row.name, id = row.id, price = row.price,
          quantity = row.remaining, keep = row.keep }
      end
    end
    return purchases
  end
  plan.auction, plan.vendor = refresh(plan.shoppingAuction), refresh(plan.shoppingVendor)
  plan.vendorSpend = 0
  for _, item in ipairs(plan.vendor) do plan.vendorSpend = plan.vendorSpend + item.quantity * item.price end
  plan.cost = shoppingQuote(plan, makePriceReader())
end

function addon.HasNewPlanPrices(plan)
  local market = makePriceReader()
  for id in pairs(plan.missingPrices) do
    if market.get({ id = id }) then return true end
  end
  return false
end

function addon.GetGuideSteps(index, plan)
  local steps = {}
  local rangeStarts = {}
  local function addStep(step, from)
    from = from or step.from
    local previous = steps[#steps]
    if previous and not previous.prep and not step.prep
      and not previous.choice and not step.choice
      and previous.recipe == step.recipe and previous.to == from then
      if previous.to <= plan.from and step.to > plan.from then
        -- Keep the full skill range when resuming, with counts from the remaining plan.
        previous.crafts, previous.keep = step.crafts, step.keep
      else
        previous.crafts = previous.crafts + step.crafts
        if step.keep then previous.keep = (previous.keep or 0) + step.keep end
      end
      previous.to = step.to
    else
      local row = {}
      for key, value in pairs(step) do row[key] = value end
      row.from = from
      steps[#steps + 1] = row
    end
  end

  if plan.from > 1 then
    -- Reconstruct earlier rows without assuming the player still owns those materials.
    local history = buildPlan(addon.routes[index], plan.source, 1, plan.cap, makePriceReader(),
      function() return 0 end, true)
    for _, step in ipairs(history.steps) do
      if step.to <= plan.from then
        addStep(step)
      elseif not step.prep and step.from < plan.from then
        rangeStarts[step.to] = step.from
      end
    end
  end
  for _, step in ipairs(plan.steps) do
    addStep(step, step.from == plan.from and rangeStarts[step.to])
  end
  return steps
end

function addon.GetCraftingMilliseconds(plan)
  local getSpellInfo = C_Spell and C_Spell.GetSpellInfo
  local durations = {}
  local total = 0
  for _, step in ipairs(plan.steps) do
    local duration = durations[step.recipe]
    if not duration then
      local info = getSpellInfo and getSpellInfo(step.recipe)
      local castTime = info and info.castTime
      duration = castTime and castTime > 0 and castTime or 3000
      durations[step.recipe] = duration
      if info then
        durations[info.name] = duration
        durations[info.spellID] = duration
      end
    end
    total = total + step.crafts * duration
  end
  return total, durations
end

function addon.GetShoppingBagSpace(plan)
  local container = C_Container
  if not container then return end
  if #plan.auction == 0 and #plan.vendor == 0 then return end

  local space = { free = 0, needed = 0, pending = {} }
  local purchases = {}
  local getItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
  for _, items in ipairs({ plan.auction, plan.vendor }) do
    for _, item in ipairs(items) do
      local _, link, _, _, _, _, _, stackSize = getItemInfo(item.id or item.name)
      if stackSize and stackSize > 0 then
        local key = item.id or (link and tonumber(link:match("item:(%d+)"))) or item.name
        local purchase = purchases[key]
        if purchase then
          purchase.remaining = purchase.remaining + item.quantity
        else
          purchases[key] = { remaining = item.quantity, stackSize = stackSize }
        end
      else
        space.incomplete = true
        if item.id then space.pending[item.id] = true end
      end
    end
  end

  for bag = 0, NUM_BAG_SLOTS do
    local freeSlots, family = container.GetContainerNumFreeSlots(bag)
    if not family or family == 0 then space.free = space.free + freeSlots end
    for slot = 1, container.GetContainerNumSlots(bag) do
      local item = container.GetContainerItemInfo(bag, slot)
      local purchase = item and purchases[item.itemID]
      if purchase and not item.isLocked then
        local room = math.max(0, purchase.stackSize - item.stackCount)
        purchase.remaining = math.max(0, purchase.remaining - room)
      end
    end
  end
  for _, purchase in pairs(purchases) do
    space.needed = space.needed + math.ceil(purchase.remaining / purchase.stackSize)
  end
  return space
end

function addon.ImportString(plan)
  local fields = { string.format("%s %d-%d", plan.name, plan.from, plan.cap) }
  local separators = string.rep(";", 11) .. "#;;"
  for _, item in ipairs(plan.auction) do
    fields[#fields + 1] = '"' .. item.name .. '"' .. separators .. item.quantity
  end
  return table.concat(fields, "^")
end
