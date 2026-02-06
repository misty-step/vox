# Mission: Fix PR #156 — Self-Healing PR Protocol

You are Thorn. You opened PR #156 on misty-step/vox (`thorn/stability-resilience`). CI is failing. Fix it and shepherd the PR to merge-ready.

## Location
`/home/sprite/workspace/vox` — branch `thorn/stability-resilience`

## Git Config (run first)
```bash
git config user.name "kaylee-mistystep"
git config user.email "kaylee@mistystep.io"
```

## Step 1: Understand Current Failures

Check out your branch and get the latest CI errors:
```bash
git checkout thorn/stability-resilience
git log --oneline -5
```

The current CI failure is about Swift 6 strict concurrency. Your test mocks use `NSLock.lock()` and `NSLock.unlock()` in async contexts, which Swift 6 forbids.

The errors:
```
DictationPipelineTests.swift:50: error: instance method 'lock' is unavailable from asynchronous contexts
DictationPipelineTests.swift:56: error: instance method 'unlock' is unavailable from asynchronous contexts
```

## Step 2: Fix

Replace `NSLock` synchronization with an actor-based pattern or use `withLock` (the async-safe scoped API). For example:

Instead of:
```swift
lock.lock()
// mutate state
lock.unlock()
```

Use a synchronization approach that Swift 6 allows in async contexts. Options:
- Use `os.OSAllocatedUnfairLock` with `withLock` closure (preferred)
- Use an actor to isolate mutable state
- Use `nonisolated(unsafe)` if the test mock doesn't actually need thread safety

Run `swift build` after fixing to verify locally on the sprite.

## Step 3: Push and Monitor CI

After fixing:
```bash
git add -A
git commit -m "fix(test): replace NSLock with async-safe synchronization in test mocks"
git push origin thorn/stability-resilience
```

## Step 4: Wait for CI and Check Results

```bash
sleep 120
gh pr checks 156 2>&1
```

If CI passes → check for review comments:
```bash
gh api repos/misty-step/vox/pulls/156/comments \
  --jq '.[] | "[\(.user.login)] \(.path):\(.line) severity=\(.body | if test("critical|Critical|CRITICAL") then "CRITICAL" elif test("high|High|HIGH") then "HIGH" elif test("major|Major|MAJOR") then "MAJOR" else "other" end) — \(.body[:150])"'
```

Address any critical/high/major comments, push fixes, wait for CI again.

If CI fails again → read the new errors:
```bash
# Get the latest CI run
RUN_ID=$(gh api repos/misty-step/vox/actions/runs?branch=thorn/stability-resilience --jq '.workflow_runs[0].id')
gh run view $RUN_ID --log-failed 2>&1 | grep "error:" | head -20
```

Fix and push again. Maximum 3 fix attempts.

## Step 5: Completion Signal

When CI passes and no unaddressed critical/high review comments:
```
TASK_COMPLETE: PR #156 is merge-ready
SUMMARY: Fixed pipeline timeout, error recovery, and comprehensive tests
```

If stuck after 3 attempts:
```
BLOCKED: [description of what's blocking]
ATTEMPTED: [list of what you tried]
```
