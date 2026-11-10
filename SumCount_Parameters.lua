local _, SC = ...

-- Ritual of Summoning in World of Warcraft: Forever (1.60.1).
-- Other Warlock summons, including demon pets, are deliberately excluded.
SC.summonSpellID = 698

-- Exact, case-insensitive chat commands; surrounding spaces are ignored.
-- !sumcount reports the requester's individual total.
SC.requestTrigger = "!sumcount"
-- !sumleaderboard reports the five most frequently summoned players.
SC.leaderboardTrigger = "!sumleaderboard"

-- Minimum time between responding to chat commands, across all senders and channels.
-- The cooldown applies to each command, not to individual lines of a leaderboard.
SC.requestCooldownSeconds = 1

-- Number of entries in chat reports. Short reports reduce channel flooding.
SC.chatLeaderboardLimit = 5
-- Number of ranked entries in the game's AddOns > Sum Count settings page.
SC.optionsLeaderboardLimit = 20
-- Delay between successive chat report lines, in seconds, to reduce throttling.
SC.reportLineDelaySeconds = 0.75

-- Spacing and alignment of the settings leaderboard, in UI pixels.
SC.optionsHorizontalPadding = 24
SC.optionsHeaderOffset = 76
SC.optionsRowSpacing = 22
SC.optionsCountRightPadding = 42
