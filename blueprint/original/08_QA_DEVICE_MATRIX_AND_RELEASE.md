# 08 · QA, Device Matrix and Release

**Scope:** what to test, on what, in what order, and the exact steps to get the build into Play Console
without a rejection.

---

## 1. Device tiers

| Tier | Example class | Specs | Share of installs (typical) | Test priority |
|---|---|---|---|---|
| Low | Redmi 9A, Galaxy A03 | 2-3 GB RAM, Mali-G31 / Adreno 505, 720 × 1600 | ~35 % | must hold 45+ fps |
| Mid | Redmi Note 12, Galaxy M34 | 4-6 GB, Mali-G68 / Adreno 610, 1080 × 2400 | ~45 % | must hold 60 fps |
| High | Pixel 8, OnePlus 12 | 8 GB+, flagship GPU, 120 Hz | ~20 % | must hold 60 fps, no battery drain |

Test on **real hardware**, at least one device per tier. Emulators lie about GPU performance and about
touch latency, and touch latency is the whole game in a bubble shooter.

Android version coverage: API 26 (8.0), 29, 31, 33, 34, and the newest API at release time. The 31+ row matters
because of scoped storage and the notification permission; 33+ because of `POST_NOTIFICATIONS`.

---

## 2. Functional test cases

### Grid and physics

1. Shot straight up into an empty column lands in row 0, centred.
2. Shot at 75° from vertical bounces off the wall and lands correctly.
3. Three bounces in one shot (preview matches the actual path).
4. Fast shot at 30 fps does not tunnel through a bubble.
5. Shot that hits the last free cell in a row snaps to the nearest free neighbour.
6. Board full: no crash, level ends as a loss.
7. Odd/even row parity: a bubble at `(q, r)` has exactly 6 neighbours at every position, including edges.
8. Colour queue never offers a colour absent from the board.

### Matching

9. 3 in a line pops; 2 does not.
10. L-shaped and hex-shaped clusters of 3 pop.
11. Cluster that detaches a floating group: the group falls.
12. A floating group that touches the ceiling via another colour does **not** fall.
13. Popping an ice blocker reduces hp; at 0 it disappears and does not score as a bubble.
14. Chain blocker freed by an adjacent pop.
15. Two clusters popped in one shot: combo audio climbs, score sums correctly.

### State and save

16. Kill the app mid-level: reopening returns to the map, level is not counted as played.
17. Kill the app on the result screen after a win: coins and stars are already saved, not double-awarded.
18. Corrupt the save file: app starts fresh with a backup, no crash loop.
19. Save from an older version migrates forward.
20. Clock changed backwards/forwards: lives regen does not break or grant free lives infinitely.

### Economy and billing

21. Purchase completes: item granted, acknowledged, balance correct.
22. Purchase pending (cash payment): nothing granted until it clears, then granted once.
23. Kill the app between payment and grant: item granted on next launch.
24. Restore purchases on a fresh install.
25. Subscription expires: benefits removed; grace period: benefits kept.
26. Buy the same consumable twice quickly: two grants, not one, not three.

### Ads

27. No ad in the first session.
28. Rewarded ad: reward granted only after the `onUserEarnedReward` callback.
29. Rewarded ad dismissed early: no reward, no penalty, button re-enabled.
30. No ads available (no fill): fail popup still works, game continues.
31. Interstitial respects the 90 s and daily caps.
32. Consent refused in EEA: non-personalised ads only, or no ads, never a crash.
33. Airplane mode: no ANR while an ad request times out.

### Interruptions

34. Incoming call during a level: pause, resume restores exactly.
35. Home button mid-shot: shot resolves on resume, no duplicate.
36. Screen rotation (if not locked): no layout break.
37. Low memory kill during gameplay: recovers to the map.
38. Audio focus loss: music ducks, does not stop permanently.

### UI and accessibility

