#!/usr/bin/env bash
# Claude Code statusline — One Dark Pro, clean
input=$(cat)

# ── One Dark Pro ────────────────────────────────────────
R='\033[0m'
DIM='\033[38;2;92;99;112m'
BLUE='\033[38;2;97;175;239m'
GREEN='\033[38;2;152;195;121m'
YELLOW='\033[38;2;229;192;123m'
RED='\033[38;2;224;108;117m'
MAGENTA='\033[38;2;198;120;221m'
ORANGE='\033[38;2;209;154;102m'
FG='\033[38;2;171;178;191m'

color_left() {
  [ "$1" -gt 50 ] && printf '%b' "$GREEN" && return
  [ "$1" -gt 20 ] && printf '%b' "$YELLOW" && return
  printf '%b' "$RED"
}

color_used() {
  [ "$1" -lt 50 ] && printf '%b' "$GREEN" && return
  [ "$1" -lt 75 ] && printf '%b' "$YELLOW" && return
  printf '%b' "$RED"
}

# ── Data ────────────────────────────────────────────────
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "?"' | sed 's/ .*//')
project_dir=$(printf '%s' "$input" | jq -r '.workspace.project_dir // .cwd // ""')

branch=""
[ -n "$project_dir" ] && [ -d "$project_dir/.git" ] && \
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$project_dir" branch --show-current 2>/dev/null)

dirty=""
if [ -n "$project_dir" ] && [ -d "$project_dir/.git" ]; then
  dc=$(GIT_OPTIONAL_LOCKS=0 git -C "$project_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$dc" -gt 0 ] && dirty=" ${ORANGE}~${dc}${R}"
fi

ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ── Zone 1: Identity ───────────────────────────────────
out="${BLUE}${model}${R} ${DIM}·${R} ${MAGENTA}${branch}${R}${dirty}"

# ── Zone 2: Metrics (each group: emoji label value) ────
parts=()

if [ -n "$ctx" ]; then
  ci=$(printf '%.0f' "$ctx")
  ico="💡"; [ "$ci" -ge 75 ] && ico="🔥"
  parts+=("${ico} ${DIM}ctx${R} $(color_used "$ci")${ci}%${R}")
fi

if [ -n "$five" ]; then
  fi=$(printf '%.0f' "$five")
  fl=$((100 - fi))
  ico="⚡"; [ "$fl" -le 10 ] && ico="⚠️"
  parts+=("${ico} ${DIM}5h${R} $(color_left "$fl")${fl}%${R}")
fi

if [ -n "$week" ]; then
  wi=$(printf '%.0f' "$week")
  wl=$((100 - wi))
  ico="🔋"; [ "$wl" -le 20 ] && ico="💀"
  parts+=("${ico} ${DIM}wk${R} $(color_left "$wl")${wl}%${R}")
fi

if [ "${#parts[@]}" -gt 0 ]; then
  metrics=""
  for i in "${!parts[@]}"; do
    [ "$i" -gt 0 ] && metrics="${metrics}  "
    metrics="${metrics}${parts[$i]}"
  done
  out="${out}  ${FG}│${R}  ${metrics}"
fi

printf '%b' "$out"
