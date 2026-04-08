# Research: low-latency gaming tweaks, rollback guidance, and why peeker's advantage feels inconsistent

Date: 2026-04-08

This report was rebuilt from scratch. It focuses on:

- Windows timer tweaks
- NIC / offload tweaks
- TCP vs UDP relevance for competitive shooters
- NVIDIA Reflex / display-latency settings
- Counter-Strike 2 peeker's advantage and "I died behind cover" style desync

Companion files in this folder:

- `rollback-suspicious-gaming-tweaks.ps1`
- `ROLLBACK-INSTRUCTIONS.txt`

## 1) Method and evidence standard

I used four evidence buckets:

- Grade A: official vendor, IETF, or academic source that I opened and read directly.
- Grade B: community source with a stated measurement method such as LDAT, high-speed camera, xperf, iperf, TimerBench, MouseTester, or synchronized capture.
- Grade C: forum discussion or anecdotal report without strong measurement controls.
- Grade D: common tweak-guide claim that I could not verify or that directly conflicts with stronger evidence.

Important rule: I did not treat forum lore as primary evidence. I used it only as supporting context, or as evidence that a tweak is highly system-dependent.

## 2) Executive summary

Short version:

1. Most TCP registry tweaks are weak or irrelevant for UDP-heavy FPS gameplay.
2. Disabling checksum offload is a bad default and conflicts with Microsoft guidance.
3. BCD timer tweaks such as `useplatformtick`, `useplatformclock`, `disabledynamictick`, and `tscsyncpolicy` are not universal wins and often make systems worse.
4. Display-pipeline tuning has much stronger evidence than low-level timer myths.
5. Peeker's advantage is real, but it is not caused by one thing. It is a stack of network latency, update rate, lag compensation, interpolation, local frame time, and display latency.
6. The safest rollback target is not "magic esports mode." It is "documented defaults plus measured per-system tuning."

## 3) High-confidence conclusions

### 3.1 Strong rollback candidates

These are the tweaks I would roll back first if they were applied without your own before/after measurements:

- `useplatformclock`
- `useplatformtick`
- `disabledynamictick`
- `tscsyncpolicy`
- `TcpAckFrequency`
- `TcpNoDelay` / `TCPNoDelay`
- `TcpDelAckTicks`
- disabled checksum offload
- disabled RSS
- disabled RSC
- hard-pinned RSS CPU placement done only because a guide said so

### 3.2 Tweaks that can be valid, but only after measurement

- Interrupt Moderation level
- RSS processor placement
- EEE / Green Ethernet / power saving on a specific NIC
- ExitLag multipath route choices
- G-SYNC + V-SYNC + Reflex combinations

### 3.3 Tweaks I would not describe as proven

- "MTU 1500 because CS2 subtick metadata needs it"
- "3 UDP / 0-1 TCP routes with less than 3 ms skew is the correct ExitLag rule"
- "CPU checksums are more accurate than NIC checksums"
- "These BCD flags force invariant TSC"

## 4) What official sources actually say

### 4.1 TCP and UDP are not the same problem

Evidence: A

Valve's Steam Networking documentation says its newer APIs relay packets through the Valve network by default and also support ordinary UDP connectivity. It describes `ISteamNetworkingMessages` as "like UDP" and `ISteamNetworkingSockets` as a connection-oriented API that still supports plain UDP over IPv4 or IPv6.

Practical implication:

- TCP tweaks matter when the traffic actually uses TCP.
- Competitive game traffic is commonly UDP-like or packet-oriented.
- So a registry tweak aimed at delayed TCP ACK behavior is usually not the main reason a gunfight feels good or bad.

What this means for CS2-style gameplay:

- Web traffic, launcher traffic, some control channels, and other apps can use TCP.
- Core real-time position / shot / movement traffic is much more likely to be UDP-style than classic TCP stream traffic.

Conclusion:

- `TcpAckFrequency`, `TcpNoDelay`, `TCP_NODELAY`, and receive-window tuning should not be treated as a primary CS2 hitreg fix.

### 4.2 What Windows says about timers and QPC

Evidence: A

Microsoft's `QueryPerformanceCounter` guidance says:

- modern Windows uses `QPC` as the primary high-resolution timestamp API;
- on modern systems, Windows usually uses an invariant/synchronized TSC as the basis for QPC;
- when TSC is not suitable, Windows automatically falls back to platform counters such as HPET or ACPI PM timer;
- platform timers have higher access latency than TSC;
- direct TSC usage is discouraged because Windows already handles timer-source choice.

Microsoft also says timer expiration is still limited by system-clock granularity and interrupt processing, even with improved relative-timer calculations.

