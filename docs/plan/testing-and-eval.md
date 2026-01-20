# Testing and Evaluation

## Behavior list (test-first)
- Hotkey tap starts session
- Hotkey tap commits, closes, inserts
- STT errors show flash, no insert
- Rewrite timeout falls back to raw transcript
- Pasteboard restore preserves prior content

## Provider adapter tests
- Deterministic mock STT events
- Deterministic mock rewrite responses
- Contract tests: no provider-specific fields leak

## Golden corpus
- Filler-heavy ramble
- Mid-sentence correction
- Code dictation
- Proper nouns + acronyms
- Multilingual snippets

## Manual app matrix
- Chrome, Safari, VS Code, Slack, Notion, Terminal
- Caret position: AX available vs unavailable
- Paste blocked apps

## Metrics
- Latency p50/p95 from release → insert
- Verifier reject rate
- Rewrite timeout rate
- STT failure rate
