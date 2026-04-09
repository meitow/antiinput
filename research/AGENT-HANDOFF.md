# Agent handoff: current antiinput research state

Last updated: 2026-04-09

This file is a context handoff for another model or agent.

It summarizes:

- what the user is actually trying to build
- which developer-side "crutches" have already been studied
- what the repository already contains
- what was learned from the first experiments
- which hypotheses look alive right now
- what should be tested next

## 1) User context and research goal

The user is not an experienced programmer, but is a high-level competitive player and analyst
working with professional-level FPS players. The user explicitly wants personal in-game
observations to be treated seriously, not overridden by generic public tweak lore.

Current target:

- VALORANT first
- later maybe a more universal product for competitive shooters

Primary product direction:

- not just rollback guides
- not just "safe defaults"
- eventually a real anti-input-lag / anti-duel-desync research workflow
- possibly later software, knowledge base, or adaptive tuning logic

User priority:

- stability and consistency over absolute minimum delay
- "clean duel feel" matters more than one headline ping number

Important communication constraint:

- keep questions short
- the user gets fatigued by long question lists
- prefer direct guidance and concrete next steps

## 2) Repository state

Current working branch for the research framework:

- `cursor/custom-tweak-lab-9926`

Important branch with uploaded test data:

- `origin/test1`

Draft PR already exists for the main research framework branch:

- PR #2

Latest commit on the working branch at the time of this handoff:

- `6ee2b46` - `Fix baseline collector ping summary types`

## 3) Key repository files already created

These files were added specifically to support structured research:

- `research/OBJECTIVE-TEST-BASE.md`
- `research/NETCODE-COMPENSATION-MAP.md`
- `research/DEVELOPER-CRUTCHES-STUDY.md`
- `research/FIRST-TEST-REMOTE-BUFFERING.md`
- `research/collect-objective-baseline.ps1`
- `research/duel-feel-session-log.csv`

What they do:

- `OBJECTIVE-TEST-BASE.md`
  - separates route quality, client state, compensation effects, and player notes
  - defines structured scoring terms

- `NETCODE-COMPENSATION-MAP.md`
  - broad map of interpolation, prediction, rewind, buffering, and relevance gating

- `DEVELOPER-CRUTCHES-STUDY.md`
  - more focused study of Riot/Valve developer-side compensation systems

- `FIRST-TEST-REMOTE-BUFFERING.md`
  - first narrow test design for route quality versus remote buffering sensitivity

- `collect-objective-baseline.ps1`
  - read-only machine/network baseline collector
  - not a route-specific ExitLag game-flow tracer

- `duel-feel-session-log.csv`
  - structured manual session log

## 4) What was established from official developer material

This work was already done and documented in `DEVELOPER-CRUTCHES-STUDY.md`.

### 4.1 VALORANT / Riot

Confirmed through Riot material:

- server-authoritative netcode
- local client prediction
- server correction when prediction diverges
- buffering of incoming movement updates
- fixed 128 Hz simulation with render decoupling
- server move queueing and burst absorption
- server rewind / lag compensation for hit registration
- interpolation delay as a real visual/gameplay trade-off
- movement/damage/animation timeline mismatch issues
- Fog of War / relevance gating / eventual consistency catch-up
- route quality and Riot Direct matter to peeker's advantage

Important Riot-specific details already captured:

- Riot explicitly documents that buffering smooths movement but adds effective latency
- Riot previously gave a concrete remote interpolation delay figure of 7.8125 ms
- Riot explicitly discusses cases where a player appears moving on one screen while the
  authoritative timeline says they were already stopped
- Riot documents that information about enemies can be withheld until relevant

### 4.2 Counter-Strike / Valve

Confirmed or strongly supported:

- Steam Networking and Steam Datagram Relay can improve ping and connection quality
- CS2 sub-tick improves action timestamp precision
- Source-family interpolation / lerp culture remains useful for thinking about remote-state delay
- Source-family lag compensation / rewind remains conceptually relevant
- CS2 has post-launch feedback-alignment work for visuals and timing

Important nuance:

- official Valve docs were easier to fetch for Steam Networking / SDR than for old Source wiki pages
- some Source-family networking references remain "Supported" instead of "Confirmed" in the docs

## 5) User observations that should be preserved

These matter and should not be lost.

### 5.1 Route quality matters more than average ping

The user repeatedly observed that:

- same or similar ping can feel radically different
- ExitLag node choice matters
- quality of ping matters more than quantity of ping

Historically the user felt:

- Frankfurt 1 at night often better
- higher-number Frankfurt nodes often worse

But in the latest live subjective test:

- Frankfurt 1 vs Frankfurt 9 showed little felt difference that night

This does not kill the route hypothesis. It just means the latest session did not show a strong
subjective route split.

### 5.2 Dirty route / dirty duel feel symptoms

The user's own language points to:

- enemy model suddenly accelerating
- strange burst-like compensation in close or collision-like contact
- poor body-shot impact
- unreadable moment of exchange at the instant of shooting

### 5.3 Smooth versus honest state

The user strongly distinguishes:

- a visually smooth state
- a more reactive or "honest" duel state

Example pattern:

- G-SYNC + V-SYNC + Reflex feels smoother but sometimes too soft/slow
- Reflex + 200 cap can feel more reactive

### 5.4 Crouch propagation mismatch

The user noticed:

- local crouch input can be visible locally
- local crosshair/camera level can already drop
- but the remote player may still see a standing pose

This was interpreted as a timing/propagation issue rather than a simple keyboard input issue.

### 5.5 New stronger phenomenon: lethal pose snap

This was clarified later and is important.

The user does NOT mean their own model snaps locally.

The user means:

- when the user kills an enemy, especially with a headshot
- on the user's client, the enemy model can rotate or snap dramatically for one frame
- sometimes close to 180 degrees
- then on the next frame it returns to the orientation in which the user actually killed them

The enemy player does not see this on their own local first-person view.

Working label for this symptom:

- `LPS` = lethal pose snap

Interpretation:

- likely remote pose / death-state reconciliation
- likely not a simple raw hitreg problem
- may be related to animation or orientation coherency
- route quality could amplify it, but route is probably not the only cause

### 5.6 New stronger phenomenon: fire-to-confirm latency

The user measured:

- first visible muzzle-flash frame
- then first visible killfeed frame

This is NOT actual bullet travel time.

It is better understood as:

- `FCL` = fire-to-confirm latency

User's measurements:

- user: 6 frames at 60 fps = about 100 ms
- teammate: 2 frames at 120 fps = about 16.7 ms

This is a very large gap.

Important nuance:

- frame counts must be converted to milliseconds
- equal capture fps is preferable for future tests
- but 100 ms vs 16.7 ms is too large to dismiss as "just different fps"

This is currently one of the strongest objective-like leads.

## 6) What `origin/test1` actually contains

The user later shared:

- `https://github.com/meitow/antiinput/tree/test1`

This is NOT a media branch.

It contains baseline output folders and one note file, not VOD.

Key contents on `origin/test1`:

- `20260409-012143-frankfurt1-night/...`
- `20260409-022156-frankfurt9-night/...`
- `20260409-012143-frankfurt1-night/s1.txt`

The branch can be inspected without checkout using:

- `git show origin/test1:<path>`
- `git ls-tree -r --name-only origin/test1`

### 6.1 Baseline summary from `test1`

Frankfurt 1:

- `1.1.1.1` mean 2.02 ms, p99 3, jitter MAD 0.03
- `8.8.8.8` mean 21.55 ms, p99 23, jitter MAD 0.58

Frankfurt 9:

- `1.1.1.1` mean 2.35 ms, p99 12, jitter MAD 0.55
- `8.8.8.8` mean 21.96 ms, p99 34, jitter MAD 1.57

Interpretation:

- mean RTT barely changed
- tails and jitter got much worse on Frankfurt 9 in those baseline probes
- this supports the user's "quality of ping" idea

### 6.2 User note from `s1.txt`

Frankfurt 1 only:

- MVC = 1
- BIC = 1
- PR = 1
- MCR = 2

Free-text note:

- model becomes less readable at the moment of shooting
- user suspects some kind of spike but did not yet know what exactly

### 6.3 Limits of `test1`

Important:

- only Frankfurt 1 had subjective notes in the branch
- there was no matching Frankfurt 9 subjective note in the branch
- there was no VOD in the branch
- baseline measurements are contextual, not proof of actual ExitLag game-route behavior

## 7) Critical caveat about the baseline collector

This must be preserved clearly for the next model.

`collect-objective-baseline.ps1` does NOT measure the actual ExitLag-rerouted Valorant UDP flow.

It currently collects:

- local machine/network snapshots
- ICMP ping style data through `.NET Ping`
- `Test-NetConnection`
- optional `tracert`

That means:

- it is useful for general machine/network baseline context
- it is NOT proof of the actual optimized game route used by ExitLag

