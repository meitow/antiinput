# Developer crutches study for competitive shooters

This document studies the developer-side "crutches" that make online shooters playable.

Many of these systems are necessary. The research goal is not to call them fake. The goal is to
understand:

- what problem each system solves
- what side effect it creates for competitive players
- which player observations may actually be symptoms of that system
- which parts can be tested from the outside

## 1) Confidence labels

- Confirmed: directly described in official Riot or Valve material that was reviewed for this repo
- Supported: widely established in Source-family networking material, but not fully re-verified in a
  directly fetched official page during this pass
- Hypothesis: plausible and useful, but not safe to present as settled fact yet

## 2) Five major categories of developer crutches

### 2.1 Remote-state smoothing

The game buffers, interpolates, or otherwise smooths remote movement updates so enemies do not pop
all over the screen when packets arrive unevenly.

### 2.2 Local responsiveness

The client predicts your own movement or actions so your controls do not feel delayed by the full
round trip to the server.

### 2.3 Fair hit registration

The server rewinds or reconciles past world state so players do not need to lead moving targets by
their own latency.

### 2.4 Information gating

The game may withhold data that the client should not know yet, especially to reduce cheat surface
or network cost.

### 2.5 Feedback alignment

The game may delay, predict, or cosmetically realign visual and audio feedback so the action feels
coherent, even when authority lives elsewhere.

## 3) VALORANT: confirmed developer crutches

### 3.1 Network buffering / interpolation delay

Confirmed by Riot.

Riot explicitly describes incoming movement buffering as the standard solution for smoothing uneven
network delivery. Riot also explicitly says that this buffering delays when the player sees remote
movement and therefore acts like extra latency. In the older gameplay update, Riot gives a concrete
number for this remote interpolation delay: 7.8125 ms.

What it solves:

- smoother enemy movement
- fewer visible pops on bursty or lossy routes
- fewer abrupt gaps in the remote-state stream

What it costs:

- older information on screen
- peek emergence can feel later
- movement and damage can appear slightly desynced

What players may report:

- "the game is smooth but not honest"
- "the enemy looked like he was still moving when he killed me"
- "fast peeks get worse on some routes"

Important Riot detail:

- Riot states the interpolation delay is tuneable through the in-game Network Buffering setting

This makes Network Buffering one of the cleanest developer-exposed knobs available to the player.

### 3.2 Client prediction plus server correction

Confirmed by Riot.

Riot documents that the client predicts local movement immediately and that the server corrects the
client when the two simulations disagree. Riot also documents that divergence becomes more likely
with dropped packets, burst latency, or collision edge cases.

What it solves:

- local movement feels responsive
- the player does not wait for full RTT before seeing movement

What it costs:

- corrections
- rubber-banding
- jumpy behavior when prediction was wrong

What players may report:

- "my movement felt normal but the fight felt wrong"
- "things break in close collisions or weird edge cases"
- "one bad network burst ruins a duel even if average ping is okay"

### 3.3 Fixed-timestep simulation and render decoupling

Confirmed by Riot.

Riot documents that movement and physics are simulated at a fixed 128 Hz, independent of render
framerate. The render loop then blends or interpolates state to frame boundaries.

What it solves:

- reduces client/server drift caused by different render framerates
- keeps simulation comparisons apples-to-apples

What it costs:

- another layer between server state and what the player sees
- render-side presentation can still make the game feel softer or harsher

What players may report:

- "higher FPS changed how fresh the world felt"
- "the world looked smooth, but model timing still felt strange"

### 3.4 Server move queueing and burst absorption

Confirmed by Riot.

Riot documents that the server keeps a short queue of client moves and predicts likely continuation
when updates are missing. This is a direct answer to uneven packet arrival.

What it solves:

- protects the whole match from one player with bursty delivery
- keeps the server from stalling on every late packet

What it costs:

- the route can still feel very different even at similar average ping
- bursty delivery can become prediction, then correction

What players may report:

- "same ping, different duel feel"
- "some routes make everybody ferrari peek"
- "the model speed is inconsistent rather than just delayed"

### 3.5 Server rewind for hit registration

Confirmed by Riot.

Riot documents that the server rewinds world state to what the shooter saw when the shot was taken
 and also documents that rewind has limits to prevent extreme abuse.

