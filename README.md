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

Follow the highlighted recipe and switch at the skill shown. Completed steps stay in the guide with checkmarks. Save crafts marked **Keep ×N** for later recipes. The planned craft and **Keep** counts stay fixed as you gain skill. A completed row shows **Made** for successful crafts recorded on the current plan, including crafts that gave no skill point.

Click a recipe row to open its profession and fill the recipe search. You must know the profession and be out of combat. The search keeps Blizzard's existing filters; a recipe you have not learned may not appear. Clear the search in the profession window to return to the full list.

**Est. crafting** shows the time estimated when the plan was calculated. It uses recipe cast times when available, with a fallback of three seconds per craft. The floating number shows how long the completed cast took. Budget separate time for shopping, travel, and training.

At a trainable skill cap, selecting the profession tab opens the trainer screen. It names the rank you need to unlock further skill gains, shows the required character level, and gives directions for your faction. Click **View plan** to plan or shop ahead. Click **Training** to return, or select the profession tab again to return and reset your target. Click a named trainer to open the map and place a waypoint where supported. Annora’s pin marks the rear entrance to Uldaman.

With **Tailoring** selected below skill 150, **Less wool** is on by default. It uses linen through 75, wool from 75 to 100, and silk through 150. Uncheck it in the footer to use the standard route. Selecting the Tailoring tab again turns it back on.

**Cooking** follows the main WoW-Professions shopping list. Cook at a campfire and use the guide link for recipe vendors. The shopping list includes the Expert Cookbook when planning past 150 and the Clamlette Surprise turn-in when planning past 225 when the plan starts before you unlock those ranks. [WoW-Professions Cooking guide](https://www.wow-professions.com/forever/cooking-leveling-guide)

## Shopping and costs

The shopping list, **Have / Need** counts, bag space, and costs use your inventory when the plan was calculated. Click **Update plan** to rebuild it from your current skill, bags, and Auctionator prices. Auction House materials and vendor supplies have separate sections. The bag-space estimate covers both groups, counts room in partial stacks and free regular bag slots, and warns when you may need more space.

- **Materials** is the estimated spend on remaining Auction House and vendor materials.
- **Vendor sales** estimates what NPC vendors will pay for the remaining crafts available to sell.
- **Net cost** combines those figures. A minus sign means gold spent, and a plus sign means gold gained. Budget separately for training and recipe fees.

If prices are missing, scan the Auction House with Auctionator and click **Update plan** to apply the new prices. Recipes, bag counts, and shopping export are usable while prices are missing. When prices are available, the planner can buy eligible intermediate materials if they cost up to 10% more than making them.

1. Click **Export to Auctionator** and press **Ctrl+C** to copy the selected text. The export contains the Auction House quantities listed for purchase in the current plan.
2. At the Auction House, open Auctionator’s **Shopping** tab, click **Import**, paste the text, and confirm with **Import**.

## Character scripts

Edit `CharacterScripts.lua` in the `ForeverProfessionPlanner` addon folder to add optional Lua callbacks that run on login or UI reload. Use an exact character name, `Name-Realm` with the normalized realm name, or a full BattleTag including its `#` and digits. A realm-specific character entry takes priority over a name-only entry. A BattleTag entry applies to the logged-in character on that account and can run once Battle.net supplies the tag. The addon includes a theme scoped to one BattleTag. Back up any edits to the script before updating.

## Guide credits

The routes are based on WoW Professions’ WoW Forever guides. Click **WoW Professions** in the planner footer to copy the selected guide’s link. [WoW Professions guides](https://www.wow-professions.com/forever)


## Development checks

Run from the source worktree with PowerShell 7, Node.js, and pnpm.

```powershell
pwsh -NoProfile -File ./scripts/check-source.ps1
pnpm install --frozen-lockfile
pnpm test
```

The source check prints the branch, revision, and both TOC versions, then compares the preview files with the WoW Forever installation using the `wow-addon-dev` skill's comparator. It is read-only. Exit codes are `0` for a match, `1` for file differences, and `2` for a setup error. Use `-InstalledDirectory` for a different installed `ForeverProfessionPlanner` folder, or `-CompareScript` for a comparator in a different location.

The test runner checks Lua 5.1 syntax and loads the addon in TOC order with mocked WoW and Auctionator APIs. It runs without WoW and covers route quotes and exports, profession tab defaults, training navigation, late prices, and crafting events. Use the game client to check layout and API behavior against the installed build.
