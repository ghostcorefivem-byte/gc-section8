Config = {}

-- =============================================
--  COMPATIBILITY
--  Auto-detected at runtime. Override here if
--  your server has naming conflicts.
--  Options:
--    Framework : 'auto' | 'qbcore' | 'esx'
--    Inventory : 'auto' | 'ox_inventory' | 'qb-inventory'
--    Target    : 'auto' | 'ox_target' | 'qb-target' | 'qtarget'
-- =============================================
Config.Compat = {
    Framework = 'auto',
    Inventory = 'auto',
    Target    = 'auto',
}

-- =============================================
--  DISCORD WEBHOOK
-- =============================================
Config.Webhook     = ''
Config.WebhookName = 'Section 8 Housing'

-- =============================================
--  NPC SETTINGS
-- =============================================
Config.NPC = {
    model    = 'a_f_m_business_02',
    coords   = vector4(-277.43, -1627.03, 33.92, 237.52),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    blip = {
        enabled = true,
        sprite  = 40,
        color   = 0,
        scale   = 0.7,
        label   = 'Section 8 Office',
    },
}

-- =============================================
--  JOB SETTINGS
-- =============================================
Config.Section8Job    = 'section8'
Config.Section8Grades = { 0, 1, 2, 3, 4 }

-- When true = NPC auto-approves all applications.
-- When false = a player with the section8 job must approve.
Config.NPCMode = true

-- =============================================
--  APPLICATION SETTINGS
-- =============================================
Config.Jobs = {
    { name = 'unemployed', label = 'Unemployed',           incomeLimit = 0     },
    { name = 'garbage',    label = 'Sanitation Worker',    incomeLimit = 3000  },
    { name = 'taxi',       label = 'Taxi Driver',          incomeLimit = 3500  },
    { name = 'carwash',    label = 'Car Wash Attendant',   incomeLimit = 3000  },
    { name = 'other',      label = 'Other / Self Report',  incomeLimit = 99999 },
}

Config.RentPercent = 0.10
Config.MinRent     = 200
Config.MaxRent     = 800

-- =============================================
--  EVICTION SETTINGS
-- =============================================
Config.WarningDays = 5
Config.RentDueDays = 30

-- =============================================
--  STATIC UNITS (fallback if DB is empty)
-- =============================================
Config.StaticUnits = {}

-- =============================================
--  INSPECTION ITEM (optional RP — set nil to disable)
-- =============================================
Config.InspectionItem = 'clipboard'

-- =============================================
--  DECORATION SYSTEM
-- =============================================
Config.DecorMaxProps = 5

Config.DecorProps = {
    { model = 'prop_couch_01',      label = 'Couch (Gray)',      price = 800  },
    { model = 'prop_couch_02',      label = 'Couch (Brown)',     price = 800  },
    { model = 'prop_couch_lg_1',    label = 'L-Shape Couch',     price = 1200 },
    { model = 'prop_table_02',      label = 'Coffee Table',      price = 300  },
    { model = 'prop_tv_flat_01',    label = 'Flat Screen TV',    price = 600  },
    { model = 'prop_tv_flat_02',    label = 'Large Flat TV',     price = 900  },
    { model = 'prop_bed_single_01', label = 'Single Bed',        price = 500  },
    { model = 'prop_bed_double_01', label = 'Double Bed',        price = 700  },
    { model = 'prop_ngt_stand_01',  label = 'Nightstand',        price = 150  },
    { model = 'prop_ngt_stand_02',  label = 'Nightstand (Lamp)', price = 200  },
    { model = 'prop_wardrobe_01',   label = 'Wardrobe',          price = 400  },
    { model = 'prop_ktchn_tab_01',  label = 'Kitchen Table',     price = 350  },
    { model = 'prop_chair_01a',     label = 'Dining Chair',      price = 120  },
    { model = 'prop_microwave_01',  label = 'Microwave',         price = 180  },
    { model = 'prop_plant_int_01',  label = 'Indoor Plant',      price = 80   },
    { model = 'prop_floor_lamp_01', label = 'Floor Lamp',        price = 150  },
    { model = 'prop_bookcase_01',   label = 'Bookshelf',         price = 250  },
}

