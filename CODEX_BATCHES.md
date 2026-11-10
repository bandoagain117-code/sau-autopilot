# CODEX BATCHES — standing work program for the autopilot agent

The codex in `scripts/codex_data.gd` is being expanded into the game's
largest reference work. Most of its bulk entries were written from
templates and read repetitively. Your job, run after run, is to rewrite
them properly, six at a time, and to build the new companion entries the
expansion calls for — without ever inventing canon.

## Hard rules (every run)

- NEVER read the whole of `scripts/codex_data.gd` into context. It is
  huge. Find entries with grep and read only the lines of the entries
  you are working on.
- Preserve every rewritten entry's `id`, `title`, `plate`, and EVERY
  fact in its body. Add no new names, people, places, events, or laws.
- Enrich with texture only: materials, weights, weather, sounds, what
  the place does to someone standing in it, what its people do with
  their hands all day.
- Preserve uncertainty. If an entry wonders or says "it is said", the
  rewrite still wonders. Never resolve an open mystery.
- Voice: adult, dread by implication, never gore. Concrete and layered —
  2–3 full paragraphs per entry. No modern slang, no game mechanics,
  no fourth wall.
- Register: this codex is a HOLY book — the awe of the game lives in
  it. Write with reverence and mythic weight (think Darksiders'
  biblical grandeur, Final Fantasy's sacred scale): grave, illuminated,
  monumental where the subject is monumental. Awe comes from the shadow
  a small thing casts, not from shouting.
- BANNED template phrases, in any variation: "crews pass through",
  "do not linger", "come back quieter", "cross back quieter",
  "does not need explaining", "nobody explains", "nobody says why",
  "how, nobody says", "the keeper of the", "it does not need to",
  "in that order".
- This file is GENERATED in the main project; your edits here are the
  working copy. Note ports audited changes upstream. Edit in place.

## Step 1 — first run only: the audit

If `tools/codex_audit.py` does not exist, write it (Python stdlib only):
it scans `scripts/codex_data.gd` for the banned markers above and writes
`docs/CODEX_AUDIT.md` listing every entry id whose body contains one,
grouped by codex section. Run it and commit both files.

## Step 2 — every run: the next batch of six

1. Read `docs/CODEX_PROGRESS.md` (create it if absent). It lists entry
   ids already rewritten, one per line.
2. From the audit list (or a fresh grep for the markers), take the NEXT
   6 entry ids not yet in the progress file, in file order.
3. Rewrite those 6 entries in place in `scripts/codex_data.gd`,
   following the hard rules.
4. Append the 6 ids to `docs/CODEX_PROGRESS.md`, each with a one-line
   note: what texture was added; confirmation no new facts entered.
5. Write `docs/RUN_NOTES.md`: the batch, the ids, anything you were
   unsure about. Uncertainty is reported, never resolved by inventing.

## Done means

The 6 entries rewritten in place, progress file updated, run notes
written, everything committed on the agent branch for review. Note
audits every batch against canon before it is merged. If a batch's
entries cannot be rewritten without inventing facts, skip them, note
why in RUN_NOTES.md, and take the next ones instead.
