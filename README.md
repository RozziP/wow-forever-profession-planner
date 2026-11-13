# Forever Profession Planner

Plan your profession leveling in WoW Forever. The addon reads your character’s current skill and shows what to craft, which materials to buy, and how much the remaining route is estimated to cost.

Supports Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, and Tailoring up to skill 300.

## Plan a route

1. Type `/fpp` and choose a profession. You can also jump straight to one with a command like `/fpp tailoring`.
2. Set your **Target skill** with the slider or number field. The plan starts at your current skill, or at 1 for a profession you haven’t learned.
3. Use **Overview** for the full remaining route, or select a skill range to see just those steps and materials. Save any crafted items marked **Keep ×N** for later steps.

**Rush 150** sets the target to 150 and compares the default guide with an optimized route from your current skill. **Buy extras** lets the planner buy extra crafted components when they cost up to 10% more than making them. Tailoring also compares supported recipe alternatives as you level.

## Shop for materials

1. Open **Overview** or the skill range you want to shop for.
2. Click **Export shopping list** and press **Ctrl+C** to copy the selected text.
3. At the Auction House, open Auctionator’s **Shopping** tab, click **Import**, paste the text, and click **Import** again.

The export covers Auction House items. Vendor supplies appear separately in the planner. Check what you already own before buying.

## Read the cost estimate

**Shopping cost** is the estimated cost of buying the materials. **After vendor sales** shows what the route is expected to cost after selling the finished items you don’t need to keep. Training and vendor recipe fees are separate.

Cost estimates require Auctionator to have a cached price for every Auction House item in the list. If prices are missing, scan the Auction House with Auctionator, then click **Refresh prices**. The leveling steps and shopping list work without price data. Craft counts can vary with skill gains.

The default routes are based on [WoW Professions’ WoW Forever guides](https://www.wow-professions.com/forever). Use **Copy guide link** to get the guide for the selected profession.
