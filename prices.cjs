const { readFileSync } = require('node:fs');
const { parse } = require('node:path');

function readPrices(file) {
  if (!file) {
    throw new Error('Pass an Auctionator price export, for example: node finalroutes.cjs prices.csv');
  }

  const contents = readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  const rows = parse(file).ext.toLowerCase() === '.json'
    ? JSON.parse(contents).map(row => [row.Price, row.Name])
    : parseCsv(contents);
  const prices = Object.create(null);
  for (const [price, name] of rows) {
    const item = name?.trim();
    if (!item || !/^\d+$/.test(String(price).trim())) continue;
    const copper = Number(price);
    prices[item] = Math.min(prices[item] ?? Infinity, copper);
  }
  if (!Object.keys(prices).length) {
    throw new Error('The export contains no numeric item prices.');
  }
  return prices;
}

function parseCsv(contents) {
  const [header, ...lines] = contents.trim().split(/\r?\n/);
  const fields = parseRow(header);
  const priceColumn = fields.indexOf('Price');
  const nameColumn = fields.indexOf('Name');
  if (priceColumn === -1 || nameColumn === -1) {
    throw new Error('Expected an Auctionator CSV with Price and Name columns.');
  }
  return lines.map(line => {
    const fields = parseRow(line);
    return [fields[priceColumn], fields[nameColumn]];
  });
}

function parseRow(line) {
  return [...line.matchAll(/(?:^|,)(?:"((?:[^"]|"")*)"|([^,]*))/g)]
    .map(([, quoted, bare]) => quoted?.replaceAll('""', '"') ?? bare);
}

module.exports = { readPrices };
