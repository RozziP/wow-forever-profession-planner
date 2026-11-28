# Changelog

## 0.4.8

- Added **Potion route** to the First Aid footer. It uses potions and poultices at skill 1–75, 90–150, and 275–300, with bandages between those ranges.
- Switching routes updates the recipe list, shopping costs, and Auctionator export. The potion route includes the Major Healing Potion manual when you still need to learn it.

## 0.4.7

- Added a 1–300 First Aid bandage guide. Open it with `/fpt first aid` or the tab below Cooking.
- First Aid shopping includes cloth, the Expert book, and any required bandage manuals. The training view points to your faction's Expert book vendor and Triage quest giver.
- Shopping lists and Auctionator exports now list finished tradeable reagents for prep, such as Heavy Blasting Powder for Explosive Sheep.
- Skill-ups now count newly crafted reagents that later recipes can use when updating the remaining shopping list.

## 0.4.6

- Refreshed all seven 1–300 leveling guides for WoW Forever. Cooking now uses Nightfin Soup from 285 to 300, and Tailoring includes Runecloth Cuffs and alternatives for players without the pattern.
- Added selectable recipes for supported skill ranges in Blacksmithing, Tailoring, and Cooking. Changing the recipe updates material costs and the Auctionator export. Hover over **WoW Professions** for recipe acquisition notes.
- Shopping lists now update when bag quantities change. Skill gains reduce the remaining craft estimates, material requirements, and crafting time.
- Added the Forever Profession Trainer icon to the in-game AddOns list.

## 0.4.5

- Clarified the shopping cost summary by showing the amounts to buy and already owned as a breakdown of all materials.

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
