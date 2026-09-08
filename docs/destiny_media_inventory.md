# Destiny Media Inventory

Canonical planned object slots for the live Destiny OS public bucket.

| Setting | Value |
|---|---|
| Project | `destiny-os` |
| Project URL | `https://xchddfpfzrzhlbbmyhyn.supabase.co` |
| Bucket | `destiny-media` (public read) |

Public URL form:

```
https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/<object-path>
```

Status legend: `planned` = slot reserved, file not uploaded yet; `migrated` = Destiny object live and wired in app; `legacy` = still using bymapara `uploads/`.

**M2 note (2026-09-08):** Inventory media copy into `destiny-media/tours|stays|vehicles|awards/...` is **blocked** pending `SUPABASE_SERVICE_ROLE_KEY`. Home objects remain `migrated`. Inventory rows below stay `planned` / `legacy` until `DESTINY_MIGRATE_MEDIA=1 python3 scripts/migrate_inventory_to_supabase.py` succeeds.

Do not invent inventory. Rows below were pulled from the live PHP API (`get_tours` / `get_accommodations` / `get_vehicles`) for migration tracking only.

## Planned slots

### HOME

| Object path | App placement | Status |
|---|---|---|
| `home/hero/main.webp` | **Primary** Home hero background (`HomeScreen` → `TravelNetworkImage`). Local promo `VideoHero` / `assets/videos/main_video.mp4` is **not** used on Home. | migrated |
| `home/editorial/travel-partner.webp` | **Primary** right-side image in “More than a booking. A travel partner.” editorial band | migrated |
| `home/editorial/destination-inspiration.webp` | **Primary** photography for Our Accolades cards (award titles remain native Flutter UI; no legacy plaque assets) | migrated |

Home refs are Destiny storage references only (`destiny-media/...`), resolved via `DestinyMediaUrl` → `TravelNetworkImage`. No hardcoded Supabase absolute URLs in Home widgets.

### TOURS

| Object path pattern | Purpose |
|---|---|
| `tours/<tour-id>/primary.webp` | Card + details primary |
| `tours/<tour-id>/gallery-01.webp` | Gallery image 1 |
| `tours/<tour-id>/gallery-02.webp` | Gallery image 2 |

### STAYS

| Object path pattern | Purpose |
|---|---|
| `stays/<stay-id>/primary.webp` | Card + details primary |
| `stays/<stay-id>/gallery-01.webp` | Gallery image 1 |
| `stays/<stay-id>/gallery-02.webp` | Gallery image 2 |

### VEHICLES

| Object path pattern | Purpose |
|---|---|
| `vehicles/<vehicle-id>/primary.webp` | Card + details primary |
| `vehicles/<vehicle-id>/gallery-01.webp` | Gallery image 1 |

### BRANDING

| Object path | Purpose | Status |
|---|---|---|
| `branding/*` | Logos and brand marks | planned |

### PLACEHOLDERS

| Object path | Purpose | Status |
|---|---|---|
| `placeholders/travel.webp` | Tour fallback | planned |
| `placeholders/stay.webp` | Stay fallback | planned |
| `placeholders/vehicle.webp` | Vehicle fallback | planned |

## Tours migration map

Source count: **25** tours from live API.

