---
name: build
description: The required workflow for every code change in this repo, whether a feature, fix, refactor, migration, spec or setup. Use it before writing or editing any code, even small changes and even if the user doesn't name the skill. It covers requirements, reuse, plan approval, branch, TDD, edge-case specs, and approved commits.
---

# Build

Work so I can trust each step without re-checking it. That means requirements first, the smallest correct change, and tests that actually prove the behaviour.

## 1. Understand
- Read `docs/requirements.md` and `CLAUDE.md` for the parts this change touches.
- If anything is unclear, missing or contradictory in the requirements, stop and ask me. Don't fill gaps with assumptions; a wrong guess in payroll logic is expensive to undo.
- Setup or infra work (gems, config, deploy) isn't covered by the requirements. Plan it from CLAUDE.md and the brief, and still get my ok.

## 2. Look for existing code
Before writing anything, search for a model, service, scope, validation, factory, shared example or component that already does part of the job. Reuse or extend it rather than duplicating it.
- Don't extract a shared abstraction for a single use. Wait until there's a second real caller.

## 3. Plan and wait for approval
Show me a short plan:
- Models, services, endpoints and screens touched
- Existing code you'll reuse
- Any migration (tables, columns, constraints, indexes)
- The edge cases you'll write specs for
- Anything needed that I didn't ask for. Flag it, don't build it.

Don't write code until I say ok.

## 4. Branch
- `git status` must be clean.
- Run `git fetch origin`. If you're already on the right branch for this work, continue there. Otherwise run `git switch -c <prefix>/<short-name> --no-track origin/main`, so the new branch doesn't track `main`. Use a prefix that matches the commit type: `feat/`, `fix/`, `refactor/`, `test/`, `chore/`, `docs/`, `ci/` or `build/`.

## 5. TDD, one behaviour at a time
1. Write the failing spec.
2. Run it and show that it fails for the right reason (a missing method or wrong value, not a typo or load error). A spec that fails for the wrong reason proves nothing.
3. Write the minimal code to make it pass.
4. Refactor, then run the full suite.

Edge cases from the requirements need their own specs wherever they apply: month end, Feb in a leap year, joining or leaving on the 1st or the last day, negative net, locked months, nil or empty data.

## 6. Commit
- Commit when a meaningful piece is working, e.g. a model with its validations, or a service with its specs. Don't commit after every small step. Each commit should be a meaningful working piece.
- Before committing:
  - run the full suite
  - run rubocop and eslint if they're set up
  - show me the diff and a single-line conventional message, with no trailer
- Commit only after I say ok.

## 7. Finish
- Update the CLAUDE.md commands section or the docs if they've changed.
- Add an entry to `docs/ai-prompts.md`: my prompt in short, what you did, and what I changed or rejected.
- Tell me it's ready for "create PR".

## Rules
- Build only what I asked for. If something else is needed, tell me instead of doing it.
- Don't add a gem without asking.
- If a test is hard to write, tell me. Don't skip it or write a weaker one.
- Don't change existing specs just to make them pass. If a change really is needed, explain why first.
