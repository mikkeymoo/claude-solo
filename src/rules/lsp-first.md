# LSP-First Navigation (CRITICAL)

When Serena MCP is connected, ALL agents MUST use LSP over Grep for semantic navigation.
Works for BOTH TypeScript/JavaScript AND Python files.

| Task | Serena Tool | cclsp Equivalent |
|------|-------------|------------------|
| Find symbol / definition | `find_symbol` | `find_definition` |
| References | `find_referencing_symbols` | `find_references` |
| Symbol search | `find_symbol` | `find_workspace_symbols` |
| Symbols overview | `get_symbols_overview` | n/a |
| Implementation | `find_symbol` | `find_implementation` |

Grep/Glob = fallback ONLY when LSP returns empty or searching non-symbol text.

## Python symbols to use LSP for
- Class definitions (`SessionError`, `AppError`, `BaseModel` subclasses)
- Function definitions (`get_session_path`, `parse_file`, `validate_input`)
- Decorators and their targets (`@router.post`, `@validator`)
- Import resolution (`from app.errors import ...`)

## When Grep is still OK
- String/pattern search (log messages, URLs, config keys)
- Non-code files (.md, .json, .yaml, .env, .sql)
- Regex patterns that aren't symbol names
