const {prices,vend,prob,sales}=require('./opt.cjs');
const professionRecipes=require('./data/recipes.json');
const paths={
Alchemy:[[1,15,'Elixir of Minor Force'],[15,76,'Elixir of Minor Defense'],[76,80,'Minor Mana Potion'],[80,90,'Blackmouth Oil'],[90,130,'Elixir of Wisdom'],[130,150,'Fire Oil']],
Blacksmithing:[[1,38,'Rough Sharpening Stone'],[38,85,'Rough Grinding Stone'],[85,95,'Rough Bronze Leggings'],[95,125,'Bronze Shortsword'],[125,129,'Iron Buckle'],[129,139,'Bronze Shortsword'],[139,150,'Green Iron Leggings']],
Enchanting:[[1,2,'Runed Copper Rod'],[2,24,'Enchant Bracer - Inferior Stamina'],[24,86,'Lesser Magic Wand'],[86,129,'Greater Magic Wand'],[129,130,'Runed Silver Rod'],[130,146,'Greater Magic Wand'],[146,150,'Enchant Boots - Minor Stamina']],
Engineering:[[1,30,'Rough Blasting Powder'],[30,57,'Rough Dynamite'],[57,58,'Arclight Spanner'],[58,69,'Rough Copper Bomb'],[69,75,'Copper Tube'],[75,100,'Coarse Dynamite'],[100,150,'Flying Tiger Goggles']],
Leatherworking:[[1,30,'Light Armor Kit'],[30,50,'Cured Light Hide'],[50,70,'Embossed Leather Pants'],[70,90,'Light Leather Pants'],[90,108,'Dark Leather Pants'],[108,123,'Light Leather Pants'],[123,134,'Dark Leather Pants'],[134,150,"Hillman's Shoulders"]],
// Use wool only for the 75–100 stretch, then rejoin the normal guide at 150.
Tailoring:[[1,43,'Bolt of Linen Cloth'],[43,70,'Linen Belt'],[70,75,'Reinforced Linen Cape'],[75,83,'Bolt of Woolen Cloth'],[83,100,'Woolen Cape'],[100,120,'Bolt of Silk Cloth'],[120,134,'Azure Silk Hood'],[134,150,'Small Silk Pack']],
};
const retained=new Set(['Arclight Spanner','Runed Copper Rod','Runed Silver Rod','Cured Light Hide','Rough Blasting Powder','Bolt of Linen Cloth','Bolt of Woolen Cloth','Bolt of Silk Cloth']);
Object.assign(vend,{'Copper Rod':124});
const yields={'Rough Dynamite':2,'Rough Copper Bomb':2,'Coarse Dynamite':2,'Heavy Dynamite':3,'Big Bronze Bomb':3,'Iron Buckle':2,'Fire Oil':2};
const embedded={
  'Lesser Magic Essence':[['Greater Magic Essence',1/3]],
  'Cured Light Hide':[['Light Hide',1],['Salt',1]],
  'Cured Medium Hide':[['Medium Hide',1],['Salt',1]],
  'Bolt of Linen Cloth':[['Linen Cloth',2]],
  'Bolt of Woolen Cloth':[['Wool Cloth',3]],
  'Bolt of Silk Cloth':[['Silk Cloth',4]],
  'Handful of Copper Bolts':[['Copper Bar',1]],
};
const optionalVendorTools={Engineering:{'Blacksmith Hammer':1},Blacksmithing:{'Blacksmith Hammer':1}};
const output={};
const add=(map,k,n)=>map[k]=(map[k]??0)+n;
function expectedCrafts(recipe, from, to) {
  let crafts = 0;
  for (let skill = from; skill < to; skill++) {
    const chance = prob(recipe, skill);
    if (!(chance > 0)) throw new Error(recipe.name + ' cannot give a skill point at ' + skill);
    crafts += 1 / chance;
  }
  return crafts;
}
const totals={};
const engRecipes=Object.fromEntries(professionRecipes.engineering.map(r=>[r.name,r]));
const dynamiteSimulation=[];
let seed=11998;
function random(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296}
for(let i=0;i<60000;i++){
 let skill=1,powder=0,stone=0,dynamite=0,roughBombs=0;
 function makePowder(){if(random()<prob(engRecipes['Rough Blasting Powder'],skill))skill++;powder++;stone++}
 while(skill<30)makePowder();
 while(skill<57){
  if(!powder)makePowder();
  powder--;
  dynamite++;
  if(random()<prob(engRecipes['Rough Dynamite'],skill))skill++;
 }
 skill=58;
 while(skill<69){
  while(powder<2)makePowder();
  powder-=2;
  roughBombs++;
  if(random()<prob(engRecipes['Rough Copper Bomb'],skill))skill++;
 }
 dynamiteSimulation.push({stone,dynamite,roughBombs,linen:dynamite+roughBombs});
}
const engExpected=Object.fromEntries(Object.keys(dynamiteSimulation[0]).map(k=>{
 const mean=dynamiteSimulation.reduce((sum,row)=>sum+row[k],0)/dynamiteSimulation.length;
 return [k,mean];
}));
for(const [p,path] of Object.entries(paths)){
 const recipes=professionRecipes[p.toLowerCase()];
 const plans=path.map(([a,b,name])=>{
  const r=recipes.find(r=>r.name===name);
  if(!r || r.start>a)throw new Error('early '+name);
  const estimate = expectedCrafts(r, a, b);
  // Match the integer recipe batches used by the in-game Less wool plan.
  const m = p === 'Tailoring' ? Math.ceil(estimate - 1e-9) : estimate;
  return {a,b,name,r,m};
 });
 const stock={};
 for(const step of plans)add(stock,step.name,step.m);
 const consumables=()=>{
  const mat={...optionalVendorTools[p]};
  const demand = {};
  function use(n,q) {
    if (embedded[n]) {
      add(demand, n, q);
      for (const [k, a] of embedded[n]) use(k, a * q);
    } else add(mat, n, q);
  }
  for(const [name,n] of Object.entries(stock)){
    const r=recipes.find(r=>r.name===name);
    if(embedded[name])continue;
    for(const [k,a] of r.mat)use(k,a*n);
  }
  if (p === 'Tailoring') {
    for (const [name, quantity] of Object.entries(stock)) {
      if (!embedded[name]) continue;
      const extra = quantity - (demand[name] ?? 0);
      if (extra > 0) use(name, extra);
    }
  }
  if(p==='Engineering'){
    delete mat['Rough Blasting Powder'];
    delete mat['Rough Stone'];
    mat['Rough Stone']=engExpected.stone;
    mat['Copper Bar']+=2*(engExpected.roughBombs-stock['Rough Copper Bomb']);
    mat['Linen Cloth']+=engExpected.linen-stock['Rough Copper Bomb']-stock['Rough Dynamite'];
  }
  return Object.fromEntries(Object.entries(mat).map(([name,quantity])=>[name,Math.ceil(quantity-1e-9)]));
 };
 const quote=mat=>Object.entries(mat).reduce((t,[n,q])=>t+q*(vend[n]??prices[n]),0);
 const cart=consumables();
 if(p==='Engineering')for(const [name,key] of [['Rough Dynamite','dynamite'],['Rough Copper Bomb','roughBombs']]){
  const step=plans.find(s=>s.name===name);
  step.m=engExpected[key];
 }
 const revenue=plans.reduce((t,s)=>t+(retained.has(s.name)?0:s.m*(sales[s.name]??0)*(yields[s.name]??1)),0);
 const gross=quote(cart),net=gross-revenue;
 const vendor=Object.fromEntries(Object.entries(cart).filter(([n])=>n in vend));
 const ah=Object.fromEntries(Object.entries(cart).filter(([n])=>!(n in vend)));
 const importString=[p+' 1-150 Trainer',...Object.entries(ah).map(([k,q])=>'"'+k+'"'+ ';'.repeat(11)+'#;;'+q)].join('^');
 const vendorSpend=quote(vendor);
 const missingPrices=Object.keys(ah).filter(name=>!Number.isFinite(prices[name]));
 output[p]={plans:plans.map(({a,b,name,m})=>({a,b,name,m})),cart,vendor,ah,importString,gross,revenue,net,vendorSpend,missingPrices};
 for(const [n,val] of Object.entries({gross,revenue,net}))add(totals,n,val);
}
if (require.main === module) console.log(JSON.stringify({output,totals},null,2));
module.exports = { output, vend, sales, retained, yields };