| Tour ID | Tour title | Current primary image reference | Planned Supabase primary object path | Migration status |
|---|---|---|---|---|
| 1 | Victoria Falls Adventure | `uploads/68c21f8416dbc-vic1.jpeg` | `destiny-media/tours/1/primary.webp` | planned |
| 2 | Durban To Mozambique Cruise | `uploads/68e4a7c27c9a3-durbanmozambiquecruise.jpg` | `destiny-media/tours/2/primary.webp` | planned |
| 3 | Hwange National Park Safari | `uploads/68c21fce2c93b-gone3.jpeg` | `destiny-media/tours/3/primary.webp` | planned |
| 14 | Kadoma Music Festival 2025 | `uploads/68e49bd28aec3-kadomamusicfestival.jpg` | `destiny-media/tours/14/primary.webp` | planned |
| 15 | Israel Holy Land Tour | `uploads/IMG-20250908-WA0000.jpg` | `destiny-media/tours/15/primary.webp` | planned |
| 16 | Zanzibar Trip | `uploads/IMG-20250902-WA0003.jpg` | `destiny-media/tours/16/primary.webp` | planned |
| 17 | Malawi Trip | `uploads/IMG-20251016-WA0000.jpg` | `destiny-media/tours/17/primary.webp` | planned |
| 18 | Durban to Mozambique Cruise | `uploads/IMG-20251004-WA0008.jpg` | `destiny-media/tours/18/primary.webp` | planned |
| 19 | Explore Singapore | `uploads/IMG-20251004-WA0014.jpg` | `destiny-media/tours/19/primary.webp` | planned |
| 20 | Archipelago Resort Summer Escape | `uploads/IMG-20251024-WA0006.jpg` | `destiny-media/tours/20/primary.webp` | planned |
| 21 | Bali Holiday Package | `uploads/IMG-20251025-WA0013.jpg` | `destiny-media/tours/21/primary.webp` | planned |
| 22 | Girls Game Drive Retreat Kariba | `uploads/IMG-20250902-WA0008.jpg` | `destiny-media/tours/22/primary.webp` | planned |
| 23 | Musumu River Lodge Binga Tour | `uploads/IMG-20250902-WA0009.jpg` | `destiny-media/tours/23/primary.webp` | planned |
| 24 | Figtree Camp Selous (Schools) | `uploads/IMG-20251016-WA0002.jpg` | `destiny-media/tours/24/primary.webp` | planned |
| 29 | Dubai (Emirates + JW Marriott Marquis) | `uploads/6a4e0663112ef-742045552_1817725842533249_6048909638074682386_n (1).jpg` | `destiny-media/tours/29/primary.webp` | planned |
| 30 | Zanzibar (Beaches & Island Escapes) | `uploads/6a4e06df711f2-735150058_1811822186456948_101665622254047033_n.jpg` | `destiny-media/tours/30/primary.webp` | planned |
| 31 | Victoria Falls – Flight of Angels | `uploads/6a4e08b9d25a3-710739115_1781943649444802_2817451762723528287_n.jpg` | `destiny-media/tours/31/primary.webp` | planned |
| 32 | ZAMBEZI ARK CRUISES | `uploads/6a4e09e9e45cc-700499814_1768197580819409_6381454881535599423_n.jpg` | `destiny-media/tours/32/primary.webp` | planned |
| 33 | KUMBA SHIRI | `uploads/6a4e14e4cf46c-657364419_1724779385161229_2149096553167828688_n.jpg` | `destiny-media/tours/33/primary.webp` | planned |
| 34 | MORROCO | `uploads/6a4e16b7113b4-659017522_1724776148494886_653600608863616191_n.jpg` | `destiny-media/tours/34/primary.webp` | planned |
| 35 | IMIRE  GIRLS TRIP | `uploads/6a4e176be2915-655699898_1724774848495016_9085784168804663092_n.jpg` | `destiny-media/tours/35/primary.webp` | planned |
| 36 | JAPAN TOUR | `uploads/6a4f5295f1894-ChatGPT Image Jul 9, 2026, 09_49_04 AM.png` | `destiny-media/tours/36/primary.webp` | planned |
| 37 | VISIT FRANCE | `uploads/6a4f54675bd28-ChatGPT Image Jul 9, 2026, 09_56_32 AM.png` | `destiny-media/tours/37/primary.webp` | planned |
| 38 | KANGARA RESORT | `uploads/6a4f55b845fa5-638097643_1697288214577013_700192901064861172_n.jpg` | `destiny-media/tours/38/primary.webp` | planned |
| 39 | PHUKET TOUR | `uploads/6a4f9a97e9470-615724801_1664832577822577_6837233941983207803_n.jpg` | `destiny-media/tours/39/primary.webp` | planned |

## Stays migration map

Source count: **36** stays from live API.