Practical implication:

- forcing a timer source with BCD is not a documented universal optimization;
- a higher or lower reported timer frequency is not, by itself, proof of lower gaming latency;
- "Windows picked the wrong timer, so override it manually" is not a safe default assumption.

### 4.3 What Windows says about NIC offloads

Evidence: A

Microsoft's networking docs support these points:

- RSC reduces receive-path overhead by coalescing packets before the stack processes them.
- Interrupt Moderation reduces interrupt count, but can increase perceived RTT for a packet.
- RSS distributes receive processing across CPUs.
- Checksum offloads should remain enabled. Microsoft explicitly recommends enabling them and notes they are required by other stateless offloads such as RSS, RSC, and LSO.

Practical implication:

- disabling checksum offload as a generic "latency" tweak is not supported by Microsoft;
- disabling RSC or Interrupt Moderation can help some low-latency workloads, but only after system-specific testing;
- there is no official basis for claiming that CPU-side checksum math is "more accurate" than the NIC and therefore always better.

### 4.4 What NVIDIA says about Reflex and the display pipeline

Evidence: A

NVIDIA's Reflex docs and blogs support the following:

- Reflex aligns CPU and GPU work just-in-time for rendering.
- Reflex eliminates the GPU render queue and reduces CPU back pressure in GPU-bound scenarios.
- Reflex is stronger than driver-only low-latency modes because it is integrated into the game pipeline.

Microsoft's DXGI flip-model docs support the following:

- flip model is more efficient than the old blt model;
- DirectFlip and Independent Flip can bypass or reduce compositor overhead in the right conditions;
- when supported, these modes can get close to fullscreen efficiency even in windowed presentation.

Practical implication:

- display-latency tuning has real, documented engineering behind it;
- this area is much stronger than registry myths built around timer flags.

### 4.5 What Valve and academic sources say about peeker's advantage

Evidence: A

Valve's official CS2 page says sub-tick updates let the server know the exact instant that motion starts, a shot is fired, or a grenade is thrown.

That is real progress, but it does not mean latency is gone. It means action timing is represented more precisely than older fixed-tick boundaries.

The 2024 WPI paper "The Effects of Network Latency on the Peeker's Advantage in First-person Shooter Games" found:

- peeker's advantage is real;
- defender latency matters more than peeker latency;
- geometry and corner distance also matter.

Practical implication:

- "it feels like the peeker always sees me first" is not imaginary;
- however, the cause is not just ping, and not just subtick, and not just packet routing.

## 5) TCP vs UDP in plain English

### 5.1 TCP

Think of TCP like registered mail with receipts:

- packets are ordered;
- missing data is retransmitted;
- delivery is guaranteed;
- the receiver acknowledges what arrived.

That is great for correctness, but bad when old information becomes worthless if it arrives late.

If a position update is late by 150 ms, reliable retransmission does not help much in a twitch shooter. You usually need fresh state, not perfect historical delivery.

### 5.2 UDP

Think of UDP like tossing postcards quickly:

- no delivery guarantee;
- no built-in ordering guarantee;
- lower overhead;
- old packets can be dropped without stalling new ones.

Games often prefer this model because:

- one missing packet is less harmful than blocking behind a retransmit;
- new state is more valuable than old state;
- the game can build its own reliability only where needed.

### 5.3 Why this matters for Windows tweak guides

Many guides treat all network traffic like TCP traffic.

That is wrong for competitive shooters.

A tweak that changes delayed ACK behavior can matter for:

- Remote Desktop
- some launchers
- file transfer
- some TCP-based control or voice paths

But it is usually not the main lever for:

- enemy peek timing
- hit registration feel
- movement desync
- being killed behind cover

## 6) Community sources that are actually useful

### 6.1 Battle(non)sense on NVIDIA Reflex

Evidence: B

Useful because:

- he used high-speed capture and LDAT-style measurement;
- he measured button-to-pixel latency instead of guessing;
- he compared GPU-bound, frame-limited, and Reflex-enabled cases.

Key finding:

- Reflex materially reduced system latency in GPU-bound scenarios;
- Reflex did not fix V-SYNC latency when the system was not GPU-bound.

Why this matters:

- it supports NVIDIA's own claims;
- it also shows where Reflex does and does not help.

### 6.2 TheWarOwl's CS2 peeker's advantage experiment

Evidence: B

Useful because:

- he used an intentionally controlled map;
- the server environment was kept consistent;
- he synchronized both displays using a physical camera capture;
- he used VPN-based ping differentials.

Key finding:

