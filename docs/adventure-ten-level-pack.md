# Adventure Mode: night-roof level pack

Adventure now has six areas of ten levels. The new area is **6-1 through 6-10** (internal levels 51–60). It reuses the existing boss-roof artwork, which already provides a night roof, and uses the existing plant and zombie roster. Level 50 is now an ordinary daytime roof level. The final boss, the note before it, the sunflower award and credits have moved to level 60.

## Level data

[GameConstants.h](../GameConstants.h) defines six Adventure areas, ten levels per area and `FINAL_LEVEL` as 60. [Lawn/Challenge.cpp](../Lawn/Challenge.cpp) defines the wave counts and zombie eligibility for each level. The new levels have 20–30 base waves and varied combinations of existing zombies. Level 51 uses normal, conehead, buckethead, newspaper, bungee and ghost zombies. Later levels introduce different mixes. This is initial content and has not yet been balanced through full playthroughs.

The eligibility table is not an exact wave script: [Board::PickZombieWaves](../Lawn/Board.cpp) generates waves using eligible zombies, zombie definitions and their weights. On replay, it normally adds ten waves. The board permits up to 100 waves and 50 zombies per wave. The final-wave generator also inserts eligible types missing from that wave; take that capacity into account when adding zombies.

## Environment and progression

[Board::PickBackground](../Lawn/Board.cpp) selects the existing night-roof background for levels 51–60, and [QuickPlayScreen.cpp](../Lawn/Widget/QuickPlayScreen.cpp) uses the same background for its preview. The existing roof rules provide five rows, flower-pot requirements and roof cleaners; night rules wake mushrooms and stop falling sun. [LawnApp::IsNight](../LawnApp.cpp) also recognizes the new area. The normal roof setup pre-places three columns of flower pots.

Adventure progression advances from level 50 to 51 and continues to 60. Levels 49–58 drop money bags; level 59 drops the final note; level 60 uses the existing boss and completion rewards. The first Adventure completion and its credits now happen after level 60. Existing profiles that have already finished Adventure retain that status and encounter the new levels as they progress through a replay; the change does not automatically move them to level 51. Quick Play can select the new levels without changing Adventure progress.

## Extending or testing the pack

- Adjust wave counts and each zombie's level columns in [Lawn/Challenge.cpp](../Lawn/Challenge.cpp); keep rows aligned with the zombie enum and verify eligibility and wave capacity. Zero-initialized rows are intentionally unavailable.
- Review special-stage predicates in [LawnApp.cpp](../LawnApp.cpp), conveyor choices in [Lawn/Challenge.cpp](../Lawn/Challenge.cpp), and [Lawn/CutScene.cpp](../Lawn/CutScene.cpp) before adding a new special level. Existing special stages do not automatically repeat in a new area.
- New seed rewards need an explicit mapping and changes to award drops, seed availability, resource preloading and award screens. The pack currently reuses money bags and does not introduce plants or zombies.
- The runtime loads `properties\resources.xml` and resource groups through [LawnApp.cpp](../LawnApp.cpp); new artwork or audio must also be included in the runtime asset distribution. The current area needs no new assets.
- Profiles store level and completed-Adventure counts in [PlayerInfo.cpp](../Lawn/System/PlayerInfo.cpp). In-progress saves serialize board state in [SaveGame.cpp](../Lawn/System/SaveGame.cpp). Test old profiles and saves, especially an in-progress original boss level, when changing progression or serialized structures.
- Build [PlantsVsZombies.sln](../PlantsVsZombies.sln) with the Debug or Release **x86** solution configuration. For playtesting, use a disposable profile: the level cheat in [CheatDialog.cpp](../Lawn/Widget/CheatDialog.cpp) writes the profile and does not enforce an upper bound.
- Verify every level on a first run and replay, including seed selection, zombies, waves and completion. In particular check transitions 49→50→51 and 59→60, boss behavior, notes, rewards, credits, Quick Play and save/reload. Playtest difficulty and make adjustments before treating the pack as balanced.
