# Mission: Fix PR #155 — Self-Healing PR Protocol

You are Bramble. You opened PR #155 on misty-step/vox (`bramble/performance`). CI is failing. Fix it and shepherd the PR to merge-ready.

## Location
`/home/sprite/workspace/vox` — branch `bramble/performance`

## Git Config (run first)
```bash
git config user.name "kaylee-mistystep"
git config user.email "kaylee@mistystep.io"
```

## Step 1: Understand Current Failures

Check out your branch and understand the errors:
```bash
git checkout bramble/performance
git log --oneline -5
```

The current CI failure is a syntax/compilation error in WhisperClient.swift:
```
WhisperClient.swift:5: error: expected declaration
WhisperClient.swift:5: error: expected '}' in class
WhisperClient.swift:4: error: type 'WhisperClient' does not conform to protocol 'STTProvider'
```

This suggests a structural issue — likely a missing brace, malformed function, or botched edit that broke the class structure. You need to:

1. Read `Sources/VoxProviders/WhisperClient.swift` carefully
2. Find the syntax error (likely near line 4-5)
3. Fix the structural issue
4. Verify the class conforms to `STTProvider` protocol

Also check that `ElevenLabsClient.swift` still compiles cleanly.

Run `swift build` after fixing.

## Step 2: Fix and Push

```bash
git add -A
git commit -m "fix: resolve WhisperClient compilation errors"
git push origin bramble/performance
```

## Step 3: Wait for CI and Check Results

```bash
sleep 120
gh pr checks 155 2>&1
```

If CI passes → check for review comments:
```bash
gh api repos/misty-step/vox/pulls/155/comments \
  --jq '.[] | "[\(.user.login)] \(.path):\(.line) severity=\(.body | if test("critical|Critical|CRITICAL") then "CRITICAL" elif test("high|High|HIGH") then "HIGH" elif test("major|Major|MAJOR") then "MAJOR" else "other" end) — \(.body[:150])"'
```

Address any critical/high/major comments, push fixes, wait for CI again.

If CI fails again → read the new errors:
```bash
RUN_ID=$(gh api repos/misty-step/vox/actions/runs?branch=bramble/performance --jq '.workflow_runs[0].id')
gh run view $RUN_ID --log-failed 2>&1 | grep "error:" | head -20
```

Fix and push again. Maximum 3 fix attempts.

## Step 4: Completion Signal

When CI passes and no unaddressed critical/high review comments:
```
TASK_COMPLETE: PR #155 is merge-ready
SUMMARY: CAF-to-Opus encoding, timing instrumentation, file-based uploads
```

If stuck after 3 attempts:
```
BLOCKED: [description of what's blocking]
ATTEMPTED: [list of what you tried]
```