| Stay ID | Stay title | Current primary image reference | Planned Supabase primary object path | Migration status |
|---|---|---|---|---|
| 1 | Kariba Safari Lodges | `uploads/68e49df503656-karibasafarilodges.jpg` | `destiny-media/stays/1/primary.webp` | planned |
| 2 | Musumu River Lodge | `uploads/68e49f8880332-musumuriverlodgebinga.jpg` | `destiny-media/stays/2/primary.webp` | planned |
| 3 | Sable Sands Safari Camp | `uploads/68c222ad3cd52-sable1.jpg` | `destiny-media/stays/3/primary.webp` | planned |
| 4 | Troutbeck Resort Nyanga | `uploads/69fc507b55985-e96a075e-bb9a-4d72-a1a4-6ea8ec26b059.jpeg` | `destiny-media/stays/4/primary.webp` | planned |
| 5 | Musumu River Lodge | `uploads/IMG-20250902-WA0009.jpg` | `destiny-media/stays/5/primary.webp` | planned |
| 6 | Victoria Falls Rainbow Hotel | `uploads/6a4e07a5c61d1-729186459_1806601646979002_8901278662318032669_n.jpg` | `destiny-media/stays/6/primary.webp` | planned |
| 7 | Samanzi Lodge, Victoria Falls | `uploads/6a4e08459ab54-714989930_1786588908980276_8190643222706287963_n.jpg` | `destiny-media/stays/7/primary.webp` | planned |
| 8 | KASAMBABEZI LODGE | `uploads/6a4e0973085fc-701757966_1771935113778989_4758451502969602632_n.jpg` | `destiny-media/stays/8/primary.webp` | planned |
| 9 | VICTORIA FALLS OASIS HOTEL | `uploads/6a4e0ac5230f9-690178754_1762327108073123_5929880093508995947_n.jpg` | `destiny-media/stays/9/primary.webp` | planned |
| 10 | GREAT ZIMBABWE HOTEL | `uploads/6a4e0baa55e73-684908563_1754812892157878_7537154398826253792_n.jpg` | `destiny-media/stays/10/primary.webp` | planned |
| 11 | CASTELO BEACH RESORT | `uploads/6a4e0c9750e3d-677063597_1748458519459982_4606751693495945160_n.jpg` | `destiny-media/stays/11/primary.webp` | planned |
| 12 | DAISY GUEST HOUSE | `uploads/6a4e0d8aeab65-679081833_1747531572886010_8241190597285094904_n.jpg` | `destiny-media/stays/12/primary.webp` | planned |
| 13 | DAISY GUEST HOUSE | `uploads/6a4e0ddb08cad-677055824_1747531492886018_465792238771702595_n.jpg` | `destiny-media/stays/13/primary.webp` | planned |
| 14 | SKY DECK MOUTAIN REREAT | `uploads/6a4e12308366a-678655289_1747526919553142_1804452063333086943_n.jpg` | `destiny-media/stays/14/primary.webp` | planned |
| 15 | NKANDLA RESORTS | `(none)` | `destiny-media/stays/15/primary.webp` | planned (no legacy primary) |
| 16 | NYAMAKWERE LODGE | `uploads/6a4e1337034cf-675020679_1746704992968668_8195398866841603539_n.jpg` | `destiny-media/stays/16/primary.webp` | planned |
| 17 | CHAMABONDO | `uploads/6a4e142b7d0bc-657331897_1727557841550050_7331887577038956413_n.jpg` | `destiny-media/stays/17/primary.webp` | planned |
| 18 | THE EDWARD | `uploads/6a4e194647330-656312260_1724773688495132_1174615719230396529_n.jpg` | `destiny-media/stays/18/primary.webp` | planned |
| 19 | CHIVERO LAKE CHALET | `uploads/6a4e1bd3db9a2-657163835_1722491342056700_4321707265649208640_n.jpg` | `destiny-media/stays/19/primary.webp` | planned |
| 20 | VICTORIA FALLS SAFARI LODGE | `uploads/6a4e3f7c569dc-ChatGPT Image Jul 8, 2026, 02_08_19 PM.png` | `destiny-media/stays/20/primary.webp` | planned |
| 21 | VICTORIA FALLS SAFARI LODGE | `uploads/6a4e3f81708b8-ChatGPT Image Jul 8, 2026, 02_08_19 PM.png` | `destiny-media/stays/21/primary.webp` | planned |
| 22 | LAGOON BEACH | `uploads/6a4e415833cf9-656647058_1722145902091244_4829004906901322191_n.jpg` | `destiny-media/stays/22/primary.webp` | planned |
| 23 | TSWA SAFARI ISLAND | `uploads/6a4e4379acf58-653704075_1719141525725015_9167148484667333969_n.jpg` | `destiny-media/stays/23/primary.webp` | planned |
| 24 | CUTTY SARK LODGE | `uploads/6a4e444e2acef-651751033_1717060289266472_8582386724155725165_n.jpg` | `destiny-media/stays/24/primary.webp` | planned |
| 25 | KENYA | `uploads/6a4e451d4395a-653050733_1716642312641603_1757143874607527524_n.jpg` | `destiny-media/stays/25/primary.webp` | planned |
| 26 | EGYPT TOUR | `uploads/6a4e48ed3217b-651035371_1713846052921229_6431422086256641855_n.jpg` | `destiny-media/stays/26/primary.webp` | planned |
| 27 | HIDDEN VALLEY BINDURA | `uploads/6a4f553251c63-641399392_1699904650982036_9069118774992262354_n.jpg` | `destiny-media/stays/27/primary.webp` | planned |
| 28 | MASUMU RIVER LODGE | `uploads/6a4f56c33b8ef-639229923_1696241041348397_4416506335286417851_n.jpg` | `destiny-media/stays/28/primary.webp` | planned |
| 29 | SHASHANI LODGE | `uploads/6a4f57861b988-639991094_1696240514681783_1183523098736264155_n.jpg` | `destiny-media/stays/29/primary.webp` | planned |
| 30 | SMILE BOUTIQUE BEACH HOTEL NUNGWI | `uploads/6a4f5851324d7-626158837_1682879592684542_3549665868704782837_n.jpg` | `destiny-media/stays/30/primary.webp` | planned |
| 31 | ZENOBIA BEACH RESORT  | `uploads/6a4f593b357f3-627143344_1682877346018100_4256269271618478209_n.jpg` | `destiny-media/stays/31/primary.webp` | planned |
| 32 | ROBINS CAMP | `uploads/6a4f5a8df12bd-626999792_1681118199527348_8781928959766861665_n.jpg` | `destiny-media/stays/32/primary.webp` | planned |
| 33 | MATOBO HILLS LODGE | `uploads/6a4f5b6c2af0b-616827839_1669620824010419_5039646770684918639_n.jpg` | `destiny-media/stays/33/primary.webp` | planned |
| 35 | CHENGETA SAFARI | `uploads/6a4f9b8069725-615434009_1663086194663882_123611080104403035_n.jpg` | `destiny-media/stays/35/primary.webp` | planned |
| 36 | PAMUZINDA SAFARI LODGE | `uploads/6a4f9dd72fab2-615471192_1663083854664116_2649064526261562484_n.jpg` | `destiny-media/stays/36/primary.webp` | planned |
| 37 | FRASER SUITES SUKHUMVIT | `uploads/6a54c1b399064-616835563_1664833494489152_6348076497884262295_n.jpg` | `destiny-media/stays/37/primary.webp` | planned |

## Vehicles migration map

Source count: **3** vehicles from live API.

| Vehicle ID | Vehicle title | Current primary image reference | Planned Supabase primary object path | Migration status |
|---|---|---|---|---|
| 1 | Toyota Hilux 4x4 | `uploads/68c222df5c074-d41.webp` | `destiny-media/vehicles/1/primary.webp` | planned |
| 2 | Toyota Corolla | `uploads/68c2237c7a4da-co1.avif` | `destiny-media/vehicles/2/primary.webp` | planned |
| 3 | Mercedes-Benz Sprinter | `uploads/68c223a6319a8-sprint1.avif` | `destiny-media/vehicles/3/primary.webp` | planned |

## Notes

- Files are **not** uploaded by this inventory document.
- Legacy bymapara `uploads/...` paths remain resolvable until each row is migrated.
- After upload, store either `destiny-media/...` refs or full public HTTPS URLs in API image JSON (API migration is a later phase).
- **M1 customer product** still renders stay/vehicle/tour cards via `DestinyMediaUrl` + `TravelNetworkImage`. Inventory rows above remain **planned/legacy** unless marked migrated — M1 did not upload stay/vehicle photography.

## Notes
