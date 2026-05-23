# Coding Agent Base Instructions

These instructions are mandatory for every task.

1. Always update `CHANGELOG.md` with clear details of what changed.
   - Every entry must include both date and time (timestamp).
   - If `CHANGELOG.md` does not exist, create it before continuing.
2. Keep changes minimal and scoped to the requested task.
3. Validate every change before moving to the next task.
   - Run relevant checks/tests for the files you changed.
4. Update `README.md` whenever behavior, setup, usage, or structure changes.
5. Keep implementation simple and easy to read.
6. Use locale and configuration files for dynamic content (for example: strings, images, labels, constants).
   - Code changes should primarily focus on business logic.
7. Keep `docs/screen_flow_graph.md` updated for every new screen, feature, and navigation change.
   - Update the screen catalog, navigation graph, and E2E coverage checklist whenever UI/flow changes.
8. Add or update integration tests for every screen/flow change.
   - Integration tests must be maintained as part of feature delivery, not deferred.
   - Ensure the single-run E2E suite remains current and covers newly added flows.

## Working Style

- Prefer small, incremental commits.
- Avoid unrelated refactors.
- Preserve existing project conventions unless the task explicitly requires changes.

## Definition of Done

A task is complete only when all of the following are true:

1. Requested code changes are implemented and scoped to the task.
2. Relevant validation has been run and passed (lint/checks/tests as applicable).
3. `CHANGELOG.md` is updated with the change details.
4. `README.md` is updated when behavior, setup, usage, or structure changes.
5. A short summary of changed files and impact is provided.
6. `docs/screen_flow_graph.md` is updated when screen/flow behavior changes.
7. Integration tests are added/updated for changed screens and flows.

## Scope Guardrails

- Do not modify unrelated files.
- Do not perform broad refactors unless explicitly requested.
- Prefer the smallest reversible change that satisfies the requirement.
- Maintain backward compatibility unless a breaking change is explicitly approved.

## Safety Rules

- Never commit secrets, tokens, credentials, or private keys.
- Do not add new dependencies unless necessary for the task and clearly justified.
- Favor existing project utilities/configuration before introducing new patterns.

## Validation Standard

- Run linting for affected areas when available.
- Run targeted tests/checks for changed modules before marking the task complete.
- If full test execution is not feasible, document what was run and what remains.

## Dynamic Content Policy

- Do not hardcode user-facing strings, image paths, labels, or environment-specific values in business logic.
- Add dynamic content to locale/configuration files with clear naming and sensible defaults.
- Keep code changes focused on business logic and wiring to configuration/locale layers.
