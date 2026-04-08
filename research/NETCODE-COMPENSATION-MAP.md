# Netcode compensation map

This file is not a final claim sheet.

It is a research map for understanding the "crutches" or compensation systems that developers use
to keep online shooters playable. Many of these systems are necessary. The point is to understand
what they solve, what they hide, and what they can distort from the player's point of view.

## 1) Confidence labels

- Confirmed: directly described in official developer material
- Supported: not fully official, but backed by strong measurement-oriented material
- Hypothesis: plausible, useful to test, but not safe to claim as fact yet

## 2) Why this matters

When a player says:

- "the enemy peeked too fast"
- "body shots had no impact"
- "the game was smooth but not honest"
- "same ping, different duel feel"

the answer may be hidden inside a compensation layer rather than a single latency number.

## 3) Compensation systems that matter

| Mechanism | Why developers use it | What it solves | What players may feel instead | Game examples | Confidence | What to log |
| --- | --- | --- | --- | --- | --- | --- |
| Interpolation buffer | Smooth uneven incoming movement updates | Reduces visible pops from late or missing packets | Older world state, model-speed catch-up, "running while accurate" look | CS:GO `cl_interp` / `cl_interp_ratio`, VALORANT Network Buffering | Confirmed for VALORANT, Supported for Source-family behavior | RTT variance, model velocity continuity, peek readability |
| Client-side prediction | Make local movement and actions feel immediate | Hides local round-trip delay from the local player | Corrections, rubber-banding, disagreement at collision extremes | Source-family prediction, VALORANT fixed-timestep client prediction | Confirmed for VALORANT, Supported generally | Local corrections, collision clips, self-movement mismatch |
| Server rewind / lag compensation | Judge hits against what the shooter saw | Prevents variable lead requirements on moving targets | Deaths behind cover, hits on targets that looked almost gone | Source-family lag compensation, VALORANT rewind limits | Confirmed for VALORANT, Supported generally | Clip timestamp, cover distance, both player pings if known |
| Feedback prediction | Show hit feedback before full confirmation | Makes combat feedback feel immediate | Visual or audio impact can disagree with authority | CS2 damage-prediction-like features, predicted hit feedback more broadly | Hypothesis for CS2-specific product details here, Supported as a design pattern | Local hit feedback versus actual damage outcome |
| Interest management / Fog of War | Hide data the client should not know and reduce cheat surface | Prevents wallhack-style information exposure | First reveal can feel abrupt if entity state becomes relevant late | VALORANT Fog of War | Confirmed | First visible frame, wide-swing emergence behavior |
| Server move queue / network buffering | Keep a short queue of client updates on the server | Smooth bursty arrival and protect match quality from one bad client | One player can still feel correction or delay when their route is bursty | VALORANT minimal server buffering and queued moves | Confirmed | Time of day, route target, p95/p99 latency, burst notes |
| Presentation buffering | Stabilize frame pacing and reduce tearing | Makes image delivery more consistent | Game can feel smooth but less direct | V-SYNC, VRR, Reflex integration | Confirmed as a general rendering trade-off | Sync stack, cap, MCR, body-shot impact notes |

## 4) Important examples

### 4.1 CS:GO and classic interpolation knobs

The Source-family model made interpolation visible enough that players learned to talk about it
directly through commands such as `cl_interp` and `cl_interp_ratio`.

Why that matters:

- the player could influence how much remote-state buffering existed
- the trade-off was clear: more buffer often meant smoother remote movement but more delay
- a lot of old FPS tweak culture was built around trying to minimize this buffer

Research implication:

- when older players describe "clean" versus "muddy" online feel, they are often talking about
  interpolation, rewind, and remote animation without naming them explicitly

### 4.2 CS2 and cosmetic feedback alignment

CS2 reduced some old tick-boundary issues with sub-tick action timing, but this does not remove:

- route variance
- rewind artifacts
- visual smoothing
- local render latency

There are also player-facing signs that modern Counter-Strike uses more cosmetic alignment and
prediction than old CS:GO did. Some of that is documented, some is only observable through updates
or settings, and some is still too fuzzy to treat as fact.

Research implication:

- separate "the server registered the shot" from "the client rendered feedback that felt right"
- never assume impact feel and server truth are the same signal

### 4.3 VALORANT and network buffering

Riot directly documents that incoming movement data is buffered to smooth the uneven stream of
network updates, and that the amount of buffering is a real trade-off:

- more smoothing
- less visible popping
- but also older information reaching the screen

Riot also documents:

- fixed 128 Hz simulation steps for movement logic
- client prediction and correction
- server rewind for hit registration
- limits on rewind to prevent extreme abuse

Research implication:

- if a player reports "the enemy is too fast" on one route and readable on another, do not jump
  straight to ping; ask whether the route changed the quality of the buffered stream

### 4.4 VALORANT Fog of War

Riot has also documented a Fog of War system that withholds enemy information from clients until
the game decides the client should have that knowledge.

Research implication:

- first reveal behavior matters
- visibility timing and state initialization may deserve their own observation lane
- "abrupt first contact" is not automatically the same as bad internet

## 5) Questions this map is meant to answer

1. When the enemy model accelerates suddenly, is that:
   - geometry,
   - interpolation catch-up,
   - route burst,
   - or client-side presentation?
2. When body-shot impact disappears, is the problem:
   - route quality,
   - local presentation,
   - predicted feedback mismatch,
   - or actual server disagreement?
3. Can the same ping produce different duel feel because:
   - one route is more bursty,
   - one path is asymmetric,
   - or one client preset makes buffered data feel less readable?
4. Do "smooth" presets hide model instability while making timing feel less honest?
5. Which compensation layers are fixed by the game, and which ones can realistically be tuned on
   the player's machine?

## 6) What a universal product should eventually model

The end goal should not be "lowest latency wins."

It should estimate:

- route quality
- client presentation state
- compensation-sensitive symptoms
- confidence that a tweak helped for the right reason

That means the product should eventually combine:

1. route probes
2. machine-state snapshots
3. replay annotations
4. repeated A/B blocks

## 7) Guardrail

Do not claim a compensation system is broken just because it creates ugly moments.

Many of these systems exist because the alternative is worse:

- no interpolation means more visible pops
- no prediction means sluggish local movement
- no rewind means moving targets require variable leading
- no information gating makes cheating easier

The research target is not "remove every crutch."

The target is:

- identify which crutch is shaping the symptom
- identify which side effect matters most for competitive play
- identify which player-side tweaks actually improve the outcome

## 8) Evidence anchors to revisit

Use these as starting points when a hypothesis needs grounding:

- Riot tech article: `https://technology.riotgames.com/news/peeking-valorants-netcode`
- Riot gameplay update on peeker's advantage and network buffering:
  `https://playvalorant.com/en-us/news/game-updates/04-on-peeker-s-advantage-ranked/`
- Existing repo research: `gaming-network-tweaks-research.md`

For Counter-Strike-specific interpolation and lag-compensation details, use official or archived
Valve material carefully and keep a hard line between:

- documented behavior
- engine-community explanations
- player folklore
