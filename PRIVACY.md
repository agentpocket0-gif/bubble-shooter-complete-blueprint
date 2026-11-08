# Privacy Policy — Bubble Shooter: Classic Blast

_Last updated: 8 November 2026_

Package: `com.classicblast.bubbleshooter`

## What the game stores on your device

The game keeps a single save file in its own private app storage:

- level progress and stars
- coins, boosters and lives
- settings (music, sound effects, haptics)
- counters used to rate-limit advertising (last ad time, ads shown today)

It also stores a random per-install salt and an HMAC of that save file so a
hand-edited save can be detected. None of this leaves your device.

## What the game sends over the network

1. **Remote configuration.** On launch the game downloads a small JSON file from
   GitHub that says whether ads are enabled and which ad unit identifiers to use.
   This request carries no personal data — it is a plain file download.
2. **Advertising (only when enabled).** When ads are switched on, our advertising
   partners may collect a device advertising identifier and technical information
   needed to serve and measure an ad. In the EEA and UK, ads are only requested
   after you answer the consent prompt, and you can change your answer at any time
   from Settings.
3. **Purchases.** In-app purchases are processed by Google Play (or the Apple App
   Store). We receive a purchase receipt, not your payment details.

The game is fully playable offline. If no network is available, the bundled
configuration is used and no request is made.

## What we do not collect

We do not collect your name, email, contacts, photos, precise location, or any
other personal data. There is no account and no login.

## Children

The game is not directed at children under 13. Where it is distributed to a
family audience, advertising is configured for a mixed audience and personalised
ads are disabled.

## Data deletion

Uninstalling the app deletes the save file and all locally stored settings.
There is no server-side account to delete.

## Contact

Open an issue on the project repository for any privacy question.
