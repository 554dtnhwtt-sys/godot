# Island Colony – pilot 0.8

A colony-building and naval strategy game in a Caribbean archipelago, made with Godot 4.7.
(Swedish: spelets text är på engelska. Dokumenten i `docs/` är på svenska.)

## How to run
1. Open Godot 4.7.2.
2. Click **Import** and select `project.godot` in this folder.
3. Press **F5** (Run). The first time, Godot needs a few seconds to import the images.

## Controls
- WASD / arrow keys: camera. Mouse wheel: zoom. H: home island.
- Space: pause. 1–4: game speed.
- Left-click / drag: select ships. Right-click: sail, attack, colonize, start a trade route.
- Click one of your islands to build. F: research. P: diplomacy. F1: help. Esc: menu.

Ships, towns, resource sites, palms and volcanoes are 3D models built in code
(`scripts/world3d/`). They are rendered in their own viewport with real light and shadows
and laid over the painted 2D islands and sea.

See `docs/` for the design notes and the development log (in Swedish).
