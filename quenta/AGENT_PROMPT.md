# Agent Prompt Conventions (Quenta)

This file defines conventions that agents should follow when working in this repository.

## Naming
- Use **snake_case** for variable names, including numbered examples.
  - ✅ `user_1`, `account_2`
  - ❌ `user1`, `account2`

## Tests and Data Setup
- Prefer **factory functions** for creating data in tests.
  - ✅ `insert(:user)` or `Factory.user()` (per existing project factories)
  - ❌ direct `Repo.insert(...)` in tests

## General
- Follow existing style and patterns in the codebase.
- If unsure which factory helper to use, search for existing test factories in the project.

If a change request conflicts with these conventions, call it out and ask for clarification.