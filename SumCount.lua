local _, SC = ...
local pendingTargets = {}
local lastResponseTime
local isWarlock = false
local eventFrame = CreateFrame("Frame")

-- Converts a potentially realm-qualified name to the existing lowercase saved-variable key.
-- playerName: the name supplied by a Blizzard spellcast or chat event.
local function getPlayerKey(playerName)
  return playerName and playerName:match("^[^-]+"):lower()
end

-- Builds the highest-count entries, sorted by total then name, from account-wide counters.
-- maximumEntries: maximum number of ranked players to return.
function SC.GetLeaderboardEntries(maximumEntries)
  local rankedPlayers = {}
  if type(SumCountAccountDB) ~= "table" or type(SumCountAccountDB.counts) ~= "table" then
    return rankedPlayers
  end
  for playerKey, summonCount in pairs(SumCountAccountDB.counts) do
    if type(playerKey) == "string" and type(summonCount) == "number" and summonCount > 0 then
      local displayName = SumCountAccountDB.names and SumCountAccountDB.names[playerKey]
      if not displayName then
        displayName = playerKey:sub(1, 1):upper() .. playerKey:sub(2)
      end
      rankedPlayers[#rankedPlayers + 1] = { name = displayName, count = summonCount, key = playerKey }
    end
  end
  table.sort(rankedPlayers, function(firstPlayer, secondPlayer)
    if firstPlayer.count == secondPlayer.count then
      return firstPlayer.key < secondPlayer.key
    end
    return firstPlayer.count > secondPlayer.count
  end)
  for index = #rankedPlayers, maximumEntries + 1, -1 do
    rankedPlayers[index] = nil
  end
  return rankedPlayers
end

-- Sends an answer using the requested channel, whispering if /say or /yell becomes protected.
-- message: outgoing text; chatType: Blizzard chat token; recipient: whisper name or channel index;
-- senderName: requester to whisper if the player leaves an instance during a delayed report.
local function sendResponseLine(message, chatType, recipient, senderName)
  if chatType == "CHANNEL" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffSum Count:|r /" .. tostring(recipient) .. " " .. message)
    return
  end
  if (chatType == "SAY" or chatType == "YELL") and not IsInInstance() then
    C_ChatInfo.SendChatMessage(message, "WHISPER", nil, senderName)
    return
  end
  C_ChatInfo.SendChatMessage(message, chatType, nil, recipient)
end

-- Resolves the reply channel and a warning when a public outdoor reply must become a whisper.
-- event: chat event name; senderName: original author; channelIndex: custom-channel number.
local function getReplyDestination(event, senderName, channelIndex)
  local chatType = event:sub(10)
  if chatType == "PARTY_LEADER" then
    return "PARTY"
  elseif chatType == "RAID_LEADER" then
    return "RAID"
  elseif chatType == "INSTANCE_CHAT_LEADER" then
    return "INSTANCE_CHAT"
  elseif chatType == "WHISPER" then
    return "WHISPER", senderName
  elseif chatType == "CHANNEL" then
    if channelIndex and tonumber(channelIndex) and tonumber(channelIndex) > 0 then
      return "CHANNEL", tonumber(channelIndex)
    end
    return nil
  elseif (chatType == "SAY" or chatType == "YELL") and not IsInInstance() then
    local channelName = chatType == "YELL" and "/yell" or "/say"
    return "WHISPER", senderName, "Cannot speak in " .. channelName .. " outdoors, sorry! Replying by whisper."
  end
  return chatType
end

-- Tracks completed Ritual of Summoning casts and responds to both chat commands.
-- event: Blizzard event; ...: the event's original payload.
eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    isWarlock = select(2, UnitClass("player")) == "WARLOCK"
    if type(SumCountDB) ~= "table" then
      SumCountDB = {}
    end
    if type(SumCountNamesDB) ~= "table" then
      SumCountNamesDB = {}
    end
    if type(SumCountAccountDB) ~= "table" then
      SumCountAccountDB = {}
    end
    if type(SumCountAccountDB.counts) ~= "table" then
      SumCountAccountDB.counts = {}
    end
    if type(SumCountAccountDB.names) ~= "table" then
      SumCountAccountDB.names = {}
    end
    -- Import the old character-specific counts exactly once per character.
    -- Other characters' old data is imported on their first login after upgrading.
    if not SumCountLegacyMigrated then
      for playerKey, summonCount in pairs(SumCountDB) do
        if type(playerKey) == "string" and type(summonCount) == "number" and summonCount > 0 then
          SumCountAccountDB.counts[playerKey] = (SumCountAccountDB.counts[playerKey] or 0) + summonCount
          local displayName = SumCountNamesDB[playerKey]
          if type(displayName) == "string" and displayName ~= "" then
            SumCountAccountDB.names[playerKey] = displayName
          end
        end
      end
      SumCountLegacyMigrated = true
    end
    return
  end

  -- Only Warlocks track casts; all characters may receive chat commands.
  if event == "UNIT_SPELLCAST_SENT" then
    if not isWarlock then return end
    local unit, targetName, castGUID, spellID = ...
    if unit == "player" and spellID == SC.summonSpellID and castGUID then
      if not targetName or targetName == "" then
        if UnitIsPlayer("target") then
          targetName = UnitName("target")
        end
      end
      if targetName and targetName ~= "" then
        local playerName = targetName:match("^[^-]+")
        local playerKey = playerName:lower()
        pendingTargets[castGUID] = playerKey
        SumCountAccountDB.names[playerKey] = playerName
      end
    end
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if not isWarlock then return end
    local unit, castGUID, spellID = ...
    if unit == "player" and spellID == SC.summonSpellID then
      local targetKey = pendingTargets[castGUID]
      if targetKey then
        SumCountAccountDB.counts[targetKey] = (SumCountAccountDB.counts[targetKey] or 0) + 1
        if SC.RefreshLeaderboard then
          SC.RefreshLeaderboard()
        end
      end
      pendingTargets[castGUID] = nil
    end
    return
  end

  if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    if not isWarlock then return end
    local unit, castGUID = ...
    if unit == "player" then
      pendingTargets[castGUID] = nil
    end
    return
  end

  local message, senderName = ...
  if not message or not senderName then
    return
  end
  local command = message:match("^%s*(.-)%s*$"):lower()
  if command ~= SC.requestTrigger and command ~= SC.leaderboardTrigger then
    return
  end
  -- Anyone may request a count; only a Warlock can send the reply.
  if not isWarlock then
    return
  end
  local senderKey = getPlayerKey(senderName)
  if not senderKey or senderKey == getPlayerKey(UnitName("player")) then
    return
  end

  local chatType, recipient, outdoorWarning = getReplyDestination(event, senderName, select(8, ...))
  if not chatType then
    return
  end
  local currentTime = GetTime()
  if lastResponseTime and currentTime - lastResponseTime < SC.requestCooldownSeconds then
    return
  end
  lastResponseTime = currentTime
  if outdoorWarning then
    C_ChatInfo.SendChatMessage(outdoorWarning, "WHISPER", nil, senderName)
  end
  if command == SC.requestTrigger then
    local displayName = senderName:match("^[^-]+")
    local response = "I have summoned " .. displayName .. " " .. (SumCountAccountDB.counts[senderKey] or 0) .. " times."
    sendResponseLine(response, chatType, recipient, senderName)
    return
  end

  local rankedPlayers = SC.GetLeaderboardEntries(SC.chatLeaderboardLimit)
  if #rankedPlayers == 0 then
    sendResponseLine("No summons recorded yet.", chatType, recipient, senderName)
    return
  end
  for index, player in ipairs(rankedPlayers) do
    local response = index .. ". " .. player.name .. " " .. player.count
    if index == 1 then
      sendResponseLine(response, chatType, recipient, senderName)
    else
      C_Timer.After((index - 1) * SC.reportLineDelaySeconds, function()
        sendResponseLine(response, chatType, recipient, senderName)
      end)
    end
  end
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("CHAT_MSG_SAY")
eventFrame:RegisterEvent("CHAT_MSG_YELL")
eventFrame:RegisterEvent("CHAT_MSG_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_RAID")
eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_GUILD")
eventFrame:RegisterEvent("CHAT_MSG_OFFICER")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
