local addonName, addon = ...

local function makePriceReader()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local getPrice = api and api.GetAuctionPriceByItemID
  local cache = {}
  return function(item)
    if not cache[item.id] then
      local price, source = item.price, "bundled"
      if type(getPrice) == "function" then
        local ok, cached = pcall(getPrice, addonName, item.id)
        if ok and type(cached) == "number" and cached > 0 then
          price, source = cached, "auctionator"
        end
      end
      cache[item.id] = { price, source }
    end
    return unpack(cache[item.id])
  end
end

local function quote(route, readPrice)
  local gross, missing = route.vendorSpend, {}
  local auctionator, bundled = 0, 0
  for _, item in ipairs(route.auction) do
    local price, source = readPrice(item)
    if price <= 0 then
      missing[#missing + 1] = item.name
    else
      gross = gross + price * item.quantity
      if source == "auctionator" then
        auctionator = auctionator + 1
      else
        bundled = bundled + 1
      end
    end
  end
  local source = "No auction prices"
  if auctionator > 0 and bundled > 0 then
    source = "Auctionator cache + bundled prices"
  elseif auctionator > 0 then
    source = "Auctionator cached prices"
  elseif bundled > 0 then
    source = "Bundled prices"
  end
  return { gross = gross, net = gross - route.revenue, missing = missing, source = source }
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
  local candidateMissing, referenceMissing = #candidate.missing, #reference.missing
  return candidateMissing < referenceMissing
    or (candidateMissing == referenceMissing and candidate.net < reference.net)
end

local buyExtraLeather = { ["Light Leather"] = true, ["Medium Leather"] = true, ["Heavy Leather"] = true }
local keepTools = {
  ["Runed Copper Rod"] = true, ["Runed Silver Rod"] = true, ["Runed Golden Rod"] = true,
  ["Runed Truesilver Rod"] = true, ["Runed Arcanite Rod"] = true,
  ["Arclight Spanner"] = true, ["Gyromatic Micro-Adjustor"] = true,
}

local function sectionPlans(base, start, target, readPrice, preferBuying)
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
    local price = prices[name] and readPrice(prices[name]) or 0
    return price > 0 and price or math.huge
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
    if previous and previous.prep and previous.recipe == caption then
      previous.crafts = previous.crafts + crafts
      previous.keep = previous.keep + remaining
      prep = previous
    else
      prep = { recipe = caption, crafts = crafts, prep = true, keep = remaining }
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
            for material, units in pairs(step.mat) do consume(material, units * crafts) end
            if step.from >= from or from == start then
              for material, units in pairs(step.turnIn or {}) do consume(material, units) end
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
      if from == 1 and to > 1 and vendorPrices["Blacksmith Hammer"] then shopping["Blacksmith Hammer"] = 1 end
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

local function finishFor(recipe, start, target, bolt, readPrice, preferBuying)
  local crafts = expectedCrafts(start, target, 275, 305)
  local finish = {
    name = recipe.name, step = { from = start, to = target, recipe = recipe.name, crafts = crafts },
    auction = { recipe.pattern }, vendor = {}, vendorSpend = 0, revenue = crafts * recipe.sell,
  }
  for _, item in ipairs(recipe.auction) do
    local supply, quantity = item, item.quantity * crafts
    if item.name == "Runecloth" then
      local clothPrice, boltPrice = readPrice(item), readPrice(bolt)
      if preferBuying and boltPrice > 0 and (clothPrice <= 0 or boltPrice <= clothPrice * 5 * 1.10) then
        supply, quantity = bolt, quantity / 5
      else
        finish.prep = { recipe = bolt.name, crafts = quantity / 5, prep = true, keep = quantity / 5 }
      end
    end
    finish.auction[#finish.auction + 1] =
      { name = supply.name, id = supply.id, quantity = quantity, price = supply.price }
  end
  for _, item in ipairs(recipe.vendor) do
    local quantity = item.quantity * crafts
    finish.vendor[#finish.vendor + 1] = { name = item.name, quantity = quantity, price = item.price }
    finish.vendorSpend = finish.vendorSpend + quantity * item.price
  end
  return finish
end

local function buildPlan(profession, source, start, cap, readPrice, preferBuying, usePublished)
  local sections = sectionPlans(source, start, cap, readPrice, preferBuying)
  local plan = newSection(start, cap)
  plan.name, plan.url, plan.notes, plan.sections = profession.name, profession.url, source.notes, sections
  local selected, alternative
  if source.finishes and cap > 265 and start < cap then
    local finishStart = math.max(start, 265)
    local first = finishFor(source.finishes[1], finishStart, cap, source.finishBolt, readPrice, preferBuying)
    local second = finishFor(source.finishes[2], finishStart, cap, source.finishBolt, readPrice, preferBuying)
    local firstQuote, secondQuote = quote(first, readPrice), quote(second, readPrice)
    selected, alternative = first, second
    if lowerCost(secondQuote, firstQuote) then
      selected, alternative = second, first
      firstQuote, secondQuote = secondQuote, firstQuote
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
  end
  for _, section in ipairs(sections) do
    section.name, section.url = profession.name, profession.url
    section.cost = quote(section, readPrice)
    for _, step in ipairs(section.steps) do plan.steps[#plan.steps + 1] = step end
    plan.auction = mergeItems(plan.auction, section.auction)
    plan.vendor = mergeItems(plan.vendor, section.vendor)
    plan.vendorSpend = plan.vendorSpend + section.vendorSpend
    plan.revenue = plan.revenue + section.revenue
  end
  local published = source.published and source.published[cap]
  if source.published and source.finishes and cap >= 265 then published = source.published[265] end
  if published and usePublished then
    plan.auction = mergeItems(published, selected and selected.auction)
    plan.published = true
  end
  plan.cost = quote(plan, readPrice)
  return plan
end

local function tailoringPlan(profession, start, cap, readPrice, preferBuying, usePublished)
  local full, rush = profession.full, profession.rush
  local belt = full.beltOption
  local canUseRush = start < 150 and start < cap
  local canUseBelt = start < belt.to and cap > belt.from and start < cap
  local best = buildPlan(profession, full, start, cap, readPrice, preferBuying,
    usePublished and not (canUseRush or canUseBelt))
  best.tailoringRoute = "WoW Professions"
  if not canUseRush and not canUseBelt then return best end

  local function compare(useRush, useBelt, label)
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
    local candidate = buildPlan(profession, route, start, cap, readPrice, preferBuying)
    if lowerCost(candidate.cost, best.cost) then
      candidate.tailoringRoute = label
      best = candidate
    end
  end

  if canUseRush then compare(true, false, "Optimized early route") end
  if canUseBelt then compare(false, true, "Runecloth Belt at 215") end
  if canUseRush and canUseBelt then compare(true, true, "Optimized early route + Runecloth Belt at 215") end
  return best
end

function addon.GetPlan(index, rush150, target, preferBuying, currentSkill)
  local profession = addon.routes[index]
  local maximum = rush150 and 150 or 300
  local cap = math.min(maximum, math.max(1, math.floor(target or maximum)))
  local start = math.max(1, math.floor(currentSkill or 1))
  local readPrice = makePriceReader()
  if not rush150 and profession.full.beltOption then
    return tailoringPlan(profession, start, cap, readPrice, preferBuying, start == 1 and not preferBuying)
  end
  local guide = buildPlan(profession, profession.full, start, cap, readPrice, preferBuying,
    start == 1 and not rush150 and not preferBuying)
  if not rush150 or start >= cap then return guide end

  local optimized = buildPlan(profession, profession.rush, start, cap, readPrice, false)
  local useOptimized = lowerCost(optimized.cost, guide.cost)
  local chosen = useOptimized and optimized or guide
  chosen.comparison = {
    route = useOptimized and "Optimized route" or "WoW Professions",
    guide = guide.cost,
    optimized = optimized.cost,
  }
  return chosen
end

function addon.ImportString(plan)
  local fields = { string.format("%s %d-%d", plan.name, plan.from, plan.cap) }
  local separators = string.rep(";", 11) .. "#;;"
  for _, item in ipairs(plan.auction) do
    fields[#fields + 1] = '"' .. item.name .. '"' .. separators .. item.quantity
  end
  return table.concat(fields, "^")
end
