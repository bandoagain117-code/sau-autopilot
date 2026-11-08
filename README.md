# sau-autopilot

SAU 3D slice — autopilot build workspace. Code and working assets only; canon documents and story material are kept elsewhere and never enter this repo.

## How the autopilot loop works
1. Note writes a task brief into `TASK.md` on `main` (or passes a brief when dispatching the workflow).
2. A human dispatches **Actions → Autopilot → Run workflow** (optionally with `build: true` to also export an Android debug APK).
3. The workflow runs an OpenCode agent on a free model (Groq) on branch `agent/run-<n>` and opens a pull request with the result.
4. Note reviews the PR, bando spot-checks, and only then does anything merge.

See `AUTOPILOT.md` for the operating rules.
