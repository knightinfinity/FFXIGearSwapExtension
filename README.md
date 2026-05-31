# FFXIGearSwapExtension
This is an extension function to gearswap made to check inventory for what is not in gearswap being used and to look for items in non-accessible inventory, like safe, that is in gearswap. Fair warning, this was vibe coded, so don't expect perfection.

# InventoryCheck

InventoryCheck adds a GearSwap command that checks your current Inventory and Wardrobes for equipment that is not used by any top-level Lua file in GearSwap's `data` folder.

## Install

Place `InventoryCheck.lua` in:

```text
Windower/addons/GearSwap/data/
```

Then add this include near the top of a job file or shared include that should make the command available:

```lua
include('InventoryCheck')
```

Example:

```lua
include('Mirdain-Include')
include('InventoryCheck')
```

If most of your jobs include a shared file such as `Mirdain-Include.lua`, adding `include('InventoryCheck')` there will make the command available for those jobs. Adding the include to only one job file is also valid; it only controls whether the command is loaded, not which job files are scanned.

Reload GearSwap after editing the job file:

```text
//gs reload
```

## Commands

Run the check:

```text
//gs inventorycheck
```

Aliases:

```text
//gs invcheck
//gs ic
```

Write the results to a dated text file in `data/export`:

```text
//gs ic export
```

Require augmented inventory pieces to also have matching augment text in the scanned Lua files:

```text
//gs inventorycheck augments
```

Check only non-equippable storage for Lua gear that is not currently accessible:

```text
//gs ic other
```

Show command help:

```text
//gs inventorycheck help
```

## Settings

To make the default command run the inaccessible-storage reverse lookup instead of the normal Inventory/Wardrobe cleanup, set this after the include:

```lua
include('InventoryCheck')
InventoryCheck.settings.check_other_inventory = true
```

## What It Checks

InventoryCheck reads:

- Inventory
- Wardrobe
- Wardrobe 2
- Wardrobe 3
- Wardrobe 4
- Wardrobe 5
- Wardrobe 6
- Wardrobe 7
- Wardrobe 8

It compares those equipment items against quoted item names in job-named `.lua` files directly inside `data`. It does not scan subfolders, including `data/export`, and it ignores non-job support files.

The scan always covers all top-level job Lua files in `data`, regardless of which job file or shared include loaded InventoryCheck.

InventoryCheck first collects your current Inventory and Wardrobe equipment, then parses the top-level data-folder Lua files and builds a table of uncommented equipment names. It compares those two tables and reports inventory equipment that is not listed in the Lua equipment table.

Chat results are ordered by Inventory, Wardrobe, Wardrobe 2, and onward. The export command creates a file named like `Inventory Check YYYY-MM-DD HH-MM-SS.txt` in `data/export`, with a separate section for each inventory type.

When `check_other_inventory` is enabled, or when you run `//gs ic other`, InventoryCheck reads Mog Safe, Mog Safe 2, Storage, Mog Locker, Mog Satchel, Mog Sack, and Mog Case. It reports only equipment from your Lua files that lives in those bags, since that gear is listed in Lua but not accessible for normal GearSwap swaps.

The inaccessible-storage results include the Lua file or files that reference each item.

By default, matching is by item ID after resolving both full names and abbreviated names from Windower resources. Use the `augments` option when you want augmented copies to match only if the same augment text exists in the scanned Lua files.

InventoryCheck scans Lua text instead of loading every job file. This avoids running setup code from jobs you are not currently on.

For performance, InventoryCheck limits each run to likely job files by filename, builds item-name lookup tables from the current inventory being checked, and parses each Lua file in a single comment-aware pass.
