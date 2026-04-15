---
name: mm-scaffold
description: "Claude-solo command skill"
---

# mm-scaffold

Claude-solo command skill

## Instructions
---
name: mm:scaffold
description: "Project scaffolding — set up a Python, PowerShell, or SQL project with proper structure, tooling, testing, and CI."
argument-hint: "[--python | --powershell | --sql]"
---

Project scaffolding. Detect language from argument or ask if not specified.

- `--python` — Python project with venv, pytest, ruff, mypy, packaging
- `--powershell` — PowerShell module with Pester tests, manifest, signing
- `--sql` — SQL schema design, migration management, query helpers

---

## --python — Python Project Scaffold

**1. Structure**
```
project/
├── src/<package>/       # main package
├── tests/               # pytest tests
├── pyproject.toml       # PEP 517 build config
├── .env.example
├── .gitignore
└── README.md
```

**2. Setup**
- Create `pyproject.toml` with: project metadata, dependencies, dev dependencies (pytest, ruff, mypy), tool configs for ruff (line-length=120, select=["E","W","F","I"]) and mypy (strict=true)
- Create `src/<package>/__init__.py` with version
- Create `tests/conftest.py` and one example test
- Create `.env.example` with required vars
- Create `.gitignore` (Python standard + .env)

**3. Virtual environment**
```bash
python -m venv .venv
source .venv/bin/activate   # or: .venv\Scripts\activate on Windows
pip install -e ".[dev]"
```

**4. Verify setup**
```bash
rtk python -m pytest tests/ -v
rtk python -m ruff check src/
rtk python -m mypy src/
```

**5. Optional: Docker**
Generate `Dockerfile` (python:3.12-slim base) and `.dockerignore` if user requests it.

**6. Optional: CI**
Generate `.github/workflows/ci.yml` — install deps, run ruff, mypy, pytest with coverage, upload to Codecov if token available.

Report: "Python project scaffolded. Run: `source .venv/bin/activate && pip install -e '.[dev]'` to get started."

---

## --powershell — PowerShell Module Scaffold

**1. Structure**
```
ModuleName/
├── ModuleName.psm1        # module root
├── ModuleName.psd1        # module manifest
├── Public/                # exported functions
├── Private/               # internal functions
├── Tests/                 # Pester tests
│   └── ModuleName.Tests.ps1
└── README.md
```

**2. Module manifest** (`ModuleName.psd1`)
- RootModule, ModuleVersion (1.0.0), Author, Description, FunctionsToExport, RequiredModules
- PowerShellVersion: '5.1' minimum

**3. Module root** (`ModuleName.psm1`)
- Dot-source all `Public/*.ps1` and `Private/*.ps1`
- Export only Public functions

**4. Example function** in `Public/`
- Full comment-based help (Synopsis, Description, Parameter, Example)
- SupportsShouldProcess for state-changing functions
- Proper error handling with `$ErrorActionPreference`

**5. Pester test template**
```powershell
BeforeAll { Import-Module $PSScriptRoot\..\ModuleName.psd1 -Force }
Describe 'FunctionName' {
    It 'should do X when Y' { ... | Should -Be Z }
}
```

**6. Verify**
```powershell
Import-Module ./ModuleName/ModuleName.psd1 -Force
Invoke-Pester ./ModuleName/Tests/ -Output Detailed
```

---

## --sql — SQL Schema and Migration Scaffold

Ask: what database? (PostgreSQL, MySQL, SQLite, SQL Server)

**1. Structure**
```
db/
├── schema/               # table definitions
├── migrations/           # numbered migration files
│   ├── 001_initial.sql
│   └── 001_initial.down.sql
├── seeds/                # test/dev seed data
└── queries/              # named queries
```

**2. Schema design**
- Ask for entity descriptions (e.g., "users, posts, comments with likes")
- Design normalized schema (3NF minimum): tables, columns with types, primary keys (BIGSERIAL/UUID), foreign keys, timestamps (created_at, updated_at)
- Create appropriate indexes: FK columns, frequently queried columns, unique constraints
- Show the full schema SQL before writing

**3. Migration files**
- Naming: `NNN_description.sql` and `NNN_description.down.sql` (both required)
- Include: CREATE TABLE with IF NOT EXISTS, index creation, constraints
- Down migration: DROP TABLE / ALTER TABLE to reverse

**4. Common patterns included**
- Soft deletes: `deleted_at TIMESTAMPTZ` column with partial index
- Audit trail: created_at / updated_at with trigger (if PostgreSQL)
- UUID primary keys: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`

**5. Verify**
Show the complete schema. Ask: "Apply to local database?" If yes, provide the apply command for the detected database.
