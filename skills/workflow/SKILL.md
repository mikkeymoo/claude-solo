---
name: workflow
description: "Execution mode selector — choose autopilot, parallel waves, strict TDD, or rapid quick mode. Use when deciding how to approach a sprint."
argument-hint: "[--auto [description] | --parallel | --tdd | --quick [task]]"
---

# /workflow — Execution Mode

- `--auto` — full hands-off pipeline: brief → plan → build → review → test → ship → retro
- `--parallel` — execute independent tasks simultaneously in waves
- `--tdd` — strict red → green → refactor, no code before failing test
- `--quick` — rapid flow for small changes under 2 hours
- No argument → show this guide and ask which mode

## --auto

Run all 7 stages. Pause only after brief (scope), after plan (approach), before merge.

## --parallel

Read PLAN.md, group independent tasks into waves, execute each wave in parallel, sync after each.

## --tdd

Red → green → refactor cycle. One test per cycle, never batch.

## --quick

4 steps: clarify → locate → implement → commit. Stop if scope grows.
