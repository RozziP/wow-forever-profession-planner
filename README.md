# WoW Forever Profession Planner

Estimate the material cost of leveling Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, and Tailoring from skill 1 to 150 using a local Auctionator price export.

## Run

Use Node.js 22 or newer. The scripts use Node's standard library.

    node finalroutes.cjs path/to/auctionator-export.csv

The command prints JSON with the six trainer-only routes, estimated craft counts, buffered shopping quantities, Auctionator import strings, vendor supplies, and costs in copper. It reprices the bundled routes using the supplied export. Estimated costs assume vendor resale and exclude training fees.

    node opt.cjs path/to/auctionator-export.csv

The second command compares individual recipes at each skill using estimated skill-up odds. Its output is exploratory. It values intermediates at replacement cost and does not assemble validated shopping lists for the suggested paths. The bundled routes and the comparison script are separate entry points.

Keep your Auctionator export local. The CSV needs the Price and Name columns, with Price in copper. A JSON array of objects with those fields also works.

## Data

The bundled recipe and vendor sell values are snapshots used for the original estimates. Check the in-game trainer and vendor values if the game has been patched.

- [WoW Forever recipe tables](https://wowtbc.gg/warcraftforever/professions/)
- [WoW Forever vendor sell values](https://gamemargins.com/wow-forever/items)
- [In-game vendor purchase prices](https://wow-forever.gg/vendors/)
