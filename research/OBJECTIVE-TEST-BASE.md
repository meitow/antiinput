# Objective test base for anti-input-lag research

This document is the starting point for turning player observations into repeatable evidence.

The goal is not to erase subjective feel. The goal is to stop subjective feel from being the
only thing that decides whether a tweak is "real."

## 1) Core idea

Competitive duel feel is a stack:

1. route quality
2. client state
3. game-side compensation systems
4. player decision quality

Most tweak guides mix all four layers together.

This test base separates them on purpose.

## 2) What counts as evidence

Split every experiment into three lanes:

### Lane A: objective telemetry

Things that can be logged without interpretation:

- average RTT
- p95 RTT
- p99 RTT
- packet loss
- jitter by standard deviation or mean absolute delta
- average FPS
- 1% low FPS
- 0.1% low FPS
- sync mode and cap
- route label and time of day

### Lane B: replay-visible artifacts

Things that can be reviewed after the match:

- enemy model speed stays stable or "bursts"
- body shots look readable or feel blank
- peek emergence looks smooth, abrupt, or catch-up corrected
- remote stop-and-shoot timing matches what the replay shows

Replay is useful, but it is not absolute truth. Treat it as a review layer, not as the final
judge of server authority.

### Lane C: player notes

Things only the player can report:

- micro-correction resistance
- input "heaviness"
- confidence in first bullet timing
- overall duel readability

Lane C still matters. It just should not act alone.

## 3) Working vocabulary

Use the same terms every time.

### Dirty route

Use this label when you repeatedly see:

- abrupt enemy acceleration
- unstable model speed
- poor body-shot impact clarity

### Clean route

Use this label when you repeatedly see:

- stable enemy model speed
- readable peeks
- consistent body-shot impact

### Smooth state

Use this label when the game is visually soft and readable, even if duel timing feels late or
over-buffered.

### Honest state

Use this label when duel timing and impact feel direct, even if the image is harsher or less
comfortable.

## 4) Metrics to score after each block

Use a simple 0 to 3 scale so the log stays usable.

### MVC: model velocity continuity

- 0 = frequent catch-up bursts or obvious speed jumps
- 1 = repeated instability
- 2 = mostly stable with isolated bursts
- 3 = stable and readable

### BIC: body-shot impact clarity

- 0 = frequent body hits feel blank, late, or unconvincing
- 1 = often unclear
- 2 = mostly clear
- 3 = consistently immediate and readable

### PR: peek readability

- 0 = frequent "ferrari" or unreadable emergence
- 1 = often too abrupt
- 2 = mostly readable
- 3 = predictable and legible

### MCR: micro-correction resistance

- 0 = heavy resistance or sticky feel
- 1 = noticeable resistance
- 2 = mild resistance
- 3 = free and direct

MCR is the least objective metric in this set, so never accept a tweak from MCR alone.

## 5) Anti-placebo rules

These rules matter more than any single tweak.

1. Change one variable at a time.
2. Route tests and client tests must be separated.
3. Use neutral labels such as `R1`, `R2`, `C1`, `C2`, not "good route" or "best preset."
4. Keep the test block fixed. Example: same drill, same mode, same number of matches.
5. If possible, do not inspect average ping until after the block is complete.
6. Review clips after the block, not during emotional rounds.
7. Promote a tweak only if it survives repeated sessions.

## 6) Minimal experiment block

Each block should log:

- date and local time
- game and mode
- server region
- route label
- ExitLag node or route tool profile if used
- client preset label
- sync stack
- FPS cap
- replay IDs or clip timestamps

Then record:

- objective telemetry
- MVC / BIC / PR / MCR
- short free-text notes

## 7) Recommended test order

Do not start with the deepest Windows tweak first.

### Phase A: route quality

Test:

- direct route versus ExitLag
- one ExitLag node versus another
- time-of-day effects on the same route

Why first:

- you already have strong player evidence that route quality changes duel feel
- equal ping does not guarantee equal model stability

### Phase B: client presentation

Test:

- G-SYNC + V-SYNC + Reflex
- Reflex plus FPS cap
- cap changes without changing the route

Why second:

- you already distinguish smooth state from honest state
- this layer strongly affects micro-correction and impact feel

### Phase C: NIC and adapter tuning

Test carefully:

- Interrupt Moderation
- RSS placement
- power-saving NIC options

Why third:

- these are real knobs, but they are system-dependent and easy to misread

### Phase D: low-level Windows myths

Test last:

- BCD timer overrides
- old TCP tweak-guide changes

Why last:

- these are the easiest to over-credit and the hardest to generalize

## 8) Research questions worth solving

The test base should answer these questions over time:

1. Which metric best predicts your "clean route" feeling: average RTT, p95 RTT, p99 RTT, loss, or
   jitter?
2. Does a route with slightly worse ping but better spacing produce better MVC and BIC?
3. Does the smooth preset improve tracking while hurting PR or MCR?
4. When a model looks too fast, is it geometry, route burst, interpolation, or local presentation?
5. Which settings survive repeat tests across players and locations?

## 9) Decision rule for a universal product

Do not ship or recommend a tweak because one player had a good night.

The baseline rule should be:

- objective telemetry must not get worse in a major way
- replay-visible artifacts must improve or stay neutral
- player notes should improve in repeated blocks

If only one lane improves, the tweak stays in the hypothesis bucket.

## 10) First repository artifacts to use with this document

- `collect-objective-baseline.ps1` for read-only system and route snapshots
- `duel-feel-session-log.csv` for block-by-block scoring
- `NETCODE-COMPENSATION-MAP.md` for interpreting what the game may be hiding or correcting
