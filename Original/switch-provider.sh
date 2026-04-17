#!/usr/bin/env bash
# Switch default model/provider across Claude and Codex configs.

set -euo pipefail

PROVIDER="both"
MODEL=""
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --claude-dir) CLAUDE_DIR="$2"; shift 2 ;;
    --codex-dir) CODEX_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$MODEL" ]]; then
  echo "Usage: bash switch-provider.sh --model <model-id> [--provider claude|codex|both]"
  exit 1
fi

set_claude_model() {
  local settings="$CLAUDE_DIR/settings.json"
  mkdir -p "$CLAUDE_DIR"
  python3 - "$settings" "$MODEL" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
model = sys.argv[2]
if p.exists():
    try:
        data = json.loads(p.read_text(encoding='utf-8'))
    except Exception:
        data = {}
else:
    data = {}
data['model'] = model
p.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
PY
  echo "  Claude model -> $MODEL"
}

set_codex_model() {
  local config="$CODEX_DIR/config.toml"
  mkdir -p "$CODEX_DIR"
  if [[ ! -f "$config" ]]; then
    printf 'model = "%s"\n' "$MODEL" > "$config"
    echo "  Codex model -> $MODEL"
    return
  fi

  python3 - "$config" "$MODEL" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
model = sys.argv[2]
text = p.read_text(encoding='utf-8')
if re.search(r'(?m)^model\s*=\s*"[^"]*"\s*$', text):
    text = re.sub(r'(?m)^model\s*=\s*"[^"]*"\s*$', f'model = "{model}"', text, count=1)
else:
    text = f'model = "{model}"\n' + text
p.write_text(text, encoding='utf-8')
PY
  echo "  Codex model -> $MODEL"
}

echo "Switching model to: $MODEL"
case "$PROVIDER" in
  claude) set_claude_model ;;
  codex) set_codex_model ;;
  both)
    set_claude_model
    set_codex_model
    ;;
  *)
    echo "Invalid provider: $PROVIDER (use claude|codex|both)"
    exit 1
    ;;
esac
