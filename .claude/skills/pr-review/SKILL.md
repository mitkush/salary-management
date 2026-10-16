---
name: pr-review
description: Review a GitHub PR before merge, the way a strict senior engineer on a good team would. Use ONLY when the user explicitly asks, e.g. "review PR" (current branch's PR) or "review PR 3". It only reports findings. It never fixes, merges or comments on GitHub.
---

# PR Review

You're the last check before the user merges. Be strict, but every point must be worth their time. A short review with real issues beats a long one full of noise.

## Setup
1. `git status` must be clean. If it isn't, stop and tell me, because checking out would mix my work into the review.
2. Note the current branch so you can return to it at the end.
3. Run `git fetch origin`. With a number, run `gh pr checkout <n>`. Without one, use the PR for the current branch (`gh pr view`).
4. Compare against `origin/main`, not local `main`, because local `main` can be stale:
   - `git log origin/main..HEAD` for the commits
   - `git diff origin/main...HEAD` for the changes
5. Read `docs/requirements.md` and `CLAUDE.md`. They are the source of truth for scope and rules, so don't rely on memory.

## What to check
Only check what the diff touches. Skip any area the PR doesn't change.

1. **Scope:** Do the changes match `docs/requirements.md`? Flag anything extra, anything missing for the feature, or anything that breaks a rule there (e.g. editing an immutable revision, writing to a locked month).
2. **Logic:** Check payroll, proration, tax, rounding and locked months against the formulas in the requirements. Try edge cases: month end, Feb in a leap year, joining or leaving on the 1st or the last day, nil values, empty data, negative net, the first run ever, recalculating the latest month.
3. **Tests:** Does every `feat`/`fix` have specs? Do they test behaviour, not implementation? Are edge cases covered? Are they fast and deterministic, with time frozen and no random values in assertions? Run the full suite using the test command in CLAUDE.md.
4. **Database:**
   - Migrations are reversible.
   - `NOT NULL`, foreign keys and unique indexes are in place where needed.
   - Filter columns are indexed.
   - Money is `decimal`, never `float`.
5. **Performance:**
   - No N+1 queries.
   - Never load all 10k rows into memory; batch them or aggregate in SQL.
   - Lists are paginated on the server.
   - Dashboard aggregates belong in SQL. Per-employee payroll math in a Ruby service with `BigDecimal` is fine if it's batched.
6. **Security:**
   - Strong params.
   - Auth on every endpoint.
   - No secrets in the code.
   - Bank account numbers are masked in every API response except the payroll export.
   - Excel uploads are handled safely: file type and size checked, and nothing executed or written to a user-controlled path.
7. **API:** Correct status codes, one error format everywhere, and clear validation messages.
8. **Frontend** (only if changed): Loading, empty and error states exist. No business logic or calculations in the UI.
9. **Code quality:**
   - Thin controllers, with logic in services.
   - Clear names.
   - No dead or duplicated code.
   - Run rubocop and oxlint (`npm --prefix frontend run lint`), and report only what fails.
10. **Commits:** Conventional format on a single line, no trailers, each commit a meaningful working piece. Tests pass before every commit, except a `test:` commit with failing specs that the very next `feat:`/`fix:` commit makes pass. Flag any red commit that isn't such a `test:` commit.
11. **Docs:** Does `docs/requirements.md`, the CLAUDE.md commands section, the README or `docs/ai-prompts.md` need updating?
12. **Built-in reviews:** Run `/security-review`, then `/code-review` on the PR. Merge their findings into yours, drop duplicates, and verify each one before keeping it. If every changed file is `.md` (a docs-only PR), skip both and say so under **Tests**, with the reason: `/security-review` excludes Markdown and `/code-review` targets code bugs.

## Rules for findings
- Report only real issues. Each one needs `file:line` and a short example of what goes wrong, e.g. "joined_on = 2028-02-29 → proration factor 1/28 instead of 1/29".
- If you aren't sure, list it under Questions. Don't state it as a fact.
- No style nitpicks that rubocop or oxlint already catch.

## Output
Use simple points, in this order:

**Verdict:** ready to merge / merge after fixes / not ready

**Blockers**
- ...

**Should fix**
- ...

**Nits** (optional)
- ...

**Questions**
- ...

**Good**
- 1–2 points

**Tests:** pass/fail counts, plus any failures, rubocop/oxlint results and anything that couldn't run (e.g. no test command yet)

Leave out empty sections.

## Finish
Switch back to the branch you started on.

## Never
- Fix or change any code.
- Commit, push or merge.
- Comment on or approve the PR on GitHub, unless I ask.
