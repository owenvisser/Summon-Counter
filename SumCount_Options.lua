local _, SC = ...
local optionsPanel = CreateFrame("Frame")
local leaderboardRows = {}

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", SC.optionsHorizontalPadding, -20)
title:SetText("Summon Leaderboard")

local subtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", SC.optionsHorizontalPadding, -44)
subtitle:SetText("Account-wide top 20 by completed Ritual of Summoning casts")

for index = 1, SC.optionsLeaderboardLimit do
  local rowOffset = -(SC.optionsHeaderOffset + (index - 1) * SC.optionsRowSpacing)
  local playerLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  playerLabel:SetPoint("TOPLEFT", SC.optionsHorizontalPadding, rowOffset)
  playerLabel:SetWidth(330)
  playerLabel:SetJustifyH("LEFT")
  local countLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  countLabel:SetPoint("TOPRIGHT", -SC.optionsCountRightPadding, rowOffset)
  countLabel:SetWidth(65)
  countLabel:SetJustifyH("RIGHT")
  leaderboardRows[index] = { player = playerLabel, count = countLabel }
end

-- Populates the top 20 rows, leaving every unused rank completely blank.
-- No inputs; reads the shared account-wide summon counters.
function SC.RefreshLeaderboard()
  local rankedPlayers = SC.GetLeaderboardEntries(SC.optionsLeaderboardLimit)
  for index, row in ipairs(leaderboardRows) do
    local entry = rankedPlayers[index]
    row.player:SetText(entry and (index .. ". " .. entry.name) or "")
    row.count:SetText(entry and tostring(entry.count) or "")
  end
end

optionsPanel:SetScript("OnShow", SC.RefreshLeaderboard)
local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Sum Count")
Settings.RegisterAddOnCategory(category)
