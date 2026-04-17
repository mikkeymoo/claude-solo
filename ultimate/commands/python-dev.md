# /python-dev Command

Comprehensive Python development command for project setup, testing, and deployment.

## Usage
```
/python-dev [action] [options]
```

## Actions

### init - Initialize Python Project
```
/python-dev init [project-name]
```

Creates a complete Python project structure:
```
project/
├── src/
│   └── __init__.py
├── tests/
│   └── __init__.py
├── docs/
├── requirements.txt
├── requirements-dev.txt
├── setup.py
├── pyproject.toml
├── .gitignore
├── README.md
└── tox.ini
```

### venv - Setup Virtual Environment
```
/python-dev venv
```

Automatically:
1. Creates virtual environment
2. Activates it
3. Installs requirements
4. Installs dev dependencies
5. Sets up pre-commit hooks

### test - Run Tests with Coverage
```
/python-dev test [--coverage] [--verbose]
```

Executes:
- Unit tests with pytest
- Coverage report generation
- Type checking with mypy
- Linting with pylint
- Format checking with black

### lint - Comprehensive Linting
```
/python-dev lint [--fix]
```

Runs:
- pylint for code quality
- mypy for type checking
- black for formatting
- flake8 for style guide
- bandit for security issues

### profile - Performance Profiling
```
/python-dev profile [function-name]
```

Generates:
- CPU profiling report
- Memory usage analysis
- Line-by-line profiling
- Flame graphs

### package - Build and Package
```
/python-dev package [--upload]
```

Creates:
- Source distribution
- Wheel distribution
- Optional PyPI upload

### deps - Dependency Management
```
/python-dev deps [--update] [--audit]
```

Manages:
- Dependency updates
- Security audits
- License checking
- Version pinning

## Configuration

### pyproject.toml
```toml
[tool.python-dev]
python_version = "3.11"
test_framework = "pytest"
linters = ["pylint", "mypy", "black", "flake8"]
coverage_threshold = 80

[tool.black]
line-length = 100
target-version = ['py311']

[tool.pylint]
max-line-length = 100
disable = ["C0111", "R0903"]

[tool.mypy]
python_version = "3.11"
warn_return_any = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-v --cov=src --cov-report=html"
```

## Workflow Integration

### With /dev-docs
```
/dev-docs python-feature
/python-dev init python-feature
/python-dev venv
# Develop...
/python-dev test --coverage
/python-dev package
```

### With /build-and-fix
```
/python-dev lint
/build-and-fix  # Auto-fixes Python errors
/python-dev test
```

## Advanced Features

### Async Testing
```python
# Automatically detected and handled
@pytest.mark.asyncio
async def test_async_function():
    result = await async_operation()
    assert result is not None
```

### Data Science Support
```
/python-dev init --template datascience
```

Includes:
- Jupyter notebook setup
- Pandas/NumPy configuration
- Matplotlib/Seaborn setup
- Scikit-learn integration

### Web Framework Templates
```
/python-dev init --template django
/python-dev init --template flask
/python-dev init --template fastapi
```

### Docker Integration
```
/python-dev docker [--build] [--run]
```

Generates:
- Optimized Dockerfile
- docker-compose.yml
- .dockerignore

### CI/CD Setup
```
/python-dev ci [--platform github|gitlab|azure]
```

Creates:
- GitHub Actions workflow
- GitLab CI configuration
- Azure Pipelines YAML

## Database Integration

### SQLAlchemy Setup
```
/python-dev db init
```

Creates:
- Database models
- Migration scripts
- Connection pooling
- ORM configuration

### Migration Management
```
/python-dev db migrate
/python-dev db upgrade
/python-dev db downgrade
```

## Security Features

### Security Scanning
```
/python-dev security
```

Checks for:
- Known vulnerabilities
- Hardcoded secrets
- SQL injection risks
- XSS vulnerabilities

### Secrets Management
```
/python-dev secrets [--encrypt]
```

Sets up:
- Environment variables
- .env file handling
- Secrets encryption
- Vault integration

## Performance Optimization

### Cython Compilation
```
/python-dev optimize [--cython]
```

Converts:
- Performance-critical code to Cython
- Generates .pyx files
- Compiles to C extensions

### Async Optimization
```
/python-dev async [--analyze]
```

Analyzes:
- Blocking operations
- Async/await usage
- Concurrency patterns

## Documentation

### Auto-documentation
```
/python-dev docs [--format sphinx|mkdocs]
```

Generates:
- API documentation
- Docstring extraction
- UML diagrams
- Usage examples

## Best Practices Enforced

1. **Type hints** on all functions
2. **Docstrings** for all public methods
3. **Test coverage** minimum 80%
4. **No hardcoded** secrets
5. **Dependency pinning**
6. **Virtual environment** usage
7. **Pre-commit hooks**
8. **Semantic versioning**

## Integration with Other Languages

### Python + SQL
```
/python-dev sql [--orm sqlalchemy|django]
```

### Python + PowerShell
```
/python-dev powershell [--wrapper]
```

Creates interop scripts for Windows automation.

## Example Session

```
User: /python-dev init data-processor
Claude: Creating Python project structure...
        ✅ Created src/ directory
        ✅ Created tests/ directory
        ✅ Generated requirements.txt
        ✅ Created pyproject.toml
        ✅ Set up pre-commit hooks

User: /python-dev venv
Claude: Setting up virtual environment...
        ✅ Created venv
        ✅ Activated environment
        ✅ Installed dependencies
        ✅ Development tools ready

User: /python-dev test --coverage
Claude: Running tests with coverage...
        ✅ 42 tests passed
        ✅ Coverage: 87%
        ✅ Type checking: passed
        ✅ Linting: no issues
```