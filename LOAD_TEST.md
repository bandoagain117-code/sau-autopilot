# Load test (re-cut for efficiency) — scripted audit + 6-entry de-template batch

Work in `scripts/codex_data.gd` (313 codex entries as GDScript dictionaries with id/title/body/plate).
TOKEN DISCIPLINE IS PART OF THE TASK: never read the whole codex file into context. Use grep/sed to read only the lines you need.

## Part 1 — audit by script, not by reading
1. Write `tools/codex_audit.py` (Python 3, stdlib only) that parses every entry and flags TEMPLATE MARKERS in body text. Marker list (case-insensitive substrings):
   "crews pass through", "do not linger", "does not need explaining", "nobody explains",
   "how, nobody says", "the keeper of the", "it does not need to", "nobody says why",
   "come back quieter", "cross back quieter", "in that order".
2. The script writes `docs/CODEX_AUDIT.md`: totals per category, flagged count, and a table of every flagged entry (id, title, category, matched markers).
3. Run the script and commit BOTH the script and its output.

## Part 2 — rewrite exactly these 6 entries in place
Targets: `ferren`, `mirell` (creations) · `weighmaster`, `glazier` (keepers) · `seamneedle`, `dredgehook` (coalescences).
For each: read ONLY that entry's current lines (grep -n for its id). Rewrite its `body`:
- Preserve the id, title, plate value, and EVERY fact in the original body. Invent no new facts, names, or lore.
- Expand to 2–3 short paragraphs (separate paragraphs with \n\n inside the string).
- No sentence may reuse any marker phrase from Part 1, and no two rewritten entries may share an opening sentence pattern.
- Voice: plain, concrete, quietly ominous — specific physical detail over summary.
- GDScript safety: the body is a double-quoted string; do not use unescaped double quotes inside it.
(Note: the file header says it is generated upstream. Edit it anyway — accepted rewrites get ported back by the reviewer.)

## Part 3 — verify and summarize
1. grep the 6 target entries again and confirm none of the marker phrases remain in them.
2. Write `docs/LOAD_TEST_NOTES.md`: per target — old body length vs new body length (characters), and one line on what changed.
Modify nothing else.
