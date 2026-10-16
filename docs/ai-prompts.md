# AI Prompts Log

Planning and design decisions were discussed with Claude in a separate session. Execution is done with Claude Code in this repo, guided by `CLAUDE.md`. Each entry has the prompt, what was produced and what I changed or rejected.

The entries below are from the Claude Code session.

## 1. Ground rules and first review of the brief
**Prompt:** Set the ground rules (push back, verify, ask when unclear, keep it simple). Read the brief and the stakeholder email thread, then report what we're building, the risks and what to push back on. No code yet.

**Claude produced:**
- A summary of the brief plus the 7 points the stakeholder had confirmed.
- Pushback:
  - The confirmed scope is much bigger than the brief, which says it is "not looking for the most complex system".
  - Suggested cutting Excel import, flat tax and the payroll run.
  - The justification for using USD was wrong. Salaries are contracted in local currency, so "the bank converts it" doesn't hold.
  - Three overlapping kinds of deduction, and "salary" wasn't defined.
  - The free-tier hosting and database choice depend on each other. Persistence on free tiers was flagged as something to verify.
  - Gaps: no auth, no employee lifecycle, no deadline.

## 2. What I accepted and rejected
**Accepted:**
- Immutable salary revisions with an effective date.
- Payroll calculated on the fly instead of stored as a process. This was later changed, see entry 3.
- Justify USD as a single currency for comparing pay across countries; local currency is out of scope.
- A single HR login.
- Serving the React build from the Rails app.

**Rejected:**
- Cutting import, tax and payroll. All 7 points stay, built in order of risk: employees + revisions + dashboard, then import, then tax, then payroll. Excel import stays because the core problem is that HR works in Excel.

**My own decisions:**
- Postgres, on an Oracle free VM with Docker, Caddy and DuckDNS.
- Synchronous import.
- The only export is the monthly payroll as Excel.
- An active/terminated status, with the dashboard counting only active employees.

## 3. Scope changes
**Prompt:** A series of clarifications while reviewing the requirements doc.
- No employee CRUD. Employees come from the seed script and import only, and the list is read-only. The only change allowed is termination, done with a date.
- Status is derived from `terminated_on` instead of being stored as a flag.
- Import keeps valid rows and reports the bad ones. It only creates employees and skips existing codes, so re-uploading is safe.
- Calculation is defined on annual amounts / 12. The one-time bonus is taxable. All deductions are taken after tax. Negative net pay is allowed and flagged (for recovering loans and advances).
- Payroll runs are stored, one per month (the month is a date and unique):
  - A new month creates a run.
  - The latest month is recalculated after a confirmation dialog.
  - Older months are locked.
  - No runs for future months.
- Proration by calendar days for people who join or leave mid-month. Proration by working days is out of scope because it needs holiday calendars.
- The payroll export includes the bank account number. The UI shows only its last 4 digits. Encryption at rest is out of scope.
- An employee's details can't be corrected after import (I chose a known limitation over allowing edits).

## 4. Catches during review
**Claude's catches that I accepted:**
- Payroll would include future hires. Added a check that `joined_on` is on or before the end of the month. I renamed `hired_on` to `joined_on`.
- `terminated_on` is defined as the last working day, so proration and the derived status agree.
- A new run must be for a later month than the latest run, to avoid creating runs that are locked from the start.
- Known limitations added:
  - a salary change mid-month applies to the whole month
  - a raise backdated into a locked month isn't paid as arrears automatically (I reworded this one)
  - the latest month can be recalculated after it's paid, with the confirmation dialog as the only safeguard

**My catches:**
- Snapshotting the salary and tax rate on payroll entries. Claude had proposed it earlier but dropped it when rewriting the doc.
- One-time adjustments are allowed only for open months.
- Termination rules: not before `joined_on`, not in a locked month, and it can't be undone.

## 5. Requirements doc committed
- Committed `docs/requirements.md` and `.gitignore` (which excludes `.private/`).
- Commit rules set: a single-line message with no trailers, the git identity set for this repo only, I review before every commit, and I push myself.

## 6. CLAUDE.md and this log
**Prompt:** Add a short CLAUDE.md that points to `docs/requirements.md` instead of copying the scope (covering ground rules, TDD, testing, Rails conventions, frontend and git rules), plus this log.

