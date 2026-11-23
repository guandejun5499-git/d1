# Orbit Roll · Web Build

A playable web prototype of the Roblox rocket-launch game, built to test the core loop and the stage-1 high-impact features before porting to Roblox Studio.

| File | What it is |
|---|---|
| `index.html` | The 3D game (main build) |
| `prototype-2d.html` | The earlier 2D core-loop prototype, kept for comparison |

Both are single, self-contained HTML files with no build step.

## Run it locally

Opening `index.html` by double-clicking works in most browsers. If your browser blocks it, serve the folder instead:

```bash
cd web-build
python3 -m http.server 8000
# then open http://localhost:8000
```

## Put it online

Any static host works, because the game is just HTML.

- **GitHub Pages:** push this folder to a repository, then turn on Pages for that branch.
- **Netlify Drop:** drag the folder onto app.netlify.com/drop.
- **itch.io:** zip the folder's contents (so `index.html` is at the top level of the zip), create an HTML project, upload the zip and tick "This file will be played in the browser".

## Requirements

- A modern desktop or mobile browser with WebGL (Chrome, Edge, Safari, Firefox).
- An internet connection on first load. The 3D build loads three.js r128 from `cdnjs.cloudflare.com` and the Lilita One and Nunito fonts from Google Fonts. To run fully offline, download `three.min.js` (r128) next to `index.html` and change the script tag to `<script src="three.min.js"></script>`.

## Controls

| Action | Desktop | Mobile |
|---|---|---|
| Move | W A S D / arrow keys | Left thumbstick |
| Jump | Space | Jump button |
| Look around | Drag, scroll to zoom | Drag the screen |
| Use a machine | E (or click the prompt) | Tap the prompt |
| Ignite | Hold Space or the button, release in the green | Hold and release the button |
| Super Launch | Keep holding through two swings, release in the rainbow zone | Same |
| BOOST at a gate | Space, click or tap anywhere when the ring meets the dashed gate outline (third beep) | Tap anywhere |
| Collect a star shard | Click the shard | Tap the shard |
| CATCH on landing | Space, click or tap anywhere when the rocket base is in the green zone | Tap anywhere |

## What's in this build

**Core loop:** roll parts → build in the glass Assembly Bay → ignite → fly gate-timed orbits → catch the landing → collect. Four part slots (nose, tank, engine, fins) × three tiers; the combination sets Δv, and only the right builds reach Jupiter.

**Stage-1 high-impact features**

| Feature | How it works |
|---|---|
| Super Launch | Overcharge the ignition: green → gold → rainbow. Releasing in the rainbow zone gives +60% coins, a white-out shockwave that knocks over nearby players, and a rainbow flame. The gauge shows the three steps and the button tells you what to do. |
| Orbit Fever | 2 PERFECT gates in a row start Fever: every later PERFECT pays ×2, gates widen, the rocket speeds up, and the screen pulses to a rainbow beat until you miss. |
| Consecutive Catches | Perfect catches build a streak across flights; recovery climbs to ×2 at a streak of 5, with sparks, electric arcs and cheers. |
| Spectacular Crash | Forget to tap CATCH and the rocket topples and explodes; a repair drone rebuilds it and you get 50% salvage. |

Gate timing windows (PERFECT): ±0.18 s with Basic Fins, ±0.22 s Swept, ±0.27 s Grid. A short beep at 0.6 s and 0.3 s before each gate and a chime on the beat help with timing.

## Testing tools

- **Wrench (top left):** skips the tutorial, unlocks every part and equips the best Jupiter build (Aero Nose, Mega Tank, Plasma Engine, Swept Fins). Build it in the Assembly Bay to fly it.
- **Reset (top left, tap twice):** clears saved progress so the tutorial, the first Super Launch hint and the Jupiter unlock reveal play again.

Progress is saved in the browser's local storage, separately for each site the game is hosted on.
