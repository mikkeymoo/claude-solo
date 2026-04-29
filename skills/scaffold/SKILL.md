---
name: scaffold
description: "Project scaffolding — set up a Python, PowerShell, or SQL project with proper structure, tooling, testing, and CI."
argument-hint: "[--python | --powershell | --sql]"
---

# /scaffold — Project Setup

Detect language from argument or ask.

## --python

Structure: `src/<pkg>/`, `tests/`, `pyproject.toml`, `.env.example`, `.gitignore`, `README.md`
Setup: ruff + mypy + pytest, venv, `pip install -e ".[dev]"`, verify with tests/lint/types.

## --powershell

Structure: `ModuleName.psm1`, `.psd1` manifest, `Public/`, `Private/`, `Tests/`
Setup: Pester tests, dot-source Public/Private, export only Public functions.

## --sql

Structure: `db/schema/`, `db/migrations/`, `db/seeds/`, `db/queries/`
Setup: Ask database type. Design normalized schema, write forward + rollback migrations, include soft deletes and audit timestamps.
