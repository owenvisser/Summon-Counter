# Sum Count

Small Warlock summon counter for World of Warcraft: Forever (1.60.1, interface 16001).

## Install

1. Replace the existing `SumCount` folder in `World of Warcraft/_forever_/Interface/AddOns/` with the folder in this ZIP.
2. Start or reload WoW and make sure **Sum Count** is enabled in the AddOns list.
3. Open **Esc > Options > AddOns > Sum Count** to view the top 20 summoned players across your account.
4. **If you used v1.1 on multiple characters, log into each character once** after updating to import its prior per-character counts into the shared totals. Log out or `/reload` between characters so the shared counts are saved.

## How it works

- **Command requests:** Any player, regardless of class or whether they have the addon, can type `!sumcount` or `!sumleaderboard` in a supported chat channel. The addon listens for those requests on every class, but **only a character logged in as a Warlock sends the response**. Non-Warlocks also do not track summons; the options leaderboard remains viewable.
- Successful player-targeted casts of **Ritual of Summoning** (spell ID 698) increase the target's account-wide count by one. Interrupted, failed, and unrelated casts are not counted.
- `!sumcount` replies with the requesting player's total across characters (zero when none are recorded).
- `!sumleaderboard` prints up to five numbered chat messages, highest count first, e.g. `1. Aria 14`, `2. Rex 8`. When there are no records, it says `No summons recorded yet.`
- **A single global 1-second cooldown** applies to `!sumcount` and `!sumleaderboard` across all requesters and chat channels. A request during that second is ignored. This cooldown is checked per command, not per leaderboard line.
- Replies use the **same channel that received the request**, including party, raid, guild, whispers, and others. Numbered channels preserve the originating channel number.
- **Outdoor `/say` and `/yell` requests:** Blizzard prevents addons from automatically replying in these channels outdoors. Instead, the requester gets a whisper saying `Cannot speak in /say outdoors, sorry! Replying by whisper.` (or `/yell`), followed by the summon count or up to five leaderboard lines in whispers. Inside dungeons, raids, and other instances, replies continue in `/say` or `/yell`.
- **Numbered channels:** These remain hardware-protected even indoors, so requests made in `/1`, `/2`, etc. show the response only in the addon owner's chat as manually sendable text.
- The options page shows the shared account-wide top 20, with unused ranks blank. It refreshes on opening and after completed casts.
- Counts are saved **per WoW account**, not per character. Old character-specific `SumCountDB` and `SumCountNamesDB` data from v1.0/v1.1 is imported once per character, without changing the original old tables. `SumCountLegacyMigrated` prevents double-imports on later logins.
- Counts reflect completed spell casts, not whether the two helpers clicked the portal or whether the target accepted the summon.
- Names are matched without realm suffixes, as in v1.1. Same-name players on different realms are combined.

## Files

- `SumCount.toc`: manifest and account-wide storage declaration, plus legacy migration fields.
- `SumCount_Parameters.lua`: spell, chat triggers, cooldown, leaderboard sizes, timing, and UI spacing.
- `SumCount.lua`: cast tracking, migration, sorting, and channel-aware chat responses.
- `SumCount_Options.lua`: settings page with 20 leaderboard rows.
