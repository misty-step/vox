# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for Vox.

## What is an ADR?

An ADR is a short document that captures an important architectural decision along with its context and consequences. ADRs provide a historical record of why the system is built the way it is.

## When to Create an ADR

Create an ADR when you make a decision that:

- Affects the structure of the codebase
- Introduces or removes a significant dependency
- Changes how components communicate
- Establishes a pattern that others should follow
- Has long-term implications that are hard to reverse

Do not create ADRs for:

- Bug fixes
- Minor refactors
- Routine dependency updates
- Implementation details that can easily change

## How to Create an ADR

1. Copy `template.md` to a new file: `NNNN-short-title.md`
2. Use the next sequential number (check existing ADRs)
3. Fill in all sections
4. Submit for review with relevant code changes

## Naming Convention

```
NNNN-short-descriptive-title.md
```

Examples:
- `0001-use-swift-for-macos-app.md`
- `0002-whisper-for-transcription.md`

## Status Lifecycle

- **Proposed**: Under discussion, not yet accepted
- **Accepted**: Decision approved and in effect
- **Deprecated**: No longer applies (explain why in the ADR)
- **Superseded**: Replaced by another ADR (link to the replacement)

## Index

_No ADRs yet. This section will be updated as decisions are recorded._
