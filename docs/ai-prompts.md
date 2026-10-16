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

## 11. Fixes from the PR 2 review
**Prompt:** Fix the four findings from `review PR 2`, and let the review skill skip the built-in reviews on docs-only PRs.

**Claude produced:**
- A new payroll run must be exactly the month after the latest run (the first run can be any month that isn't in the future), so a month can't be skipped and left unpaid.
- Bank account numbers are masked in payroll entries too. The full number appears only in the export.
- "Active" now requires `joined_on <= today`, so future joiners don't inflate the headcount.
- Import accepts only `.xlsx` files up to 5 MB.
- The review skill skips `/security-review` and `/code-review` when every changed file is `.md`, and says so in the result.

**I changed:** nothing. I accepted all four findings as reported, and specified the 5 MB limit.

## 12. Rails setup
**Prompt:** Set up the app through the build skill:
- Ruby 3.4.11 and Rails 8.1.4, installed only under 3.4.11
- React with plain Vite in `frontend/` and Ant Design
- RSpec and factory_bot
- Docker from the start: `docker compose up` gives a migrated, seeded app, and `docker compose run --rm test` runs the suite
- GitHub Actions with separate backend, frontend and docker jobs

**Claude produced:**
- A setup plan with every `rails new` flag checked against `--help` before running it. Skipped: minitest, jbuilder, Hotwire, the asset pipeline, mailers, Cable, Active Storage, Solid, Kamal and Thruster.
- The Rails app, RSpec, and a fallback route that serves the React build for every page path outside `/api`, written test-first.
- A Dockerfile with a Node stage for the frontend build and a `test` stage; force-SSL, assume-SSL and allowed hosts read from environment variables; and a compose file with a clearly labelled local-only secret.
- The CI workflow, with action versions checked against GitHub.
- Problems caught along the way:
  - `rails new --force` dropped `.private/` from `.gitignore`
  - `.private/` was missing from `.dockerignore`, so the private brief would have been sent to Docker builds
  - the image build failed because `.ruby-version` wasn't copied before `bundle install`
  - CI's schema check needed the baseline `db/schema.rb` committed
  - the current Vite template uses oxlint, not ESLint

**I changed:**
- Ruby 3.4.11 instead of the installed 3.4.8, and Node 24 LTS everywhere, with `.nvmrc`.
- Docker moved into the setup instead of waiting for deployment.
- Keep oxlint.
- Remove unused files: PWA views and routes, `app/assets`, the layout, the Rails icons and the `@types` packages.
- The `/api` route check: plain `start_with?("/api")` would also have excluded paths like `/apiary`. It now matches only `/api` or `/api/...`, with a spec for each.

## 13. HR login
**Prompt:**
- Use the Rails 8 auth generator, without password reset, the mailer or HTML views. Login comes from React.
- JSON login and logout. Every `/api` endpoint needs login and returns 401 in our error format; the React page and `/up` stay open.
- An httponly cookie, CSRF protection, a login rate limit, and a seeded HR user from environment variables.
- A simple Ant Design login page, and Logout.
- Built test-first.

**Claude produced:**
- A plan based on the generator's actual templates:
  - **Trimmed from the generator:** password reset and HTML views. Without Action Mailer, the generated `PasswordsController` would have been broken anyway.
  - **Where login is required:** the `Authentication` concern goes only in `Api::BaseController`, so the React page and `/up` stay open.
  - **Login check after refresh:** `GET /api/session` returns the login status and a CSRF token, and React calls it on load.
  - **CSRF:** Rails' built-in protection, with the token sent as an `X-CSRF-Token` header and rotated by resetting the session on login.
  - **Rate limit:** a dedicated memory store, because the test cache counts nothing and a spec could never trigger the limit.
- Specs for:
  - login success and failure
  - identical errors for a wrong password and an unknown email
  - the cookie flags and 1-day expiry
  - logout
  - 401
  - CSRF and token rotation
  - the rate limit
  - the seed
- An end-to-end check with curl against a real server with CSRF protection on.
- The React login page, the layout with Logout, and a `fetch` wrapper that adds the CSRF token and returns to login on 401. No new packages.
- Checks along the way:
  - **Session expiry:** Rails already rejects expired signed cookies on the server, so an extra `created_at` session filter wasn't needed.
  - **Rate-limit spec:** with only the `rate_limit` line removed, it failed with 200 instead of 429, so it tests the limit and not just the store.

**I changed:**
- **Cookie expiry:** 1 day instead of Claude's suggested 2 weeks, because this is salary data.
- **Login errors:** a wrong password and an unknown email must give exactly the same error, checked in a spec.
- **Following TDD:** Claude first wrote all the controller code for the specs in one go. I asked for real TDD, so the code was rebuilt one behaviour at a time, with each spec shown failing for the right reason first.
- **Commit pairs:** failing specs are committed first as `test:`, then the code as `feat:`, one pair per meaningful piece. "Tests pass before every commit" now has an exception for those `test:` commits.
- **Expiry spec:** made stricter, so it sends the expired cookie back by hand and proves the server rejects it.
- **Deploy:** I'll set my own `HR_PASSWORD` on the VM.

## 14. Fixes from the PR 4 review
**Prompt:** Fix the review findings: logout should return a new CSRF token (failing spec first), clear the rate-limit store before every spec and check with random seeds, keep HR logged in and show the error when logout fails, and add a `WEB_CONCURRENCY` deploy note.

**Claude produced:**
- **Flaky suite fixed:** the rate-limit store is now cleared before every spec. Before, 7 of 60 random orders failed; after, 0 of 60 fail, and the 7 previously failing seeds pass on the full suite.
- **Logout:** it now returns `200 { csrf_token }`.
  - **Specs first:** the two logout specs changed from 204 to 200, and a new spec covers logging back in from the same tab. All three failed before the fix.
  - **Why:** without this, logging back in after logout in the same tab failed with 422 until a refresh. The review skill's `/code-review` step found this.
- **Failed logout:** the app now shows the error and keeps HR logged in, instead of showing the login page while the server session was still valid.
- **Deploy checklist:** leave `WEB_CONCURRENCY` unset, because the rate limit is counted per process.

**I changed:** nothing. I accepted all four. I skipped cleaning up expired session rows for now.

## 15. Employees and salary revisions (backend)
**Prompt:**
- Build employees and salary revisions, plus a 10k seed with realistic data (countries with tax rates, departments, job titles, salary ranges, some employees with 2–3 revisions, a few leavers and a few future joiners).
- The seed lives in its own file with its own spec, uses a fixed random seed, and inserts quickly.
- Check the median query with `EXPLAIN ANALYZE`.
- Ask before adding any package.
- Split the work into two stacked PRs, backend and frontend.

**Claude produced:**
- A plan with the decisions I needed to make:
  - **Packages:** `react-router` for the frontend; pagination done by hand instead of the `pagy` gem
  - **Statuses:** `active`, `upcoming` and `terminated`
  - **Termination:** the locked-month check deferred to the payroll feature
  - **Seed dates:** calculated from today
- **TDD pairs for:** countries, employees (status at each date boundary, masking, `terminate!`), salary revisions (date rules, reasons, no updates after saving, database-generated `annual_gross`, "never applied" revisions), the seeder, the list API and the detail/revision/termination APIs.
- **Seeder:** 10,000 employees and about 15,000 revisions in about 2 seconds, using bulk inserts. The same random seed gives identical data, which is checked in the spec.
- **Median query:** 9 ms under `EXPLAIN ANALYZE` (28 ms before Postgres refreshed its statistics), using the existing unique index.
- **Checks along the way:**
  - The "same number of queries" spec was green before the route existed. Loading each employee's salary separately made it fail (30 queries instead of 10), so it does catch N+1 queries.
  - A request missing its parameters returned 400 as HTML. Claude added a test/fix pair so it now uses our JSON error format.
  - Confirmed that Rails 8.1 returns the generated `annual_gross` straight after insert.

**Claude's slip:** it committed every test/feat pair without showing me the diff and waiting for my ok, which the build skill requires, because I had only approved the plan. Claude told me before opening the PR. I reviewed the commits and kept them; from then on, Claude stops before each commit.

**I changed:**
- Statuses: approved `upcoming` and documented it in the requirements.
- Termination: the locked-month check is noted as a follow-up for payroll.
- Two stacked PRs instead of one.

## 16. Employees and salary revisions (frontend) and the schema mismatch
**Prompt:** Build the employee list and detail pages with `react-router` and server-side pagination, as a second PR stacked on the backend PR.

**Claude produced:**
- **Routing:** `react-router` 8.4. I checked its exports before using it.
- **Employee list:**
  - search, filters and pagination, all kept in the URL
  - a search box that waits 300 ms after you stop typing
  - loading, empty and error states
- **Employee detail:**
  - details, and the revision history with a "Never applied" tag
  - an "Add revision" modal with a note that revisions can't be edited after saving, only replaced by a new one
  - a "Terminate" modal that warns it can't be undone
  - errors from the API (422) shown under the matching form fields
- **Bugs Claude found in its own diffs before committing:**
  - the Back button after a search put the old search back into the URL
  - changing a filter reset the page size
  - switching from one employee to another briefly showed the previous employee
- **Lint:** oxlint flagged setting state directly inside an effect, so the loading state is now derived from the data instead.
- **Schema mismatch on PR 5:**
  - **What happened:** CI's schema check failed because my local database printed the `reason` check constraint differently from a database built fresh from the migrations, on the same Postgres 16.15. The rule itself was identical.
  - **What was ruled out:** Claude checked my suggested cause (a migration edited after it ran) and its own guess (the text changes when `schema.rb` is loaded and dumped again), and both were wrong. **The real cause wasn't found.**
  - **Fix:** rebuild the databases from the migrations and commit the regenerated `schema.rb`.

**I changed:**
- Asked for the note in the "Add revision" modal that revisions can't be edited after saving.
- The `initial` reason stays available only through the API, used by the seed and the import, by choice. HR picks increment, promotion, correction or other in the UI.
- I checked all scenarios in the browser myself.

## 17. Fixes from the PR 5 review
**Prompt:** Fix the four should-fix items and the nit from `review PR 5`, test-first. Cap amounts at 1,000,000,000. For two requests racing to save a revision, add a known limitation instead of a database lock.

**Claude produced:** a test/fix pair for each item. Each spec was seen failing for the right reason first.
- **Backdated termination:** with one, the current salary showed a raise that never applied. The lookup now stops at the last working day.
- **Huge amounts:** these crashed with a 500 (`RangeError`). Each amount is now capped at 1,000,000,000, so the database-generated `annual_gross` always fits.
- **Malformed list parameters:** an array search, an array page or a huge page number crashed. They now fall back to the defaults, and the page number is capped.
- **Duplicate revision date:** two requests saving the same date at once gave a 500 instead of a 422. The spec simulates the race by skipping the duplicate-date check in Ruby, so the database's unique index rejects the second save.
- **`terminate!`:** it kept the errors from a failed attempt, so a later valid call still failed. It now clears them first.
- **How the findings were found:** the review skill's `/code-review` step found the backdated-termination bug and the race. Claude's throwaway specs reproduced every finding before it was reported.

**I changed:** nothing. I accepted all five, chose the 1,000,000,000 cap, and chose a known limitation over a database lock for the race.

## 18. Fixes from the PR 6/8 review, and the first frontend tests
**Prompt:** Fix the three should-fix bugs and the nit from the PR 6 review on PR 8, which has the same commits but targets `main`. Work test-first. Resolve the `ai-prompts.md` conflict by merging `main` into the branch with a merge commit, without a force-push.

**Claude raised:** the frontend had no test framework, so test-first wasn't possible without new packages. It asked before adding any.

**I decided:** add Vitest, but keep it tight. The buggy search/URL logic moves into plain functions tested with Vitest and no DOM. Testing Library is used only for the network-error case in the modals, because that depends on component state. Setup goes in one chore commit, and `npm test` is added to the CI frontend job.

**Claude produced:**
- **Setup:** `vitest`, `@testing-library/react`, `@testing-library/dom` (a required peer) and `jsdom`, all dev-only. `npm test` passes when there are no test files, so the setup commit isn't red.
- **Search pair:** `searchState.js` with a delayed search that reads the current URL when it fires and drops itself if Back changed the search in the meantime. The search box's text is now recorded as belonging to the search it wrote.
  - These tests failed only because the module didn't exist yet, since the bugs lived in the page's wiring. That's a weaker red than usual.
- **Modal pair:** `formErrorUpdate` returns a "couldn't reach the server" message for network failures, and shows the API's message when an error matches no field on the form.
  - The two Testing Library tests failed on the real bug: `TypeError: err.fieldErrors is not a function`, as an unhandled rejection.
  - Before that, they had failed for the wrong reason, because jsdom has no `ResizeObserver`. A stub fixed the test setup.
- **Lint:** oxlint flagged a ref read during render (a false alarm). The debouncer is now created in the event handler instead.
- The review skill's `/code-review` step found all three bugs. Claude confirmed the stale-URL one in react-router 8.4's source.

## 19. Dashboard
**Prompt:** Build the insights dashboard. I decided:
- use `@ant-design/charts` for a donut chart of cost by country or department, with the total in the centre, tooltips showing name, value and percent, and a switch between the two views
- `/` goes to the dashboard
- the median is rounded to cents in SQL

**Claude produced:**
- **`SalaryStatsQuery`:** one SQL query over active employees' current salary, built on the existing `current_for` and status scopes.
  - **Numbers:** headcount, total, min, max, average and median (`percentile_cont`), with an optional grouping.
  - **Share:** each group's share of the total cost is calculated in SQL (a window function), so the UI doesn't calculate it.
- **`GET /api/insights`:** returns 400 for an unknown `group_by`.
- **Dashboard page:**
  - six stat cards and the donut
  - shared filters (extracted from the employee list, now that two pages use them)
  - lazy-loaded
- **Pushback and checks:**
  - **New package:** `@ant-design/charts` wasn't in our stack yet; it's a new package.
  - **Brakeman:** it flagged a possible SQL injection in a hand-built SQL string. The query was rewritten with ActiveRecord `from`/`group`/`pluck`, so no warning needed to be ignored.
  - **Validation:** a broad `rescue ArgumentError` was replaced by checking `group_by` up front.
  - **Bundle size:** the chart library took the JS bundle from 462 kB to 2.7 MB. Importing from `@ant-design/plots` measured the same. Lazy loading brings everything except the dashboard to about 1.2 MB.
- **On the 10k seed:** the median is $76,339.42, matching the earlier `EXPLAIN` check. The summary query takes 77 ms on its first run and the breakdown 22 ms.

**Follow-ups:** split the shared chart code out of the main bundle.

## 20. Excel import
**Prompt:** Import employees from `.xlsx`, synchronously, with row-by-row validation.
- **File checks:** only `.xlsx` up to 5 MB, rejected with 422 before parsing.
- **Rows:** country by code or name; department and job title trimmed; an existing code is skipped; failed rows come back with their reasons; each new employee gets an initial revision on `joined_on`.
- **Frontend:** an import page with the results. I later added a "Download template" button.

**Decided in the plan:**
- `roo` to read the files.
- `caxlsx` to build the test files and the template.
- An existing code with identical details is **skipped**, while one with different details **fails**, since import never updates.
- Country matching ignores capitalisation.
- A repeated code in the same file fails.

**Claude produced:**
- **`Employees::Importer`:** it reuses the `Employee` and `SalaryRevision` validations for each row, so the amount cap and the date rules apply here too, and saves valid rows in bulk.
- **File checks:** `.xlsx` is confirmed by both the extension and the zip signature. Specs check that too-big and wrong-type files are rejected before `roo` reads them.
- **Template endpoint, the import page, and `FormData` support in `api.js`** (test-first).
- **Performance:** 10,000 rows took 9.5 s at first, because of 30,022 queries (3 per row: two uniqueness checks and loading the country). Claude skipped the uniqueness validators, which the importer already covers, and passed preloaded countries instead of ids. That brought it down to 22 queries and 3.8 s, of which reading the file is 1.7 s.
- **Upload size:** Rails only checks the 5 MB limit after the whole upload has arrived, so a Caddy body limit is in the deploy checklist.
- **Review fixes (PR 10), test-first:**
  - Each import batch is saved in one transaction, so employees can't be left without their first revision.
  - The template formats `employee_code` and `bank_account_number` as text. Excel keeps only 15 significant digits for numbers, which would silently change long account numbers.
  - I kept the other two review findings (a duplicate-code race and the template link when logged out) as known limitations, since there's a single user.

## 21. Tax rates
**Prompt:** A countries page where HR edits each country's flat tax rate.
- The rate is stored as 0–1 but shown and entered as a percent, from 0 to 100 with at most 2 decimals.
- Errors appear under the field, with a success message after saving.
- Test-first, kept simple for payroll.

**Decided in the plan:** the API works in percent (`tax_rate_percent`) and converts on the server, so the conversion and its error messages live in one place and the UI does no maths. A percent with more than 2 decimals is rejected, not rounded.

**Claude produced:**
- `Country#tax_rate_percent` reader and writer, with errors for blank, not a number, out of range and too many decimals. An invalid value leaves the stored rate unchanged.
- `GET` and `PATCH /api/countries`: only the rate can be changed, and the code and name are ignored.
- The Countries page, with an edit modal and a success message, reusing `formErrorUpdate`.
- Each piece in test/feat pairs. Two API specs ("404 for an unknown country" and "only changes the tax rate") already passed before the route existed. They check real behaviour once it does.

## 22. Payroll (backend)
**Prompt:** The payroll backend, following the requirements and the architecture doc:
- generate and recalculate runs, with locked months and proration
- edit an entry's bonus, deduction and note
- the outdated flag and the Excel export
- the termination check against locked months that was left as a follow-up
- specs for every edge case

Split into two PRs (not stacked), backend first.

**Decided in the plan:**
- Bonus and one-time deduction are capped at 1,000,000,000.
- A badly formatted month returns 400.
- An empty month gives an empty run.
- `upsert_all` with `update_only` is checked by a spec before relying on it.

**Claude produced, test-first pairs:**
- **`Payroll::EntryCalculator`:**
  - **Proration:** full month, joining or leaving on the 1st or the last day, joining and leaving in the same month, February 2028 (leap year) and 2027.
  - **Money:** rounding half up, a taxed bonus, deductions after tax, negative net, and a 0% rate.
  - **Half-up rounding** is pinned by `0.105 → 0.11` and `10.005 → 10.01`, which banker's rounding would get wrong.
- **`PayrollRun` and `PayrollEntry`**, with database checks.
- **`Payroll::Generator`:**
  - the month rules (first run, next month only, future, skipped and locked months)
  - who is eligible, and the revision in effect on the last day worked (reusing `current_for` with `on: month end`)
  - a snapshot of each tax rate
  - recalculation that keeps HR's values, adds newly eligible employees and never deletes
- **The rest:** `outdated?`, `PayrollEntry#adjust!` (recalculates tax and net for that entry only), the locked-month check on termination, the API and `Payroll::Exporter`.

**Caught along the way:**
- **Export order:** `find_each` silently ignored the sort by employee code. Claude added a sort spec, showed it failing with `find_each` (EMP00001, EMP00003, EMP00002), and switched to one ordered `pluck`.
- **A flaky import spec from PR 10:** the helper didn't keep the temp file alive, so garbage collection could delete it before it was read. Fixed in its own `test:` commit.

**Performance on the 10k seed:** generating 9,329 entries took 1.3 s, recalculating 1.1 s, and exporting 0.7 s.
- **Review fixes (PR 12), test-first:**
  - A month generated twice at the same moment now returns 409 instead of 500.
  - The first payroll run must be for the current or the previous month, so HR can't accidentally start years back and then have to generate every month since.
  - Specs that made their first run further back were changed to match the new rule, not just to make them pass. The earlier runs are now created directly.

## 23. Payroll page
**Prompt:** The payroll page:
- a month picker and "Generate payroll" (disabled while it runs; asks to confirm before recalculating an existing month)
- the runs list with locked and outdated tags, and the "please recalculate" message for the open month
- a paginated entries table with a masked bank account and negative net in red
- an adjustment modal for the open month, with read-only locked months
- totals from the API, not calculated in the UI
- an Excel export downloaded with `fetch` so a 401 goes to login
- clear 409 messages, Vitest for any logic, and no new package

**Claude flagged:** the API had no month totals, so they were added to the runs endpoint first, as a backend test/feat pair summed in SQL. Gross means monthly gross before bonuses.

**I decided:** also use the new `download()` for the Import page's "Download template", which removes that known limitation.

**Claude produced, test-first where there's logic:**
- **Run totals** on `GET /api/payroll_runs` and the generate response.
- **`download()` in `api.js`,** sharing the 401 and error handling with `api()`. It returns the file and the filename from `Content-Disposition`. Tests cover success, 401 going to login, and 404.
- **Month helpers** `toMonthParam`, `monthLabel` and `findRun`, with tests.
- **The Payroll page and adjustment modal.** Entries come back from the API after each change, and 409/400 messages appear as an alert with the server's text.
- **A spec that first failed for the wrong reason:** a factory employee code collided with a fixed `EMP00001`. Fixed in the spec before committing.

## 24. UI fixes
**Prompt:** Remove the white gap around the page. Filters can't be cleared once selected, so add `allowClear`.

**Claude pushed back:** `allowClear` was already on every filter. When asked, I confirmed no clear icon appears at all. Claude couldn't reproduce why without a browser, so it added a visible "Clear filters" button instead of guessing.

**Claude produced:**
- `body { margin: 0 }` in `index.html`.
- `clearFilters` and `hasFilters` (test-first). They keep the page size and the dashboard view.
- A "Clear filters" button on the employee list and the dashboard. It shows only when a filter is set, and on the employee list it also cancels a pending delayed search.

## 25. Dashboard as of a month, with trends
**Prompt:** The dashboard gets a month picker:
- data is shown as of that month's end, defaulting to the previous month, reusing the status and revision-on-date logic
- a 12-month column chart of salary cost and a 12-month line chart of joiners against leavers
- the donut stays, and nothing is calculated in the UI

**I decided:**
- Monthly cost is annual gross / 12.
- The current month is allowed and uses today, not its month end, while future months return 400.

**Claude produced, test-first pairs:**
- `Employee.with_status(…, on:)` and `SalaryStatsQuery(as_of:)`, both reusing `current_for(on:)`. Specs cover joining or leaving on the month end and a raise after it.
- `SalaryTrendsQuery`: 12 month-end points, each using the stats query (352 ms on the 10k seed), plus joiners and leavers grouped in SQL.
- An `as_of` parameter on `/api/insights` and a new `/api/insights/trends`. Month parsing moved into a shared `Api::MonthParam` (a refactor).
- A frontend fix: the URL helpers dropped `as_of` when filters changed. It's now kept (test-first).
- The month picker, the "As of" date from the API, and the column and line charts.

**Spec changes:** the existing spec that checks the exact insights response now includes the new `as_of` field, a deliberate change to the response format.
- **Follow-up fixes in the same PR:**
  - **Cards:** "Annual salary cost", plus a new "Monthly salary cost" card. The monthly figure is an API `monthly_cost` computed in SQL, which the trends query now reuses (test-first).
  - **Month selector:** a select of the last 24 months showing "Sep 2026". It replaces the date picker, which would have needed `dayjs` as a new direct package.
  - **Headcount tooltip:** explains that payroll also includes leavers who worked part of the month.
  - **Donut:** percentages from the API's `share`.
  - **Layout:** the donut and the column chart side by side, the line chart below.
  - **Description:** a shorter line.

## 26. Deployment
**Done by me on the Oracle VM, outside this Claude Code session.** Claude only recorded it here and updated the docs.

**What happened:**
- **VM shape:** the Always Free ARM shape (Ampere A1) was out of capacity, so the app runs on the AMD `VM.Standard.E2.1.Micro` (1 GB of RAM, plus 2 GB of swap added).
- **Firewall:** the iptables rules opening ports 80 and 443 were first added *after* the image's default `REJECT` rule, so they never matched and the site was unreachable. Moving them before the `REJECT` rule fixed it.
- **Image:** the Docker image is built locally for `linux/amd64` and loaded onto the VM (`docker save` / `docker load`). The 1 GB VM doesn't have to build it, which matches the deploy plan in the architecture doc.
- **HTTPS:** Caddy provides it automatically for the DuckDNS domain `sal-mgnt.duckdns.org`.
- **Secrets:** `SECRET_KEY_BASE`, `HR_EMAIL`, `HR_PASSWORD`, `RAILS_HOSTS` and the database password are in `.env` on the VM. The live login is shared with the reviewer separately.

**Earlier checks that mattered here:**
- The planning stage had flagged that free ARM capacity on Oracle is often unavailable, which is what happened.
- The deploy checklist built up across the PRs (own `SECRET_KEY_BASE`, `RAILS_HOSTS`, `HR_PASSWORD`, Caddy upload limit, a single Puma process) was followed and marked done.
