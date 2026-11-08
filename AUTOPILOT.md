# Autopilot operating rules

- **Brief in, branch out.** The agent works ONLY from the brief in `TASK.md` (or the dispatch input). It never invents scope.
- **Budget:** Groq free tier — ~200K tokens/day is the real cap. Briefs must be small and specific; one task per run.
- **Model:** `google/gemini-2.5-flash` (default). LESSON (runs #3-4, 2026-11-08): Groq free TPM caps (gpt-oss-120b 8,000; llama-3.3-70b ~12,000) are smaller than an agent loop's working requests (~9,170 first request, growing) - Groq free is structurally too tight for OpenCode agents. Gemini free tier (~250K TPM) is the primary; Groq key kept as backup for tiny jobs.
- **Never in this repo:** canon documents, story bibles, personal data, credentials. Secrets live only in GitHub Actions secrets.
- **Review:** every agent branch gets reviewed by Note before merge. Agent output is a draft, never a ship.
- **Builds:** `build: true` exports a debug APK as a workflow artifact for verification — it is not a release.
