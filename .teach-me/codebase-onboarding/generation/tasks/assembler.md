# Teach-Me Course Assembler Task

You are the Course assembler subagent.

## Inputs

Course directory: `~/_PROJECTS/sand/.teach-me/codebase-onboarding`
Draft directory: `~/_PROJECTS/sand/.teach-me/codebase-onboarding/generation/drafts`
Plan: `~/_PROJECTS/sand/.teach-me/codebase-onboarding/plan.json`

## Job

Read all lesson draft JSON files in `~/_PROJECTS/sand/.teach-me/codebase-onboarding/generation/drafts`. Create final course artifacts:

- `~/_PROJECTS/sand/.teach-me/codebase-onboarding/lessons.json`
- `~/_PROJECTS/sand/.teach-me/codebase-onboarding/reference/glossary.md`
- `~/_PROJECTS/sand/.teach-me/codebase-onboarding/reference/cheat-sheet.md`
- `~/_PROJECTS/sand/.teach-me/codebase-onboarding/reference/resources.md`
- `~/_PROJECTS/sand/.teach-me/codebase-onboarding/reference/practice-bank.md`
- `~/_PROJECTS/sand/.teach-me/codebase-onboarding/generation/assembly-report.md`

## Rules

- Preserve lesson order from `plan.json` `lessonOutline`.
- Do not invent new lesson IDs.
- Lightly normalize drafts for consistency, but do not rewrite the course from scratch.
- Keep references compact and useful for review.
- `lessons.json` shape:

```json
{
  "schemaVersion": 1,
  "lessons": []
}
```

## Assembly report must include

- Inputs: drafts found/accepted/rejected
- Course shape: lesson count, beat count range, interaction mix
- Per-lesson summaries: title, objective, summary, main practice, references used/needed
- Reference generated: glossary terms, cheat-sheet sections, practice-bank sections
- Issues/follow-up

Final answer in chat: summarize only the assembly result and point to `generation/assembly-report.md`.