39. Every touch target ≥ 88 × 88 px at 1080 width.
40. Back button pops overlays before changing state.
41. Text at 200 % system font scale does not clip.
42. Safe area respected on a notched device and with a gesture bar.
43. TalkBack reads every button with a meaningful label.
44. Colour-blind check: bubbles distinguishable in deuteranopia simulation (add a pattern/shape variant if not).

---

## 3. Automated tests

| Layer | What | Tool |
|---|---|---|
| Unit | grid neighbour parity, snap selection, cluster BFS, floating BFS, scoring formula | plain test runner, no engine needed if you keep the model engine-free |
| Golden | 20 saved board states → expected pop/fall results | snapshot comparison |
| Content | every level validates, greedy solver clears it | CI step, fails the build |
| Balance | star thresholds recomputed from the solver score | CI report |
| Integration | purchase → grant → acknowledge against a mocked billing client | CI |
| Visual | key screens screenshotted at 3 resolutions, diffed | optional, catches layout regressions |

Keep the board model pure (no engine types) so the first two layers run in milliseconds on CI. This is the
single highest-value engineering decision in the project.

---

## 4. Performance profiling

Measure with the platform profiler, on the low-tier device, in a level with 80 bubbles and 200 particles.

| Metric | Target | How to check |
|---|---|---|
| Frame time | ≤ 22 ms (45 fps) low tier, ≤ 16.6 ms mid | profiler, 60 s capture |
| Draw calls | ≤ 40 | engine stats overlay |
| Resident texture memory | ≤ 80 MB | memory profiler |
| Peak heap | ≤ 120 MB | memory profiler |
| Cold start to map | ≤ 3 s low tier | `adb shell am start -W` |
| Battery, 15 min play | ≤ 4 % on mid tier | battery historian |
| APK size | ≤ 60 MB | build output |

---

## 5. Crash and ANR policy

- Integrate crash reporting (Crashlytics or Sentry) from day one, with a user id that is a random UUID, not
  an email.
- Treat any crash in the top 3 stack traces as a release blocker.
- ANRs in a game are almost always: synchronous file IO on the main thread, or a network call with no timeout.
  Set every timeout to ≤ 10 s and never block a frame on it.
- Log a breadcrumb per state transition — a crash report without the state is nearly useless.

---

## 6. Play Console release checklist

1. **App content:** privacy policy URL, data safety form (declare everything the ad SDKs collect), content
   rating questionnaire, ads declaration, target audience and content, news app = no, COVID = no.
2. **Store listing:** title ≤ 30 chars, short description ≤ 80, full description ≤ 4000, icon 512², feature
   graphic 1024 × 500, 4+ screenshots, contact email, category.
3. **Target API level:** must meet Play's current requirement (API 34 or newer at the time of writing).
4. **Data safety:** if you show ads, declare device identifiers and approximate location (ad SDKs collect
   them). A false declaration is a policy strike.
5. **Families policy:** if the app could appeal to children, either design for it (certified SDKs, no
   personalised ads) or set the target audience to 13+ explicitly.
6. **Tracks:** internal → closed (20-50 testers) → open (optional) → production, with a staged rollout
   (10 % → 50 % → 100 %).
7. **Pre-launch report:** run it. It catches crashes on real devices you do not own.

### Most common rejection reasons for a casual game

| Reason | Fix |
|---|---|
| Missing/incorrect data safety declaration | declare ad SDK collection honestly |
| Broken privacy policy link | host it, check it in an incognito window |
| Deceptive store listing (screenshots show content not in the app) | screenshots must be from the build |
| Ads shown to children | age gate or certified SDK |
| App crashes on the pre-launch device farm | fix before submitting |
| Intellectual property complaint | see `docs/LEGAL_AND_SCOPE.md` — this is the one that ends projects |

---

## 7. Definition of done

- All 44 functional cases pass on one device per tier.
- CI runs unit + golden + content + balance tests on every pull request.
- Zero crashes in a 30-minute soak test on the low tier.
- Pre-launch report is clean.
- Data safety form reviewed against the SDK list in `04_ECONOMY_AND_AD_MEDIATION.md`.