**Claude produced:** both files. It corrected the attribution I had given in entry 4.

**I changed:** the git rules. Conventional commits, one branch per piece of work, merge commits (not squash), and I push and open PRs myself.

## 7. PR skill
**Prompt:** Add a project skill so that saying "create PR" or "update PR" handles the PR:
- checks: not on main, a clean tree, tests passing
- pushes the branch
- creates the PR, or rewrites its description from all commits on the branch
- shows me the title and description for approval first
- never merges

**Claude produced:** `.claude/skills/pr/SKILL.md` and an updated git rule in CLAUDE.md. Claude kept the skill invocable by plain words rather than restricting it to `/pr`, and relied on the strict description plus the approval step to stop it running unprompted.

## 8. PR review skill
**Prompt:** Add a project skill that reviews a PR before merge like a strict senior engineer, without unnecessary noise. It checks scope, logic, tests, database, performance, security, API, frontend, code quality, commits and docs. It also runs the built-in `/security-review` and `/code-review`. It reports a verdict and findings, and never fixes, merges or comments.

**Claude produced:** `.claude/skills/pr-review/SKILL.md`, with these changes from my prompt:
- It refuses to start on a dirty tree, and switches back to the original branch when it's done.
- Business rules are read from `docs/requirements.md` instead of copied into the skill.
- "Heavy calculations in SQL" was narrowed to dashboard aggregates. Per-employee payroll math stays in a Ruby service with BigDecimal, as long as it's batched.
- Findings from the built-in reviews are deduplicated and verified before they're reported.

## 9. Build skill
**Prompt:** Add a project skill that every code change goes through:
- read the requirements and ask if anything is unclear
- reuse existing code (DRY, but no abstraction for a single use)
- show a plan and wait for approval
- branch from `origin/main`
- TDD, showing each spec fail for the right reason
- specs for every edge case
- commit meaningful working pieces, only after my ok
- add a log entry, then hand off to "create PR"

Also align the commit-granularity wording across CLAUDE.md and the review skill.

**Claude produced:** `.claude/skills/build/SKILL.md`, a workflow line in CLAUDE.md, and the wording fix. Additions to my prompt:
- Setup and infra work isn't covered by the requirements, so it's planned from CLAUDE.md and still needs approval.
- The plan has to flag anything needed outside the request.
- The working tree must be clean before branching.

## 10. Architecture doc
**Prompt:** Write `docs/architecture.md` with Mermaid diagrams, covering the system, data model, services, API, pages, flows and key decisions. Before writing, give opinions on three questions: department and job title as tables or strings, how to calculate the median, and anything hard to model.

**Claude answered:**
- Use strings for department and job title, and a table for country (because of the tax rate).
- Calculate the median with `percentile_cont` in Postgres, with no stored current salary, and check it with `EXPLAIN ANALYZE` after seeding.
- Eight modelling points, including:
  - use the revision in effect on the last day worked
  - round, then calculate net from the rounded values
  - unique `(employee_id, effective_on)`
  - derive locked months instead of storing a flag
  - a check that the payroll month is the 1st

**I decided:**
- Accepted all of the above.
- Added a rule that no revision can be effective after `terminated_on`.
- Payroll rules stay in Ruby with BigDecimal, and dashboard aggregates go in one SQL query object.
- `annual_gross` is a generated column, so it's defined in one place.

**I changed after reading the doc:**
- A future revision must not block termination. Claude had added that rule, but it would have left HR stuck with a revision they can't delete.
- Revisions need a reason.
- Removed the `one_time_adjustments` table. The bonus, deduction and note now live on payroll entries:
  - they're edited on the Payroll page, for the open month only
  - saving one recalculates only that entry
  - recalculating the month keeps HR's values
- Entries no longer copy the revision amounts or store taxable and days in the month, because those can be derived.
- The export has monthly gross and deductions (so the columns add up), plus days worked and the note.
- Recalculating only adds newly eligible employees. Claude pointed out that removing entries could never happen under our rules, and if it did run it would delete HR's bonus and note.
- An "Outdated" badge on the Payroll page when revisions, terminations, tax rates or imported employees changed after the last generation. Claude extended my idea (revisions and terminations) to also cover tax rates and imports, since both change the payroll too.
