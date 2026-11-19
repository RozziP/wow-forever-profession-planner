# Changelog

## 0.4.4

- Include the value of owned materials in the total material cost and net cost.
- Show the cost of materials to buy and the value of materials already owned in the shopping list.

## 0.4.3

- Click a recipe row to open its profession and search for that recipe.
- Recipe searches wait for profession changes to finish and keep the latest clicked recipe.
- Added clear feedback for unlearned professions and attempts during combat.
- Fixed tooltip cleanup that prevented recipe clicks from reaching the search.

## 0.4.2

- Added Cooking through skill 300, including the Expert Cookbook and Clamlette Surprise shopping requirements, rank directions, and `/fpt cooking`.
- Keep craft estimates, **Keep** amounts, shopping quantities, costs, and exports fixed while crafting. Use **Update plan** to recalculate from current skill, inventory, and Auctionator prices.
- Completed rows now show **Made** counts for successful crafts recorded on the current plan, including crafts without a skill-up. Floating feedback shows the actual completed cast duration.
- Replaced **Skip wool** with **Less wool**: linen through 75, wool from 75 to 100, then silk through 150. Corrected partial-step estimates and the Mageweave handoff for later recipes.
- Fixed trainer waypoint feedback so a successful placement does not report that waypoints are unavailable.
- Preserved vendor item IDs so shopping quantities account for supplies already in your bags.

## 0.4.1

- Lightning McQueen now drives across the full screen on Balto’s planner entrance and plays “Ka-chow!” three times over 4.8 seconds.
- Added **Play Balto entrance** to Animation Debug and restored the standard planner background for the Balto account.

## 0.4.0

- Added a book tab to Blizzard’s **Professions** window that opens the planner alongside it when space permits.
- Marked learned professions with gold tab borders and gave the guide you’re viewing its own selection highlight.
- Added a current-skill marker and clickable targets at 75, 150, 225, and 300. Selecting a profession defaults to the next skill milestone, and the slider stops at your exact current skill.
- Added faction-specific trainer directions for all six professions. The cap screen explains which rank unlocks further skill gains and shows the required character level, even when you’ve reached your target. Click named trainers to open their map and place a waypoint where supported.
- Added a remaining crafting-time estimate that counts down during matching casts and recalculates after crafts.
- Added floating feedback for completed cast durations.
- Added **View plan** to the skill-cap screen for shopping ahead. Selecting a capped profession tab opens training.
- Tailoring defaults to the linen-based **Skip wool** route before skill 150. The footer compares material cost and crafting time.
- Fixed vendor proceeds to count the outputs left after reserving materials for later recipes at the selected target.
- Updated provisional recipe choices as missing Auctionator prices become available.
- Added bag-space estimates for remaining purchases, including room in partial stacks, with warnings when more slots may be needed.
- Kept planned prep, remaining craft counts, and shopping quantities in sync as bag contents or prices change.
- Preserved the saved planner size when opening from Blizzard’s Professions window.
- Improved recipe and shopping readability with a clearer current-step highlight, inline **Keep** notes, aligned **Have / Need** counts, coin icons, and a dedicated **Export to Auctionator** button.
- Shortened the cost labels to **Materials**, **Vendor sales**, and **Net cost**, with signs to distinguish spending from gains.
- Added login script hooks for a character name, a realm-qualified character name, or a BattleTag.
- Included the account-scoped Balto theme with animated traffic and the Animation Debug panel.
