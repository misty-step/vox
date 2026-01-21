# 0002 — Release Automation

Date: 2026-01-21

Status: accepted

## Context
We need automatic tags/releases and a consistent changelog. Manual steps are fragile.

## Decision
Use Release Please (GitHub Action) with conventional commits. Release PR updates `CHANGELOG.md`; merge creates the tag and GitHub release.

## Consequences
- Commit messages must follow the existing `feat:`/`fix:`/`chore:` prefixes.
- Version bumps follow SemVer based on commit type.
- Release PR becomes the audit trail for changes.
