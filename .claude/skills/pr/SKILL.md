---
name: pr
description: Push the current branch and create or update its GitHub PR against main. Use ONLY when the user explicitly says "create PR" or "update PR" (or runs /pr). Never use it on your own initiative, for example after a commit.
---

# PR

## 1. Checks (stop and tell me if any fail)
- The current branch is not `main`.
- `git status` is clean: nothing uncommitted and nothing untracked.
- Tests pass, using the test command from the Commands section of CLAUDE.md. If no test command exists yet, say so and continue.

## 2. Push
`git push -u origin <branch>`

## 3. Draft
- Read every commit on the branch: `git log main..HEAD`, plus the diff where needed.
- Check whether a PR already exists: `gh pr view --json number,title,body`.
- Write a title in conventional commit style (`type(scope): short message`).
- Write the description from scratch, covering all commits on the branch, using this template:

```
**What:** 1–2 lines on what this PR does.

**Changes**
- simple bullet points

**Why:** 1–2 lines.

**How to test** (only if there is something to test)
1. steps

**Notes** (only if there are limitations or follow-ups)
- ...
```

Keep it simple and non-technical. No long paragraphs, no file-by-file list, no AI or "Generated with" footer.

## 4. Approve
Show me the title and description. Don't create or update anything until I say ok.

## 5. Create or update
Pass the body through `--body-file -` with a heredoc, so the markdown isn't mangled by shell quoting.
- If there's no PR yet: `gh pr create --base main --title "<title>" --body-file -`
- If a PR exists: `gh pr edit <number> --title "<title>" --body-file -`

Then show me the PR URL.

## Never
- Merge the PR. I merge it myself with a merge commit.
- Force push.
