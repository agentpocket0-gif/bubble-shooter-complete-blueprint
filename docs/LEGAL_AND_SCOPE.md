# Legal and Scope

Plain language, no legal advice. If money or a store listing is involved, talk to a lawyer in your
jurisdiction.

---

## What this repository does

- Analyses an Android package **you** obtained and place here yourself.
- Produces documentation about its structure: manifest, resources, asset inventory, level file schema,
  SDK identification.
- Ships a hand-written specification for building an original game.

## What this repository deliberately does not do

| Not done | Why |
|---|---|
| Download the package from APKPure, Uptodown, APKCombo or similar | Those sites redistribute apps without the publisher's permission. Automating a download from them makes you a party to that. |
| Publish the package or its original art/audio/fonts/levels in a release or a public repo | Redistribution of someone else's copyrighted work. The publisher owns it; you do not have a licence to redistribute. |
| Ship extracted assets into a new app | Same problem, plus a store takedown and account risk. |
| Reproduce the original app's name, icon, package id, store text or trademark | Trademark and passing-off exposure, independent of copyright. |

---

## The rules that actually matter

**1. Decompiling for study is one thing; redistributing is another.**
Analysing an app you have installed, to understand how it works, is generally treated more leniently than
copying it. Republishing the result is not. Keep the analysis private, keep the assets out of your build,
and you are on defensible ground. Publish them and you are not.

**2. Game mechanics are not copyrightable; expression is.**
A staggered grid, match-3 popping, a shot counter, a coin currency — these are ideas and systems. Nobody
owns them, and you can build a game with all of them. What you cannot do is copy the *expression*: the
specific art, the exact level layouts, the sound recordings, the code, the UI layout pixel-for-pixel, the
level names, the icon.

**3. Anti-circumvention is separate from copyright.**
In India, s.65A of the Copyright Act 1957 makes it an offence to circumvent technological protection
measures. In the US, DMCA §1201 does the same. Decrypting a protected asset bundle or stripping a DRM layer
is a different (and worse) problem than reading a plain manifest. If a package is protected, stop; do not
"just try apktool with different flags".

**4. Your own EULA obligations.**
Using an app does not grant you rights the EULA withholds. Many EULAs prohibit reverse engineering outright.
That is a contract term, not a criminal one, but it is still binding on you.

**5. Store policy is its own layer.**
Google Play's Developer Programme Policy prohibits apps that infringe intellectual property, and requires
you to be able to prove you have rights to everything you ship. A clone with recoloured sprites still fails
that test if the sprites trace back to someone else's work.

**6. Privacy law applies to your own game too.**
India's Digital Personal Data Protection Act 2023 governs any personal data you handle. If your game shows
ads, the ad SDKs collect device data — you need a privacy policy, a lawful basis, disclosure, and a deletion
route. If the audience is children, Play's Families policy adds certified-SDK and no-personalised-ads
requirements.

---

## The safe path (and it is also the faster one)

1. Run the analysis on your own copy, in a private repo, for your own understanding.
2. Take **measurements** from it, not files: target resolutions, atlas granularity, audio formats, grid
   geometry, the shape of the level data.
3. Rebuild every asset yourself, or license it, and record the source in `ASSET_CREDITS.md`.
4. Design your own economy, your own level curve, your own art direction.
5. Ship with your own package name, icon, name and store listing.

Step 2 is where nearly all the value is. Knowing that a competitor ships 2× atlases at 2048², or that their
levels are 60-bubble staggered grids with a 1.4 shot ratio, saves you weeks — and none of that is anybody's
property.
