# 🧬 Primordia

One run, from a single cell to a galactic empire. Start as a mote of life in the primordial soup, crawl onto land, light the first fire, raise a civilization, then take the galaxy. Five stages, all playable, each one shaped by what you evolved in the last.

Built in **Godot 4** with **GDScript** and free CC0 / CC-BY low-poly art. This is an early **v0.2** release.

[![Download for Windows](https://img.shields.io/badge/Download-Windows-2ea44f?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/BroPilot-AI/Primordia/releases/latest)
[![Made with Godot](https://img.shields.io/badge/Made%20with-Godot%204.7-478cbf?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

---

## ✨ Features

- **Five stages in one run** — **Primordial soup → Creature → Tribe → Civilization → Space**. A full run is an hour or more.
- **Four lineages** — pick where life begins (**Freshwater Pool**, **Saltwater Coast**, **Deep Ocean** or **Inland Soil**) and that origin decides your species for the rest of the run.
- **Your genome carries forward** — what you eat and which organelles you build in the soup set your genome axes. Those shape your creature's body, your tribe's hunters, your civilization's soldiers and finally your fleet.
- **One seed, one world** — a single world seed drives every stage, so the planet you settle is the one you evolved on.
- **A soup worth swimming in** — sixteen kinds of food, compound vents, viruses and micro-predators, and an organelle editor that changes how your cell looks and feeds.
- **Creature survival** — forage and hunt through turning seasons, hide from predators at night, knap tools, gather kindling and discover fire.
- **Tribe management** — assign your people to forage and hunt zones, build huts, research at the fire, and hold off wolves and rival bands.
- **Civilization RTS** — six ages from **Stone** to **Near-Future**, cities, production chains, rival nations, and **drop-in tactical ground battles**. Win by founding three cities, building a Spaceport and eliminating one rival nation before you launch, or by razing every rival capital.
- **A living galaxy** — 24 star systems where worlds climb the ladder of life and empires rise and fall around you. Eight warship classes, shipyards, mining rigs, bastions, a superweapon, fleet battles, rival empires and a roaming cube collective that is hostile to everyone.
- **Save and continue** — checkpoint a run from the pause menu and pick it up from the title screen.

## 🆕 What's new in v0.2

- **Civilization is now the long game** — each age needs its tech first, the economy runs slower, and a spaceflight launch also needs one rival nation wiped out. Expect around half an hour in this stage.
- **Towns that make sense** — every building, turret and prop stands on a hex of its own and blocks it, new units walk out beside the capital instead of inside it, and a fallen city takes its buildings, turrets and bonuses with it.
- **A new look** — a planet-at-dawn title screen, real water and surf on the Civilization map, living water behind the soup, a procedural nebula behind the galaxy, natural grass and rock tones, and sun shadows everywhere.
- **Easier to read** — the objective sits on a dark pill at the bottom of every stage, your soup cell stands out, tribe villagers look like your own species, and late-age soldiers carry their weapons instead of floating capsules.
- **Fixes** — units stand on hills instead of sinking into them, the settler stays at ground height after a reload, and buildings come back where they stood when you continue a saved run.

## 🎮 How to play

Every stage opens with a short card that tells you the story so far and the controls. Press **?** at any time to see it again.

| Stage | Goal | Controls |
|-------|------|----------|
| 🦠 **Primordial soup** | Grow and evolve into a creature | **WASD / arrows** to swim. Drift over glowing motes to eat. Spend mutation points on organelles. Steer around red-ringed hazards |
| 🦎 **Creature** | Grow, make tools, gather kindling, discover fire | **WASD** to move. Gather materials, shelter in green thickets at night, craft a campfire and shelter |
| 🔥 **Tribe** | Reach the population and shelter milestones | Assign people to forage and hunt zones, build huts, research at the fire. **F** focuses your chief |
| 🏛️ **Civilization** | Three cities, a Spaceport and one rival eliminated, or eliminate all rivals | Drag a box to select, right-click to attack-move. **B** drops into a ground battle near hostiles. **T / F** zoom. Click the minimap to jump |
| 🚀 **Space** | Own every system | **WASD** to fly, park on a system to capture it. **B** drops into a fleet battle near hostiles. Click the minimap to route your fleet |

**Esc** opens the pause menu (resume, save run, settings, quit to title). The strategy stages have a speed control: pause, 1x, 2x and 3x.

## 🚀 Play it

1. Grab **Primordia-Windows.zip** from the **[latest release](https://github.com/BroPilot-AI/Primordia/releases/latest)**.
2. Unzip it anywhere and run **Primordia.exe**. Nothing to install.

Windows may show a SmartScreen warning because the exe isn't signed: click **More info**, then **Run anyway**.

## 🛠️ Running from source

1. Install **[Godot 4.7](https://godotengine.org/download)** (the standard build, not .NET).
2. Open `project.godot` in the Godot editor and press **F5**.

To build the exe, use **Project → Export → Windows Desktop**, or:

```
godot --headless --path . --export-release "Windows Desktop" build/Primordia.exe
```

The `.godot/` import cache is regenerated automatically on first open and is intentionally not tracked.

## 🎨 Credits & licensing

The art is free low-poly content plus models made for this game:

- **Kits and props** — **Kenney** and **Quaternius** (CC0).
- **Ships, cabins and a few props** — **Poly Pizza** contributors (**CC-BY 3.0**, attribution required).
- **Music and sound** — CC0 tracks from OpenGameArt and Kenney, plus effects synthesised for the game.
- **Font** — DynaPuff, under the SIL Open Font License.

Per-asset sources, authors and licences are listed in [`CREDITS.md`](CREDITS.md). CC-BY assets require keeping that attribution.

**Code license:** [MIT](LICENSE).
**Engine:** made with [Godot Engine](https://godotengine.org), used under its MIT license — see [`LICENSE.godot.txt`](LICENSE.godot.txt).
