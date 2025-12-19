# Session Handoff

Context is running low. Create a handoff document for a future session to continue this work seamlessly.

Write a file to `.claude/handoff.md` in this project containing:

## 1. Goal
What are we trying to accomplish? What did the user originally ask for?

## 2. Progress
- What's been completed so far?
- What files were created/modified?
- Key decisions made and why

## 3. Current State
- Where exactly did you stop?
- What were you in the middle of doing?
- Any partial work or uncommitted changes?

## 4. Remaining Work
- What still needs to be done?
- In what order?

## 5. Context
- Important file paths discovered
- Patterns or gotchas learned about this codebase
- Anything non-obvious that future-you needs to know

## 6. Blockers (if any)
- What's blocking progress?
- Questions that need answers?

---

After writing the handoff file, tell the user:
- The handoff file location
- That they should start a new session and reference it with: "Continue from .claude/handoff.md"
