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

local function useBags(bags, used, item, quantity, vendor)
  if not item then return quantity end
  local key = item.id or item.name
  local alreadyUsed = used[key] and used[key].quantity or 0
  local available = math.max(0, bags(item) - alreadyUsed)
  local taken = math.min(quantity, available)
  if taken > 0 then used[key] = { item = item, quantity = alreadyUsed + taken, vendor = vendor } end
  return quantity - taken
end

local function makePriceReader()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local getPrice = api and api.GetAuctionPriceByItemID
  if type(getPrice) ~= "function" then
    return { get = function() end, available = false }
  end
  local cache = {}
  local function readPrice(item)
    if cache[item.id] == nil then
      local ok, price = pcall(getPrice, addonName, item.id)
      cache[item.id] = ok and type(price) == "number" and price > 0 and price or false
    end
    return cache[item.id] or nil
  end
  return { get = readPrice, available = true }
end

local function quote(route, market)
  local cost = { missing = {}, available = market.available }
  if #route.auction > 0 and not cost.available then return cost end
  if route.from and route.from >= route.cap then return cost end
  local gross = route.vendorSpend
  for _, item in ipairs(route.auction) do
    local price = market.get(item)
    if price then
      gross = gross + price * item.quantity
    else
      cost.missing[#cost.missing + 1] = item.name
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

local function expectedCrafts(from, to, yellow, gray)
  local crafts = 0
  for skill = from, to - 1 do
    crafts = crafts + (skill <= yellow and 1 or (gray - yellow) / (gray - skill))
  end
  return math.ceil(crafts - 1e-9)
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

local function sectionPlans(base, start, target, market, preferBuying, bags, used)
  local sections, prices, vendorPrices = {}, {}, {}
  local recipes, stock = {}, {}
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

  local function addStock(name, step, quantity)
    local lots = stock[name] or {}
    lots[#lots + 1] = { step = step, quantity = quantity }
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
    remaining = useBags(bags, used, vendor or prices[name], remaining, vendor ~= nil)
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
    addStock(name, prep, crafts * yield - remaining)
  end

  local function craftsTo(step, targetSkill)
    if targetSkill <= step.from then return 0 end
    if targetSkill >= step.to then return step.crafts end
    if step.yellow then return math.min(step.crafts, expectedCrafts(step.from, targetSkill, step.yellow, step.gray)) end
    return math.ceil(step.crafts * (targetSkill - step.from) / (step.to - step.from))
  end

  for _, bounds in ipairs({ { 1, 75 }, { 75, 150 }, { 150, 225 }, { 225, 300 } }) do
    local from, to = math.max(bounds[1], start), math.min(bounds[2], target)
    if to > from then
      section, shopping = newSection(from, to), {}
      sections[#sections + 1] = section
      for _, step in ipairs(base.steps) do
        if step.from < to and step.to > from then
          local crafts = craftsTo(step, to) - craftsTo(step, from)
          local stepFrom, stepTo = math.max(from, step.from), math.min(to, step.to)
          if crafts > 0 then
            local firstPrep = #section.steps + 1
            for material, units in pairs(step.mat) do consume(material, units * crafts) end
            if step.from >= from or from == start then
              for material, units in pairs(step.turnIn or {}) do consume(material, units) end
            end
            for i = firstPrep, #section.steps do
              section.steps[i].from, section.steps[i].to = stepFrom, stepTo
            end
            local row = { from = stepFrom, to = stepTo, recipe = step.recipe, crafts = crafts }
            if keepTools[step.recipe] then row.keep = crafts end
            addStock(step.recipe, row, crafts * step.yield)
            recipes[step.recipe] = step
            section.revenue = section.revenue + step.sell * crafts
            section.steps[#section.steps + 1] = row
          end
        end
      end
      local hammer = vendorPrices["Blacksmith Hammer"]
      if from == 1 and hammer and useBags(bags, used, hammer, 1, true) > 0 then shopping[hammer.name] = 1 end
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
  return sections
end

local function finishFor(recipe, start, target, bolt, market, preferBuying, bags, sectionUsed)
  local used = {}
  for key, quantity in pairs(sectionUsed) do used[key] = quantity end
  local crafts = expectedCrafts(start, target, 275, 305)
  local finish = {
    name = recipe.name, step = { from = start, to = target, recipe = recipe.name, crafts = crafts },
    auction = {}, vendor = {}, vendorSpend = 0, revenue = crafts * recipe.sell,
  }
  local function addAuction(item, quantity)
    if quantity > 0 then
      finish.auction[#finish.auction + 1] = { name = item.name, id = item.id, quantity = quantity, price = item.price }
    end
  end

  addAuction(recipe.pattern, useBags(bags, used, recipe.pattern, recipe.pattern.quantity))
  for _, item in ipairs(recipe.auction) do
    local quantity = item.quantity * crafts
    if item.name == "Runecloth" then
      local boltsNeeded = useBags(bags, used, bolt, quantity / 5)
      local clothPrice, boltPrice = market.get(item), market.get(bolt)
      if preferBuying and boltPrice and (not clothPrice or boltPrice <= clothPrice * 5 * 1.10) then
        addAuction(bolt, boltsNeeded)
      else
        addAuction(item, useBags(bags, used, item, boltsNeeded * 5))
        if boltsNeeded > 0 then
          finish.prep = { recipe = bolt.name, from = start, to = target, crafts = boltsNeeded, prep = true, keep = boltsNeeded }
        end
      end
    else
      addAuction(item, useBags(bags, used, item, quantity))
    end
  end
  for _, item in ipairs(recipe.vendor) do
    local quantity = useBags(bags, used, item, item.quantity * crafts, true)
    if quantity > 0 then
      finish.vendor[#finish.vendor + 1] = { name = item.name, id = item.id, quantity = quantity, price = item.price }
      finish.vendorSpend = finish.vendorSpend + quantity * item.price
    end
  end
  return finish, used
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

local function buildPlan(profession, source, start, cap, market, bags, preferBuying, usePublished, finishName)
  local used = {}
  local sections = sectionPlans(source, start, cap, market, preferBuying, bags, used)
  local plan = newSection(start, cap)
  plan.source = source
  plan.name, plan.url, plan.notes, plan.sections = profession.name, profession.url, source.notes, sections
  local selected, alternative
  if source.finishes and cap > 265 and start < cap then
    local finishStart = math.max(start, 265)
    local first, firstUsed = finishFor(source.finishes[1], finishStart, cap, source.finishBolt, market, preferBuying, bags, used)
    local second, secondUsed = finishFor(source.finishes[2], finishStart, cap, source.finishBolt, market, preferBuying, bags, used)
    local firstQuote, secondQuote = quote(first, market), quote(second, market)
    selected, alternative = first, second
    local selectedUsed = firstUsed
    if finishName == second.name or (not finishName and lowerCost(secondQuote, firstQuote)) then
      selected, alternative = second, first
      firstQuote, secondQuote = secondQuote, firstQuote
      selectedUsed = secondUsed
    end
    local last = sections[#sections]
    last.selected = { name = selected.name, cost = firstQuote }
    last.alternative = { name = alternative.name, cost = secondQuote }
    if selected.prep then last.steps[#last.steps + 1] = selected.prep end
    last.steps[#last.steps + 1] = selected.step
    last.auction = mergeItems(last.auction, selected.auction)
    last.vendor = mergeItems(last.vendor, selected.vendor)
    last.vendorSpend = last.vendorSpend + selected.vendorSpend
    last.revenue = last.revenue + selected.revenue
    plan.selected, plan.alternative = last.selected, last.alternative
    used = selectedUsed
  end
  for _, section in ipairs(sections) do
    section.name, section.url = profession.name, profession.url
    section.cost = quote(section, market)
    for _, step in ipairs(section.steps) do plan.steps[#plan.steps + 1] = step end
    plan.auction = mergeItems(plan.auction, section.auction)
    plan.vendor = mergeItems(plan.vendor, section.vendor)
    plan.vendorSpend = plan.vendorSpend + section.vendorSpend
    plan.revenue = plan.revenue + section.revenue
  end
  local published = source.published and source.published[cap]
  if source.published and source.finishes and cap >= 265 then published = source.published[265] end
  if published and usePublished and not next(used) then
    plan.auction = mergeItems(published, selected and selected.auction)
    plan.published = true
  end
  plan.cost = quote(plan, market)
  local ownedAuction, ownedVendor = {}, {}
  for _, entry in pairs(used) do
    local rows = entry.vendor and ownedVendor or ownedAuction
    local item = entry.item
    rows[#rows + 1] = { name = item.name, id = item.id, quantity = entry.quantity, keep = item.name == "Blacksmith Hammer" }
  end
  plan.shoppingAuction = shoppingProgress(plan.auction, ownedAuction, bags)
  plan.shoppingVendor = shoppingProgress(plan.vendor, ownedVendor, bags)
  return plan
end

local function tailoringPlan(profession, start, cap, market, bags, preferBuying, usePublished)
  local full, rush = profession.full, profession.rush
  local belt = full.beltOption
  local canUseRush = start < 150 and start < cap
  local canUseBelt = start < belt.to and cap > belt.from and start < cap
  local guide = buildPlan(profession, full, start, cap, market, bags, preferBuying,
    usePublished and not (canUseRush or canUseBelt))
  if not canUseRush and not canUseBelt then return guide end

  local best = guide
  local function compare(useRush, useBelt)
    local route = {
      steps = {}, notes = full.notes, finishes = full.finishes, finishBolt = full.finishBolt,
      auction = useRush and mergeItems(full.auction, rush.auction) or full.auction,
      vendor = useRush and mergeItems(full.vendor, rush.vendor) or full.vendor,
      intermediates = useRush and mergeItems(full.intermediates, rush.intermediates) or full.intermediates,
    }
    if useRush then
      for _, step in ipairs(rush.steps) do route.steps[#route.steps + 1] = step end
    end
    for _, step in ipairs(full.steps) do
      if not useRush or step.from >= 150 then
        route.steps[#route.steps + 1] = useBelt and step.from == belt.from and step.to == belt.to and belt or step
      end
    end
    local candidate = buildPlan(profession, route, start, cap, market, bags, preferBuying)
    if lowerCost(candidate.cost, best.cost) then
      candidate.defaultGuideCost = guide.cost
      best = candidate
    end
  end

  if canUseRush then compare(true, false) end
  if canUseBelt then compare(false, true) end
  if canUseRush and canUseBelt then compare(true, true) end
  return best
end

function addon.GetPlan(index, rush150, target, preferBuying, currentSkill, pinnedPlan)
  local profession = addon.routes[index]
  local maximum = rush150 and 150 or 300
  local cap = math.min(maximum, math.max(1, math.floor(target or maximum)))
  local start = math.max(1, math.floor(currentSkill or 1))
  local market = makePriceReader()
  local bags = makeBagReader()
  if pinnedPlan then
    return buildPlan(profession, pinnedPlan.source, start, cap, market, bags, preferBuying, false,
      pinnedPlan.selected and pinnedPlan.selected.name)
  end
  if not rush150 and profession.full.beltOption then
    return tailoringPlan(profession, start, cap, market, bags, preferBuying, start == 1 and not preferBuying)
  end
  local guide = buildPlan(profession, profession.full, start, cap, market, bags, preferBuying,
    start == 1 and not rush150 and not preferBuying)
  if not rush150 or start >= cap then return guide end

  local optimized = buildPlan(profession, profession.rush, start, cap, market, bags, preferBuying)
  if lowerCost(optimized.cost, guide.cost) then
    optimized.defaultGuideCost = guide.cost
    return optimized
  end
  return guide
end

function addon.GetGuideSteps(index, plan)
  local steps = {}
  local rangeStarts = {}
  if plan.from > 1 then
    -- Reconstruct earlier rows without assuming the player still owns those materials.
    local history = buildPlan(addon.routes[index], plan.source, 1, plan.cap, makePriceReader(),
      function() return 0 end, true, false, plan.selected and plan.selected.name)
    for _, step in ipairs(history.steps) do
      if step.to <= plan.from then
        steps[#steps + 1] = step
      elseif not step.prep and step.from < plan.from then
        rangeStarts[step.to] = step.from
      end
    end
  end
  for _, step in ipairs(plan.steps) do
    if step.from == plan.from and rangeStarts[step.to] then
      local row = {}
      for key, value in pairs(step) do row[key] = value end
      row.from = rangeStarts[step.to]
      steps[#steps + 1] = row
    else
      steps[#steps + 1] = step
    end
  end
  return steps
end

function addon.ImportString(plan)
  local fields = { string.format("%s %d-%d", plan.name, plan.from, plan.cap) }
  local separators = string.rep(";", 11) .. "#;;"
  for _, item in ipairs(plan.auction) do
    fields[#fields + 1] = '"' .. item.name .. '"' .. separators .. item.quantity
  end
  return table.concat(fields, "^")
end