What it solves:

- players do not have to lead shots by their own latency
- hit registration stays close to what the shooter saw

What it costs:

- deaths behind cover
- shots that look valid on one screen and suspicious on the other

What players may report:

- "I died already behind the wall"
- "I killed him when he looked almost gone"
- "the replay makes both sides look right in different ways"

### 3.6 Animation and death-timeline alignment

Confirmed by Riot.

Riot explicitly says that network interpolation delay creates a desync between movement data and
damage data, and that this can make a player appear to be running when they actually stopped before
firing on the server. Riot also describes developer-side responses such as faster animation
blending, corpse-blocking fixes, and even delaying the death message a few milliseconds so the kill
looks more like what actually happened.

What it solves:

- makes gunfights look more coherent
- reduces the impression of impossible run-and-gun kills

What it costs:

- visuals and authority are not always the same timeline
- some feedback is partly presentation engineering

What players may report:

- "he looked fully running but the server thought he stopped"
- "what I saw was not the same as what the server resolved"

This matters a lot because some "bad netcode" complaints are really complaints about timeline
alignment between movement, damage, animation, and death presentation.

### 3.7 Fog of War / relevance gating

Confirmed by Riot.

Riot documents that VALORANT withholds enemy position data until the client should have that
knowledge. Riot also documents eventual consistency catch-up, relevance changes, invisibility and
despawn when not relevant, and a look-ahead approach to reduce pop-ins when actors become visible.

What it solves:

- drastically reduces wallhack usefulness
- reduces unnecessary network updates

What it costs:

- first reveal behavior becomes a real phenomenon
- catch-up state and state initialization can matter
- an enemy may not simply be "always there but hidden"

What players may report:

- "Valorant does not feel like games where the enemy is already fully known client-side"
- "first contact can feel abrupt"
- "some peeks feel like the model enters the world late"

Important nuance:

- Riot had to add look-ahead logic and optimistic visibility checks specifically to avoid extreme
  pop-in and accidental extra peeker's advantage

So first-reveal behavior is not just a cheat topic. It is also a competitive-feel topic.

### 3.8 Riot Direct and routing control

Confirmed by Riot.

Riot explicitly says it built Riot Direct to reduce routing delays and processing time and treats
one-way network lag and routing path as direct inputs into peeker's advantage.

What it solves:

- better path quality
- less routing overhead
- lower and more stable one-way lag for many players

What it costs:

- if the route is bad, the buffering and correction systems are stressed more often

What players may report:

- "one route feels cleaner than another at the same ping"
- "night routes feel different"
- "quality of ping matters more than quantity"

This is one reason route tools cannot be dismissed as placebo on principle. Route quality is a real
part of the latency stack.

## 4) Counter-Strike / Source-family crutches

### 4.1 Classic interpolation knobs in Source-family games

Supported.

Classic Counter-Strike networking culture made interpolation unusually visible to players because
settings such as `cl_interp` and `cl_interp_ratio` exposed the remote-buffer trade-off directly.

What it solved:

- smoother remote motion
- tolerance for packet loss and irregular update arrival

What it cost:

- more buffer meant older enemy state
- less buffer could mean pops or instability

Research implication:

- older Counter-Strike players often learned to think in terms of lerp, even when they were really
  feeling a mixture of interpolation, rewind, and remote animation

### 4.2 Lag compensation / rewind in Source-family games

Supported.

Source-family networking is historically associated with lag compensation and shot evaluation
against past target state. This is not unique to VALORANT; it is one of the standard crutches of
online shooters.

Research implication:

- "I got killed behind cover" is not enough to diagnose route quality by itself
- the visual symptom may come from a fairness system doing exactly what it was designed to do

### 4.3 CS2 sub-tick action timing

Confirmed for the basic claim that actions are timestamped more precisely.

Valve's official CS2 material says the server knows the exact instant that movement starts, a shot
is fired, or a grenade is thrown. This reduces old fixed-tick boundary problems, but it does not
remove route variance, rewind, or render delay.

Research implication:

- sub-tick improves action timing fidelity
- it does not erase the rest of the latency stack

### 4.4 CS2 feedback alignment after launch

Supported by official release-note summaries tied to Valve's site.

