# gc-section8

**Ghost Core | Section 8 Housing System**  
A full-featured Section 8 housing resource for FiveM, built for QBCore with multi-framework, multi-inventory, and multi-target compatibility.

---

## Features

- Section 8 housing application system with NPC or staff-controlled approvals
- 
- Rent cycle management with overdue warnings and automatic eviction
- 
- SNAP / EBT Link Card system with PIN protection and stolen-card RP
- 
- Link Card replacement at the Section 8 NPC (lost or stolen cards)
- 
- SNAP grocery store NPCs with PIN-verified purchases
- 
- Decoration system — place and remove furniture in your unit
- 
- Shower system with daily use limits
- 
- ox_doorlock integration — door access granted and revoked automatically
- 
- Staff and admin tools built in
- 
- Discord webhook logging for all major events
- 
- Multi-framework, multi-inventory, multi-target — auto-detected at startup

---

## Compatibility

| Category  | Supported                            |

|-----------|--------------------------------------|

| Framework | QBCore, ESX                          |

| Inventory | ox_inventory, qb-inventory           |

| Target    | ox_target, qb-target, qtarget        |

| Notify    | ox_lib, QBCore native, chat fallback |

Detection is fully automatic. Override in `shared/config.lua` under `Config.Compat` if needed.

---

## Dependencies

**Required**
- [qb-core](https://github.com/qbcore-framework/qb-core) or [es_extended](https://github.com/esx-framework/esx_core)
- [oxmysql](https://github.com/overextended/oxmysql)
- ox_target **or** qb-target **or** qtarget

**Recommended**
- [ox_lib](https://github.com/overextended/ox_lib) — enables full UI menus and input dialogs
- [ox_inventory](https://github.com/overextended/ox_inventory) — recommended inventory
- [ox_doorlock](https://github.com/overextended/ox_doorlock) — required for the door access system

---

## Installation

### 1. Database

Run `gc_section8.sql` in your database. Then run `gc_section8_decor.sql` if you want the decoration system.

```sql
source gc_section8.sql;

source gc_section8_decor.sql;
```

### 2. Resource

Place the `gc-section8` folder in your `resources` directory.

Add to `server.cfg` **after** your framework, ox_lib, oxmysql, and inventory resource:

```
ensure gc-section8
```

### 3. Register Items

You need to register the `link_card` item in your inventory.

**ox_inventory** — add to `ox_inventory/data/items.lua`:

```lua
['link_card'] = {

    label  = 'Link Card',

    weight = 10,

    stack  = false,

    close  = true,

    client = { export = 'gc-section8.useLinkCard' },

},
```

Then add this export to `gc-section8/client/snap.lua`:

```lua
exports('useLinkCard', function()
    TriggerServerEvent('gc-section8:snap:checkBalance')
end)
```

**qb-inventory** — add to `qb-core/shared/items.lua`:

```lua
['link_card'] = {

    name        = 'link_card',

    label       = 'Link Card',

    weight      = 10,

    type        = 'item',

    image       = 'link_card.png',

    unique      = true,

    useable     = true,

    shouldClose = true,

    combinable  = nil,

    description = 'SNAP / EBT Link Card',

},
```

Then register it as useable in a server script:

```lua
QBCore.Functions.CreateUseableItem('link_card', function(source)
    TriggerClientEvent('gc-section8:snap:checkBalance', source)
end)
```

---

## Configuration

All configuration lives in `shared/config.lua`.

### Key Settings

| Setting | Description |
|---|---|
| `Config.Compat` | Override auto-detection for framework, inventory, and target |

| `Config.Webhook` | Discord webhook URL for logging |

| `Config.NPC` | Section 8 office NPC model, coordinates, and blip |

| `Config.NPCMode` | `true` = NPC auto-approves applications, `false` = staff must approve |

| `Config.Jobs` | Qualifying jobs for Section 8 eligibility (low income list) |

| `Config.RentPercent` | Monthly rent as a percentage of stated income (default 10%) |

| `Config.MinRent` / `Config.MaxRent` | Rent floor and ceiling |

| `Config.RentDueDays` | How many real-life days between rent cycles |

| `Config.WarningDays` | Grace period in days after rent is overdue before eviction |

| `Config.SNAP.ReplacementCost` | Bank fee to replace a lost or stolen Link Card |

| `Config.SNAP.ReplacementCooldown` | Hours a player must wait between replacement requests |

| `Config.DecorMaxProps` | Maximum furniture props a tenant can place in their unit |

### SNAP Store Locations

Edit `SnapShopConfig.Stores` in `shared/config.lua`. Use `/snapshoppos` in-game to print a `vector4` for your current position.

### SNAP Shop Items

Edit `SnapShopConfig.Items`. Each entry follows this format:

```lua
{ item = 'item_name', label = 'Display Name', price = 5 },
```

The `item` field must match the registered item name in your inventory.

---

## Setting Up Units

Units are created in-game using the admin tool (`/section8tool`) and saved to the database automatically. You can also define fallback units in `Config.StaticUnits` if the database is empty on first boot.

Each unit requires:

- A unique `id`
- 
- A `label`
- 
- A `size` — e.g. `studio`, `1br`, `2br`
- 
- `coords` — entrance point used for the home blip
- 
- `door_id` — the ox_doorlock door ID for this unit's door

---

## Staff & Admin Commands

| Command | Permission | Description |

|---|---|---|

| `/section8apps` | section8 job or admin | View all pending applications |

| `/section8tenants` | section8 job or admin | View all current tenants |

| `/section8evict [citizenid]` | section8 job or admin | Evict a tenant by citizenid |

| `/section8npcmode` | admin | Toggle NPC auto-approve on or off |

| `/section8npcpos` | admin | Print current coordinates for NPC placement |

| `/section8tool` | admin | Open the in-game unit placement tool |

| `/snapreset [citizenid]` | admin | Unlock a locked Link Card or clear replacement cooldown |

| `/snapshoppos` | any | Print current coordinates for SNAP store NPC placement |

| `/ebtbalance` | any | Check your own SNAP balance |

---

## NPC Interactions

### Section 8 Office NPC

| Option | Available To |

|---|---|

| Section 8 Application | Anyone |

| Check Application Status | Anyone |

| Pay Rent | Approved tenants |

| Replace Lost Link Card | Anyone with an active SNAP account |

### SNAP Grocery Store NPCs

- Interact to shop using your Link Card
- 
- First visit: you are prompted to create a 4-digit PIN
- 
- All purchases require PIN confirmation
- 
- Card locks after 5 failed PIN attempts — admin unlocks with `/snapreset [citizenid]`

---

## Card Replacement System

Players who have lost or had their Link Card stolen can request a replacement directly from the Section 8 office NPC.

**Requirements:**
- Must have an active SNAP account (approved Section 8 tenant)
- 
- Must **not** have the card currently in their inventory
- 
- Must have sufficient bank funds for the replacement fee
- 
- Must not be within the replacement cooldown window

The fee and cooldown are both configurable in `Config.SNAP`.

---

## License

This resource is released free for the FiveM community. You may use and modify it freely. Please do not repackage and sell it.

© Ghost Core Scripts
