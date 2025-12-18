Load the most recent plan from `.claude/plans/` in this repo.

## Instructions

Run the latest-plan script:
```bash
~/.claude/scripts/latest-plan.sh $ARGUMENTS
```

- No arguments: loads the highest-numbered plan
- With argument: finds plans matching by number or name

After loading the plan, ask: "Ready to implement this plan?"
