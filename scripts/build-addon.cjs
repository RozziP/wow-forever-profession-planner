const { writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { readPrices } = require('../prices.cjs');
const guides = require('../data/guide-routes.cjs');
const guideMaterials = require('../data/guide-materials.cjs');
const recipes = require('../data/recipes.json');

function lua(value, depth = 0) {
  if (typeof value === 'string') {
    return '"' + value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')
      .replaceAll('\n', '\\n').replaceAll('\r', '\\r') + '"';
  }
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  if (typeof value !== 'object' || value === null) throw new Error('Unsupported Lua value');
  const indent = '  '.repeat(depth);
  const lines = Array.isArray(value)
    ? value.map(entry => lua(entry, depth + 1))
    : Object.entries(value).map(([key, entry]) =>
      '[' + lua(/^\d+$/.test(key) ? Number(key) : key) + '] = ' + lua(entry, depth + 1));
  return '{\n' + lines.map(line => indent + '  ' + line + ',\n').join('') + indent + '}';
}

const exportPath = process.argv[2];
if (!exportPath) {
  console.error('Usage: node scripts/build-addon.cjs path/to/auctionator-export.csv');
  process.exit(1);
}

const prices = readPrices(exportPath);
const { output: rushRoutes, vend, sales, yields } = require('../finalroutes.cjs');

function auctionItem([name, id, quantity = 0]) {
  if (!id) throw new Error('Missing WoW item ID for ' + name);
  return { name, id, quantity, price: prices[name] ?? 0 };
}

const vendorItemIds = {
  'Blacksmith Hammer': 5956,
  'Weak Flux': 2880,
  'Strong Flux': 3466,
  'Empty Vial': 3371,
  'Leaded Vial': 3372,
  'Crystal Vial': 8925,
  'Green Dye': 2605,
  'Mote of Magic': 247786,
  'Copper Rod': 6217,
  'Maple Seed': 17034,
  'Stranglethorn Seed': 17035,
  'Salt': 4289,
  'Coarse Thread': 2320,
  'Fine Thread': 2321,
  'Silken Thread': 4291,
  'Heavy Silken Thread': 8343,
  'Rune Thread': 14341,
  'Gray Dye': 4340,
  'Black Dye': 2325,
  'Blue Dye': 6260,
  'Red Dye': 2604,
  'Simple Wood': 4470,
};

function vendorItem([name, quantity, price, explicitId]) {
  const id = explicitId ?? vendorItemIds[name];
  if (!id) throw new Error('Missing WoW item ID for ' + name);
  return { name, id, quantity, price };
}

const outputs = {
  'Fire Oil': 2, 'Blackmouth Oil': 2, 'Stonescale Oil': 2, 'Silver Contact': 5, 'Iron Buckle': 2,
  'Rough Copper Bomb': 2, 'Coarse Dynamite': 2, 'Iron Grenade': 3, 'Hi-Explosive Bomb': 4,
};
const intermediateIds = {
  'Fire Oil': 6371,
  'Stonescale Oil': 13423,
  'Lesser Magic Essence': 10938,
  'Rough Grinding Stone': 3470,
  'Coarse Grinding Stone': 3478,
  'Heavy Grinding Stone': 3486,
  'Solid Grinding Stone': 7966,
  'Rough Blasting Powder': 4357,
  'Coarse Blasting Powder': 4364,
  'Heavy Blasting Powder': 4377,
  'Solid Blasting Powder': 10505,
  'Handful of Copper Bolts': 4359,
  'Bronze Tube': 4371,
  'Whirring Bronze Gizmo': 4375,
  'Bronze Framework': 4382,
  'Unstable Trigger': 10560,
  'Mithril Casing': 10561,
  'Cured Light Hide': 4231,
  'Cured Medium Hide': 4233,
  'Cured Heavy Hide': 4236,
  'Fine Leather Belt': 4246,
  'Bolt of Linen Cloth': 2996,
  'Bolt of Woolen Cloth': 2997,
  'Bolt of Silk Cloth': 4305,
  'Bolt of Mageweave': 4339,
  'Bolt of Runecloth': 14048,
};
const questThorium = {
  'Imperial Plate Belt': 20,
  'Imperial Plate Bracers': 20,
  'Imperial Plate Boots': 40,
  'Imperial Plate Leggings': 60,
};

function stepsFor(name, rows, yieldsByRecipe = outputs, modeledSteps = []) {
  const professionRecipes = recipes[name.toLowerCase()] ?? [];
  return rows.map(([from, to, recipe, estimate, sellPrice, yellow, gray]) => {
    const data = professionRecipes.find(row => row.name === recipe);
    const mat = data ? Object.fromEntries(data.mat) : guideMaterials[recipe];
    if (!mat) throw new Error('Missing materials for ' + recipe);
    const step = {
      from, to, recipe, crafts: Math.ceil(estimate - 1e-9),
      mat, yield: yieldsByRecipe[recipe] ?? 1, sellPrice: sellPrice ?? sales[recipe] ?? 0,
    };
    if (yellow !== undefined) {
      step.yellow = yellow;
      step.gray = gray;
    } else if (data && data.skill[3] >= to && !modeledSteps.includes(recipe)) {
      step.yellow = data.skill[1];
      step.gray = data.skill[3];
    }
    if (questThorium[recipe]) step.turnIn = { 'Thorium Bar': questThorium[recipe] };
    const pattern = guides[name].patterns?.[recipe];
    if (pattern) step.pattern = pattern[0];
    return step;
  });
}

function intermediates(route) {
  const used = new Set([...route.steps, ...Object.values(route.choices ?? {}), ...(route.finishes ?? [])]
    .flatMap(step => Object.keys(step.mat)));
  return Object.entries(intermediateIds)
    .filter(([name]) => used.has(name))
    .map(([name, id]) => auctionItem([name, id, 0]));
}

const rushItemIds = {
  'Oily Blackmouth': 6358,
  'Greater Magic Essence': 10939,
  Tigerseye: 818,
  'Light Leather': 2318,
  'Medium Leather': 2319,
  'Heavy Leather': 4234,
};
const rushPrep = {
  Enchanting: { 'Lesser Magic Essence': { mat: { 'Greater Magic Essence': 1 }, yield: 3, action: 'Split Greater Magic Essence' } },
  Engineering: { 'Handful of Copper Bolts': { mat: { 'Copper Bar': 1 }, yield: 1 } },
  Leatherworking: { 'Cured Medium Hide': { mat: { 'Medium Hide': 1, Salt: 1 }, yield: 1 } },
};

const professions = Object.entries(guides).map(([name, guide]) => {
  const full = {
    steps: stepsFor(name, guide.steps),
    auction: [...guide.auction, ...Object.values(guide.patterns ?? {})].map(auctionItem),
    vendor: guide.vendor.map(([item, price, id]) => vendorItem([item, 0, price, id])),
    notes: guide.notes,
  };
  if (guide.choices) {
    full.choices = Object.fromEntries(Object.entries(guide.choices).map(([id, row]) =>
      [id, stepsFor(name, [row])[0]]));
  }
  if (guide.finishes) {
    full.finishes = stepsFor(name, guide.finishes);
  }
  full.intermediates = intermediates(full);
  const profession = {
    name,
    url: 'https://www.wow-professions.com/forever/' + name.toLowerCase() + '-leveling-guide',
    full,
  };
  if (guide.rankMaterials) full.rankMaterials = guide.rankMaterials;
  const rushRoute = rushRoutes[name];
  if (!rushRoute) return profession;
  const ids = { ...intermediateIds, ...Object.fromEntries(guide.auction.map(([item, id]) => [item, id])), ...rushItemIds };
  profession.rush = {
    steps: stepsFor(name, rushRoute.plans.map(({ a, b, name: recipe, m }) => [a, b, recipe, m]),
      { ...outputs, ...yields }, ['Rough Dynamite', 'Rough Copper Bomb']),
    auction: Object.entries(rushRoute.ah).map(([item, quantity]) => auctionItem([item, ids[item], quantity])),
    vendor: Object.entries(rushRoute.vendor).map(([item, quantity]) => vendorItem([item, quantity, vend[item]])),
    prep: rushPrep[name] ?? {},
    notes: 'Use the estimated craft counts to shop, then switch recipes when you reach the next skill range.',
  };
  profession.rush.intermediates = intermediates(profession.rush);
  if (name === 'Tailoring') {
    const handoff = profession.rush.steps.at(-1).to;
    if (!full.steps.some(step => step.from === handoff)) {
      throw new Error('Less wool must end at a normal Tailoring step boundary');
    }
    // Later recipes still use Mageweave bolts when leveling with silk to 150.
    const bolt = full.steps.find(step => step.recipe === 'Bolt of Mageweave');
    profession.rush.prep[bolt.recipe] = { mat: bolt.mat, yield: bolt.yield };
  }
  return profession;
});

writeFileSync(resolve(__dirname, '../addon/ForeverProfessionPlanner/Routes.lua'),
  '-- Generated by scripts/build-addon.cjs. Do not edit by hand.\n' +
  'local _, addon = ...\naddon.routes = ' + lua(professions) + '\n');
