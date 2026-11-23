# Orbit Roll · Web Build

A playable web prototype of the Roblox rocket-launch game, built to test the core loop before porting it to Roblox Studio.

| File | What it is |
|---|---|
| `index.html` | The 3D game (main build) |
| `prototype-2d.html` | The earlier 2D core-loop prototype, kept for comparison |

Both are single, self-contained HTML files with no build step.

## Run it locally

Opening `index.html` by double-clicking works in most browsers. If your browser blocks it, serve the folder instead:

```bash
cd orbit-roll
python3 -m http.server 8000
# then open http://localhost:8000
```

## Put it online

Any static host works, because the game is just HTML.

- **GitHub Pages:** push the folder to a repository, then turn on Pages for that branch.
- **Netlify Drop:** drag the `orbit-roll` folder onto app.netlify.com/drop.
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
| BOOST at a gate / CATCH on landing | Space, click, or tap anywhere | Tap anywhere |
| Collect a star shard | Click the shard | Tap the shard |

## Testing tools

- **Wrench (top left):** skips the tutorial, unlocks every part and equips the best Jupiter build (Aero Nose, Mega Tank, Plasma Engine, Swept Fins). Build it in the Assembly Bay to fly it.
- **Reset (top left, tap twice):** clears saved progress so the tutorial and the Jupiter unlock reveal play again.

Progress is saved in the browser's local storage, separately for each site the game is hosted on.