This matters because the user explicitly pointed out that ExitLag works by process/packet interception.

Correct interpretation:

- baseline collector = local baseline and rough line quality context
- NOT a final route-quality truth source for Valorant-over-ExitLag

Practical consequence:

- for route tests, trust in-game telemetry, structured observations, replay/VOD, and dual-POV evidence
- use the baseline collector only as supporting context

## 8) Current live hypotheses

These are the hypotheses that still look alive after the latest exchange.

### H1: route quality / tail behavior matters

Still alive, but not dominant in the latest session.

Meaning:

- route/node quality can matter
- but the latest subjective test did not show a strong Frankfurt 1 vs 9 split

### H2: remote-state coherency may now be the stronger lead

This is currently the most interesting direction.

Specifically:

- the user's main issue may not be route alone
- it may be a combination of remote model reconstruction, lethal-state alignment, and event confirmation

Strong signals:

- lethal pose snap
- fire-to-confirm latency gap versus teammate

### H3: node may affect FCL more directly than LPS

Provisional interpretation:

- node/path quality can directly affect `FCL`
- node/path quality may influence `LPS`, but probably not as the sole root cause

### H4: if user-versus-teammate difference is stronger than node difference, prioritize controlled
user-versus-teammate comparison before deeper Windows tweaking

This became the practical direction after the latest messages.

## 9) Metrics that now matter most

If the next model has to continue the work, prioritize these labels.

### 9.1 FCL

- `FCL` = fire-to-confirm latency
- measure in milliseconds, not raw frames
- start frame = first muzzle-flash frame
- end frame = first killfeed frame

### 9.2 LPS

- `LPS` = lethal pose snap
- binary and severity-friendly metric
- did the enemy model snap on the lethal frame?
- if yes, how severe was it?

Suggested severity labels:

- `none`
- `small`
- `medium`
- `large`

Optional note:

- approximate degrees or qualitative "near 180"

### 9.3 MVC / BIC / PR / MCR

These still matter, but after the latest discussion they are secondary to FCL and LPS.

## 10) Recommended next tests

The next model should probably not start with more broad route questioning.

### Test A: controlled user-versus-teammate FCL/LPS comparison

Goal:

- isolate why the user sees much slower confirmation and dirtier lethal-state behavior than the teammate

Requirements:

- same server
- same mode
- same scenario
- same capture fps if possible
- ideally 120 fps or higher for both
- same method for marking first muzzle flash and first killfeed frame

Measure:

- FCL in ms
- LPS presence / severity

Prefer:

- single-shot or simple repeatable kills
- not chaotic spray fights

### Test B: dual-POV crouch propagation test

Goal:

- test local crouch onset versus remote visible crouch onset

Protocol idea:

- fixed line of sight
- repeated crouch toggles
- change only node/route for the crouching player
- record from both sides

Why:

- crouch is discrete and easier to observe than broad duel feel

### Test C: local presentation test with route fixed

Only after route and remote-state questions are clearer:

- G-SYNC + V-SYNC + Reflex
- versus Reflex + 200 cap

Measure:

- FCL
- LPS
- MVC / BIC / PR

Do not mix this with route changes in the same session.

## 11) What should NOT be done next

Avoid these mistakes:

- do not start a rollback phase in the middle of route/coherency testing
- do not mix node changes with sync-stack changes in one block
- do not interpret baseline ICMP probes as proof of ExitLag game-route quality
- do not compare frame counts without converting to milliseconds
- do not over-question the user with large questionnaires

## 12) Communication style for the next model

Recommended approach:

- short explanations
- concrete hypotheses
- practical next steps
- preserve the user's terminology when useful, but translate it into sharper technical language

Avoid:

- generic tweak-guide tone
- pretending certainty where evidence is indirect
- long interrogations

## 13) If another model needs a one-paragraph summary

The project is no longer mainly about generic Windows "input lag" tweaks. It has shifted toward a
more precise problem: how route quality, remote-state buffering, prediction/correction, and
client-side presentation affect duel readability in VALORANT. Official Riot and Valve material has
already been studied and documented. A first route-focused framework exists, but the strongest new
signals are now a one-frame lethal enemy pose snap (`LPS`) and a large user-versus-teammate
fire-to-confirm latency gap (`FCL`, about 100 ms vs 16.7 ms in current measurements). The baseline
collector is useful for machine context but does not measure the real ExitLag-rerouted Valorant
flow. The next best step is a controlled user-versus-teammate dual-POV test focused on FCL and LPS
before going deeper into rollback or low-level OS tweaking.
