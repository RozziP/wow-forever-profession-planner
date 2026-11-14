# Forever Profession Trainer

Rush your profession leveling in WoW Forever. The addon reads your character’s current skill, shows what to craft, checks total cost, and gives you an Auctionator shopping list.

The default routes are based on [WoW Professions’ WoW Forever guides](https://www.wow-professions.com/forever). 
Use **Copy guide link** to get the guide for the selected profession.

Supports Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, and Tailoring up to skill 300.

## Getting Started

1. Type `/fpt` (or `/foreverprofessiontrainer`) and choose a profession.
2. Set your **Target skill** with the slider or number field. The plan starts at your current skill, or at 1 for a profession you haven’t learned.
3. Use **Overview** for the full remaining route, or select a skill range to see just those steps and materials. Save any crafted items marked **Keep ×N** for later steps.


Drag the bottom-right corner to resize the planner. It remembers the size for your next session.

### While crafting

The progress bar shows your current skill, target, and how many points you still need. Follow the highlighted recipe and switch at the skill shown. Craft counts are estimates, and the planner updates them as you gain skill. If you hit your trained cap before reaching the target, the planner prompts you to train the next rank.

### Shop for materials

1. Open **Overview** or the skill range you want to shop for.
2. Click **Export shopping list** and press **Ctrl+C** to copy the selected text.
3. At the Auction House, open Auctionator’s **Shopping** tab, click **Import**, paste the text, and click **Import** again.

### Auctionator Integration
**Shopping cost** is the estimated cost of buying the materials. **After vendor sales** shows what the route is expected to cost after selling the finished items you don’t need to keep. Training and vendor recipe fees are separate.

Cost estimates require Auctionator to have a cached price for every Auction House item in the list. If prices are missing, scan the Auction House with Auctionator, then click **Refresh prices**. The leveling steps and shopping list work without price data. Craft counts can vary with skill gains.


## Rush 150 
Rush 150 sets the target to 150 and compares the default guide with an optimized route from your current skill. 
This is for rushing the professions legacy points. Higher level optimized routes will come in the future.

## Settings
**Buy extras** lets the planner buy crafted components when they cost up to 10% more than making them.
e.g. instead of crafting 10 light leather for no skill points, it'll prefer buying them


The export covers Auction House items. Vendor supplies appear separately in the planner. Check what you already own before buying.


