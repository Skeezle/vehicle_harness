#skeezle_harness (standalone configurable)

A fully standalone harness + seatbelt resource for Qbox servers using `ox_inventory`, `ox_lib`, and `oxmysql`.

## What this version does
- Uses its **own** seatbelt / harness logic.
- Works with `ox_inventory` item use through a `client.export` item callback.
- Stores permanent harness installs on owned vehicles in `player_vehicles.harness` so the harness stays with the vehicle.
- Supports temporary harness use in unowned vehicles with configurable metadata uses.
- Adds configurable ejection logic for unbuckled crashes.

## Dependencies
- ox_lib
- ox_inventory
- oxmysql

## Installation
1. Put the resource in your resources folder.
2. Ensure it after `ox_lib`, `ox_inventory`, and `oxmysql`.
3. Run `db.sql`.
4. Add the item below to `ox_inventory/data/items.lua`.
5. Add harness.png to 'oc_inventory/web/images'
6. Disable any other seatbelt script to avoid conflicts.

## ox_inventory item
```lua
['harness'] = {
    label = 'Racing Harness',
    weight = 2500,
    stack = false,
    close = true,
    consume = 0,
    description = 'Install into an owned vehicle or use temporarily in any car.',
    client = {
        export = 'skeezle_harness.harness'
    }
},
```

## How it works
- **Owned vehicle:** right-click the harness item from ox_inventory while sitting in the driver seat to install it permanently.
- **Owned vehicle with installed harness:** use the normal seatbelt key (`B` by default) to attach or detach the installed harness.
- **Unowned vehicle:** use the item to attach a temporary harness. Each use reduces the item metadata `uses` counter.
- **No installed harness:** the same key toggles a normal seatbelt.

## Config you can change
Open `shared/config.lua`.

- `Config.ToggleKey`
- `Config.ToggleCommand`
- `Config.InstallTime`
- `Config.UninstallTime`
- `Config.DefaultTemporaryUses`
- `Config.RequireDriverForInstall`
- `Config.AllowTemporaryHarness`
- `Config.AllowPermanentHarness`
- `Config.UninstallHarnessWithItem`
- `Config.AutoDetachOnExit`
- `Config.DisableExitWhenBuckled`
- `Config.BlacklistedVehicleClasses`
- `Config.Eject.*`

## Notes
- This resource does **not** require `qb-smallresources` or `qbx_seatbelt`.
- The item metadata defaults are applied automatically when a harness item is created inside ox_inventory.
- If your MariaDB/MySQL version does not support `ADD COLUMN IF NOT EXISTS`, add the `harness` column manually.


## Behavior requested
- Right-click the `harness` item in ox_inventory while seated in the vehicle.
- A progress bar appears during installation.
- On success, the item is removed from inventory.
- The vehicle record is updated in the database and the installed harness is treated as available for every seat in that vehicle.

## License
This project is licensed under the MIT License. You are free to use, modify, and distribute this script, including for commercial use, as long as the original license notice is included.
