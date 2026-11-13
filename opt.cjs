const { readPrices } = require('./prices.cjs');
const prices = readPrices(process.argv[2]);
const vend={'Mote of Magic':10,'Copper Rod':125,'Simple Wood':38,'Coarse Thread':10,'Fine Thread':100,'Silken Thread':500,'Weak Flux':100,'Strong Flux':2000,'Blacksmith Hammer':18,'Wooden Stock':50,'Heavy Stock':1000,'Blue Dye':50,'Red Dye':50,'Green Dye':100,'Gray Dye':350,'Bleach':25,'Salt':50,'Empty Vial':4,'Leaded Vial':40};
const recipes=require('./data/recipes.json');
const sales=Object.fromEntries(Object.entries(require('./data/sales.json')).map(([n,v])=>[n,v[0]]));
Object.assign(sales,{"Elixir of Minor Force":25,"Minor Arcane Elixir":5});
const quantities={'Rough Dynamite':2,'Coarse Dynamite':2,'Heavy Dynamite':2,'Rough Copper Bomb':2,'Small Bronze Bomb':2,'Large Copper Bomb':2,'Big Bronze Bomb':2,'Crafted Light Shot':200,'Crafted Heavy Shot':200,'Crafted Solid Shot':200,'Silver Contact':5,'Silver Skeleton Key':2,'Golden Skeleton Key':2,'Iron Buckle':2};
const never=new Set(['Runed Copper Rod','Runed Silver Rod','Arclight Spanner']);
const excluded=new Set(['Lesser Discolored Healing Potion','Discolored Healing Potion','Sandpaper','Enchant Bracer - Minor Deflect','Novice Ardent\'s Sash','Novice Arcanist\'s Sash','Earthen Vest','Formal White Shirt','Red Swashbuckler\'s Shirt','White Swashbuckler\'s Shirt','Silk Headband','Azure Silk Belt','Crimson Silk Belt','Green Silken Shoulders']);
const edits={'Linen Bag':5,'Arclight Spanner':50};
const conversions={
  'Lesser Magic Essence':[['Greater Magic Essence',1/3]],
  'Lesser Astral Essence':[['Greater Astral Essence',1/3]],
  'Rough Blasting Powder':[['Rough Stone',1]],
  'Coarse Blasting Powder':[['Coarse Stone',1]],
  'Rough Grinding Stone':[['Rough Stone',2]],
  'Coarse Grinding Stone':[['Coarse Stone',2]],
  'Heavy Grinding Stone':[['Heavy Stone',3]],
  'Heavy Blasting Powder':[['Heavy Stone',1]],
  'Cured Light Hide':[['Light Hide',1],['Salt',1]],
  'Cured Medium Hide':[['Medium Hide',1],['Salt',1]],
  'Cured Heavy Hide':[['Heavy Hide',1],['Salt',3]],
  'Bolt of Linen Cloth':[['Linen Cloth',2]],
  'Bolt of Woolen Cloth':[['Wool Cloth',3]],
  'Bolt of Silk Cloth':[['Silk Cloth',4]],
  'Bolt of Mageweave':[['Mageweave Cloth',5]],
  'Copper Tube':[['Copper Bar',2],['Weak Flux',1]],
  'Handful of Copper Bolts':[['Copper Bar',1]],
  'Copper Modulator':[['Copper Bar',3],['Linen Cloth',2]],
  'Silver Contact':[['Silver Bar',.2]],
  'Bronze Tube':[['Bronze Bar',2],['Weak Flux',1]],
  'Fire Oil':[['Firefin Snapper',2],['Empty Vial',1]],
  'Blackmouth Oil':[['Oily Blackmouth',2],['Empty Vial',1]],
  'Elixir of Wisdom':[['Mageroyal',1],['Briarthorn',2],['Empty Vial',1]],
};
function val(n,force=false){
  const base=Math.min(prices[n]??Infinity,vend[n]??Infinity);
  if(!conversions[n])return base;
  const raw=conversions[n].reduce((s,[k,a])=>s+val(k)*a,0);
  return force?raw:Math.min(base,raw);
}
const cost=r=>r.mat.reduce((s,[n,a])=>s+val(n)*a,0);
const sale=r=>never.has(r.name)?0:(sales[r.name]??0)*(quantities[r.name]??1);
const prob=(r,s)=>Math.max(0,Math.min(1,(r.skill[3]-s)/(r.skill[3]-r.skill[1])));
const prep = Object.fromEntries(Object.entries(recipes).map(([p,rs])=>[p,rs.filter(r=>!excluded.has(r.name)&&r.skill[3]>r.start&&Number.isFinite(cost(r))).map(r=>({...r,start:edits[r.name]??r.start,cost:cost(r),sale:sale(r)}))]));
function calculate(p,net=true){
  const rs=prep[p];
  const candidates=rs.filter(r=>!never.has(r.name)&&r.name!=='Mote of Magic');
  const path=[];
  const rod=p==='enchanting'?129:-1;
  const first=p==='enchanting'?2:1;
  for(let s=first;s<150;s++){
    if(s===rod){path.push([s,rs.find(r=>r.name==='Runed Silver Rod'),1]);continue}
    const rs2=candidates.filter(r=>s>=r.start&&s<r.skill[3]&&(p!=='enchanting'||s>rod||!['Enchant Boots - Minor Stamina','Enchant Cloak - Lesser Fire Resistance','Enchant Bracer - Lesser Stamina','Enchant Shield - Lesser Spirit','Enchant Chest - Lesser Absorption','Enchant Weapon - Lesser Striking','Enchant 2H Weapon - Lesser Impact','Enchant Chest - Intellect'].includes(r.name)));
    const score=r=>(r.cost-(net?r.sale:0))/prob(r,s);
    const chosen=rs2.sort((a,b)=>score(a)-score(b))[0];
    if(!chosen)throw new Error(p+' '+s);
    path.push([s,chosen,1/prob(chosen,s)]);
  }
  if(first===2)path.unshift([1,rs.find(r=>r.name==='Runed Copper Rod'),1]);
  const groups=[];
  for(const [s,r,num] of path){const last=groups.at(-1);if(last?.r.name===r.name){last.end=s+1;last.n+=num}else groups.push({start:s,end:s+1,r,n:num})}
  return groups;
}
if(require.main===module)for(const p of Object.keys(recipes)){
 console.log('\n'+p);
 for(const net of [true,false]){
 let all=calculate(p,net);console.log(net?'NET':'GROSS',all.map(g=>[g.start,g.end,g.r.name,g.n.toFixed(1),g.r.cost,g.r.sale].join(' ')).join('\n'),'\n');
 }
}
module.exports={prices,vend,sales,prep,prob,val,quantities,cost,calculate};
