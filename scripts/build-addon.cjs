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

function auctionItem([name, id, quantity]) {
  if (!id) throw new Error('Missing WoW item ID for ' + name);
  return { name, id, quantity, price: prices[name] ?? 0 };
}

function vendorItem([name, quantity, price]) {
  return { name, quantity, price };
}

function tailoringFinishes(finishes) {
  return finishes.map(({ name, pattern, auction, sell }) => ({
    name,
    pattern: auctionItem(pattern),
    auction: [
      ...auction.map(auctionItem),
    ],
    vendor: [vendorItem(['Rune Thread', 1, 5000])],
    sell,
  }));
}

const outputs = { 'Fire Oil': 2, 'Blackmouth Oil': 2, 'Silver Contact': 5, 'Iron Buckle': 2 };
const intermediateIds = {
  'Fire Oil': 6371,
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

function stepsFor(name, rows) {
  const professionRecipes = recipes[name.toLowerCase()];
  return rows.map(([from, to, recipe, estimate, sell]) => {
    const data = professionRecipes.find(row => row.name === recipe);
    const mat = data ? Object.fromEntries(data.mat) : guideMaterials[recipe];
    if (!mat) throw new Error('Missing materials for ' + recipe);
    const step = {
      from, to, recipe, crafts: Math.ceil(estimate - 1e-9),
      mat, yield: outputs[recipe] ?? 1, sell,
    };
    if (data && data.skill[3] >= to) {
      step.yellow = data.skill[1];
      step.gray = data.skill[3];
    }
    if (questThorium[recipe]) step.turnIn = { 'Thorium Bar': questThorium[recipe] };
    return step;
  });
}

function intermediates(route) {
  const used = new Set(route.steps.flatMap(step => Object.keys(step.mat)));
  return Object.entries(intermediateIds)
    .filter(([name]) => used.has(name))
    .map(([name, id]) => auctionItem([name, id, 0]));
}

const publishedCheckpoints = {
  Alchemy: { 225: { Liferoot: 36, Stranglekelp: 82, "Khadgar's Whisker": 0, Sungrass: 0, Blindweed: 0, 'Stonescale Oil': 0 } },
  Blacksmithing: {
    150: { 'Heavy Stone': 60, 'Iron Bar': 0, 'Solid Stone': 0, 'Steel Bar': 0, 'Mithril Bar': 0,
      'Heavy Leather': 0, Citrine: 0, 'Dense Stone': 0, 'Thick Leather': 0, 'Thorium Bar': 0,
      'Rugged Leather': 0, 'Star Ruby': 0, Aquamarine: 0 },
    225: { 'Mithril Bar': 436, 'Dense Stone': 0, 'Thick Leather': 0, 'Thorium Bar': 0, 'Rugged Leather': 0, 'Star Ruby': 0, Aquamarine: 0 },
  },
  Enchanting: {
    225: { 'Vision Dust': 31, 'Dream Dust': 0, 'Purple Lotus': 0, 'Arcanite Rod': 0, 'Golden Pearl': 0,
      'Illusion Dust': 0, 'Greater Eternal Essence': 0, 'Small Brilliant Shard': 0, 'Large Brilliant Shard': 0 },
  },
  Engineering: { 225: { 'Mithril Bar': 74, 'Dense Stone': 0, 'Thorium Bar': 0, Runecloth: 0 } },
  Leatherworking: { 225: { 'Thick Leather': 340, 'Rugged Leather': 0, Runecloth: 0 } },
  Tailoring: {
    150: { 'Silk Cloth': 216, 'Mageweave Cloth': 115, Runecloth: 0, 'Rugged Leather': 0 },
    225: { Runecloth: 115, 'Rugged Leather': 0 },
    265: {},
  },
};

const professions = Object.entries(guides).map(([name, guide]) => {
  const full = {
    steps: stepsFor(name, guide.steps.map(([from, to, recipe, crafts, units = 0, sell = 0]) =>
      [from, to, recipe, crafts, sell * units / crafts])),
    auction: guide.auction.map(auctionItem),
    vendor: guide.vendor.map(vendorItem),
    notes: guide.notes,
  };
  if (guide.finishes) {
    full.finishes = tailoringFinishes(guide.finishes);
    full.finishBolt = auctionItem(['Bolt of Runecloth', intermediateIds['Bolt of Runecloth'], 0]);
  }
  full.intermediates = intermediates(full);
  full.published = Object.fromEntries(Object.entries({ ...publishedCheckpoints[name], 300: {} })
    .map(([cap, counts]) => [cap, guide.auction.map(([item, id, quantity]) =>
      [item, id, counts[item] ?? quantity]).filter(([, , quantity]) => quantity > 0).map(auctionItem)]));
  return {
    name,
    url: 'https://www.wow-professions.com/forever/' + name.toLowerCase() + '-leveling-guide',
    full,
  };
});

writeFileSync(resolve(__dirname, '../addon/ForeverProfessionPlanner/Routes.lua'),
  '-- Generated by scripts/build-addon.cjs. Do not edit by hand.\n' +
  'local _, addon = ...\naddon.routes = ' + lua(professions) + '\n');
