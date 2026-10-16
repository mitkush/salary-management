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
- Every code change goes through the `build` skill (`.claude/skills/build/SKILL.md`).
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
- Payroll entries are the only stored payroll. View and export read them and never recalculate.
- Locked payroll months are read-only.
- Employee details are never edited. The only change allowed is termination.
- The UI shows only the last 4 digits of a bank account number.

## Frontend
- React with Vite, in plain JavaScript, using Ant Design and `react-router`. Ask before adding any other package.
- Keep list filters and pagination in the URL, so Back, Forward and shared links work.
- No business logic in the UI. Every calculation comes from the API.

## Commands
- Setup: `bin/setup --skip-server` and `npm --prefix frontend ci`
- Run: `bin/dev` (Rails on :3000, Vite on :5173), or `docker compose up --build` (app on :3000)
- Test: `bundle exec rspec`, or `docker compose run --rm test`
- Lint: `bin/rubocop` and `npm --prefix frontend run lint`
- All backend checks (RuboCop, bundler-audit, Brakeman, RSpec): `bin/ci`

## Git
- Use Conventional Commits: `type(scope): message`, where type is one of `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `ci` or `build`. Keep each message to a single line, with no co-author line or any other trailer. Each commit should be a meaningful working piece.
- Put every piece of work on its own branch, e.g. `chore/ai-setup` or `feat/salary-revisions`. No direct commits on `main`.
- PRs are merged with a merge commit, not squashed, so every commit stays in the history.
- Never commit without my approval.
- Push and create/update PRs only when I ask, using the `pr` skill. Never merge.
- Tests pass before every commit, except a `test:` commit with failing specs that the very next `feat:`/`fix:` commit makes pass.
- TDD commits come in pairs, one per meaningful piece: first `test:` with the failing specs, then `feat:`/`fix:` with the code that makes them pass.

## AI prompt log
After each meaningful task, add an entry to `docs/ai-prompts.md` with:
- my prompt, in short
- what you did
- what I changed or rejected

## Don'ts
- Don't add a gem without asking.
- Don't edit or commit `.private/`, `.env` or any keys.
