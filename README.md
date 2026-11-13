# WoW Forever Profession Planner

Estimate the material cost of leveling Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, and Tailoring to skill 150 or 300 using Auctionator prices.

## WoW Forever addon

For a local install, copy `addon/ForeverProfessionPlanner` into your WoW installation's `_forever_/Interface/AddOns` directory. Once the addon has a public GitHub release, select **WoW Forever** in WowUp and paste the repository URL into **Get Addons → Install from URL**. Restart the game, enable **Forever Profession Planner**, and type `/fpp` or `/foreverprof`. Use `/fpp tailoring` to open a specific profession.

The header has a **Target skill** slider from 1 to 300, a number field, and presets for 75, 150, 225, and 300. The planner remembers the selected target. **Overview** shows the entire plan. Each skill tab shows its own steps, costs, and shopping list. **Keep ×N** marks recipe outputs used later in the selected plan or tools you should retain.

**Buy extras** is on by default. It builds the shopping list from the WoW Professions recipes and buys extra components when they cost at most 10% more than their ingredients. Turn it off to use the published shopping list in Overview at the guide’s checkpoints. Skill-up recipes stay in the route. Leatherworking converts leather during its leveling stretches and buys any additional leather. Tailoring estimates up to 62 crafts to finish from 265. It compares Runecloth Shoulders and Wizardweave Turban using the pattern cost, materials, and vendor resale.

The **Auctionator import** button selects a quantity-aware shopping list for copying into **Auctionator → Shopping → Import**. **Refresh prices** rereads Auctionator's cache and re-evaluates the Tailoring finish. The planner falls back to bundled prices per item and flags partial quotes. Costs exclude training and vendor recipe fees. The leveling quantities are estimates and contain no added shopping buffer.

Rebuild the addon data from another local export with:

    node scripts/build-addon.cjs path/to/auctionator-export.csv

The generated Lua contains route estimates and shopping lists. It does not include the export itself.

## Releasing for WowUp

Use PowerShell 7 to build the same ZIP locally that GitHub Actions publishes.

```powershell
pwsh -NoProfile -File scripts/package-addon.ps1 -Tag v0.3.2
```

The package is written to `dist/ForeverProfessionPlanner-0.3.2-forever.zip`. It has one top-level addon folder and a `ForeverProfessionPlanner_Forever.toc` for WoW Forever. The source TOC stays in its usual location for local installs. The build packages the addon directory with its bundled route data.

Connect the repository to a public GitHub remote and push the source. Create and push a tag matching the `## Version` in the TOC. The release workflow packages that tag and attaches the ZIP to a GitHub Release. Add the `professions` and `auction-economy` topics on GitHub to categorize the addon. [WowUp Hub publishing guide](https://wowup.io/guide/wowup/hub)

## Run

Use Node.js 22 or newer. The scripts use Node's standard library.

    node finalroutes.cjs path/to/auctionator-export.csv

The command prints JSON with the six short routes, estimated craft counts, shopping quantities, Auctionator import strings, vendor supplies, and costs in copper. It reprices the bundled routes using the supplied export. Estimated costs assume vendor resale and exclude training fees.

    node opt.cjs path/to/auctionator-export.csv

The second command compares individual recipes at each skill using estimated skill-up odds. Its output is exploratory. It values intermediates at replacement cost and does not assemble validated shopping lists for the suggested paths. The bundled routes and the comparison script are separate entry points.

Keep your Auctionator export local. The CSV needs the Price and Name columns, with Price in copper. A JSON array of objects with those fields also works.

## Data

The bundled recipe and vendor sell values are snapshots used for the original estimates. Check the in-game trainer and vendor values if the game has been patched.

- [WoW Forever recipe tables](https://wowtbc.gg/warcraftforever/professions/)
- [WoW Forever vendor sell values](https://gamemargins.com/wow-forever/items)
- [In-game vendor purchase prices](https://wow-forever.gg/vendors/)
