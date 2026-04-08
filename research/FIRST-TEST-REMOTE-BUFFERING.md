# First test: remote buffering and route quality

This is the first test to run after studying developer-side compensation systems.

It is intentionally narrow.

The goal is not to prove "the whole game is bad" or "this tweak fixes input lag."

The goal is to test one specific idea:

> A large part of "enemy too fast", "model speed bursts", and "body shots have no impact"
> may come from the quality of remote-state delivery into the game's smoothing/buffering
> systems, not from average ping alone.

## 1) Why this is the first test

Based on the current research:

- Riot explicitly documents incoming movement buffering, server move queues, client prediction,
  corrections, and rewind.
- Riot also exposes a Network Buffering setting because the remote-state smoothing trade-off is
  real.
- Valve documents relay networking and explicitly claims that route choice can improve both ping
  and connection quality.
- Your strongest player observations already point to route quality and enemy model readability as
  the first big axis.

So the first test should attack the highest-value question first:

> Does a route/node change alter model readability and body-shot impact more than average ping
> suggests?

## 2) Primary hypothesis

### H1

Two routes with similar average ping can produce clearly different duel feel because the game is
buffering and smoothing a different quality of incoming stream.

If this is true, the better route should show:

- higher MVC
- higher BIC
- higher PR
- equal or better jitter metrics

even if average ping is not meaningfully better.

### H0

If average ping is the main thing that matters, then similar ping routes should not repeatedly
produce different scores.

## 3) Variable to change

Change only one axis:

- ExitLag node / route path

Do not change:

- FPS cap
- G-SYNC / V-SYNC / Reflex
- monitor refresh
- mouse polling
- Windows power plan
- NIC settings

## 4) Recommended A/B pair

Use the cleanest version of the route difference you already trust exists.

Example:

- Route A: Frankfurt 1 at night
- Route B: Frankfurt 9 at night

If possible, use the same:

- date window
- session length
- game mode
- stack size
- warmup routine

## 5) Test block

For each route:

1. Run `collect-objective-baseline.ps1` before the session.
2. Play a fixed block.
3. Save replay IDs or clip timestamps.
4. Fill one row in `duel-feel-session-log.csv`.

### Suggested fixed block

- 1 short warmup that is not scored
- 2 scored matches or 2 scored custom/replay review blocks

If ranked is too noisy, use a repeatable scenario pool:

- holding common angle
- reacting to wide swing
- body-shot tracing on a moving target

## 6) What to score

Score these four after each block:

- MVC: model velocity continuity
- BIC: body-shot impact clarity
- PR: peek readability
- MCR: micro-correction resistance

For this first test, the most important fields are:

- MVC
- BIC
- PR

MCR matters, but it is secondary here because this test is mostly about remote-state quality.

## 7) What to collect objectively

From the baseline collector and the session log, focus on:

- route label
- route target
- ping mean
- ping p95
- ping p99
- jitter stddev
- jitter mean absolute delta
- loss
- time of day

The key comparison is:

- similar mean ping
- different tail latency / jitter / subjective remote-model quality

## 8) Replay review checklist

When reviewing clips, do not ask "did I get robbed?"

Ask:

1. Did the enemy model emerge at a constant speed or with catch-up acceleration?
2. Did contact at close range create exaggerated speed changes?
3. Did body shots feel blank in the live round and also look visually weak or mistimed in replay?
4. Did the model appear to be "running while accurate," and is this better explained by:
   - interpolation delay,
   - animation lag,
   - route burst,
   - or actual move/shoot timing?

## 9) Pass condition

Promote the result only if all of this is true:

- Route A beats Route B on MVC or BIC in repeated sessions
- the result repeats on different nights
- objective jitter or tail-latency metrics are at least not worse
- the route difference is still visible when the client preset is unchanged

## 10) Fail condition

Reject the hypothesis for now if:

- differences vanish when repeated
- only MCR changes while MVC/BIC/PR stay flat
- the result only appears in one emotional session
- route A and B trade wins randomly with no metric pattern

## 11) What this test does NOT prove

Even if Route A wins, this does not prove:

- Riot buffering is "bad"
- the game is broken
- the node itself is overloaded in all cases
- local client state does not matter

It only proves something smaller and more useful:

> route quality can materially change how the game's remote-state compensation layers are felt
> by the player

## 12) Next test if this succeeds

If this test shows a repeatable route effect, the next test should keep the route fixed and vary
only the client presentation layer:

- G-SYNC + V-SYNC + Reflex
- Reflex + 200 cap

That will tell us whether "smooth" and "honest" are mostly a local presentation issue after the
route is already stable.