- low-ping desync looked roughly similar between CS2 and CS:GO in his setup;
- larger ping differentials changed the perceived fairness of engagements;
- visual clarity and game feel did not always match underlying server timing.

Why this matters:

- it is not peer-reviewed academic work;
- but it is much better than "I changed one reg key and my aim felt insane."

### 6.3 Overclock.net / djdallmann xperf NIC research

Evidence: B

Useful because:

- xperf and iperf were used;
- DPC and ISR behavior was measured rather than guessed;
- interrupt moderation levels were compared with real numbers.

Important limitation:

- much of this testing used heavy TCP throughput simulation or controlled load;
- that is useful for understanding NIC behavior, but it is not the same thing as proving "best CS2 setting."

Practical takeaway:

- Interrupt Moderation absolutely changes interrupt and DPC behavior;
- the best value is workload- and hardware-dependent;
- "disabled is always best" is too simplistic.

### 6.4 Blur Busters and timer-tweak forum threads

Evidence: mostly C, with occasional B-like screenshots and TimerBench/MouseTester references

What is useful about them:

- they show the same timer tweak can help one machine and hurt another;
- several experienced posters explicitly say modern Windows often works best with default BCD timing behavior;
- a lot of negative reports cluster around `useplatformtick yes` or forced HPET combinations.

Important limitation:

- many posts are subjective;
- forum users often mix real measurement with strong personal bias;
- contradiction across systems is the norm.

Practical takeaway:

- forum disagreement is not proof that any one tweak is "secretly right";
- it is evidence that the tweak is not universal.

## 7) Tweak-by-tweak verdicts

| Tweak | Verdict | Confidence | Why |
| --- | --- | --- | --- |
| `TcpAckFrequency`, `TcpNoDelay`, `TcpDelAckTicks` | Roll back unless you have a TCP-specific reason | A/B | Primarily affects TCP behavior, while shooter gameplay is usually UDP-style |
| TCP autotuning disabled or static tiny buffers | Keep `normal` | A | Windows supports auto-tuning for modern networks; no strong CS2-specific reason to force old behavior |
| Disable checksum offload | Roll back now | A | Conflicts directly with Microsoft guidance |
| Disable RSC | Mixed; roll back unless measured benefit | A/B | Real feature with real CPU-efficiency benefits; not proven bad for all games |
| Disable RSS | Usually roll back | A | RSS is a real scaling feature and is often useful |
| Hard-pin RSS to specific cores | Mixed | A/B | Can help specific systems, but is not universal and can create contention elsewhere |
| Interrupt Moderation off / minimal | Mixed | A/B | Real trade-off between latency and interrupt load |
| Disable EEE / Green Ethernet / vendor power options | Mixed | A/C | Plausible on some NICs, but highly vendor-specific |
| `useplatformclock` | Roll back | A/C | Forcing clock source is not a vendor-recommended general optimization |
| `useplatformtick` | Roll back | A/C | Commonly reported as problematic; not a universal win |
| `disabledynamictick` | Roll back to default unless measured | A/C | Highly system-dependent and not supported by strong universal evidence |
| `tscsyncpolicy` tweaks | Roll back | D | Not supported as a general gaming optimization |
| MTU 1500 because of "CS2 subtick metadata" | Unverified | D | 1500 is standard Ethernet MTU, but the special CS2 claim is weak |
| ExitLag multipath itself | Real technology | A | Valve/Steam/ExitLag-style relayed or multipath networking is real |
| "3 UDP / 0-1 TCP with less than 3 ms skew" | Unverified rule | D | I could not verify this as an official engineering rule |

## 8) Why enemies sometimes "peek too fast"

There are multiple layers involved.

### 8.1 The peeker moves instantly on his own screen

When someone swings a corner:

- the peeker sees his own movement immediately;
- you only see that movement after network transmission, server processing, remote update, interpolation, and your own display latency.

So even before packet loss enters the picture, the moving player has a built-in timing edge.

### 8.2 Defender latency matters a lot

The WPI paper found the defender's latency can matter more than the peeker's latency.

That matches the real feeling of:

- "I held the angle and still got deleted"
- "he was visible on his screen earlier than he was visible on mine"

### 8.3 Your local PC can make peeks feel worse

Even if your ping is decent, if your system has:

- render queue buildup
- unstable frame times
- power-state oscillation
- bad display sync settings

then the peek can feel late on your side.

That is why two people with similar ping can describe the same server very differently.

### 8.4 Jitter is often more important than average ping

If your route sometimes adds 5 ms and sometimes 30 ms, the fight feels inconsistent.

This is one reason players describe:

