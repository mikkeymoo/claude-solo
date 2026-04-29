---
name: scaffold
description: "Project scaffolding — set up a Python, PowerShell, or SQL project with proper structure, tooling, testing, and CI."
argument-hint: "[--python | --powershell | --sql | --react | --next | --fastapi | --express]"
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

## --react

Structure: `src/App.tsx`, `src/components/`, `src/main.tsx`, `index.html`, `vite.config.ts`, `tsconfig.json`, `package.json`, `.env.example`, `README.md`
Setup: Generate with real, working content — not empty files. Include basic error handling in React idiom (error boundaries, try-catch in async components). Add `<!-- @template: react -->` comment at top of each generated file.

- `src/App.tsx` — root component with React Router setup (BrowserRouter, Routes, Link)
- `src/components/Home.tsx` — placeholder component with example content
- `index.html` — entry point with `<div id="root"></div>`
- `vite.config.ts` — Vite config with React plugin
- `tsconfig.json` — strict mode enabled
- `package.json` — dependencies: react, react-dom, react-router-dom, vite, @vitejs/plugin-react, typescript, @types/react, @types/react-dom
- `.env.example` — `VITE_API_URL=http://localhost:3000` placeholder
- `README.md` — installation: `npm install && npm run dev`, build: `npm run build`

## --next

Structure: `app/page.tsx`, `app/layout.tsx`, `app/globals.css`, `app/api/`, `next.config.ts`, `tsconfig.json`, `package.json`, `.env.example`, `README.md`
Setup: Generate with real, working content — not empty files. Include basic error handling in Next.js idiom (try-catch in API routes, error.tsx boundary). Add `/* @template: next */` comment at top of each generated file.

- `app/layout.tsx` — root layout with metadata
- `app/page.tsx` — home page component
- `app/globals.css` — global styles
- `app/api/hello/route.ts` — example GET API route returning JSON
- `next.config.ts` — Next.js configuration
- `tsconfig.json` — strict mode enabled
- `package.json` — dependencies: next, react, react-dom, typescript, @types/node, @types/react
- `.env.example` — `NEXT_PUBLIC_API_URL=http://localhost:3000` placeholder
- `README.md` — installation: `npm install && npm run dev`, build: `npm run build`

## --fastapi

Structure: `main.py`, `routers/`, `models/`, `requirements.txt`, `.env.example`, `README.md`
Setup: Generate with real, working content — not empty files. Include basic error handling in FastAPI idiom (try-except in routes, HTTPException). Add `# @template: fastapi` comment at top of each generated file.

- `main.py` — FastAPI app with health check route `/health` returning `{"status": "ok"}`
- `routers/example.py` — example router with GET `/items` returning list
- `models/schemas.py` — Pydantic BaseModel schemas for request/response validation
- `requirements.txt` — dependencies: fastapi==0.104.1, uvicorn==0.24.0, pydantic==2.5.0
- `.env.example` — `DATABASE_URL=sqlite:///./test.db`, `SECRET_KEY=your-secret-key` placeholders
- `README.md` — installation: `pip install -r requirements.txt`, run: `uvicorn main:app --reload`

## --express

Structure: `src/index.ts`, `src/routes/`, `src/middleware/`, `tsconfig.json`, `package.json`, `.env.example`, `README.md`
Setup: Generate with real, working content — not empty files. Include basic error handling in Express idiom (try-catch in handlers, error middleware). Add `// @template: express` comment at top of each generated file.

- `src/index.ts` — Express app with health check route `/health` returning JSON, middleware setup
- `src/routes/example.ts` — example router with GET and POST endpoints
- `src/middleware/errorHandler.ts` — centralized error handling middleware
- `src/middleware/logger.ts` — request logging middleware
- `tsconfig.json` — strict mode enabled, target ES2020
- `package.json` — dependencies: express, @types/express, typescript, ts-node, @types/node, dotenv
- `.env.example` — `PORT=3000`, `DATABASE_URL=sqlite:///./test.db` placeholders
- `README.md` — installation: `npm install`, run: `npm run dev`, build: `npm run build`
