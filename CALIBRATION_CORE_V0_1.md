# Impress Calibration Core v0.1 — public development contract

Status: prototype core + isolated tests; **no user-facing check-in, chart, or database persistence**.
Source: public \`feature/impress-calibration-v01\` branched from public \`feature/impress-v3-r04-2-build\`.
Do not change the private source repository during this phase. Do not publish actual personal logs, original private documents, keys, or Vault content.

## Product objective

Offer a low-friction **behavior feedback instrument**, not a clinical mood assessor, a game, or a promise that one number measures personal growth.

First pilot: a few user-configured recurring items such as sleep schedule, movement and eating plan. Work and learning are optional user-added tasks, not mandatory defaults. **Mood is an optional 1–5 observation**, not a behavior to reward/punish. Avoid claiming the factors are independent causes: sleep, movement, food and mood may affect each other.

## Data and scoring v0.1

- User selects the task(s) scheduled for each local civil day. A task list for a historical day must be a snapshot; editing a current template must not rewrite historical evaluations.
- Scheduled \`completed\` = +1; explicitly \`missed\` = -1.
- \`excused\` or planned rest = 0 and excluded from planned-task denominator.
- \`unrecorded\` = unknown; do not infer a failure, fill in a zero, or finalize the day.
- Explicit extras: at most one unscheduled +1 and one unscheduled -1 per day. Distinct event IDs must not overlap scheduled task IDs. Refrain from double-counting the same physical behavior even if IDs differ.
- Optional moodLevel (1..5) is observational and **never contributes to netScore**.
- \`dailyNet = completedCount - missedCount + extraScore\`. If no eligible event or some scheduled item is unrecorded, \`netScore = nil\` rather than a fabricated 0.
- \`taskBalance = (completedCount - missedCount)/(completedCount + missedCount)\`, only for a finalized day with scheduled tasks. Extras are deliberately excluded. This range [-1,+1] can help compare days with different task counts but is **not** a personal-worth or health score.

Example: sleep +1, exercise -1, food +1, explicitly unplanned snack -1 -> dailyNet 0. Mood 2/5 remains an independent observation. If the snack was already the reason for marking the scheduled food task missed, do not deduct it again.

## Time series

- X = **local civil day** (YYYY-MM-DD). The caller is responsible for using the user's local day when recording; the core treats these IDs as calendar dates rather than UTC instants.
- Daily chart Y = dailyNet. A missing or partially recorded day is a gap, not 0.
- Second daily curve = average of finalized scores in the **trailing seven calendar days**. It does not pretend that missing days were -1 or 0.
- Week = daily points for the last 7 calendar days; month = daily points over the selected date range; year = monthly **average daily netScore**, not an accumulating total.
- Changing the number of scheduled tasks changes the range of raw dailyNet. Show planned count and/or compare the separate taskBalance when interpreting historical changes. Do not automatically compare raw sums from radically different plans.
- Mood comparisons, if ever implemented, are observational correlations, not causal conclusions.

## Delivery boundary

Implemented: deterministic Foundation-only scoring, validation and trends; portable XCTest cases for ±1, extras, omissions, mood, duplicates, rest, calendar-date windows and monthly aggregation.

**Not implemented:** task-plan editor, persisted daily records, WCDB migration, notifications, chart UI, AI interpretation, integrations with Health or Obsidian, and migration to the private repository.

Keep the calibration model independent from FSRS scheduling and review ratings; do not modify review cadence, card types, Vault source files, credentials or the validated R04.2 look-and-feel. The pure calculator lives in the existing portable Swift package to reuse its test harness, but its types do not depend on flashcard contracts.

## Release checks before UI integration

1. Run the full public Swift core test suite, and iOS simulator tests where CI permits. Isolated Linux Swift tests alone do not validate the full iPhone application.
2. Confirm a no-record day stays unknown, not negative; rest and mood never auto-deduct.
3. Confirm a planned-task edit does not rewrite an older day's score once persistence is added.
4. Confirm manual extras cannot silently duplicate a scored scheduled behavior.
5. Re-review trend comparability before the first user-visible Y-axis is finalized.
6. Keep all actual user scores and journal text on device, never in source-control test fixtures.
