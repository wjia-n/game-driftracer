# Drift Racer — Rules

_This document is the authoritative source of truth for Drift Racer
(`com.gameswajiha.driftracer`). If the implementation conflicts with this
document, fix the implementation — never silently modify the rules._

Toy-car drift championship: chunky die-cast cars on physical asphalt
circuits. Drift through corners, chain drifts for multipliers, beat
visible rival racers to the finish.

---

## 1. Objective

- **Race modes (Career / Quick Race):** finish the required laps ahead of
  all rival racers. Highest total score wins the podium.
- **Time Trial:** set the fastest lap over 3 solo laps.
- **Endless Drift:** score the most drift points in 120 seconds.

## 2. Setup

- The player picks a mode on the menu: Career (4 tiers), Quick Race,
  Time Trial, or Endless Drift.
- Quick Race setup: 1–4 human drivers (pass-and-play), 1–3 rival
  racers (single-driver races only), rival skill Easy/Medium/Hard
  (Hard is PRO), 1–5 laps.
- Career tiers: Novice (1 Easy rival, 2 laps), Amateur (2 Medium
  rivals, 3 laps), Pro Cup (3 Medium rivals, 4 laps), Champion
  (3 Hard rivals, 4 laps — PRO).
- Grid start: cars line up staggered behind the start/finish line,
  alternating inside/outside.
- Countdown: 3 → 2 → 1 → GO. Cars cannot move before GO.

## 3. Turn order

- Real-time racing — there are no turns. All cars move simultaneously
  at 60 simulation ticks per second.
- Pass-and-play (2–4 drivers): drivers race **sequentially**, each a
  solo 2-lap time trial. Fastest total time wins; ties broken by best
  single lap, then drift score.

## 4. Legal moves

- **Steer:** drag left/right anywhere on the track to steer.
- **Drift:** HOLD the skid button while steering (steering input must
  exceed ~22%) and above ~42% of top speed to enter a drift.
- **Boost:** release the drift button with charge above 35% to trigger
  a speed boost (1.4×–2.4 s depending on charge).
- **Chain:** ending a drift with charge above 12% banks a chain link;
  starting the next drift within 1.4 s continues the chain and raises
  the drift-score multiplier (+50% per link, up to 4×).
- Drifting through corners preserves more speed than gripping.

## 5. Illegal moves

- Steering input before GO is ignored (cars are held on the grid).
- Drift requires steering input, speed, and being on the asphalt —
  holding the button on a straight at low speed does nothing.
- Leaving the track (grass) is allowed but penalized, not illegal.

## 6. Captures

- Not applicable — no captures in Drift Racer. Cars cannot collide;
  they race as ghosts on the same circuit (positions decided by
  distance).

## 7. Special rules

- **Off-track (grass):** speed is dragged down toward 30% of top
  speed, the drift chain resets to zero, and a rumble sounds.
- **Fence:** pushing past the track edge clamps the car, cuts speed
  to 55%, and plays a crash thud (0.9 s cooldown between hits).
- **Boost:** 1.38× top speed while active; cannot stack (releasing a
  drift mid-boost does not extend it).
- **Chain gap:** more than 1.4 s between drift segments resets the
  chain to zero.
- **AI rivals** visibly drift on corners per their skill tier
  (Easy never drifts, Medium sometimes, Hard aggressively chains),
  with smoke, skid marks, and narration.

## 8. Scoring

- **Race modes:** position points (1st 1000, 2nd 700, 3rd 500, 4th 350)
  + drift points (rounded) = total.
- **Drift points:** accumulate while drifting at
  `speed × 0.9 × (1 + 0.5 × chain-links)` per second.
- **Time Trial:** scored by lap times only; best lap persisted.
- **Endless Drift:** scored by drift points only; best score persisted.
- **Hot-seat:** each driver's score = drift points; standings by
  total race time.

## 9. Winning conditions

- **Career / Quick Race:** the driver with the highest total score
  after all laps wins. Career wins at 1st place unlock the next tier
  and award stars (1st = 3★, 2nd = 2★, 3rd/4th = 1★).
- **Time Trial:** beating your stored best lap sets a new record.
- **Endless Drift:** beating your stored best score sets a new record.
- **Hot-seat:** lowest total 2-lap time across all drivers wins.

## 10. Draw conditions

- **Hot-seat:** identical total times are broken by best single lap,
  then drift score; a perfect tie shares the podium place.
- Other modes cannot draw — scores and times are continuous.

## 11. AI strategy

Rival racers follow a racing line with per-difficulty skill:

- **Easy:** 82% of player top speed, lazy steering corrections,
  never drifts, occasional wobble mistakes.
- **Medium:** 95% of player top speed, firm corrections, drifts on
  sharp corners ~55% of the time, cuts to the inside line.
- **Hard:** 106% of player top speed, sharp corrections, drifts
  aggressively (~90%) and chains drifts, steers harder mid-drift.
- All AI re-decides steering/drift every 0.15 s (0.3 s on Easy),
  aims for the inside on corners, and visibly smokes/skids when
  drifting.

## 12. Edge cases

- The race ends when the human finishes (rivals get a 2 s grace to
  complete their lap) or when every car finishes — whichever first.
- A race can never run longer than 15 minutes (engine safety net
  forces the finish).
- Pausing freezes the simulation; the watchdog never mistakes a
  pause for a stuck state.
- Backgrounding the app mid-race auto-pauses.
- Restart resets grid, laps, scores, chains, and the countdown.
- If a rival finishes before the player, it keeps cruising visually
  until the results.
- Audio interruptions pause music/SFX and resume them afterwards;
  audio can never crash the app.

## 13. Test cases

1. Countdown 3-2-1-GO plays beeps then the start horn; cars are
   frozen before GO.
2. Holding drift with steering on a corner shows smoke, lays skid
   marks, builds charge, and scores drift points.
3. Releasing drift at high charge triggers a visible boost flame and
   speed surge.
4. Chaining two drifts within 1.4 s raises the multiplier; waiting
   longer resets it.
5. Driving onto grass slows the car, rumbles, and breaks the chain.
6. Hitting the fence clamps the car and plays the crash thud.
7. Easy rivals never drift; Hard rivals visibly drift and chain.
8. Overtaking a rival announces the new position; being passed
   announces the rival.
9. Winning a Career tier unlocks the next tier and awards stars;
   Champion tier requires PRO.
10. Time Trial stores a new best lap only when beaten.
11. Renaming a driver persists across app restarts, in order.
12. Hard skill, PRO themes/cars/tracks, and the theme creator stay
    locked until PRO is purchased.
13. Purchases use real product IDs (`driftracerpro`,
    `driftracercoffee`, `driftracerchocolate`); unconfigured store
    shows an honest "available after store setup" state.
14. Pause → background → resume never loses race state or stucks.
