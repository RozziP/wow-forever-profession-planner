# Forever Profession Trainer

<p><img src="branding/icon.png" width="96" height="96" alt="Forever Profession Trainer icon"></p>

Plan profession leveling in WoW Forever through skill 300. Forever Profession Trainer reads your character’s current skill, shows what to craft, estimates the cost, and builds an Auctionator shopping list.

Supports Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, Leatherworking, and Tailoring. Install and enable Auctionator for WoW Forever alongside the addon.

## Getting started

1. Type `/fpt` or `/foreverprofessiontrainer`, or click the book tab in Blizzard’s **Professions** window. The book opens the planner at the Professions window’s scale and places it alongside when there’s room.
2. Choose any profession tab on the right. Gold borders mark learned professions, and the highlighted tab shows the guide you’re viewing. You can also jump straight to a guide with a command such as `/fpt cooking`.
3. Each profession tab click resets the **Skill target** to the next milestone above your current skill, up to **300**. Click a marker at **75**, **150**, **225**, or **300**, or use the slider to choose a different target. Unlearned professions are previewed from skill 1 and default to a target of 75.

Drag the bottom-right corner to resize the planner. It remembers your chosen size for the next session.

## Crafting and training

Follow the highlighted recipe and switch at the skill shown. Completed steps stay in the guide with checkmarks. Save crafts marked **Keep ×N** for later recipes. As you gain skill, the active recipe’s estimated remaining crafts and materials update. A completed row shows **Made** for successful crafts recorded on the current plan, including crafts that gave no skill point.

Click a recipe row to open its profession and fill the recipe search. You must know the profession and be out of combat. The search keeps Blizzard's existing filters; a recipe you have not learned may not appear. Clear the search in the profession window to return to the full list.

Some skill ranges show two recipe panels. Left-click a panel to choose that recipe and rebuild the plan, costs, and shopping list. Right-click either panel to search for its recipe. The selected recipe is highlighted and saved. Blacksmithing offers Mithril Spurs and Imperial Plate alternatives. Tailoring offers Runecloth Gloves and Shoulders if you cannot acquire the Runecloth Cuffs pattern. Cooking lets you choose between Spotted Yellowtail and Filet of Redgill. Craft counts are estimates. Budget separately for recipe acquisition.

**Est. crafting** shows the estimated time for the remaining plan. It uses recipe cast times when available, with a fallback of three seconds per craft. The floating number shows how long the completed cast took. Budget separate time for shopping, travel, and training.

At a trainable skill cap, selecting the profession tab opens the trainer screen. It names the rank you need to unlock further skill gains, shows the required character level, and gives directions for your faction. Click **View plan** to plan or shop ahead. Click **Training** to return, or select the profession tab again to return and reset your target. Click a named trainer to open the map and place a waypoint where supported. Annora’s pin marks the rear entrance to Uldaman.

With **Tailoring** selected below skill 150, **Less wool** is on by default. It uses linen through 75, wool from 75 to 100, and silk through 150. Uncheck it in the footer to use the standard route. Selecting the Tailoring tab again turns it back on.

**Cooking** follows the main WoW-Professions shopping list. Cook at a campfire and use the guide link for recipe vendors. The shopping list includes the Expert Cookbook when planning past 150 and the Clamlette Surprise turn-in when planning past 225 when the plan starts before you unlock those ranks. [WoW-Professions Cooking guide](https://www.wow-professions.com/forever/cooking-leveling-guide)

## Shopping and costs

The shopping list updates **Have** as your bags change. **Need** stays fixed between skill gains; a skill gain reduces the active recipe’s estimated crafts and material requirements. Costs and the export reflect the materials still needed. Click **Update plan** to rebuild the plan from your current skill, bags, and Auctionator prices. Auction House materials and vendor supplies have separate sections. The bag-space estimate covers both groups, counts room in partial stacks and free regular bag slots, and warns when you may need more space.

- **All materials** includes both the estimated **To buy** amount and the value of materials **Already owned** that the plan will use. The two indented amounts show how the total is calculated, using Auctionator prices for auction materials and vendor prices for vendor supplies.
- **Vendor sales** estimates what NPC vendors will pay for the remaining crafts available to sell.
- **Net cost** combines those figures. A minus sign means gold spent, and a plus sign means gold gained. Budget separately for training and recipe fees.

The Shopping List uses finished tradeable reagents for prep. It includes raw materials for skill-up crafts and reserves those crafts' outputs for later recipes that use them.

If prices are missing, scan the Auction House with Auctionator and click **Update plan** to apply the new prices. Recipes, bag counts, and shopping export are usable while prices are missing.

1. Click **Export to Auctionator** and press **Ctrl+C** to copy the selected text. The export contains the Auction House quantities listed for purchase in the current plan.
2. At the Auction House, open Auctionator’s **Shopping** tab, click **Import**, paste the text, and confirm with **Import**.

## Character scripts

Edit `CharacterScripts.lua` in the `ForeverProfessionPlanner` addon folder to add optional Lua callbacks that run on login or UI reload. Use an exact character name, `Name-Realm` with the normalized realm name, or a full BattleTag including its `#` and digits. A realm-specific character entry takes priority over a name-only entry. A BattleTag entry applies to the logged-in character on that account and can run once Battle.net supplies the tag. The addon includes a theme scoped to one BattleTag. Back up any edits to the script before updating.

## Guide credits

The routes use the WoW Professions guides reviewed on November 25, 2026, with recipe data checked against WoW Forever build 1.60.1.71091. Hover over **WoW Professions** in the planner footer for recipe acquisition notes, or click it to copy the guide link. [WoW Professions guides](https://www.wow-professions.com/forever)


## Development checks

Run from the source worktree with PowerShell 7, Node.js, and pnpm.

```powershell
pwsh -NoProfile -File ./scripts/check-source.ps1
pnpm install --frozen-lockfile
pnpm test
```

The source check prints the branch, revision, and both TOC versions, then compares the preview files with the WoW Forever installation using the `wow-addon-dev` skill's comparator. It is read-only. Exit codes are `0` for a match, `1` for file differences, and `2` for a setup error. Use `-InstalledDirectory` for a different installed `ForeverProfessionPlanner` folder, or `-CompareScript` for a comparator in a different location.

The test runner checks Lua 5.1 syntax and loads the addon in TOC order with mocked WoW and Auctionator APIs. It runs without WoW and covers route quotes and exports, profession tab defaults, training navigation, late prices, and crafting events. Use the game client to check layout and API behavior against the installed build.