- "sometimes everyone ferrari peeks me"
- "other times the game feels slow and readable"

Average ping is only one number. Fight feel is driven heavily by variance.

## 9) Why you sometimes kill enemies who look fully running

This is usually some combination of the following:

### 9.1 Lag compensation / server rewind

In many shooters, the server evaluates the shot against a slightly older version of the target's position, based on the shooter's view of the world when the shot was taken.

That means:

- on your screen, the enemy looked hittable;
- on his screen, he may already be further along;
- the server can still award the hit based on the rewound state.

This is one reason for:

- killing someone who looked almost behind cover;
- killing someone who looked like he was still full-running.

### 9.2 Remote animation is not the same thing as server authority

The animation you see is smoothed.

The authoritative state used for hit evaluation is not always exactly the same visual moment you are watching.

So "I shot a running body" can still be:

- valid on the server
- weird-looking to the target
- or vice versa

### 9.3 Ping difference changes who feels cheated

If the other player has much higher or much lower latency than you, the same fight can feel different from each perspective.

This is why the same match can produce both:

- "he wide swung insanely fast"
- "I killed him even though he was already gone"

Those are not contradictions. They are often two sides of the same latency-compensation system.

### 9.4 Sub-tick helps, but it is not magic

CS2's sub-tick architecture helps the server know the exact instant of actions.

That improves timing fidelity.

But it does not remove:

- geographic delay
- jitter
- lag compensation artifacts
- render/display latency
- visual smoothing

So the system can be more precise and still feel inconsistent when the total latency stack is unstable.

## 10) Practical rollback and testing plan

### Phase 1: strong rollback

Safe first actions:

- delete timer-related BCD overrides
- remove per-interface TCP ACK / Nagle-style registry tweaks
- set TCP autotuning back to `normal`
- enable global RSS / RSC / Task Offload
- enable adapter RSS / RSC / checksum offload

This is what the companion PowerShell script does by default.

### Phase 2: optional NIC factory reset

If you changed lots of NIC advanced properties and do not trust the current state:

- factory-reset advanced NIC properties on the chosen adapter(s)

Risk:

- this also removes any intentional adapter customization, not only gaming tweaks

That is why the companion script makes this step optional.

Important caveat:

- Windows has good cmdlets to enable RSS again, but not a clean universal "reset all RSS adapter placement knobs to exact factory default" cmdlet.
- If you manually changed RSS placement with `Set-NetAdapterRss` such as `BaseProcessorNumber`, `MaxProcessors`, or related profile choices, inspect `Get-NetAdapterRss` after rollback.
- If those values still look custom, use the optional NIC factory reset path, or restore the adapter driver/vendor defaults deliberately instead of guessing.

### Phase 3: reboot and measure

After rollback, reboot and evaluate:

- in-game network graph / packet loss / jitter
- frame-time consistency
- whether peeks feel more stable

If you want deeper measurement:

- xperf / Windows Performance Analyzer for DPC and ISR work
- PresentMon for frame pacing and presentation mode
- high-speed camera or LDAT-style tools for button-to-pixel latency
- TimerBench / MouseTester only as secondary context, not as the final truth

## 11) What I would keep, what I would undo, what I would test

### Keep or prefer

- NVIDIA Reflex in supported games
- sane G-SYNC / V-SYNC configuration based on whether you prioritize no tearing or absolute minimum latency
- checksum offload enabled
- RSS enabled
- autotuning normal
- flip model / fullscreen behavior that keeps frame pacing stable

### Undo unless proven on your machine

- timer-source BCD tweaks
- TCP delayed-ACK / Nagle registry tweaks done only for CS2
- checksum offload disabled
- blanket "turn everything off" NIC power / offload advice

### Test carefully, per machine

- Interrupt Moderation level
- EEE / Green Ethernet / vendor power settings
- RSS core placement
- ExitLag multipath and route choice

## 12) Verified source list

### Official vendor / standards / academic

- Microsoft - IPPROTO_TCP socket options  
  https://learn.microsoft.com/en-us/windows/win32/winsock/ipproto-tcp-socket-options
- Microsoft - TcpAckFrequency / delayed ACK behavior  
  https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/registry-entry-control-tcp-acknowledgment-behavior
- Microsoft - Overview of Receive Segment Coalescing  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-receive-segment-coalescing
- Microsoft - Interrupt Moderation  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/interrupt-moderation
- Microsoft - Overview of NDIS MSI-X  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/ndis-msi-x
- Microsoft - Set the number of RSS processors  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/setting-the-number-of-rss-processors
- Microsoft - Set-NetAdapterRss  
  https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterrss?view=windowsserver2025-ps
