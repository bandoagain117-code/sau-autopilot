# Autopilot operating rules

- **Brief in, branch out.** The agent works ONLY from the brief in `TASK.md` (or the dispatch input). It never invents scope.
- **Budget:** Groq free tier — ~200K tokens/day is the real cap. Briefs must be small and specific; one task per run.
- **Model:** `groq/openai/gpt-oss-120b` (default in the workflow). Fallbacks if a run fails on model access: `groq/llama-3.3-70b-versatile`, then Gemini/Mistral keys as additional secrets.
- **Never in this repo:** canon documents, story bibles, personal data, credentials. Secrets live only in GitHub Actions secrets.
- **Review:** every agent branch gets reviewed by Note before merge. Agent output is a draft, never a ship.
- **Builds:** `build: true` exports a debug APK as a workflow artifact for verification — it is not a release.
