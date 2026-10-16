# CLAUDE.md

## Project
A salary management web app for ACME's HR Manager, covering about 10,000 employees across several countries.
- `docs/requirements.md` is the source of truth for scope and rules. Read it before any feature work.
- Don't build anything that isn't in it without asking first.

## Working with me
- Push back when something is wrong, overcomplicated, out of scope or against the requirements. Explain why.
- Verify before claiming: check the docs or the code, or run it. Never invent gem versions, APIs or config options.
- If you're not sure, say so instead of guessing.
- Ask when something is unclear. Make small, obvious calls yourself and mention them.
- Keep it simple: no extra features, and no abstractions before they're needed.

## Workflow
- Always TDD: write a failing spec first, then the minimal code to pass it, then refactor.
- For anything non-trivial, show me the plan before writing code.
- Work in small steps.

## Testing
- RSpec + factory_bot. Mostly unit specs for models and services, plus a few request specs for the API.
- Tests must be deterministic:
  - no random values in assertions
  - freeze time for any date logic
  - use a fixed random seed in `db/seeds.rb`
- No network calls and no `sleep` in tests.

## Rails conventions
- Keep controllers thin. Business logic goes in `app/services`: payroll generation, import, insights and salary calculation.
- Store money as `decimal(12,2)` and handle it as `BigDecimal`. Never use floats for money.
- Back validations with DB constraints: `NOT NULL`, foreign keys, and a unique month on payroll runs.
- Index foreign keys and the columns used for filtering. Avoid N+1 queries.
- Paginate on the server.

## Domain reminders (details in docs/requirements.md)
- Salary revisions are immutable.
- Payroll entries are snapshots of the salary and tax rate at generation time.
- Locked payroll months are read-only.
- Employee details are never edited. The only change allowed is termination.
- The UI shows only the last 4 digits of a bank account number.

## Frontend
- React with Vite, in plain JavaScript, using Ant Design.
- No business logic in the UI. Every calculation comes from the API.

## Commands
<!-- TODO: fill in after Rails setup -->
- Setup: `TBD`
- Run: `TBD`
- Test: `TBD`
- Lint: `TBD`

## Git
- Use Conventional Commits: `type(scope): message`, where type is one of `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `ci` or `build`. Keep each message to a single line, with no co-author line or any other trailer.
- Put every piece of work on its own branch, e.g. `chore/ai-setup` or `feat/salary-revisions`. No direct commits on `main`.
- PRs are merged with a merge commit, not squashed, so every commit stays in the history.
- Never commit without my approval. Never push; I push and open PRs myself.
- Tests must pass before every commit.

## AI prompt log
After each meaningful task, add an entry to `docs/ai-prompts.md` with:
- my prompt, in short
- what you did
- what I changed or rejected

## Don'ts
- Don't add a gem without asking.
- Don't edit or commit `.private/`, `.env` or any keys.
