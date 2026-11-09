# Static detail pass — maximum richness, zero gameplay change

The slice scene (`main.tscn`) already works: movement, combat, codex, touch.
Its weakness is sparseness. This task is a pure **static detail** pass: make the
existing place feel dense, storied, and finished — as much visual richness as
can be layered in — **without changing how the game plays at all.**

## Match the established look (this is the style law)

Do not invent a new style. Study the existing assets and scene first (file
names, the scene text, texture names) and extend what is already there:

- Dark void world; black does the heavy lifting.
- Stone is neutral dark grey-black (`stone_albedo.png` / `stone_normal.png`).
- Purple is an **accent only** — crystals, gems, runes, rim light. Never a
  wash over the whole scene.
- Gold is the most vibrant thing in the world — liquid, metallic, reflective.
  It wins on intensity, never on coverage: small amounts, impossible to miss.
- The mood is ancient, forsaken, and quiet. Detail should feel *found*, like
  the place has been still for an age — not decorated, not busy for its own sake.

## What to add (aim high — density is the assignment)

Layer the space in foreground, midground, and background:

- **Ground:** crack networks, worn paths, ash and dust drifts, scattered
  rubble and stone shards, gold inlay seams in the floor (thin, sparing),
  etched rune circles/lines (purple, faint), dark staining, broken edges.
- **Walls / arena bounds:** relief carving panels, chipped and missing blocks,
  hanging remnant fragments, recessed niches with crystal clusters, gold seam
  lines along a few chosen edges.
- **Beyond the bounds (background depth):** silhouettes of shattered distant
  architecture, floating broken fragments in the void, faint far crystal
  glints — the world must not look like it ends at the arena wall.
- **Set dressing:** toppled pillars, a broken lectern-like remnant, embedded
  blade/weapon shards, scattered bone-pale fragments, tattered remnant cloth
  (static), old braziers unlit or faintly purple-lit.
- **Micro-detail:** pebble scatter, dust piles in corners, moss-dark staining
  in crevices (dark, not green-cheerful), scratch and wear variation on
  existing stone.

Reuse existing textures/materials wherever possible. New textures: max
1024×1024, dark palette, generated procedurally in code or as simple PNGs —
no external downloads.

## Hard rules

1. **No gameplay changes.** Do not modify `scripts/*.gd` logic, input
   handling, the codex, or `project.godot`. (`emulate_mouse_from_touch`
   stays `true`.) Scene and asset additions only.
2. **Collision honesty:** nothing that *looks* solid may be placed inside
   the playable area — you are adding no collision, so solid-looking objects
   go outside the playable bounds, or lie flat on surfaces (decals, relief,
   inlay, cracks). A player must never walk through something that reads
   as solid, and never bump into something invisible.
3. **Performance budget:** static detail must be baked/merged into as few
   meshes as practical (the project's standing line is ~300 draw calls per
   scene). Merge rubble/scatter into combined meshes; do not add hundreds
   of individual nodes. Report before/after draw-call estimates in the
   notes file.
4. **Standing agent rules apply:** text files only, never open binary
   assets, read big files in grep/sed slices, list assets by name.
5. Canon guardrail: add **no** new lore, names, text, factions, or story
   content. This is visual density only. If a detail would imply a story
   fact, leave it out.

## Deliverables

- The enriched `main.tscn` (+ any new asset files), on the agent branch.
- `docs/STATIC_DETAIL_NOTES.md`: what was added layer by layer, the full
  list of new files, before/after draw-call estimates, and anything you
  deliberately left out and why.
