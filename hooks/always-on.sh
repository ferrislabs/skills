#!/usr/bin/env sh
# SessionStart hook. Injects the always-on output rules into every session.
# No opt-in flag: the rules are permanent. Never blocks: any failure exits 0.

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname -- "$0")/.." 2>/dev/null && pwd)}"

strip_frontmatter() {
  awk '
    NR == 1 && /^---[ \t]*$/ { fm = 1; next }
    fm && /^---[ \t]*$/      { fm = 0; next }
    !fm                      { print }
  ' "$1"
}

for skill in i-have-adhd ferris-communication; do
  file="$root/skills/$skill/SKILL.md"
  [ -f "$file" ] || continue
  printf 'ALWAYS-ON RULES (%s). Apply to every response. No off switch.\n\n' "$skill"
  strip_frontmatter "$file"
  printf '\n'
done

exit 0