- Microsoft - High-performance networking / hardware-only features  
  https://learn.microsoft.com/en-us/windows-server/networking/technologies/hpn/hpn-hardware-only-features
- Microsoft - Overview of NDIS selective suspend  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-ndis-selective-suspend
- Microsoft - Standardized INF keywords for power management  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/standardized-inf-keywords-for-power-management
- Microsoft - DXGI flip model  
  https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/dxgi-flip-model
- Microsoft - For best performance, use DXGI flip model  
  https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/for-best-performance--use-dxgi-flip-model
- Microsoft - Acquiring high-resolution time stamps  
  https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps
- Microsoft - Timer Accuracy  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/timer-accuracy
- Intel - Performance Hybrid Architecture  
  https://www.intel.com/content/www/us/en/developer/articles/technical/hybrid-architecture.html
- Intel - 12th Gen Intel Core Game Dev Guide  
  https://www.intel.com/content/www/us/en/developer/articles/guide/12th-gen-intel-core-processor-gamedev-guide.html
- Intel - Interrupt Moderation Rate  
  https://edc.intel.com/content/www/us/en/design/products/ethernet/adapters-and-devices-user-guide/29.3.1/interrupt-moderation-rate/
- NVIDIA - Reflex SDK  
  https://developer.nvidia.com/reflex
- NVIDIA - Reflex SDK technical blog  
  https://developer.nvidia.com/blog/optimizing-system-latency-with-nvidia-reflex-sdk-available-now/
- NVIDIA - System latency optimization guide  
  https://www.nvidia.com/en-us/geforce/guides/system-latency-optimization-guide/
- Valve - Counter-Strike 2 official page  
  https://www.counter-strike.net/cs2
- Valve - Steam Networking  
  https://partner.steamgames.com/doc/features/multiplayer/networking
- Valve - Steam Datagram Relay  
  https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay
- Valve - ISteamNetworkingSockets  
  https://partner.steamgames.com/doc/api/ISteamNetworkingSockets
- IETF - RFC 896  
  https://datatracker.ietf.org/doc/html/rfc896
- IETF - RFC 7323  
  https://datatracker.ietf.org/doc/html/rfc7323
- IETF - RFC 2474  
  https://datatracker.ietf.org/doc/html/rfc2474
- WPI / FDG 2024 - The Effects of Network Latency on the Peeker's Advantage in First-person Shooter Games  
  https://web.cs.wpi.edu/~claypool/papers/peeker-fdg-24/

### Measurement-oriented community sources

- Battle(non)sense - NVIDIA Reflex Low Latency - How It Works & Why You Want To Use It  
  https://www.youtube.com/watch?v=QzmoLJwS6eQ
- TheWarOwl - Peeker's Advantage in CS2  
  https://www.youtube.com/watch?v=e4dQS8-9cLI
- djdallmann / GamingPCSetup - Network research  
  https://djdallmann.github.io/GamingPCSetup/CONTENT/RESEARCH/NETWORK/
- Overclock.net - Differences Between Intel Adapter Interrupt Moderation Settings  
  https://www.overclock.net/threads/differences-between-intel-adapter-interrupt-moderation-settings.1751970/
- Overclock.net - Reducing ISR DPC Processing Times for Network Adapters  
  https://www.overclock.net/threads/reducing-isr-dpc-processing-times-for-network-adapters.1743946/

### Supporting forum context only

- Blur Busters - NVIDIA Reflex thread  
  https://forums.blurbusters.com/viewtopic.php?f=10&hilit=nvidia+profile+inspector+latency+tweaks&t=7522
- Blur Busters - HPET On vs Off thread  
  https://forums.blurbusters.com/viewtopic.php?start=10&t=11951
- Blur Busters - useplatformclock / stutter thread  
  https://forums.blurbusters.com/viewtopic.php?start=10&t=13284
- Overclock.net - useplatformtick causes input lag thread  
  https://www.overclock.net/threads/win-10-1909-bcdedit-set-useplatformtick-yes-causes-input-lag.1742922/page-5
- Overclock.net - Windows 10 disable HPET thread  
  https://www.overclock.net/threads/windows-10-disable-hpet-before-install-and-enjoy-low-latencies.1567745/

## 13) Bottom line

If your goal is to make the game feel more stable and less "random":

- prioritize stable frame time, sane sync settings, and clean routing;
- stop trusting universal timer myths;
- roll back undocumented low-level overrides before chasing new tweaks;
- treat TCP registry tweaks as niche tools, not as the main CS2 answer;
- use measurements where possible, because low-latency superstition spreads faster than evidence.
