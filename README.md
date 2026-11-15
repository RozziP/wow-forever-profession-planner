# Forever Profession Trainer

Plan profession leveling in WoW Forever through skill 300. Forever Profession Trainer reads your character’s current skill, shows what to craft, estimates the cost, and builds an Auctionator shopping list.

Supports Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, and Tailoring. Install and enable Auctionator for WoW Forever alongside the addon.

## Install

In WowUp, select WoW Forever and use **Install from URL** with the project’s GitHub repository. You can also extract the `-forever.zip` from [GitHub Releases](https://github.com/RozziP/wow-forever-profession-planner/releases) into `_forever_/Interface/AddOns`. Keep the `ForeverProfessionPlanner` folder name so WoW can load your existing settings. Restart the client after installation or an update.

See the [changelog](CHANGELOG.md) for what changed.

## Getting started

1. Type `/fpt` or `/foreverprofessiontrainer`, or click the book tab in Blizzard’s **Professions** window. The book opens the planner at the Professions window’s scale and places it alongside when there’s room.
2. Choose any of the six profession tabs on the right. Gold borders mark learned professions, and the highlighted tab shows the guide you’re viewing. You can also jump straight to a guide with a command such as `/fpt tailoring`.
3. Each profession tab click resets the **Skill target** to the next milestone above your current skill, up to **300**. Click a marker at **75**, **150**, **225**, or **300**, or use the slider to choose a different target. Unlearned professions are previewed from skill 1 and default to a target of 75.

Drag the bottom-right corner to resize the planner. It remembers your chosen size for the next session.

## Crafting and training

Follow the highlighted recipe and switch at the skill shown. Completed steps stay in the guide with checkmarks. Save crafts marked **Keep ×N** for later recipes. Craft counts are estimates and update as you gain skill.

**Est. crafting** covers the remaining crafts and prep. It uses recipe cast times when available, with a fallback of three seconds per craft. When you cast a recipe on the selected route, the estimate counts down and recalculates after the craft. The floating number shows how long the completed cast took. Budget separate time for shopping, travel, and training.

At a trainable skill cap, selecting the profession tab opens the trainer screen even if you’ve already reached your planned target. It names the rank you need to unlock further skill gains, shows the required character level, and gives directions for your faction. Click **View plan** and set a higher target to plan or shop ahead. Click **Training** or select the profession tab again to return. Click a named trainer to open the map and place a waypoint where supported. Annora’s pin marks the rear entrance to Uldaman.

With **Tailoring** selected below skill 150, **Skip wool** is on by default and uses the linen-based route for early skill gains. Uncheck it in the footer to use wool. Selecting the Tailoring tab again turns it back on. The footer compares material cost and crafting time.

## Shopping and costs

The shopping list updates when your bags change. **Have / Need** shows what you already carry against what the remaining route uses. Auction House materials and vendor supplies have separate sections. The bag-space estimate covers both groups, counts room in partial stacks and free regular bag slots, and warns when you may need more space.

- **Materials** is the estimated spend on remaining Auction House and vendor materials.
- **Vendor sales** estimates what NPC vendors will pay for the remaining crafts available to sell.
- **Net cost** combines those figures. A minus sign means gold spent, and a plus sign means gold gained. Budget separately for training and recipe fees.

If prices are missing, scan the Auction House with Auctionator and reopen the planner. The planner uses newly available prices to re-evaluate provisional recipe choices. Recipes, bag counts, and shopping export are usable while prices are missing. When prices are available, the planner can buy eligible intermediate materials if they cost up to 10% more than making them.

1. Click **Export to Auctionator** and press **Ctrl+C** to copy the selected text. The export contains only Auction House quantities you still need.
2. At the Auction House, open Auctionator’s **Shopping** tab, click **Import**, paste the text, and confirm with **Import**.

## Character scripts

Edit `CharacterScripts.lua` in the `ForeverProfessionPlanner` addon folder to add optional Lua callbacks that run on login or UI reload. Use an exact character name, `Name-Realm` with the normalized realm name, or a full BattleTag including its `#` and digits. A realm-specific character entry takes priority over a name-only entry. A BattleTag entry applies to the logged-in character on that account and can run once Battle.net supplies the tag. Back up any edits to the script before updating.

The account-scoped Balto entrance sends Lightning McQueen across the screen with three plays of “Ka-chow!” Run `/fpt debug` and click **Play Balto entrance** on the debug-enabled account to replay it. [Disney/Pixar character render](https://www.pngfind.com/mpng/ihwhJ_disney-cars-png-lightning-mcqueen-disney-cars-clipart/) · [Audio clip from Cars](https://www.101soundboards.com/sounds/9606776-ka-chow)

## Guide credits

The routes are based on WoW Professions’ WoW Forever guides. Click **WoW Professions** in the planner footer to copy the selected guide’s link. [WoW Professions guides](https://www.wow-professions.com/forever)

## Development checks

Run from the source worktree with PowerShell 7, Node.js, and pnpm.

```powershell
pwsh -NoProfile -File ./scripts/check-source.ps1
pnpm install --frozen-lockfile
pnpm test
```

The source check prints the branch, revision, and both TOC versions, then compares the source files with the WoW Forever installation using the `wow-addon-dev` skill's comparator. It is read-only. Exit codes are `0` for a match, `1` for file differences, and `2` for a setup error. Use `-InstalledDirectory` for a different installed `ForeverProfessionPlanner` folder, or `-CompareScript` for a comparator in a different location.

The test runner checks Lua 5.1 syntax and loads the addon in TOC order with mocked WoW and Auctionator APIs. It runs without WoW and covers route quotes and exports, profession tab defaults, training navigation, late prices, and crafting events. Use the game client to check layout and API behavior against the installed build.
