---
name: map-repo
description: Regenerate docs/MAP.md — the structural repository map (file tree, per-file purpose, key symbols per file, and the dependency/data-flow graph). Use when files have been added/removed/moved, a service or engine's responsibilities changed, or the user asks to refresh/update the repo map, architecture map, or function map.
---

# map-repo

Produce or refresh **`docs/MAP.md`**, a structural orientation map that complements the prose in
`CLAUDE.md`. The goal: any model (or human) reading `MAP.md` instantly knows the repo's shape, what
each file does, the key symbols inside it, and how things wire together — so it knows *where to look*
without re-grepping the whole tree.

## Principles
- **Structural, not prose.** CLAUDE.md explains *why/how to work*; MAP.md is the *index*. Don't duplicate
  long prose — link to CLAUDE.md / SCIENCE.md / SPEC.md for the deep dives.
- **Symbol-level, not just files.** Each file row lists its key types/functions so the map doubles as a
  symbol index. Skip `private` helpers and trivial getters.
- **Capture relationships.** The most valuable part is the dependency/data-flow graph: which thing owns
  which, what flows where, and a "where do I change X → go to Y" table.
- **Stay honest.** Note orphaned/dead code and known gotchas. Don't invent structure that isn't there.

## Procedure
1. **Inventory the tree** (exclude build artifacts, generated `.xcodeproj`, `build/`, dot-dirs):
   ```bash
   find HealthAggregator -type f \( -name "*.swift" -o -name "*.plist" -o -name "*.entitlements" \) \
     | grep -vE 'build/|\.xcodeproj|HealthAggregator 2' | sort
   ```
2. **Extract key symbols** per source file (types + public/internal funcs, drop `private func`):
   ```bash
   for f in <dir>/*.swift; do echo "### $f"; \
     grep -nE '^(final )?(public )?(class|struct|enum|protocol|actor|extension) |    func |@Observable' "$f" \
     | grep -v 'private func'; done
   ```
   For non-Swift repos, swap the grep pattern (e.g. `def `/`class ` for Python, `func `/`type ` for Go,
   `export (function|const|class)` for TS). If a Serena/LSP MCP is connected, prefer its
   symbol-overview tools over grep — they're language-aware and catch more.
3. **Find the composition root & hubs** — the object(s) everything hangs off (here: `AppState`) and any
   pure-logic engines. These anchor the dependency graph.
4. **Write `docs/MAP.md`** with these sections, in order:
   - `# <Project> — Repository Map` + an auto-generated banner with today's date and a "regenerate with
     /map-repo" note.
   - **30-second model** — an ASCII tree of the core ownership graph.
   - **Data-flow / dependency graph** — ASCII arrows + a "where to change X → go to Y" table.
   - **File index** — grouped by area (App / Design / Services / Models / Views / infra), one table row
     per file: path · key symbols · one-line purpose.
   - **Gotchas** — the must-know-before-editing list (pull from CLAUDE.md + what you observed).
5. **Update the date** in the banner and keep the file under ~250 lines — it's an index, not a manual.

## When done
State what changed since the previous map (new/removed files, moved responsibilities). If you noticed
drift between MAP.md and CLAUDE.md (e.g. a service CLAUDE.md doesn't mention), flag it.