Post-launch, Valve described at least two important feedback-alignment changes:

- visual and audio feedback from sub-tick input would render on the next frame
- shooting spread randomization would be synchronized so tracers and decals better match
  server-authoritative trajectories

What this suggests:

- modern Counter-Strike also has a layer that tries to make feedback look right, not just be right
- impact feel and server authority are not identical signals

### 4.5 Steam Networking and Steam Datagram Relay

Confirmed by Valve documentation.

Valve's current networking docs explicitly say:

- newer APIs relay traffic through the Valve network by default
- SDR can improve ping times and connection quality for many players
- relayed paths may be better than the default Internet route

Research implication:

- route quality is a first-class engineering concern, not forum superstition
- the network path itself can be part of the solution architecture

### 4.6 CS2 damage prediction

Hypothesis for this repo at the moment.

The user-facing idea of CS2 damage prediction is widely discussed, but in this pass I did not
directly verify a clean official explanation in the fetched official sources. Treat it as an
interesting lead, not as a stable pillar of the model yet.

## 5) What these crutches mean for the user's observations

### 5.1 "Fast peek"

This can be produced by several layers at once:

- route burstiness
- remote interpolation buffer
- reveal timing / relevance gating
- local display and presentation latency

So "fast peek" is not one bug and not one metric.

### 5.2 "He looked fully running but killed me accurately"

This may be:

- move/damage desync caused by interpolation delay
- animation blend lag
- stop timing that occurred on the authoritative timeline before the remote animation caught up

This is a classic perception problem created by necessary developer crutches.

### 5.3 "Same ping, different duel feel"

Developer-side systems strongly suggest that average ping is too small a summary. Different routes
can feed very different update streams into the same smoothing and correction layers.

### 5.4 "No impact on body shots"

This may come from several different failures:

- unreadable remote model continuity
- presentation that feels delayed or cosmetically detached
- actual disagreement between what felt hittable and what the authoritative timeline resolved

This is why body-shot impact should be treated as a primary symptom, not a side note.

### 5.5 "Valorant feels different from CS in how enemies enter the client"

That idea is directionally reasonable, but it needs precise language:

- VALORANT officially uses aggressive information gating and relevance decisions
- VALORANT actors can become non-relevant and later catch up through eventual consistency
- this is not the same as saying the client literally knows nothing until a single event in every
  case, but it is a real architectural difference from the simpler way many players imagine classic
  FPS clients

So first-reveal behavior deserves its own observation lane.

## 6) What players can and cannot tune

### Reasonably testable from the player side

- route choice
- relay or path choice
- VALORANT Network Buffering
- local sync stack and FPS cap
- hardware / frametime stability

### Mostly not directly tunable from the player side

- server rewind policy
- Fog of War rules
- move queue sizing inside the game server
- animation blending rules chosen by the developer

This means a universal player product should focus on:

- identifying which crutch is most likely shaping the symptom
- selecting the cleanest player-side lever that interacts with that crutch

## 7) First hypothesis that follows from this study

The cleanest first hypothesis is:

> H1: A large share of "enemy too fast," "model speed unstable," and "body shots lack impact" is
> sensitivity to remote-state buffering quality rather than pure input delay alone.

Why this is a good first hypothesis:

- Riot documents the remote buffering layer directly
- Riot exposes a tuning knob for it in-game
- the user's strongest observations already point toward route quality and remote model behavior

That is why the first test should target remote-state buffering sensitivity before deep Windows
tweaks.

## 8) Official source anchors

- Riot - Peeking into VALORANT's Netcode  
  https://www.riotgames.com/en/news/peeking-valorants-netcode
- Riot - 04: On Peeker's Advantage & Ranked  
  https://playvalorant.com/en-us/news/game-updates/04-on-peeker-s-advantage-ranked/
- Riot - Demolishing Wallhacks with VALORANT's Fog of War  
  https://www.riotgames.com/en/news/demolishing-wallhacks-valorants-fog-war
- Valve - Steam Networking  
  https://partner.steamgames.com/doc/features/multiplayer/networking
- Valve - Steam Datagram Relay  
  https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay
- Valve - ISteamNetworkingSockets  
  https://partner.steamgames.com/doc/api/ISteamNetworkingSockets
