# Project Memory System

This directory contains persistent memory files for Claude Code conversations about this project. The memory system helps maintain context across sessions, especially important in devcontainer environments where home directories may not persist.

## Structure

- **MEMORY.md** — Index of all memory files (links used to navigate)
- **aten-*.md** — Topic-specific memory files about ATen build integration

## How Memory Works

Memory files are organized by type:
- **project** — ongoing work, goals, initiatives, bugs
- **feedback** — guidance on approach (what works, what to avoid)
- **reference** — external resources (Linear projects, Grafana dashboards, etc.)
- **user** — profile information (role, expertise, preferences)

## Adding New Memory

When saving new memory:
1. Create a `.md` file with frontmatter (name, description, metadata)
2. Add an entry to **MEMORY.md** under ~150 characters
3. Commit to git

For details, see the [memory system documentation in the harness](https://github.com/anthropics/claude-code/blob/main/README.md#memory-system).

## Version Control

All memory files are tracked in git, so they persist across devcontainer rebuilds and remain synchronized across team members.