-- =============================================
--  SHOWER SYSTEM
-- =============================================
Config.Shower = {
    Command       = 'shower',
    MaxUsesPerDay = 3,
    ResetHours    = 24,
    Duration      = 8,
}

-- =============================================
--  SNAP / EBT CONFIG
-- =============================================
Config.SNAP = {
    Item             = 'link_card',
    BaseAmount       = 210,
    PerKid           = 20,
    IncomeThreshold  = 1500,
    IncomeReduction  = 50,
    MaxBenefit       = 400,
    MinBenefit       = 100,
    ReloadDays       = 30,

    -- Replacement card settings
    ReplacementCost   = 25,    -- Cost in cash to replace a lost/stolen card
    ReplacementCooldown = 72,  -- Hours between replacement requests (prevents abuse)
}

-- =============================================
--  SNAP SHOP LOCATIONS
-- =============================================
SnapShopConfig = {}

SnapShopConfig.Stores = {
    {
        id       = 'snap_store_1',
        label    = 'Grocery Mart — EBT',
        coords   = vector4(29.71, -1343.59, 29.49, 185.63),
        npcModel = 'a_f_m_downtown_01',
        blip = { enabled = true, sprite = 52, color = 2, scale = 0.7, label = 'SNAP Food Store' },
    },
    {
        id       = 'snap_store_2',
        label    = 'Family Foods — EBT',
        coords   = vector4(-223.44, -1086.05, 23.27, 250.13),
        npcModel = 'a_f_m_downtown_01',
        blip = { enabled = true, sprite = 52, color = 2, scale = 0.7, label = 'SNAP Food Store' },
    },
    {
        id       = 'snap_store_3',
        label    = 'Corner Store — Southside',
        coords   = vector4(0.0, 0.0, 0.0, 0.0), -- Set your coords
        npcModel = 'a_m_m_stlat_01',
        blip = { enabled = true, sprite = 52, color = 2, scale = 0.7, label = 'SNAP Food Store' },
    },
}

SnapShopConfig.Items = {
    -- BREAD & BAKERY
    { item = 'bread',           label = 'Bread Loaf',          price = 3  },
    { item = 'shephards_pie',   label = 'Hot Dog Buns (8pk)',   price = 4  },
    -- DAIRY
    { item = 'milk',            label = 'Milk (Gallon)',        price = 4  },
    { item = 'cheese',          label = 'Cheese Slices',        price = 5  },
    { item = 'eggs',            label = 'Eggs (Dozen)',         price = 4  },
    { item = 'butter',          label = 'Butter',               price = 4  },
    -- MEAT & PROTEIN
    { item = 'sandwich',        label = 'Deli Sandwich',        price = 6  },
    { item = 'hot_dog',         label = 'Hot Dogs (Pack)',      price = 5  },
    { item = 'tuna_can',        label = 'Canned Tuna',          price = 3  },
    -- CANNED & DRY GOODS
    { item = 'beans_can',       label = 'Canned Beans',         price = 2  },
    { item = 'soup_can',        label = 'Canned Soup',          price = 2  },
    { item = 'rice',            label = 'Rice (2lb Bag)',        price = 3  },
    { item = 'pasta',           label = 'Pasta (1lb Box)',       price = 3  },
    { item = 'cereal',          label = 'Cereal Box',           price = 5  },
    { item = 'peanut_butter',   label = 'Peanut Butter',        price = 4  },
    -- DRINKS
    { item = 'water_bottle',    label = 'Water Bottle',         price = 1  },
    { item = 'juice',           label = 'Apple Juice',          price = 3  },
    { item = 'soda',            label = 'Soda Can',             price = 2  },
    -- PRODUCE
    { item = 'apple',           label = 'Apples',               price = 2  },
    { item = 'banana',          label = 'Bananas',              price = 2  },
    { item = 'orange',          label = 'Orange',               price = 2  },
    { item = 'strawberry',      label = 'Strawberry',           price = 1  },
    -- BABY
    { item = 'baby_formula',    label = 'Baby Formula',         price = 12 },
    { item = 'baby_food',       label = 'Baby Food (4pk)',      price = 8  },
}
