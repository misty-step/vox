# Growth Analysis — 2026-02-23

## Key Findings

### README: 7/10
- Missing demo GIF (placeholder comment exists)
- No binary download — requires swift build (60% drop-off)
- BYOK/offline advantages buried, not in hero

### First-Run: 6/10
- Onboarding checklist marks "complete" after permissions only
- No latency comparison to justify API key signup
- No direct links to "get free Deepgram key ($150 credit)"
- Silent paste failures (Accessibility permission) have no recovery guidance

### Virality: Share menu exists (v1.26.0) but:
- No referral tracking (?ref= params)
- No incentive mechanism
- Points to github.com with no UTM

### Distribution Gaps (Priority Order)
1. No notarized DMG download — biggest acquisition barrier
2. No demo GIF in README — second biggest bounce cause
3. No Show HN / Reddit / Product Hunt launch
4. 2 GitHub stars — zero social proof
5. No GitHub Discussions / Discord

### Competitive Positioning (Strengths)
- Open source + BYOK = cost transparency vs SuperWhisper $10/mo
- Resilient fallback chain = reliability story
- Offline on macOS 26+ = privacy story
- 26 releases in 2 months = velocity/trust signal

### Quick Wins
1. Ship DMG: `./scripts/release-macos.sh` + notarize + GitHub Releases
2. Record 30s GIF → embed in README above Quick Start
3. Write Show HN / Reddit launch post
