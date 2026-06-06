--[[ src/timer.lua ]]--

local List = {}
function List.new()
	return {
		first = 0,
		last = -1
	}
end

function List.pushleft(list, value)
	local first = list.first - 1
	list.first = first
	list[first] = value
end

function List.pushright(list, value)
	local last = list.last + 1
	list.last = last
	list[last] = value
end

function List.popleft(list)
	local first = list.first
	if first > list.last then
		return nil
	end
	local value = list[first]
	list[first] = nil -- to allow garbage collection
	list.first = first + 1
	return value
end

function List.popright(list)
	local last = list.last
	if list.first > last then
		return nil
	end
	local value = list[last]
	list[last] = nil -- to allow garbage collection
	list.last = last - 1
	return value
end

-- the lib
local timerList = {}
local timersPool = List.new()

function addTimer(callback, ms, loops, label, ...)
	local id = List.popleft(timersPool)
	if id then
		local timer = timerList[id]
		timer.callback = callback
		timer.label = label
		timer.arguments = { ... }
		timer.time = ms
		timer.currentTime = 0
		timer.currentLoop = 0
		timer.loops = loops or 1
		timer.isComplete = false
		timer.isPaused = false
		timer.isEnabled = true
	else
		id = #timerList + 1
		timerList[id] = {
			callback = callback,
			label = label,
			arguments = { ... },
			time = ms,
			currentTime = 0,
			currentLoop = 0,
			loops = loops or 1,
			isComplete = false,
			isPaused = false,
			isEnabled = true
		}
	end
	return id
end

function getTimerId(label)
	local found
	for id = 1, #timerList do
		local timer = timerList[id]
		if timer.label == label then
			found = id
			break
		end
	end
	return found
end

function pauseTimer(id)
	if type(id) == "string" then
		id = getTimerId(id)
	end

	if timerList[id] and timerList[id].isEnabled then
		timerList[id].isPaused = true
		return true
	end
	return false
end

function resumeTimer(id)
	if type(id) == "string" then
		id = getTimerId(id)
	end

	if timerList[id] and timerList[id].isPaused then
		timerList[id].isPaused = false
		return true
	end
	return false
end

function removeTimer(id)
	if type(id) == "string" then
		id = getTimerId(id)
	end

	if timerList[id] and timerList[id].isEnabled then
		timerList[id].isEnabled = false
		List.pushright(timersPool, id)
		return true
	end
	return false
end

function clearTimers()
	local timer
	repeat
		timer = List.popleft(timersPool)
		if timer then
			table.remove(timerList, timer)
		end
	until timer == nil
end

function timersLoop()
	for id = 1, #timerList do
		local timer = timerList[id]
		if timer.isEnabled and timer.isPaused == false then
			if not timer.isComplete then
				timer.currentTime = timer.currentTime + 500
				if timer.currentTime >= timer.time then
					timer.currentTime = 0
					timer.currentLoop = timer.currentLoop + 1
					if timer.loops > 0 then
						if timer.currentLoop >= timer.loops then
							timer.isComplete = true
							if eventTimerComplete ~= nil then
								eventTimerComplete(id, timer.label)
							end
							removeTimer(id)
						end
					end
					if timer.callback ~= nil then
						timer.callback(timer.currentLoop, table.unpack(timer.arguments))
					end
				end
			end
		end
	end
end



--[[ src/main.lua ]]--

tfm.exec.disableAutoShaman(true)
tfm.exec.disableAutoNewGame(true)
tfm.exec.disableAutoScore(true)
tfm.exec.disableAutoTimeLeft(true)
tfm.exec.disablePhysicalConsumables(true)
tfm.exec.disableAfkDeath(true)
tfm.exec.setRoomMaxPlayers(16)
system.disableChatCommandDisplay(nil, true)
tfm.exec.disableMortCommand(true)

local permanentAdmins = {
	["Refletz#6472"] = true,
	["Soristl1#0000"] = true
}

local admins = {
	["Refletz#6472"] = true,
	["Soristl1#0000"] = true
}

local x = { 70, 275, 70, 275, 70, 275, 480, 685, 480, 685, 480, 685 }
local y = { 340, 340, 400, 400, 460, 460, 340, 340, 400, 400, 460, 460 }
local playersInGame = {}

local playerDisableWall = {}
local playerDelayWall = {}
local playerCanGetBall = {}
local playerTeam = {}
local playerForce = {}
local playerPressSpace = {}
local keys = { 0, 1, 2, 3, 32, 76 }
local ballOwner = ""
local ballOwnerPressDown = false
local playerLastShoot = ""
local playerLastPass = ""
local canCatchBall = true
local ballIdImage = 999999
local ballCanShoot = false
local playerArrowImage = 0
local lastBallCoordX = 0
local isPlayerDirectionRight = {}
local disableVerifyBall = false
local increaseXBall = 10
local increaseYBall = 5
local increaseXPlayer = 10
local increaseYPlayer = 5
local rankSettings = {}
local rankPlayer = {}
local rankPlayerMatch = {}
local playerTeamHistory = {}
local rankRoom = {}
local delayCountPass = {}
local lastPlayerKey = {}
local canPass = true
local rankingSelected = {}
local timerCanCatchBall = false



--[[ src/events/eventChatCommand.lua ]]--

function eventChatCommand(name, c)
	local command = string.lower(c)
	if mode == "lobby" then
		if string.sub(command, 1, 9) == "stoptimer" and permanentAdmins[name] then
			local args = split(command)

			if args[2] ~= "true" or args[2] ~= "false" then
				print("<bv>Invalid second parameter must be true or false<n>")
			end

			if args[2] == "true" then
				gameStats.stopTimer = true

				return
			end

			lobbyTimer = os.time() + (gameStats.stopTimerSeconds * 1000)
			gameStats.stopTimer = false
		elseif command == "skiptimer" and admins[name] then
			lobbyTimer = os.time() + 5000
		elseif command == "resettimer" and admins[name] then
			lobbyTimer = os.time() + 15000
		elseif string.sub(command, 1, 9) == "autostart" then
			local args = split(command)

			if args[2] ~= "true" and args[2] ~= "false" then return end

			if args[2] == "false" then
				minPlayerRed = 1
				minPlayerBlue = 1

				return
			end

			minPlayerRed = 0
			minPlayerBlue = 0
		end
	elseif mode == "game" then
		if string.sub(command, 1, 2) == "fs" then
			local args = split(command)

			vx1 = tonumber(args[2])
			vy1 = tonumber(args[3])

			t1 = true
		elseif command == "px" then
			local x = tfm.get.room.playerList[name].x
			local y = tfm.get.room.playerList[name].y

			print("X: " .. tostring(x))
			print("Y: " .. tostring(y))
		elseif command == "ball" then
			local ballData = tfm.get.room.objectList[ball_id]

			if ballData == nil then return end

			local x = tfm.get.room.objectList[ball_id].x
			local y = tfm.get.room.objectList[ball_id].y

			print("===")
			print("BALL COORDS")
			print("X: " .. tostring(x))
			print("Y: " .. tostring(y))
			print("===")
		elseif string.sub(command, 1, 5) == "arrow" and permanentAdmins[name] then
			local args = split(command)

			if args[2] == nil then return end

			if args[2] == "true" then
				removeTimer("arrow")

				addTimer(
					function(i)
						local ballData = tfm.get.room.objectList[ball_id]
						local player = tfm.get.room.playerList[ballOwner]

						if ballOwner ~= "" then
							if player == nil then return end

							local x = player.x + (player.vx * increaseXPlayer)
							local y = player.y + (player.vy * increaseYPlayer)

							tfm.exec.addShamanObject(0, x, y, 0, 0, 0, true)
						else
							if ballData == nil then return end

							local x = ballData.x + (ballData.vx * increaseXBall)
							local y = ballData.y + (ballData.vy * increaseYBall)

							tfm.exec.addShamanObject(0, x, y, 0, 0, 0, true)
						end
					end,
					500,
					0,
					"arrow"
				)

				return
			end

			if args[2] == "false" then
				removeTimer("arrow")

				return
			end
		elseif command == "join" and not playersInGame[name] then
			local quantity = quantityPlayers()

			print(quantity.red)
			print(quantity.blue)

			if quantity.red > quantity.blue and quantity.blue ~= 6 then
				for i = 1, #playersBlue do
					if playersBlue[i].name == "" then
						playersBlue[i].name = name

						playersInGame[name] = true
						playerTeam[name] = {
							team = "blue",
							index = i
						}

						createMatchRankingPlayer(name, "blue")

						local foundTeam = false

						for i = 1, #playerTeamHistory[name] do
							local team = playerTeamHistory[name][i]

							if team == "blue" then
								foundTeam = true

								break
							end
						end

						if not foundTeam then
							local length = #playerTeamHistory[name]

							playerTeamHistory[length + 1] = "blue"
							rankPlayer[name].matches = rankPlayer[name].matches + 1
							rankPlayerMatch[name].matches = rankPlayerMatch[name].matches + 1
						end

						teleportPlayerToTeam(name)

						playerCanGetBall[name] = false

						canCatch = addTimer(
							function(i)
								if i == 1 then
									playerCanGetBall[name] = true
								end
							end,
							1500,
							1,
							"canCatch"
						)

						return
					end
				end
			elseif quantity.blue > quantity.red and quantity.red ~= 6 then
				for i = 1, #playersRed do
					if playersRed[i].name == "" then
						playersRed[i].name = name

						playersInGame[name] = true
						playerTeam[name] = {
							team = "red",
							index = i
						}

						createMatchRankingPlayer(name, "red")

						local foundTeam = false

						for i = 1, #playerTeamHistory[name] do
							local team = playerTeamHistory[name][i]

							if team == "red" then
								foundTeam = true

								break
							end
						end

						if not foundTeam then
							local length = #playerTeamHistory[name]

							playerTeamHistory[length + 1] = "red"
							rankPlayer[name].matches = rankPlayer[name].matches + 1
							rankPlayerMatch[name].matches = rankPlayerMatch[name].matches + 1
						end

						teleportPlayerToTeam(name)

						playerCanGetBall[name] = false

						canCatch = addTimer(
							function(i)
								if i == 1 then
									playerCanGetBall[name] = true
								end
							end,
							1500,
							1,
							"canCatch"
						)

						return
					end
				end
			elseif quantity.red == quantity.blue and quantity.red ~= 6 then
				for i = 1, #playersRed do
					if playersRed[i].name == "" then
						playersRed[i].name = name

						playersInGame[name] = true
						playerTeam[name] = {
							team = "red",
							index = i
						}

						createMatchRankingPlayer(name, "red")

						local foundTeam = false

						for i = 1, #playerTeamHistory[name] do
							local team = playerTeamHistory[name][i]

							if team == "red" then
								foundTeam = true

								break
							end
						end

						if not foundTeam then
							local length = #playerTeamHistory[name]

							playerTeamHistory[length + 1] = "red"
							rankPlayer[name].matches = rankPlayer[name].matches + 1
							rankPlayerMatch[name].matches = rankPlayerMatch[name].matches + 1
						end

						teleportPlayerToTeam(name)

						playerCanGetBall[name] = false

						canCatch = addTimer(
							function(i)
								if i == 1 then
									playerCanGetBall[name] = true
								end
							end,
							1500,
							1,
							"canCatch"
						)

						return
					end
				end
			end
		elseif command == "leave" and playersInGame[name] then
			local playerValues = playerTeam[name]
			local player = tfm.get.room.playerList[name]
			local x = player.x
			local y = player.y

			if playerValues.team == "red" then
				playersRed[playerValues.index].name = ""

				playerTeam[name] = {
					team = "",
					index = 1
				}
			elseif playerValues.team == "blue" then
				playersBlue[playerValues.index].name = ""

				playerTeam[name] = {
					team = "",
					index = 1
				}
			end

			playersInGame[name] = false
			tfm.exec.setNameColor(name, 0x9292AA)
			tfm.exec.movePlayer(name, 800, 50)

			if name == ballOwner then
				ui.removeTextArea(58, ballOwner)
				ui.removeTextArea(59, ballOwner)
				ui.removeTextArea(60, ballOwner)
				tfm.exec.removeImage(playerArrowImage)
				ballOwner = ""
				lastBallCoordX = x
				tfm.exec.removeImage(ballIdImage)
				playerForce[name] = 0
				removeTimer("chargeBallForce" .. name)
				removeTimer("canCatchBall")

				ball_id = tfm.exec.addShamanObject(17, x, y, 0, 0, 0, true)
			end
		elseif string.sub(command, 1, 8) == "winscore" and admins[name] then
			local args = split(command)

			local winscoreSet = tonumber(args[2])

			if type(winscoreSet) ~= "number" then return end

			winscore = math.abs(tonumber(args[2]))
		end
	end
end



--[[ src/events/eventKeyboard.lua ]]--

function eventKeyboard(name, key, down, x, y, xv, yv)
	local playerData = tfm.get.room.playerList[name]

	if name ~= ballOwner then
		ui.removeTextArea(58, name)
		ui.removeTextArea(59, name)
		ui.removeTextArea(60, name)
	end

	if playerData ~= nil then
		tfm.get.room.playerList[name].x = x + xv
		tfm.get.room.playerList[name].y = y + yv
		tfm.get.room.playerList[name].vx = xv
		tfm.get.room.playerList[name].vy = yv
	end

	if key == 76 then
		if rankSettings[name].open then
			rankSettings[name].open = false

			removeRankingUI(name)

			return
		end

		rankSettings[name].sort = "total"
		rankSettings[name].page = 1
		rankSettings[name].open = true
		rankingUI(name)
	end

	if mode == "game" and playersInGame[name] then
		local OffsetX = 0
		local OffsetY = 0

		if xv < 0 then
			OffsetX = -15
		elseif xv > 0 then
			OffsetX = 15
		end
		if yv < 0 then
			OffsetY = -5
		elseif yv > 0 then
			OffsetY = 5
		end

		local coordinatesX = (x + xv) + OffsetX
		local coordinatesY = (y + yv) + OffsetY

		if key == 0 or key == 1 or key == 2 or key == 3 then
			lastPlayerKey[name] = key
		end

		if key == 0 or key == 2 then
			if key == 0 then
				isPlayerDirectionRight[name] = false
			else
				isPlayerDirectionRight[name] = true
			end

			if ballOwner == name then
				if key == 0 then
					isFacingRight = false
					showImageBallWithPlayer(name)
				elseif key == 2 then
					isFacingRight = true
					showImageBallWithPlayer(name)
				end
			end
		end

		if key == 32 and down then
			playerPressSpace[name] = true

			if ballOwner == name then
				local textAreaX = 340

				if x < 350 then
					textAreaX = x
				end
				ui.addTextArea(58, "", name, textAreaX, 300, 120, 20, 0x465a6e, 0x71a3c1, 0.6, true)
				ui.addTextArea(59, "<j>[<n><vp>—<n>", name, textAreaX + 10, 302, 120, 20, 0x161616, 0x161616, 0, true)
				ui.addTextArea(60, "<font color='#465a6e'>[——————</font><j>]<n>", name, textAreaX + 10, 302, 120, 20, 0x161616, 0x161616, 0, true)
			end
		elseif key == 32 and not down then
			playerPressSpace[name] = false
		end

		if key == 32 and ballOwner ~= name and down then
			if ballOwner == "" and playerCanGetBall[name] then
				if canCatchBall then
					getBall(name, x, y)
				end
			else
				stealBall(name, x, y)
			end

			return
		end

		if key == 32 and ballOwner == name and not playerPressSpace[name] then
			ui.removeTextArea(58, name)
			ui.removeTextArea(59, name)
			ui.removeTextArea(60, name)

			shootBall(name, x, y)

			playerForce[name] = 0

			return
		end

		if key == 1 then
			if playerDisableWall[name] and not playerDelayWall[name] then
				local increaseJump = 0
				local vx = xv
				if x <= 216 or x >= 1384 then
					if x <= 226 then
						vx = -3.45
					else
						vx = 3.45
					end
					increaseJump = -75
				else
					increaseJump = -60
				end

				local vy = yv

				if yv >= 0 then
					vy = 0
				end

				tfm.exec.movePlayer(name, 0, 0, true, 0, increaseJump + vy, true)
				tfm.get.room.playerList[name].y = tfm.get.room.playerList[name].y + (increaseJump + vy)
				playerDelayWall[name] = true

				delayWall = addTimer(
					function(i)
						if i == 1 then
							playerDisableWall[name] = false
							playerDelayWall[name] = false
						end
					end,
					3500,
					1,
					"delayWall"
				)

				return
			end

			if not playerDisableWall[name] and not playerDelayWall[name] then
				playerDisableWall[name] = true

				disableWall = addTimer(
					function(i)
						if i == 1 then
							playerDisableWall[name] = false
						end
					end,
					1500,
					1,
					"disableWall"
				)

				return
			end
		end
	end
end



--[[ src/events/eventLoop.lua ]]--

function eventLoop()
	updateBallCoordinates()
	updateBallPlayerCoordinates()
	timersLoop()

	if mode == "lobby" and not gameStats.stopTimer then
		local x = math.ceil((lobbyTimer - os.time()) / 1000)
		local c = string.format("%d", x)

		ui.addTextArea(13, "<p align='center'><r>Game starting in " .. c .. "s", nil, 375, 300, 200, 20, 0x161616, 0x161616, 0, false)

		gameStats.stopTimerSeconds = x

		if x == 0 then
			local quantity = quantityPlayers()

			if quantity.red >= minPlayerRed and quantity.blue >= minPlayerBlue then
				mode = "wait-start"

				startGame()
			else
				lobbyTimer = os.time() + 15000
			end
		end
	elseif mode == "game" then
		local name = ballOwner
		local playerStats = tfm.get.room.playerList[name]

		if name ~= "" then
			print(canCatchBall)
			if playerPressSpace[name] then
				if playerForce[name] <= 6 then
					if playerForce[name] >= 1 then
						if playerForce[name] % 2 == 0 and not timerCanCatchBall then
							canCatchBall = true
						else
							if not timerCanCatchBall then
								canCatchBall = false
							end
						end
					end
					playerForce[name] = playerForce[name] + 1
				else
					playerForce[name] = 0
				end
				setImageCharge(name, playerForce[name])
			else
				ui.removeTextArea(58, name)
				ui.removeTextArea(59, name)
				ui.removeTextArea(60, name)
				playerForce[name] = 0
			end
		end
	elseif mode == "end" then
		local x = math.ceil((timerEnd - os.time()) / 1000)
		local c = string.format("%d", x)

		if x == 0 then
			updateRanking()
			ui.removeTextArea(61, nil)
			init()
		end
	end
end



--[[ src/events/eventMouse.lua ]]--

function eventMouse(name, x, y)
	local playerX = tfm.get.room.playerList[name].x

	if math.abs(x - playerX) > 580 then return end

	print("===")
	print("EVENT MOUSE")
	print(name)
	print("X: " .. tostring(x))
	print("Y: " .. tostring(y))
	print("===")

	if mode == "game" then
		local playerSelected = ""
		local minX = 9999999
		if ballOwner == name and canPass then
			if playerTeam[name].team == "red" then
				for i = 1, #playersRed do
					if playersRed[i].name ~= name then
						local playerStats = tfm.get.room.playerList[playersRed[i].name]

						if playerStats ~= nil then
							local xPlayer = playerStats.x + (playerStats.vx * 5)
							local yPlayer = playerStats.y + (playerStats.vy * 5)

							print("===")
							print("PLAYER STATS " .. playersRed[i].name)
							print(xPlayer)
							print(yPlayer)

							print(math.abs(x - xPlayer))
							print(math.abs(y - yPlayer))
							print("===")

							if math.abs(x - xPlayer) <= 100 and math.abs(y - yPlayer) <= 100 then
								if minX == 9999999 then
									minX = xPlayer
									playerSelected = playersRed[i].name
								elseif xPlayer < minX then
									minX = xPlayer
									playerSelected = playersRed[i].name
								end
							end
						end
					end

					if playerSelected ~= "" then
						ui.removeTextArea(58, name)
						ui.removeTextArea(59, name)
						ui.removeTextArea(60, name)
						system.bindKeyboard(name, 32, false, false)
						if not delayCountPass[name] then
							rankPlayer[name].passes = rankPlayer[name].passes + 1
							rankPlayerMatch[name].passes = rankPlayerMatch[name].passes + 1

							delayCountPass[name] = true

							addTimer(
								function(i)
									delayCountPass[name] = false
								end,
								500,
								1
							)
						end

						tfm.exec.removeImage(ballIdImage)
						removeTimer("chargeBallForce" .. name)
						removeTimer("canCatchBall")
						removeTimer("bindSpace")
						tfm.exec.removeImage(playerArrowImage)

						setPlayerArrowImage(playerSelected)

						ui.updateTextArea(61, "<font size='16px'><r>" .. string.sub(name, 1, #name - 5) .. "<n> passed to <r>" .. string.sub(playerSelected, 1, #playerSelected - 5) .. "<n>", nil)

						ballOwner = playerSelected
						playerForce[playerSelected] = 0
						ballOwnerPressDown = false
						canPass = false
						playerLastPass = name

						addTimer(
							function(i)
								canPass = true
							end,
							1500,
							1,
							"canCatchBall"
						)

						addTimer(
							function(i)
								system.bindKeyboard(playerSelected, 32, false, true)
							end,
							500,
							1,
							"bindSpace"
						)

						showImageBallWithPlayer(playerSelected)
					end
				end
			elseif playerTeam[name].team == "blue" then
				for i = 1, #playersBlue do
					if playersBlue[i].name ~= name then
						local playerStats = tfm.get.room.playerList[playersBlue[i].name]

						if playerStats ~= nil then
							local xPlayer = playerStats.x + (playerStats.vx * 5)
							local yPlayer = playerStats.y + (playerStats.vy * 5)

							print("===")
							print("PLAYER STATS " .. playersBlue[i].name)
							print(xPlayer)
							print(yPlayer)

							print(math.abs(x - xPlayer))
							print(math.abs(y - yPlayer))
							print("===")

							if math.abs(x - xPlayer) <= 100 and math.abs(y - yPlayer) <= 100 then
								if minX == 9999999 then
									minX = xPlayer
									playerSelected = playersBlue[i].name
								elseif xPlayer < minX then
									minX = xPlayer
									playerSelected = playersBlue[i].name
								end
							end
						end
					end

					if playerSelected ~= "" then
						ui.removeTextArea(58, name)
						ui.removeTextArea(59, name)
						ui.removeTextArea(60, name)
						system.bindKeyboard(name, 32, false, false)
						if not delayCountPass[name] then
							rankPlayer[name].passes = rankPlayer[name].passes + 1
							rankPlayerMatch[name].passes = rankPlayerMatch[name].passes + 1

							delayCountPass[name] = true

							addTimer(
								function(i)
									delayCountPass[name] = false
								end,
								500,
								1
							)
						end
						tfm.exec.removeImage(ballIdImage)
						removeTimer("chargeBallForce" .. name)
						removeTimer("canCatchBall")
						removeTimer("bindSpace")

						tfm.exec.removeImage(playerArrowImage)

						setPlayerArrowImage(playerSelected)

						ui.updateTextArea(61, "<font size='16px'><bv>" .. string.sub(name, 1, #name - 5) .. "<n> passed to <bv>" .. string.sub(playerSelected, 1, #playerSelected - 5) .. "<n>", nil)

						ballOwner = playerSelected
						playerForce[playerSelected] = 0
						ballOwnerPressDown = false
						canPass = false
						playerLastPass = name

						addTimer(
							function(i)
								canPass = true
							end,
							1500,
							1,
							"canCatchBall"
						)

						addTimer(
							function(i)
								system.bindKeyboard(playerSelected, 32, false, true)
							end,
							1000,
							1,
							"bindSpace"
						)

						showImageBallWithPlayer(playerSelected)
					end
				end
			end
		end
	end
end



--[[ src/events/eventNewPlayer.lua ]]--

function eventNewPlayer(name)
	tfm.exec.respawnPlayer(name)
	system.bindMouse(name, true)
	tfm.exec.setNameColor(name, 0x9292AA)

	playerDisableWall[name] = false
	playerDelayWall[name] = false
	playerCanGetBall[name] = true
	playersInGame[name] = false
	lastPlayerKey[name] = 0
	playerTeam[name] = {
		team = "",
		index = 1
	}
	rankSettings[name] = {
		page = 1,
		sort = "total",
		open = false
	}
	isPlayerDirectionRight[name] = true
	playerForce[name] = 0
	delayCountPass[name] = false
	playerPressSpace[name] = false
	rankingSelected[name] = "room"

	if playerTeamHistory[name] == nil then
		playerTeamHistory[name] = {}
	end

	if rankPlayer[name] == nil then
		rankPlayer[name] = {
			name = name,
			matches = 0,
			wins = 0,
			winRatio = 0,
			def = 0,
			passes = 0,
			assists = 0,
			d3 = 0,
			d2 = 0,
			points = 0,
			total = 0
		}
	end

	for i = 1, #keys do
		if keys[i] == 32 then
			system.bindKeyboard(name, keys[i], true, true)
			system.bindKeyboard(name, keys[i], false, true)
		else
			system.bindKeyboard(name, keys[i], true, true)
		end
	end

	if mode == "lobby" then
		showLobbyTextAreas(name)
	else
		--tfm.exec.addImage("img@19c1981123a", "?99", 10, -110, name, 0.98)
		ui.addTextArea(61, "<font size='16px'>", name, 5, 375, 400, 30, 0x3E2B20, 0x3E2B20, 1, true)
	end
end



--[[ src/events/eventPlayerDied.lua ]]--

function eventPlayerDied(name)
	tfm.exec.respawnPlayer(name)
end



--[[ src/events/eventPlayerLeft.lua ]]--

function eventPlayerLeft(name)
	if mode == "lobby" then
		if playerTeam[name].team == "red" then
			playersInGame[name] = false
			playersRed[playerTeam[name].index].name = ""
			ui.addTextArea(
				playerTeam[name].index,
				"<p align='center'><font size='15px'><a href='event:joinTeamRed" .. tostring(playerTeam[name].index) .. "'>Join",
				nil,
				x[playerTeam[name].index],
				y[playerTeam[name].index],
				185,
				40,
				0xE14747,
				0xE14747,
				1,
				false
			)

			playerTeam[name] = {
				team = "",
				index = 1
			}
		elseif playerTeam[name].team == "blue" then
			playersInGame[name] = false
			playersBlue[playerTeam[name].index].name = ""
			ui.addTextArea(
				playerTeam[name].index + 6,
				"<p align='center'><font size='15px'><a href='event:joinTeamBlue" .. tostring(playerTeam[name].index) .. "'>Join",
				nil,
				x[playerTeam[name].index + 6],
				y[playerTeam[name].index + 6],
				185,
				40,
				0x184F81,
				0x184F81,
				1,
				false
			)

			playerTeam[name] = {
				team = "",
				index = 1
			}
		end
	elseif mode == "game" then
		if playersInGame[name] then
			local playerValues = playerTeam[name]

			if playerValues.team == "red" then
				playersRed[playerValues.index].name = ""

				playerTeam[name] = {
					team = "",
					index = 1
				}
			elseif playerValues.team == "blue" then
				playersBlue[playerValues.index].name = ""

				playerTeam[name] = {
					team = "",
					index = 1
				}
			end

			playersInGame[name] = false

			if name == ballOwner then
				ballOwner = ""
				lastBallCoordX = 0
				tfm.exec.removeImage(ballIdImage)
				playerForce[name] = 0
				removeTimer("chargeBallForce" .. name)
				removeTimer("canCatchBall")

				spawnInitialBall()
			end
		end
	end
end



--[[ src/events/eventTextAreaCallback.lua ]]--

function eventTextAreaCallback(id, name, c)
	if string.sub(c, 1, 11) == "joinTeamRed" and playersRed[tonumber(string.sub(c, 12))].name == "" and not playersInGame[name] then
		local index = tonumber(string.sub(c, 12))

		playersRed[index].name = name
		playerTeam[name] = {
			team = "red",
			index = index
		}
		playersInGame[name] = true

		ui.addTextArea(index, "<p align='center'><font size='15px'><a href='event:leaveTeamRed" .. index .. "'>" .. playersRed[index].name, nil, x[index], y[index], 185, 40, 0x871F1F, 0x871F1F, 1, false)
	elseif string.sub(c, 1, 12) == "leaveTeamRed" and playersRed[tonumber(string.sub(c, 13))].name == name and playersInGame[name] then
		local index = tonumber(string.sub(c, 13))

		playersRed[index].name = ""
		playersInGame[name] = false
		playerTeam[name] = {
			team = "",
			index = 1
		}

		ui.addTextArea(index, "<p align='center'><font size='15px'><a href='event:joinTeamRed" .. index .. "'>Join", nil, x[index], y[index], 185, 40, 0xE14747, 0xE14747, 1, false)
	elseif string.sub(c, 1, 12) == "joinTeamBlue" and playersBlue[tonumber(string.sub(c, 13))].name == "" and not playersInGame[name] then
		local index = tonumber(string.sub(c, 13))

		playersBlue[index].name = name
		playersInGame[name] = true
		playerTeam[name] = {
			team = "blue",
			index = index
		}

		ui.addTextArea(index + 6, "<p align='center'><font size='15px'><a href='event:leaveTeamBlue" .. index .. "'>" .. playersBlue[index].name, nil, x[index + 6], y[index + 6], 185, 40, 0x0B3356, 0x0B3356, 1, false)
	elseif string.sub(c, 1, 13) == "leaveTeamBlue" and playersBlue[tonumber(string.sub(c, 14))].name == name and playersInGame[name] then
		local index = tonumber(string.sub(c, 14))

		playersBlue[index].name = ""
		playersInGame[name] = false
		playerTeam[name] = {
			team = "",
			index = 1
		}

		ui.addTextArea(index + 6, "<p align='center'><font size='15px'><a href='event:joinTeamBlue" .. index .. "'>Join", nil, x[index + 6], y[index + 6], 185, 40, 0x184F81, 0x184F81, 1, false)
	elseif string.sub(c, 1, 8) == "prevRank" then
		local pageNumber = tonumber(string.sub(c, 9))

		rankSettings[name].page = pageNumber

		rankingUI(name)
	elseif string.sub(c, 1, 8) == "nextRank" then
		local pageNumber = tonumber(string.sub(c, 9))

		rankSettings[name].page = pageNumber

		rankingUI(name)
	elseif string.sub(c, 1, 7) == "setsort" then
		local sortValue = string.sub(c, 8)

		rankSettings[name].sort = sortValue

		rankingUI(name)
	elseif c == "room" then
		rankingSelected[name] = "room"
		rankSettings[name].sort = "total"
		rankSettings[name].page = 1
		rankSettings[name].open = true
		rankingUI(name)
	elseif c == "match" then
		rankingSelected[name] = "match"
		rankSettings[name].sort = "total"
		rankSettings[name].page = 1
		rankSettings[name].open = true
		rankingUI(name)
	elseif c == "closeRanking" then
		removeRankingUI(name)
		rankSettings[name].open = false
	end
end



--[[ src/functions/game/ball/get/getBall.lua ]]--

function getBall(name, coordinatesX, coordinatesY)
	local ballStats = tfm.get.room.objectList[ball_id]
	playerCanGetBall[name] = false

	canCatch = addTimer(
		function(i)
			if i == 1 then
				playerCanGetBall[name] = true
			end
		end,
		500,
		1,
		"canCatch"
	)

	if ballStats == nil then return end

	local x = ballStats.x
	local y = ballStats.y

	local xIncrease = ballStats.x + (ballStats.vx * increaseXBall)

	if coordinatesX >= 1429 or coordinatesX <= 170 then
		if coordinatesY <= 200 then return end
	end

	if xIncrease <= 175 or xIncrease >= 1412 then
		if y <= 150 and y >= 128 then return end
	end

	print("=====")
	print("GET BALL " .. name)
	print(math.abs(coordinatesX - x))
	print(math.abs(coordinatesY - y))
	print("=====")

	if (math.abs(coordinatesX - x) <= 80 and math.abs(coordinatesY - y) <= 80) then
		tfm.exec.removeObject(ball_id)
		ball_id = nil
		playerForce[ballOwner] = 0
		ballOwner = name
		playerForce[ballOwner] = 0
		playerPressSpace[ballOwner] = false
		removeTimer("chargeBallForce" .. playerLastShoot)
		ballOwnerPressDown = false
		-- canCatchBall = false
		playerCanGetBall[ballOwner] = true
		playerLastShoot = name
		playerLastPass = ""
		removeTimer("chargeBallForce" .. name)
		removeTimer("bindSpace")
		removeTimer("canCatchBall")

		setPlayerArrowImage(name)

		-- addTimer(function(i)
		--     if i == 1 then
		--         canCatchBall = true
		--     end
		-- end, 500, 1, "canCatchBall")

		system.bindKeyboard(name, 32, false, true)

		showImageBallWithPlayer(name)

		print("pegou")
	end
end



--[[ src/functions/game/ball/get/stealBall.lua ]]--

function stealBall(name, coordinatesX, coordinatesY)
	if (ballOwner == name) then return end

	local ballOwnerNickname = ballOwner
	local playerOwner = tfm.get.room.playerList[ballOwnerNickname]

	local delay = 500

	local countPlayers = calculatePlayersOnArea(ballOwnerNickname)

	if countPlayers == 0 or countPlayers == 1 then
		delay = 500
	elseif countPlayers == 2 then
		delay = 1000
	elseif countPlayers >= 3 then
		delay = 1500
	end

	print("===")
	print("DELAY PARA PEGAR DENOVO")
	print(delay)
	print("===")

	removeTimer("canCatch" .. name .. "")

	canCatch = addTimer(
		function(i)
			if i == 1 then
				playerCanGetBall[name] = true
			end
		end,
		delay,
		1,
		"canCatch" .. name .. ""
	)

	if playerCanGetBall[name] then
		playerCanGetBall[name] = false
	else
		return
	end

	if playerOwner == nil then return end

	if playerTeam[ballOwnerNickname].team == playerTeam[name].team then return end

	local playerX = playerOwner.x
	local playerY = playerOwner.y
	local playerVX = playerOwner.vx

	print("===")
	print("STEAL BALL " .. name)
	print(math.abs(coordinatesX - playerX))
	print(math.abs(coordinatesY - playerY))
	print(canCatchBall)
	print("===")

	local isCorner = isCornerCourt(coordinatesX)

	local minX = 45
	local minY = 30

	if not canCatchBall then return end

	-- if lastPlayerKey[name] == lastPlayerKey[ballOwner] then
	-- 	minX = 85
	-- end

	-- if playerVX > 4 or playerVX < -4 then
	-- 	print("aq")
	-- 	minX = 50
	-- 	minY = 50
	-- end

	if isCorner and coordinatesY <= 205 and playerOwner.y <= 205 then
		minX = 200
		minY = 200
	end

	print(minX)
	print(minY)

	if (math.abs(coordinatesX - playerX) <= minX and math.abs(coordinatesY - playerY) <= minY) then
		ui.removeTextArea(58, ballOwner)
		ui.removeTextArea(59, ballOwner)
		ui.removeTextArea(60, ballOwner)
		tfm.exec.removeImage(playerArrowImage)
		tfm.exec.removeImage(ballIdImage)
		canCatchBall = false
		timerCanCatchBall = true
		playerForce[ballOwner] = 0
		ballOwner = name
		playerForce[ballOwner] = 0
		playerCanGetBall[ballOwner] = true
		playerLastShoot = name
		playerLastPass = ""
		setPlayerArrowImage(name)
		rankPlayer[name].def = rankPlayer[name].def + 1
		rankPlayerMatch[name].def = rankPlayerMatch[name].def + 1

		addTimer(
			function(i)
				if i == 1 then
					canCatchBall = true
					timerCanCatchBall = false
				end
			end,
			3000,
			1,
			"canCatchBall"
		)

		system.bindKeyboard(name, 32, false, true)

		showImageBallWithPlayer(name)

		print("pegou")
	end
end



--[[ src/functions/game/ball/shoot/setImageCharge.lua ]]--

function setImageCharge(name, force)
	local playerStats = tfm.get.room.playerList[name]

	if force <= 1 then
		ui.updateTextArea(60, "<j>[<n><font color='#465a6e'>——————</font><j>]<n>", name)
		ui.updateTextArea(59, "<j>[<n><vp>—<n>", name)
	elseif force == 2 then
		ui.updateTextArea(59, "<j>[<n><vp>——<n>", name)
	elseif force == 3 then
		ui.updateTextArea(59, "<j>[<n><vp>———<n>", name)
	elseif force == 4 then
		ui.updateTextArea(59, "<j>[<n><vp>———<n><v>—<n>", name)
	elseif force == 5 then
		ui.updateTextArea(59, "<j>[<n><vp>———<n><v>——<n>", name)
	elseif force >= 6 then
		if force == 6 then
			ui.updateTextArea(59, "<j>[<n><vp>———<n><v>——<n><j>—<n>", name)

			return
		end
		ui.updateTextArea(60, "<j>[<n><font color='#465a6e'>————————</font><j>]<n>", name)
		ui.updateTextArea(59, "<j>[<n><vp>———<n><v>——<n><j>—<n><j>——<n>", name)
	end
end



--[[ src/functions/game/ball/shoot/shootBall.lua ]]--

function shootBall(name, x, y)
	print(t1)
	if t1 then
		playerForce[name] = 8
	end

	local timer = 1500

	if playerForce[name] >= 4 and playerForce[name] <= 5 then
		timer = 2000
	elseif playerForce[name] == 6 then
		timer = 2500
	end

	if playerForce[name] <= 1 then
		playerForce[name] = 0
		ui.removeTextArea(58, name)
		ui.removeTextArea(59, name)
		ui.removeTextArea(60, name)

		-- system.bindKeyboard(name, 32, false, false)

		-- addTimer(
		-- 	function(i)
		-- 		system.bindKeyboard(name, 32, false, true)
		-- 		ballOwnerPressDown = false
		-- 	end,
		-- 	500,
		-- 	1,
		-- 	"chargeBallForce"
		-- )

		return
	elseif playerForce[name] == 2 then
		local vx = -2
		local vy = -3

		if x <= 274 or x >= 1330 then
			vy = -5
			vx = -3

			if isPlayerDirectionRight[name] then
				vx = 3
			end
		end

		if isPlayerDirectionRight[name] then
			vx = 2
		end

		if x <= 274 and isPlayerDirectionRight[name] then
			vy = -3
		elseif x >= 1330 and not isPlayerDirectionRight[name] then
			vy = -3
		end

		ball_id = tfm.exec.addShamanObject(17, x, y, 0, 0, 0, true)
		tfm.exec.moveObject(ball_id, 0, 0, true, vx, vy, true, 0, true)
	elseif playerForce[name] == 3 then
		local vx = -4
		local vy = -6

		if x <= 274 or x >= 1327 then
			vy = -8
		end

		if isPlayerDirectionRight[name] then
			vx = 4
		end

		if x <= 274 and isPlayerDirectionRight[name] then
			vy = -6
		elseif x >= 1330 and not isPlayerDirectionRight[name] then
			vy = -6
		end

		ball_id = tfm.exec.addShamanObject(17, x, y, 0, 0, 0, true)
		tfm.exec.moveObject(ball_id, 0, 0, true, vx, vy, true, 0, true)
	elseif playerForce[name] == 4 then
		local vx = -6
		local vy = -8

		if x <= 274 or x >= 1327 then
			vy = -10
		end

		if isPlayerDirectionRight[name] then
			vx = 6
		end

		if x <= 274 and isPlayerDirectionRight[name] then
			vy = -8
		elseif x >= 1330 and not isPlayerDirectionRight[name] then
			vy = -8
		end

		ball_id = tfm.exec.addShamanObject(17, x, y, 0, 0, 0, true)
		tfm.exec.moveObject(ball_id, 0, 0, true, vx, vy, true, 0, true)
	elseif playerForce[name] == 5 then
		local vx = -7.5
		local vy = -10

		if x <= 274 or x >= 1327 then
			vy = -13
		end

		if isPlayerDirectionRight[name] then
			vx = 7.5
		end

		if x <= 274 and isPlayerDirectionRight[name] then
			vy = -10
		elseif x >= 1330 and not isPlayerDirectionRight[name] then
			vy = -10
		end

		ball_id = tfm.exec.addShamanObject(17, x, y, 0, 0, 0, true)
		tfm.exec.moveObject(ball_id, 0, 0, true, vx, vy, true, 0, true)
	elseif playerForce[name] >= 6 then
		local vx = -9
		local vy = -12

		if x <= 274 or x >= 1327 then
			vy = -16
		end

		if isPlayerDirectionRight[name] then
			vx = 9
		end

		if x <= 274 and isPlayerDirectionRight[name] then
			vy = -12
		elseif x >= 1330 and not isPlayerDirectionRight[name] then
			vy = -12
		end

		ball_id = tfm.exec.addShamanObject(17, x, y, 0, 0, 0, true)
		tfm.exec.moveObject(ball_id, 0, 0, true, vx, vy, true, 0, true)
	end

	canCatchBall = false

	ui.removeTextArea(58, name)
	ui.removeTextArea(59, name)
	ui.removeTextArea(60, name)
	tfm.exec.removeImage(playerArrowImage)
	playerLastShoot = name
	lastBallCoordX = x
	tfm.exec.removeImage(ballIdImage)
	playerForce[name] = 0
	removeTimer("chargeBallForce" .. name)
	removeTimer("canCatchBall")
	ballOwner = ""
	tfm.exec.addImage("17bd8be9691.png", "#" .. ball_id, -15, -15, nil, 1, 1)

	addTimer(
		function(i)
			if i == 1 then
				canCatchBall = true
			end
		end,
		timer,
		1,
		"canCatchBall"
	)
end



--[[ src/functions/game/ball/spawn/spawnInitialBall.lua ]]--

function spawnInitialBall()
	ball_id = tfm.exec.addShamanObject(17, 800, 180, 0, 0, 0, true)
	tfm.exec.addImage("17bd8be9691.png", "#" .. ball_id, -15, -15, nil, 1, 1)
end



--[[ src/functions/game/mice/calculatePlayersOnArea.lua ]]--

function calculatePlayersOnArea(name)
	local playerStats = tfm.get.room.playerList[name]

	if playerStats == nil then
		return 1
	end

	local countPlayers = 0
	local x = playerStats.x + playerStats.vx
	local minX = x - 150
	local maxX = x + 150

	if playerTeam[name].team == "red" then
		for i = 1, #playersBlue do
			local playerName = playersBlue[i].name

			if playerName ~= "" then
				local player = tfm.get.room.playerList[playerName]

				if player ~= nil then
					local playerCoordinatesX = player.x + player.vx

					if playerCoordinatesX >= minX and playerCoordinatesX <= maxX then
						countPlayers = countPlayers + 1
					end
				end
			end
		end
	elseif playerTeam[name].team == "blue" then
		for i = 1, #playersRed do
			local playerName = playersRed[i].name

			if playerName ~= "" then
				local player = tfm.get.room.playerList[playerName]

				if player ~= nil then
					local playerCoordinatesX = player.x + player.vx

					if playerCoordinatesX >= minX and playerCoordinatesX <= maxX then
						countPlayers = countPlayers + 1
					end
				end
			end
		end
	end

	return countPlayers
end



--[[ src/functions/game/mice/spawn/teleportPlayers.lua ]]--

function teleportPlayers()
	for name, data in pairs(tfm.get.room.playerList) do
		if playerTeam[name].team == "red" then
			local x = math.random(900, 1400)
			tfm.exec.movePlayer(name, x, 280)
			tfm.exec.setNameColor(name, 0xE14747)
		elseif playerTeam[name].team == "blue" then
			local x = math.random(155, 600)
			tfm.exec.movePlayer(name, x, 280)
			tfm.exec.setNameColor(name, 0x184F81)
		end
	end
end



--[[ src/functions/game/mice/spawn/teleportPlayerToTeam.lua ]]--

function teleportPlayerToTeam(name)
	if playerTeam[name].team == "red" then
		local x = math.random(900, 1400)
		tfm.exec.movePlayer(name, x, 280)
		tfm.exec.setNameColor(name, 0xE14747)
	elseif playerTeam[name].team == "blue" then
		local x = math.random(155, 600)
		tfm.exec.movePlayer(name, x, 280)
		tfm.exec.setNameColor(name, 0x184F81)
	end
end



--[[ src/functions/game/startGame.lua ]]--

function startGame()
	removeLobbyTexts()

	--img@19c1981123a
	-- 1510b6a3e10.jpg
	tfm.exec.newGame(
		'<C><P yoff="-106" L="1600" /><Z><S><S i="0,-391,1510b6a3e10.jpg" X="800" L="1600" o="" H="10" c="2" Y="289" T="12" P="0,0,,0.8,0,0,0,0" /><S P="0,0,0.3,0.2,0,0,0,0" L="1600" o="" H="30" Y="300" T="12" X="800" /><S H="10" L="17" o="" X="31" c="2" Y="124" T="12" P="0,0,,0.8,0,0,0,0" /><S H="65" L="10" o="" X="12" c="2" Y="85" T="12" P="0,0,,0.8,0,0,0,0" /><S P="0,0,,0.8,0,0,0,0" L="17" o="" H="10" Y="124" T="12" X="1569" /><S H="65" L="10" o="" X="1588" c="2" Y="85" T="12" P="0,0,,0.8,0,0,0,0" /><S P="0,0,0.3,,90,0,0,0" L="68" o="0" X="116" c="3" Y="-51" T="12" H="200" /><S P="0,0,,0.2,45,0,0,0" L="68" o="0" H="175" Y="-39" T="12" X="18" /><S L="68" o="0" H="175" X="1582" Y="-39" T="12" P="0,0,,0.2,-45,0,0,0" /><S H="800" L="70" o="6a7495" X="325" c="1" Y="-119" T="12" P="0,0,,,90,0,0,0" /><S P="0,0,0.3,,65,0,0,0" L="68" o="0" X="255" c="3" Y="-73" T="12" H="120" /><S P="0,0,,,90,0,0,0" L="70" o="6a7495" X="1275" c="1" Y="-119" T="12" H="800" /><S P="0,0,0.3,,90,0,0,0" L="68" o="0" X="1484" c="3" Y="-51" T="12" H="200" /><S P="0,0,0.3,,-65,0,0,0" L="68" o="0" X="1345" c="3" Y="-73" T="12" H="120" /><S H="10" L="420" o="" X="210" c="3" Y="104" T="12" P="0,0,0.3,0.2,0,0,0,0" /><S H="10" L="420" o="" X="1390" c="3" Y="104" T="12" P="0,0,0.3,0.2,0,0,0,0" /><S H="65" L="280" o="" X="800" c="3" Y="89" T="12" P="0,0,0.3,0.2,0,0,0,0" /><S H="49" L="10" o="" X="91" c="1" Y="144" T="12" P="0,0,,0.8,20,0,0,0" /><S P="0,0,,0.4,-20,0,0,0" L="10" o="" H="49" Y="144" T="12" X="37" /><S H="49" L="10" o="" X="1509" c="1" Y="144" T="12" P="0,0,,0.8,-20,0,0,0" /><S L="50" X="64" H="20" v="1" Y="140" T="9" P="0,0,,,,0,0,0" /><S X="21" L="17" o="" H="10" c="2" Y="116" T="12" P="0,0,,0.7,40,0,0,0" /><S H="10" L="17" o="" X="1579" c="2" Y="116" T="12" P="0,0,,0.7,-40,0,0,0" /><S P="0,0,0.3,0.6,0,0,0,0" L="68" o="0" H="402" Y="200" T="12" X="1634" /><S X="-4" L="10" o="" H="65" c="2" Y="27" T="12" P="0,0,,0.4,-30,0,0,0" /><S H="65" L="10" o="" X="1604" c="2" Y="27" T="12" P="0,0,,0.4,30,0,0,0" /><S P="0,0,,,0,0,0,0" L="1010" o="0" H="68" N="" Y="-96" T="12" X="800" /><S P="0,0,,,65,0,0,0" L="10" o="0" X="243" c="1" Y="-100" T="12" H="120" /><S H="120" L="10" o="" X="1357" c="1" Y="-100" T="12" P="0,0,,,-65,0,0,0" /><S P="0,0,,1.5,20,0,0,0" L="10" o="" X="104" c="3" Y="150" T="12" H="60" /><S P="0,0,,1.1,90,0,0,0" L="10" o="" X="1562" c="1" Y="162" T="12" H="100" /><S L="68" o="0" H="402" X="-34" Y="200" T="12" P="0,0,0.3,0.6,0,0,0,0" /><S H="100" L="10" o="" X="38" c="1" Y="162" T="12" P="0,0,,1.1,90,0,0,0" /><S P="0,0,0.3,0.2,0,0,0,0" L="1600" o="" X="800" c="3" Y="117" T="12" H="10" /><S L="10" o="" H="49" X="1563" Y="144" T="12" P="0,0,,0.4,20,0,0,0" /><S P="0,0,,2,80,0,0,0" L="10" o="" X="49" c="3" Y="183" T="12" H="100" /><S H="60" L="10" o="" X="1496" c="3" Y="150" T="12" P="0,0,,1.5,-20,0,0,0" /><S P="0,0,,,,0,0,0" L="50" H="20" v="1" Y="140" T="9" X="1536" /><S H="100" L="10" o="" X="1551" c="3" Y="183" T="12" P="0,0,,2,-80,0,0,0" /></S><D><DS Y="42" X="800" /></D><O /><L><JD c="6a7495,250" P1="-53,524" P2="1652,524" /><JD c="6a7495,250,1,1" P1="216,-255" P2="1502,-255" /></L></Z></C>'
	)

	-- tfm.exec.newGame(
	-- 	'<C><P yoff="-106" L="1600" /><Z><S><S lua="99" X="800" L="1600" o="" H="10" c="2" Y="289" T="12" P="0,0,,0.8,0,0,0,0" /><S P="0,0,0.3,0.2,0,0,0,0" L="1600" o="" H="30" Y="300" T="12" X="800" /><S H="10" L="17" o="" X="31" c="2" Y="124" T="12" P="0,0,,0.8,0,0,0,0" /><S H="65" L="10" o="" X="12" c="2" Y="85" T="12" P="0,0,,0.8,0,0,0,0" /><S P="0,0,,0.8,0,0,0,0" L="17" o="" H="10" Y="124" T="12" X="1569" /><S H="65" L="10" o="" X="1588" c="2" Y="85" T="12" P="0,0,,0.8,0,0,0,0" /><S P="0,0,0.3,,90,0,0,0" L="68" o="0" X="116" c="3" Y="-51" T="12" H="200" /><S P="0,0,,0.2,45,0,0,0" L="68" o="0" H="175" Y="-39" T="12" X="18" /><S L="68" o="0" H="175" X="1582" Y="-39" T="12" P="0,0,,0.2,-45,0,0,0" /><S H="800" L="70" o="6a7495" X="325" c="1" Y="-119" T="12" P="0,0,,,90,0,0,0" /><S P="0,0,0.3,,65,0,0,0" L="68" o="0" X="255" c="3" Y="-73" T="12" H="120" /><S P="0,0,,,90,0,0,0" L="70" o="6a7495" X="1275" c="1" Y="-119" T="12" H="800" /><S P="0,0,0.3,,90,0,0,0" L="68" o="0" X="1484" c="3" Y="-51" T="12" H="200" /><S P="0,0,0.3,,-65,0,0,0" L="68" o="0" X="1345" c="3" Y="-73" T="12" H="120" /><S H="10" L="420" o="" X="210" c="3" Y="104" T="12" P="0,0,0.3,0.2,0,0,0,0" /><S H="10" L="420" o="" X="1390" c="3" Y="104" T="12" P="0,0,0.3,0.2,0,0,0,0" /><S H="65" L="280" o="" X="800" c="3" Y="89" T="12" P="0,0,0.3,0.2,0,0,0,0" /><S H="49" L="10" o="" X="91" c="1" Y="144" T="12" P="0,0,,0.8,20,0,0,0" /><S P="0,0,,0.4,-20,0,0,0" L="10" o="" H="49" Y="144" T="12" X="37" /><S H="49" L="10" o="" X="1509" c="1" Y="144" T="12" P="0,0,,0.8,-20,0,0,0" /><S L="50" X="64" H="20" v="1" Y="140" T="9" P="0,0,,,,0,0,0" /><S X="21" L="17" o="" H="10" c="2" Y="116" T="12" P="0,0,,0.7,40,0,0,0" /><S H="10" L="17" o="" X="1579" c="2" Y="116" T="12" P="0,0,,0.7,-40,0,0,0" /><S P="0,0,0.3,0.6,0,0,0,0" L="68" o="0" H="402" Y="200" T="12" X="1634" /><S X="-4" L="10" o="" H="65" c="2" Y="27" T="12" P="0,0,,0.4,-30,0,0,0" /><S H="65" L="10" o="" X="1604" c="2" Y="27" T="12" P="0,0,,0.4,30,0,0,0" /><S P="0,0,,,0,0,0,0" L="1010" o="0" H="68" N="" Y="-96" T="12" X="800" /><S P="0,0,,,65,0,0,0" L="10" o="0" X="243" c="1" Y="-100" T="12" H="120" /><S H="120" L="10" o="" X="1357" c="1" Y="-100" T="12" P="0,0,,,-65,0,0,0" /><S P="0,0,,1.5,20,0,0,0" L="10" o="" X="104" c="3" Y="150" T="12" H="60" /><S P="0,0,,1.1,90,0,0,0" L="10" o="" X="1562" c="1" Y="162" T="12" H="100" /><S L="68" o="0" H="402" X="-34" Y="200" T="12" P="0,0,0.3,0.6,0,0,0,0" /><S H="100" L="10" o="" X="38" c="1" Y="162" T="12" P="0,0,,1.1,90,0,0,0" /><S P="0,0,0.3,0.2,0,0,0,0" L="1600" o="" X="800" c="3" Y="117" T="12" H="10" /><S L="10" o="" H="49" X="1563" Y="144" T="12" P="0,0,,0.4,20,0,0,0" /><S P="0,0,,2,80,0,0,0" L="10" o="" X="49" c="3" Y="183" T="12" H="100" /><S H="60" L="10" o="" X="1496" c="3" Y="150" T="12" P="0,0,,1.5,-20,0,0,0" /><S P="0,0,,,,0,0,0" L="50" H="20" v="1" Y="140" T="9" X="1536" /><S H="100" L="10" o="" X="1551" c="3" Y="183" T="12" P="0,0,,2,-80,0,0,0" /></S><D><DS Y="42" X="800" /></D><O /><L><JD c="6a7495,250" P1="-53,524" P2="1652,524" /><JD c="6a7495,250,1,1" P1="216,-255" P2="1502,-255" /></L></Z></C>'
	-- )

	-- tfm.exec.addImage("img@19c1981123a", "?99", 10, -110, nil, 0.98)

	createMatchRanking()
	addMatchToPlayers()
	teleportPlayers()
	spawnInitialBall()
	showTheScore()

	local initGame = addTimer(
		function(i)
			if i == 1 then
				mode = "game"
			end
		end,
		1000,
		1,
		"initGame"
	)

	ui.addTextArea(61, "<font size='16px'>", nil, 5, 375, 400, 30, 0x3E2B20, 0x3E2B20, 1, true)

	verifyBallPoint()
end



--[[ src/functions/game/verifyIsPoint/updateBallCoordinates.lua ]]--

function updateBallCoordinates()
	local ballData = tfm.get.room.objectList[ball_id]

	if ballData == nil then return end

	local x = ballData.x + (ballData.vx * increaseXBall)
	local y = ballData.y + (ballData.vy * increaseYBall)

	if x <= 75 or x >= 1512 then return end

	ballData.x = x
	ballData.y = y
end



--[[ src/functions/game/verifyIsPoint/updatePlayerCoordinates.lua ]]--

function updateBallPlayerCoordinates()
	local player = tfm.get.room.playerList[ballOwner]

	if player == nil then return end

	local x = player.x + (player.vx * increaseXPlayer)
	local y = player.y + (player.vy * increaseYPlayer)

	player.x = x
	player.y = y
end



--[[ src/functions/game/verifyIsPoint/verifyBallPoint.lua ]]--

function verifyBallPoint()
	addTimer(
		function(i)
			if not disableVerifyBall then
				local ballCoords = tfm.get.room.objectList[ball_id]
				local text = ""
				local textComplement = ""

				if ballCoords == nil then return end

				local x = ballCoords.x
				local y = ballCoords.y

				if x <= 75 and y <= 150 and y >= 128 then
					if lastBallCoordX >= 482 then
						redScore = redScore + 3
						ui.updateTextArea(61, "<font size='16px'>The <r>Red<n> team scored!", nil)

						print("É PONTO")
						print(playerTeam[playerLastShoot].team)
						print("===")

						if playerTeam[playerLastShoot].team == "red" then
							tfm.exec.setPlayerScore(playerLastShoot, 3, true)
							rankPlayer[playerLastShoot].d3 = rankPlayer[playerLastShoot].d3 + 3
							rankPlayerMatch[playerLastShoot].d3 = rankPlayerMatch[playerLastShoot].d3 + 3
							text = "<r>" .. string.sub(playerLastShoot, 1, #playerLastShoot - 5) .. "<n> <j>scored<n> <v>+3<n>"

							if playerLastPass ~= "" then
								if playerTeam[playerLastPass].team == "red" then
									tfm.exec.setPlayerScore(playerLastPass, 1, true)
									rankPlayer[playerLastPass].assists = rankPlayer[playerLastPass].assists + 1
									rankPlayerMatch[playerLastPass].assists = rankPlayerMatch[playerLastPass].assists + 1
									textComplement = "<r>" .. string.sub(playerLastPass, 1, #playerLastPass - 5) .. " <n><j>with the assist<n>"
								end
							end
						end
					else
						redScore = redScore + 2
						ui.updateTextArea(61, "<font size='16px'>The <r>Red<n> team scored!", nil)

						if playerTeam[playerLastShoot].team == "red" then
							tfm.exec.setPlayerScore(playerLastShoot, 2, true)
							rankPlayer[playerLastShoot].d2 = rankPlayer[playerLastShoot].d2 + 2
							rankPlayerMatch[playerLastShoot].d2 = rankPlayerMatch[playerLastShoot].d2 + 2
							text = "<r>" .. string.sub(playerLastShoot, 1, #playerLastShoot - 5) .. "<n> <j>scored<n> <v>+2<n>"

							if playerLastPass ~= "" then
								if playerTeam[playerLastPass].team == "red" then
									tfm.exec.setPlayerScore(playerLastPass, 1, true)
									rankPlayer[playerLastPass].assists = rankPlayer[playerLastPass].assists + 1
									rankPlayerMatch[playerLastPass].assists = rankPlayerMatch[playerLastPass].assists + 1
									textComplement = "<r>" .. string.sub(playerLastPass, 1, #playerLastPass - 5) .. " <n><j>with the assist<n>"
								end
							end
						end
					end

					if redScore < winscore then
						tfm.exec.moveObject(ball_id, 54, 218, false, 0, 0, true)
					else
						for i = 1, #playersRed do
							if playersRed[i].name ~= "" then
								rankPlayer[playersRed[i].name].wins = rankPlayer[playersRed[i].name].wins + 1
								rankPlayerMatch[playersRed[i].name].wins = rankPlayerMatch[playersRed[i].name].wins + 1
							end
						end
						text = "<r>Red<n> <j>won!<n> <r>" .. tostring(redScore) .. "<n> <g>|<n> <bv>" .. tostring(blueScore) .. "<n>"
						local playerMVP = foundMVP()
						textComplement = "<font size='14px'><vp>MVP<n> <j>" .. playerMVP.name .. "<n> <vp>(Total " .. playerMVP.total .. ")"

						tfm.exec.removeObject(ball_id)
						timerEnd = os.time() + 7000
						mode = "end"
						removeTimer("loop")
					end

					disableVerifyBall = true

					addTimer(
						function(i)
							disableVerifyBall = false
						end,
						1000,
						1
					)

					teleportPlayers()

					if text == "" then
						text = "<bv>" .. string.sub(playerLastShoot, 1, #playerLastShoot - 5) .. " scored own goal<n>"
					end

					if textComplement == "" then
						textComplement = text
					end

					showPlayerPoint(text, textComplement)
				elseif x >= 1512 and y <= 150 and y >= 128 then
					if lastBallCoordX <= 1114 then
						blueScore = blueScore + 3
						ui.updateTextArea(61, "<font size='16px'>The <bv>Blue<n> team scored!", nil)

						if playerTeam[playerLastShoot].team == "blue" then
							tfm.exec.setPlayerScore(playerLastShoot, 3, true)
							rankPlayer[playerLastShoot].d3 = rankPlayer[playerLastShoot].d3 + 3
							rankPlayerMatch[playerLastShoot].d3 = rankPlayerMatch[playerLastShoot].d3 + 3
							text = "<bv>" .. string.sub(playerLastShoot, 1, #playerLastShoot - 5) .. "<n> <j>scored<n> <v>+3<n>"

							if playerLastPass ~= "" then
								if playerTeam[playerLastPass].team == "blue" then
									tfm.exec.setPlayerScore(playerLastPass, 1, true)
									rankPlayer[playerLastPass].assists = rankPlayer[playerLastPass].assists + 1
									rankPlayerMatch[playerLastPass].assists = rankPlayerMatch[playerLastPass].assists + 1
									textComplement = "<bv>" .. string.sub(playerLastPass, 1, #playerLastPass - 5) .. " <n><j>with the assist<n>"
								end
							end
						end
					else
						blueScore = blueScore + 2
						ui.updateTextArea(61, "<font size='16px'>The <bv>Blue<n> team scored!", nil)

						if playerTeam[playerLastShoot].team == "blue" then
							tfm.exec.setPlayerScore(playerLastShoot, 2, true)
							rankPlayer[playerLastShoot].d2 = rankPlayer[playerLastShoot].d2 + 2
							rankPlayerMatch[playerLastShoot].d2 = rankPlayerMatch[playerLastShoot].d2 + 2
							text = "<bv>" .. string.sub(playerLastShoot, 1, #playerLastShoot - 5) .. "<n> <j>scored<n> <v>+2<n>"

							if playerLastPass ~= "" then
								if playerTeam[playerLastPass].team == "blue" then
									tfm.exec.setPlayerScore(playerLastPass, 1, true)
									rankPlayer[playerLastPass].assists = rankPlayer[playerLastPass].assists + 1
									rankPlayerMatch[playerLastPass].assists = rankPlayerMatch[playerLastPass].assists + 1
									textComplement = "<bv>" .. string.sub(playerLastPass, 1, #playerLastPass - 5) .. " <n><j>with the assist<n>"
								end
							end
						end
					end

					if blueScore < winscore then
						tfm.exec.moveObject(ball_id, 1534, 218, false, 0, 0, true)
					else
						for i = 1, #playersBlue do
							if playersBlue[i].name ~= "" then
								rankPlayer[playersBlue[i].name].wins = rankPlayer[playersBlue[i].name].wins + 1
								rankPlayerMatch[playersBlue[i].name].wins = rankPlayerMatch[playersBlue[i].name].wins + 1
							end
						end
						text = "<bv>Blue<n> <j>won!<n> <r>" .. tostring(redScore) .. "<n> <g>|<n> <bv>" .. tostring(blueScore) .. "<n>"
						local playerMVP = foundMVP()
						textComplement = "<font size='14px'><vp>MVP<n> <j>" .. playerMVP.name .. "<n> <vp>(Total " .. playerMVP.total .. ")"

						tfm.exec.removeObject(ball_id)
						timerEnd = os.time() + 7000
						mode = "end"
						removeTimer("loop")
					end

					disableVerifyBall = true

					addTimer(
						function(i)
							disableVerifyBall = false
						end,
						1000,
						1
					)

					teleportPlayers()

					if textComplement == "" then
						textComplement = text
					end

					if text == "" then
						text = "<r>" .. string.sub(playerLastShoot, 1, #playerLastShoot - 5) .. " scored own goal<n>"
					end

					showPlayerPoint(text, textComplement)
				end
			end
		end,
		500,
		0,
		"loop"
	)
end



--[[ src/functions/ranking/addMatchToPlayers.lua ]]--

function addMatchToPlayers()
	for name, data in pairs(tfm.get.room.playerList) do
		local length = #playerTeamHistory[name]

		if playersInGame[name] then
			if playerTeam[name].team == "red" then
				playerTeamHistory[name][length + 1] = "red"
				rankPlayer[name].matches = rankPlayer[name].matches + 1
				rankPlayerMatch[name].matches = rankPlayerMatch[name].matches + 1
			elseif playerTeam[name].team == "blue" then
				playerTeamHistory[name][length + 1] = "blue"
				rankPlayer[name].matches = rankPlayer[name].matches + 1
				rankPlayerMatch[name].matches = rankPlayerMatch[name].matches + 1
			end
		end
	end
end



--[[ src/functions/ranking/createMatchRanking.lua ]]--

function createMatchRanking()
	for i = 1, #playersRed do
		local name = playersRed[i].name

		rankPlayerMatch[name] = {
			name = name,
			color = "red",
			matches = 0,
			wins = 0,
			winRatio = 0,
			def = 0,
			passes = 0,
			assists = 0,
			d3 = 0,
			d2 = 0,
			points = 0,
			total = 0
		}
	end

	for i = 1, #playersBlue do
		local name = playersBlue[i].name

		rankPlayerMatch[name] = {
			name = name,
			color = "blue",
			matches = 0,
			wins = 0,
			winRatio = 0,
			def = 0,
			passes = 0,
			assists = 0,
			d3 = 0,
			d2 = 0,
			points = 0,
			total = 0
		}
	end
end



--[[ src/functions/ranking/createMatchRankingPlayer.lua ]]--

function createMatchRankingPlayer(name, team)
	if rankPlayerMatch[name] == nil then
		rankPlayerMatch[name] = {
			name = name,
			color = team,
			matches = 0,
			wins = 0,
			winRatio = 0,
			def = 0,
			passes = 0,
			assists = 0,
			d3 = 0,
			d2 = 0,
			points = 0,
			total = 0
		}

		return
	end

	rankPlayerMatch[name].color = team
end



--[[ src/functions/ranking/foundMVP.lua ]]--

function foundMVP()
	local tempRankRoom = {}

	local rank = rankPlayerMatch

	for name, data in pairs(rank) do
		if data.matches >= 0 then
			if data.name ~= "" then
				tempRankRoom[#tempRankRoom + 1] = {
					name = name,
					color = data.color,
					matches = data.matches,
					wins = data.wins,
					winRatio = winRatioPercentage(data.wins, data.matches),
					def = data.def,
					passes = data.passes,
					assists = data.assists,
					d3 = data.d3,
					d2 = data.d2,
					points = data.d3 + data.d2,
					total = data.def + data.passes + data.assists + data.d3 + data.d2 + data.points
				}
			end
		end
	end

	table.sort(tempRankRoom, function(a, b)
		return a.total > b.total
	end)

	return {
		name = tempRankRoom[1].name,
		total = tempRankRoom[1].total
	}
end



--[[ src/functions/ranking/sortRankingData.lua ]]--

function sortRankingData(name)
	local tempRankRoom = {}

	local rank = {}

	if rankingSelected[name] == "room" then
		rank = rankPlayer
	else
		rank = rankPlayerMatch
	end

	for name, data in pairs(rank) do
		if data.matches >= 0 then
			if rankingSelected[name] == "room" then
				tempRankRoom[#tempRankRoom + 1] = {
					name = name,
					color = "",
					matches = data.matches,
					wins = data.wins,
					winRatio = winRatioPercentage(data.wins, data.matches),
					def = data.def,
					passes = data.passes,
					assists = data.assists,
					d3 = data.d3,
					d2 = data.d2,
					points = data.d3 + data.d2,
					total = data.def + data.passes + data.assists + data.d3 + data.d2 + data.points
				}
			else
				if data.name ~= "" then
					tempRankRoom[#tempRankRoom + 1] = {
						name = name,
						color = data.color,
						matches = data.matches,
						wins = data.wins,
						winRatio = winRatioPercentage(data.wins, data.matches),
						def = data.def,
						passes = data.passes,
						assists = data.assists,
						d3 = data.d3,
						d2 = data.d2,
						points = data.d3 + data.d2,
						total = data.def + data.passes + data.assists + data.d3 + data.d2 + data.points
					}
				end
			end
		end
	end

	if rankSettings[name].sort == "total" then
		table.sort(tempRankRoom, function(a, b)
			return a.total > b.total
		end)
	elseif rankSettings[name].sort == "points" then
		table.sort(tempRankRoom, function(a, b)
			return a.points > b.points
		end)
	elseif rankSettings[name].sort == "d2" then
		table.sort(tempRankRoom, function(a, b)
			return a.d2 > b.d2
		end)
	elseif rankSettings[name].sort == "d3" then
		table.sort(tempRankRoom, function(a, b)
			return a.d3 > b.d3
		end)
	elseif rankSettings[name].sort == "assists" then
		table.sort(tempRankRoom, function(a, b)
			return a.assists > b.assists
		end)
	elseif rankSettings[name].sort == "passes" then
		table.sort(tempRankRoom, function(a, b)
			return a.passes > b.passes
		end)
	elseif rankSettings[name].sort == "def" then
		table.sort(tempRankRoom, function(a, b)
			return a.def > b.def
		end)
	elseif rankSettings[name].sort == "winRatio" then
		table.sort(tempRankRoom, function(a, b)
			return a.winRatio > b.winRatio
		end)
	elseif rankSettings[name].sort == "wins" then
		table.sort(tempRankRoom, function(a, b)
			return a.wins > b.wins
		end)
	elseif rankSettings[name].sort == "matches" then
		table.sort(tempRankRoom, function(a, b)
			return a.matches > b.matches
		end)
	end

	return tempRankRoom
end



--[[ src/functions/ranking/updateRanking.lua ]]--

function updateRanking()
	local tempRankRoom = {}

	for name, data in pairs(rankPlayer) do
		if data.matches > 0 then
			tempRankRoom[#tempRankRoom + 1] = {
				name = name,
				matches = data.matches,
				wins = data.wins,
				winRatio = winRatioPercentage(data.wins, data.matches),
				def = data.def,
				passes = data.passes,
				assists = data.assists,
				d3 = data.d3,
				d2 = data.d2,
				points = data.d3 + data.d2,
				total = data.def + data.passes + data.assists + data.d3 + data.d2 + data.points
			}
		end
	end

	rankRoom = tempRankRoom
end



--[[ src/functions/utils/isCornerCourt.lua ]]--

function isCornerCourt(x)
	if x <= 216 or x >= 1384 then
		return true
	else
		return false
	end
end



--[[ src/functions/utils/positionsString.lua ]]--

function positionsString(page)
	local positions = {}

	for i = 1, 10 do
		if i == 1 and page == 1 then
			positions[#positions + 1] = "<j>" .. tostring(i + (10 * (page - 1))) .. ".<n>"
		elseif i == 2 and page == 1 then
			positions[#positions + 1] = "<n2>" .. tostring(i + (10 * (page - 1))) .. ".<n>"
		elseif i == 3 and page == 1 then
			positions[#positions + 1] = "<ce>" .. tostring(i + (10 * (page - 1))) .. ".<n>"
		else
			positions[#positions + 1] = "<n>" .. tostring(i + (10 * (page - 1))) .. ".<n>"
		end
	end

	return positions
end



--[[ src/functions/utils/quantityPlayers.lua ]]--

function quantityPlayers()
	local playersRedCount = 0
	local playersBlueCount = 0

	for i = 1, #playersRed do
		if playersRed[i].name ~= "" then
			playersRedCount = playersRedCount + 1
		end
	end

	for i = 1, #playersBlue do
		if playersBlue[i].name ~= "" then
			playersBlueCount = playersBlueCount + 1
		end
	end

	local players = {
		red = playersRedCount,
		blue = playersBlueCount
	}

	return players
end



--[[ src/functions/utils/setPlayerArrowImage.lua ]]--

function setPlayerArrowImage(name)
	if playerTeam[name].team == "red" then
		playerArrowImage = tfm.exec.addImage("15296835cdd.png", "$" .. name, -20, -110, nil, 1, 1, _, 1)
	else
		playerArrowImage = tfm.exec.addImage("1529682cc1e.png", "$" .. name, -20, -110, nil, 1, 1, _, 1)
	end
end



--[[ src/functions/utils/showImageBallWithPlayer.lua ]]--

function showImageBallWithPlayer(name)
	if isPlayerDirectionRight[name] then
		tfm.exec.removeImage(ballIdImage)
		ballIdImage = tfm.exec.addImage("17bd8be9691.png", "$" .. name, 10, -25, nil, 1, 1, _, 1)
	else
		tfm.exec.removeImage(ballIdImage)
		ballIdImage = tfm.exec.addImage("17bd8be9691.png", "$" .. name, -40, -25, nil, 1, 1, _, 1)
	end
end



--[[ src/functions/utils/split.lua ]]--

function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end



--[[ src/functions/utils/winRatioPercentage.lua ]]--

function winRatioPercentage(wins, matches)
	if matches == 0 then
		return 0
	end

	return (wins / matches) * 100
end



--[[ src/ui/addWindow/addWindow.lua ]]--

function ui.addWindow(id, text, player, x, y, width, height, alpha, corners, closeButton, buttonText, showCornerImage)
	id = tostring(id)
	ui.addTextArea(id .. "0", "", player, x + 1, y + 1, width - 2, height - 2, 0x8a583c, 0x8a583c, alpha, true)
	ui.addTextArea(id .. "00", "", player, x + 3, y + 3, width - 6, height - 6, 0x2b1f19, 0x2b1f19, alpha, true)
	ui.addTextArea(id .. "000", "", player, x + 4, y + 4, width - 8, height - 8, 0xc191c, 0xc191c, alpha, true)
	ui.addTextArea(id .. "0000", "", player, x + 5, y + 5, width - 10, height - 10, 0x2d5a61, 0x2d5a61, alpha, true)
	ui.addTextArea(id .. "00000", text, player, x + 5, y + 6, width - 10, height - 12, 0x142b2e, 0x142b2e, alpha, true)
	local imageId = {}

	if corners then
		if showCornerImage[1] == true then
			table.insert(imageId, tfm.exec.addImage("155cbe97a3f.png", "&1", x - 7, (y + height) - 22, player))
		end

		if showCornerImage[2] == true then
			table.insert(imageId, tfm.exec.addImage("155cbe99c72.png", "&1", x - 7, y - 7, player))
		end

		if showCornerImage[3] == true then
			table.insert(imageId, tfm.exec.addImage("155cbe9bc9b.png", "&1", (x + width) - 20, (y + height) - 22, player))
		end

		if showCornerImage[4] == true then
			table.insert(imageId, tfm.exec.addImage("155cbea943a.png", "&1", (x + width) - 20, y - 7, player))
		end
	end

	if closeButton then
		ui.addTextArea(id .. "000000", "", player, x + 8, y + height - 22, width - 16, 13, 0x7a8d93, 0x7a8d93, alpha, true)
		ui.addTextArea(id .. "0000000", "", player, x + 9, y + height - 21, width - 16, 13, 0xe1619, 0xe1619, alpha, true)
		ui.addTextArea(id .. "00000000", "", player, x + 9, y + height - 21, width - 17, 12, 0x314e57, 0x314e57, alpha, true)
		ui.addTextArea(id .. "", buttonText, player, x + 9, y + height - 24, width - 17, nil, 0x314e57, 0x314e57, 0, true)
	end

	return imageId
end



--[[ src/ui/addWindow/buttonNextOrPrev.lua ]]--

function buttonNextOrPrev(id, name, x, y, width, height, alpha, text)
	id = tostring(id)
	ui.addTextArea(id .. "0000000000", "", name, x + 8, y + height - 22, width - 16, 13, 0x7a8d93, 0x7a8d93, alpha, true)
	ui.addTextArea(id .. "00000000000", "", name, x + 9, y + height - 21, width - 16, 13, 0xe1619, 0xe1619, alpha, true)
	ui.addTextArea(id .. "000000000000", "", name, x + 9, y + height - 21, width - 17, 12, 0x314e57, 0x314e57, alpha, true)
	ui.addTextArea(id .. "0000000000000", text, name, x + 9, y + height - 24, width - 17, nil, 0x314e57, 0x314e57, 0, true)
end



--[[ src/ui/addWindow/lobby/showLobbyTextAreas.lua ]]--

function showLobbyTextAreas(name)
	ui.addTextArea(0, "<p align='center'><font size='25px'>Teams", name, 50, 260, 840, 270, 0xc191c, 0x8a583c, 1, false)

	for i = 1, #playersRed do
		if playersRed[i].name == "" then
			ui.addTextArea(i, "<p align='center'><font size='15px'><a href='event:" .. "joinTeamRed" .. tostring(i) .. "'>Join", name, x[i], y[i], 185, 40, 0xE14747, 0xE14747, 1, false)
		else
			ui.addTextArea(i, "<p align='center'><font size='15px'><a href='event:leaveTeamRed" .. i .. "'>" .. playersRed[i].name, name, x[i], y[i], 185, 40, 0x871F1F, 0x871F1F, 1, false)
		end
	end

	for i = 1, #playersBlue do
		if playersBlue[i].name == "" then
			ui.addTextArea(i + 6, "<p align='center'><font size='15px'><a href='event:joinTeamBlue" .. i .. "'>Join", name, x[i + 6], y[i + 6], 185, 40, 0x184F81, 0x184F81, 1, false)
		else
			ui.addTextArea(i + 6, "<p align='center'><font size='15px'><a href='event:leaveTeamBlue" .. i .. "'>" .. playersBlue[i].name, name, x[i + 6], y[i + 6], 185, 40, 0x0B3356, 0x0B3356, 1, false)
		end
	end
end



--[[ src/ui/addWindow/ranking/rankingUI.lua ]]--

function rankingUI(name)
	local rank = sortRankingData(name)
	local page = rankSettings[name].page

	local namesRank = ""
	local matchesRank = ""
	local winsRank = ""
	local winRatioRank = ""
	local defRank = ""
	local passesRank = ""
	local assistsRank = ""
	local d3Rank = ""
	local d2Rank = ""
	local pointsRank = ""
	local totalRank = ""
	local y = 137
	local colorBackground = 0x2d5a61
	local indexPositions = positionsString(rankSettings[name].page)

	if rankingSelected[name] == "room" then
		ui.addWindow(
			24,
			"<p align='center'><font size='16px'>Room Ranking<br></font><font size='12px'><ch>Room ranking<n> | <a href='event:match'>Match ranking</a>",
			name,
			25,
			60,
			750,
			300,
			1,
			false,
			true,
			"<p align='center'><a href='event:closeRanking'>Close"
		)
	else
		ui.addWindow(
			24,
			"<p align='center'><font size='16px'>Room Ranking<br></font><font size='12px'><a href='event:room'>Room ranking</a> | <ch>Match ranking</n>",
			name,
			25,
			60,
			750,
			300,
			1,
			false,
			true,
			"<p align='center'><a href='event:closeRanking'>Close"
		)
	end

	for i = 9999559, 9999568 do
		local index = (i - 9999558) + (10 * (page - 1))

		print(rank[index])

		if rank[index] ~= nil then
			local winRatioString = tostring(rank[index].winRatio)
			ui.addTextArea(i, "", name, 35, y, 730, 6, colorBackground, colorBackground, 1, true)

			if page == 1 and index == 1 and rankingSelected[name] == "room" then
				namesRank = "" .. namesRank .. "<br>" .. indexPositions[(i - 9999558)] .. " <cs>" .. string.sub(rank[index].name, 1, #rank[index].name - 5) .. "<n><bl>" .. string.sub(rank[index].name, #rank[index].name - 4) .. "<n>"
			else
				if rankingSelected[name] == "match" then
					local color = ""

					if rank[index].color == "red" then
						color = "<r>"
					else
						color = "<bv>"
					end

					namesRank =
						"" .. namesRank .. "<br>" .. indexPositions[(i - 9999558)] .. " " .. color .. "" .. string.sub(rank[index].name, 1, #rank[index].name - 5) .. "<n><bl>" .. string.sub(rank[index].name, #rank[index].name - 4) .. "<n>"
				else
					namesRank = "" .. namesRank .. "<br>" .. indexPositions[(i - 9999558)] .. " " .. string.sub(rank[index].name, 1, #rank[index].name - 5) .. "<bl>" .. string.sub(rank[index].name, #rank[index].name - 4) .. "<n>"
				end
			end
			matchesRank = "" .. matchesRank .. "<br>" .. rank[index].matches .. ""
			winsRank = "" .. winsRank .. "<br>" .. rank[index].wins .. ""
			winRatioRank = "" .. winRatioRank .. "<br>" .. string.sub(winRatioString, 1, 4) .. ""
			defRank = "" .. defRank .. "<br>" .. rank[index].def .. ""
			passesRank = "" .. passesRank .. "<br>" .. rank[index].passes .. ""
			assistsRank = "" .. assistsRank .. "<br>" .. rank[index].assists .. ""
			d3Rank = "" .. d3Rank .. "<br>" .. rank[index].d3 .. ""
			d2Rank = "" .. d2Rank .. "<br>" .. rank[index].d2 .. ""
			pointsRank = "" .. pointsRank .. "<br>" .. rank[index].points .. ""
			totalRank = "" .. totalRank .. "<br>" .. rank[index].total .. ""

			if colorBackground == 0x2d5a61 then
				colorBackground = 0x142b2e
			else
				colorBackground = 0x2d5a61
			end
		else
			ui.addTextArea(i, "", name, 35, y, 730, 6, colorBackground, colorBackground, 0, true)
		end

		y = y + 16
	end

	ui.addTextArea(9999548, "<textformat leading='3px'><j>Name<n>" .. namesRank .. "", name, 37, 115, 185, 185, 0x161616, 0x161616, 0, true)

	if rankSettings[name].sort == "matches" then
		ui.addTextArea(9999549, "<textformat leading='3px'><ce>Matches<n>" .. matchesRank .. "", name, 237, 115, 50, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999549, "<textformat leading='3px'><j><a href='event:setsortmatches'>Matches</a><n>" .. matchesRank .. "", name, 237, 115, 50, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "wins" then
		ui.addTextArea(9999550, "<textformat leading='3px'><ce>Wins<n>" .. winsRank .. "", name, 302, 115, 40, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999550, "<textformat leading='3px'><j><a href='event:setsortwins'>Wins</a><n>" .. winsRank .. "", name, 302, 115, 40, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "winRatio" then
		ui.addTextArea(9999551, "<textformat leading='3px'><ce>%W<n>" .. winRatioRank .. "", name, 355, 115, 35, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999551, "<textformat leading='3px'><j><a href='event:setsortwinRatio'>%W</a><n>" .. winRatioRank .. "", name, 355, 115, 35, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "def" then
		ui.addTextArea(9999552, "<textformat leading='3px'><ce>DEF<n>" .. defRank .. "", name, 402, 115, 30, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999552, "<textformat leading='3px'><j><a href='event:setsortdef'>DEF</a><n>" .. defRank .. "", name, 402, 115, 30, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "passes" then
		ui.addTextArea(9999553, "<textformat leading='3px'><ce>Passes<n>" .. passesRank .. "", name, 447, 115, 50, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999553, "<textformat leading='3px'><j><a href='event:setsortpasses'>Passes</a><n>" .. passesRank .. "", name, 447, 115, 50, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "assists" then
		ui.addTextArea(9999554, "<textformat leading='3px'><ce>Assists<n>" .. assistsRank .. "", name, 512, 115, 50, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999554, "<textformat leading='3px'><j><a href='event:setsortassists'>Assists</a><n>" .. assistsRank .. "", name, 512, 115, 50, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "d3" then
		ui.addTextArea(9999555, "<textformat leading='3px'><ce>D3<n>" .. d3Rank .. "", name, 577, 115, 30, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999555, "<textformat leading='3px'><j><a href='event:setsortd3'>D3</a><n>" .. d3Rank .. "", name, 577, 115, 30, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "d2" then
		ui.addTextArea(9999556, "<textformat leading='3px'><ce>D2<n>" .. d2Rank .. "", name, 622, 115, 30, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999556, "<textformat leading='3px'><j><a href='event:setsortd2'>D2</a><n>" .. d2Rank .. "", name, 622, 115, 30, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "points" then
		ui.addTextArea(9999557, "<textformat leading='3px'><ce>Points<n>" .. pointsRank .. "", name, 667, 115, 40, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999557, "<textformat leading='3px'><j><a href='event:setsortpoints'>Points</a><n>" .. pointsRank .. "", name, 667, 115, 40, 185, 0x161616, 0x161616, 0, true)
	end

	if rankSettings[name].sort == "total" then
		ui.addTextArea(9999558, "<textformat leading='3px'><ce>Total<n>" .. totalRank .. "", name, 722, 115, 40, 185, 0x161616, 0x161616, 0, true)
	else
		ui.addTextArea(9999558, "<textformat leading='3px'><j><a href='event:setsorttotal'>Total</a><n>" .. totalRank .. "", name, 722, 115, 40, 185, 0x161616, 0x161616, 0, true)
	end

	if page == 1 then
		buttonNextOrPrev(26, name, 25, 300, 200, 30, 1, "<p align='center'><n2>Previous</n>")
	else
		buttonNextOrPrev(26, name, 25, 300, 200, 30, 1, "<p align='center'><a href='event:prevRank" .. tostring(page - 1) .. "'>Previous</a/>")
	end

	if page == 3 then
		buttonNextOrPrev(25, name, 575, 300, 200, 30, 1, "<p align='center'><n2>Next</n>")
	else
		buttonNextOrPrev(25, name, 575, 300, 200, 30, 1, "<p align='center'><a href='event:nextRank" .. tostring(page + 1) .. "'>Next</a>")
	end
end



--[[ src/ui/addWindow/showPlayerPoint.lua ]]--

function showPlayerPoint(text, textComplement)
	ui.addTextArea(62, "<p align='center'><font size='18px'>", nil, 680, 78, 240, 30, 0x161616, 0x161616, 0, false)
	for i = 1, 3 do
		ui.removeTextArea(i, nil)
	end

	addTimer(
		function(i)
			if i == 1 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>")
			elseif i == 2 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>" .. text .. "")
			elseif i == 3 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>")
			elseif i == 4 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>" .. textComplement .. "")
			elseif i == 5 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>")
			elseif i == 6 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>" .. text .. "")
			elseif i == 7 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>")
			elseif i == 8 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>" .. textComplement .. "")
			elseif i == 10 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>")
			elseif i == 11 then
				ui.updateTextArea(62, "<p align='center'><font size='18px'>" .. text .. "")
			elseif i == 12 then
				ui.removeTextArea(62, nil)
				showTheScore()
			end
		end,
		500,
		12
	)
end



--[[ src/ui/addWindow/showTheScore.lua ]]--

function showTheScore()
	ui.addTextArea(1, "<p align='center'><font size='25px'><r>" .. tostring(redScore), nil, 720, 75, 70, 40, 0x161616, 0x161616, 0, false)
	ui.addTextArea(2, "<p align='center'><font size='25px'><bv>" .. tostring(blueScore), nil, 820, 75, 70, 40, 0x161616, 0x161616, 0, false)
	ui.addTextArea(3, "", nil, 800, 75, 10, 30, 0x161616, 0x161616, 1, false)
end



--[[ src/ui/removeWindow.lua/closeWindow.lua ]]--

function closeWindow(id, name)
	local id = tostring(id)
	local str = "0"
	ui.removeTextArea(id, name)
	for i = 1, 9 do
		ui.removeTextArea(id .. "" .. str .. "", name)
		str = "" .. str .. "0"
	end
end



--[[ src/ui/removeWindow.lua/removeButtons.lua ]]--

function removeButtons(id, name)
	local id = tostring(id)
	local str = "000000000"
	ui.removeTextArea(id, name)
	for i = 10, 14 do
		ui.removeTextArea(id .. "" .. str .. "", name)
		str = "" .. str .. "0"
	end
end



--[[ src/ui/removeWindow.lua/removeLobbyTexts.lua ]]--

function removeLobbyTexts()
	for i = 0, 13 do
		ui.removeTextArea(i)
	end
end



--[[ src/ui/removeWindow.lua/removeRankingUI.lua ]]--

function removeRankingUI(name)
	closeWindow(24, name)

	for i = 9999548, 9999568 do
		ui.removeTextArea(i, name)
	end

	removeButtons(25, name)
	removeButtons(26, name)
end



--[[ src/init.lua ]]--

function init()
	tfm.exec.newGame(
		'<C><P L="2258" H="600" F="8" defilante="-1,-1,-1,1" MEDATA="6,1;;;;-0;0::0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,281,282,283,284,285,286,287:1-"/><Z><S><S T="12" X="1453" Y="462" L="315" H="10" P="0,0,0.3,0.2,-10,0,0,0"/><S T="9" X="1270" Y="463" L="50" H="200" P="0,0,0,0,0,0,0,0" m=""/><S T="10" X="1198" Y="593" L="100" H="46" P="0,0,0.3,0,170,0,0,0"/><S T="10" X="1750" Y="585" L="1020" H="46" P="0,0,0.3,0,180,0,0,0"/><S T="10" X="1129" Y="630" L="2258" H="100" P="0,0,0.3,0,0,0,0,0" N=""/><S T="9" X="1638" Y="380" L="50" H="400" P="0,0,0,0,0,0,0,0" m=""/><S T="9" X="2107" Y="426" L="170" H="400" P="0,0,0,0,0,0,0,0" m=""/><S T="12" X="1745" Y="406" L="146" H="10" P="0,0,0.3,0.2,-5,0,0,0"/><S T="12" X="1875" Y="406" L="110" H="10" P="0,0,0.3,0.2,5,0,0,0"/><S T="12" X="2341" Y="334" L="165" H="713" P="0,0,0.3,0.2,0,0,0,0" o="6a7495" N=""/><S T="12" X="-83" Y="323" L="165" H="713" P="0,0,0.3,0.2,0,0,0,0" o="6a7495" N=""/><S T="9" X="22" Y="415" L="45" H="320" P="0,0,0,0,0,0,0,0" m=""/><S T="16" X="452" Y="260" L="814" H="10" P="0,0,0.3,0.2,0,0,0,0" m=""/></S><D><DS X="417" Y="567"/></D><O/><L><JD c="666666,16,1," P1="533,551" P2="533,590"/><JD c="666666,16,1," P1="622,551" P2="622,590"/><JD c="666666,16,1," P1="711,551" P2="711,590"/><JD c="666666,16,1," P1="800,551" P2="800,590"/><JD c="666666,16,1," P1="889,551" P2="889,590"/><JD c="666666,16,1," P1="978,551" P2="978,590"/><JD c="666666,16,1," P1="1067,551" P2="1067,590"/><JD c="666666,16,1," P1="1156,551" P2="1156,590"/><JD c="666666,16,1," P1="1245,535" P2="1245,574"/><JD c="8e502b,250,1," P1="2283,142" P2="2100,265"/><JD c="8e502b,138,1," P1="1882,83" P2="2093,226"/><JD c="8e502b,78,1," P1="1922,60" P2="2171,112"/><JD c="8e502b,42,1," P1="2224,50" P2="2124,85"/><JD c="666666,16,1," P1="444,551" P2="444,590"/><JD c="666666,16,1," P1="355,551" P2="355,590"/><JD c="666666,16,1," P1="266,551" P2="266,590"/><JD c="666666,16,1," P1="177,551" P2="177,590"/><JD c="666666,16,1," P1="88,551" P2="88,590"/><JD c="000000,27,1," P1="2118,267" P2="1972,244"/><JD c="000000,27,1," P1="2230,240" P2="2117,267"/><JD c="000000,42,1," P1="2039,216" P2="2049,248"/><JD c="000000,42,1," P1="2188,212" P2="2178,244"/><JD c="000000,15,1," P1="1994,47" P2="2034,201"/><JD c="ffffff,37,1," P1="2039,216" P2="2049,248"/><JD c="000000,15,1," P1="2041,224" P2="2048,247"/><JD c="000000,15,1," P1="2236,29" P2="2193,195"/><JD c="ffffff,10,1," P1="1994,47" P2="2034,200"/><JD c="ffffff,37,1," P1="2188,212" P2="2178,244"/><JD c="000000,15,1," P1="2187,217" P2="2178,246"/><JD c="ffffff,10,1," P1="2236,29" P2="2193,195"/><JD c="000000,5,1," P1="1922,25" P2="1972,223"/><JD c="000000,142,1," P1="2013,415" P2="2198,415"/><JD c="000000,5,1," P1="2117,64" P2="2117,570"/><JD c="000000,10,1," P1="2027,259" P2="2060,351"/><JD c="ffffff,8,1," P1="2027,259" P2="2060,351"/><JD c="000000,10,1," P1="2189,260" P2="2161,364"/><JD c="ffffff,22,1," P1="2118,267" P2="1972,244"/><JD c="ffffff,22,1," P1="2230,240" P2="2117,267"/><JD c="ffffff,8,1," P1="2189,260" P2="2161,364"/><JD c="c27b00,60,1," P1="2021,378" P2="2200,378"/><JD c="b08766,55,1," P1="2021,378" P2="2198,379"/><JD c="cad4e1,106,1," P1="2209,537" P2="2041,537"/><JD c="777777,6,1," P1="-9,543" P2="1149,543"/><JD c="444444,6,1," P1="-9,549" P2="1149,549"/><JD c="777777,6,1," P1="-9,555" P2="1149,555"/><JD c="444444,6,1," P1="1235,534" P2="1149,549"/><JD c="777777,6,1," P1="1235,540" P2="1149,555"/><JD c="777777,6,1," P1="1235,528" P2="1149,543"/><JD c="777777,6,1," P1="1267,528" P2="1235,528"/><JD c="777777,6,1," P1="1270,540" P2="1235,540"/><JD c="444444,6,1," P1="1268,534" P2="1235,534"/><JD c="238ac2,20,0.35," P1="1311,312" P2="1325,482"/><JD c="238ac2,27,0.35," P1="1331,310" P2="1345,480"/><JD c="238ac2,20,0.35," P1="1295,312" P2="1309,482"/><JD c="238ac2,20,0.35," P1="1362,312" P2="1376,482"/><JD c="238ac2,20,0.35," P1="1376,282" P2="1392,476"/><JD c="238ac2,20,0.35," P1="1392,283" P2="1409,482"/><JD c="238ac2,20,0.35," P1="1408,274" P2="1426,482"/><JD c="238ac2,44,0.35," P1="1435,256" P2="1457,484"/><JD c="238ac2,20,0.35," P1="1464,251" P2="1486,484"/><JD c="238ac2,20,0.35," P1="1481,251" P2="1503,484"/><JD c="238ac2,20,0.35," P1="1498,251" P2="1520,484"/><JD c="238ac2,42,0.35," P1="1528,237" P2="1552,478"/><JD c="238ac2,20,0.35," P1="1556,233" P2="1580,484"/><JD c="238ac2,20,0.35," P1="1573,233" P2="1597,484"/><JD c="238ac2,20,0.35," P1="1590,233" P2="1614,484"/><JD c="238ac2,20,0.35," P1="1659,140" P2="1683,484"/><JD c="238ac2,20,0.35," P1="1676,140" P2="1700,484"/><JD c="238ac2,20,0.35," P1="1693,140" P2="1717,484"/><JD c="238ac2,20,0.35," P1="1722,161" P2="1744,484"/><JD c="238ac2,20,0.35," P1="1737,140" P2="1761,484"/><JD c="238ac2,20,0.35," P1="1753,140" P2="1777,484"/><JD c="238ac2,20,0.35," P1="1770,140" P2="1794,484"/><JD c="238ac2,20,0.35," P1="1786,140" P2="1810,484"/><JD c="238ac2,37,0.35," P1="1813,140" P2="1837,484"/><JD c="238ac2,20,0.35," P1="1839,149" P2="1862,484"/><JD c="238ac2,20,0.35," P1="1856,149" P2="1878,484"/><JD c="238ac2,20,0.35," P1="1307,469" P2="1624,416"/><JD c="238ac2,20,0.35," P1="1307,452" P2="1624,399"/><JD c="238ac2,20,0.35," P1="1307,435" P2="1624,382"/><JD c="238ac2,20,0.35," P1="1307,418" P2="1624,365"/><JD c="238ac2,20,0.35," P1="1307,401" P2="1624,348"/><JD c="238ac2,20,0.35," P1="1307,384" P2="1624,331"/><JD c="238ac2,20,0.35," P1="1307,367" P2="1624,314"/><JD c="238ac2,20,0.35," P1="1289,353" P2="1624,296"/><JD c="238ac2,20,0.35," P1="1289,336" P2="1624,279"/><JD c="238ac2,20,0.35," P1="1289,319" P2="1624,262"/><JD c="238ac2,20,0.35," P1="1289,302" P2="1624,245"/><JD c="238ac2,20,0.35," P1="1289,285" P2="1624,228"/><JD c="238ac2,20,0.35," P1="1653,399" P2="1818,383"/><JD c="238ac2,20,0.35," P1="1653,383" P2="1818,367"/><JD c="238ac2,20,0.35," P1="1653,366" P2="1818,350"/><JD c="238ac2,20,0.35," P1="1653,349" P2="1818,333"/><JD c="238ac2,20,0.35," P1="1653,332" P2="1818,316"/><JD c="238ac2,20,0.35," P1="1653,315" P2="1818,299"/><JD c="238ac2,20,0.35," P1="1653,298" P2="1813,282"/><JD c="238ac2,20,0.35," P1="1653,282" P2="1813,265"/><JD c="238ac2,20,0.35," P1="1653,265" P2="1814,249"/><JD c="238ac2,20,0.35," P1="1657,247" P2="1805,222"/><JD c="238ac2,20,0.35," P1="1657,230" P2="1805,205"/><JD c="238ac2,20,0.35," P1="1657,214" P2="1805,189"/><JD c="238ac2,20,0.35," P1="1657,197" P2="1805,172"/><JD c="238ac2,20,0.35," P1="1657,180" P2="1805,155"/><JD c="238ac2,20,0.35," P1="1830,384" P2="1885,392"/><JD c="238ac2,20,0.35," P1="1830,367" P2="1885,375"/><JD c="238ac2,20,0.35," P1="1830,350" P2="1885,358"/><JD c="238ac2,20,0.35," P1="1830,333" P2="1885,341"/><JD c="238ac2,20,0.35," P1="1830,316" P2="1885,324"/><JD c="238ac2,20,0.35," P1="1830,299" P2="1885,307"/><JD c="238ac2,20,0.35," P1="1830,282" P2="1885,290"/><JD c="238ac2,20,0.35," P1="1830,265" P2="1885,273"/><JD c="238ac2,20,0.35," P1="1830,249" P2="1885,257"/><JD c="238ac2,20,0.35," P1="1820,223" P2="1873,237"/><JD c="238ac2,20,0.35," P1="1820,206" P2="1873,220"/><JD c="238ac2,20,0.35," P1="1820,189" P2="1873,203"/><JD c="238ac2,20,0.35," P1="1820,171" P2="1873,185"/><JD c="238ac2,20,0.35," P1="1820,154" P2="1873,168"/><JD c="238ac2,20,0.35," P1="1761,143" P2="1797,136"/><JD c="aaaaaa,85,1," P1="1966,304" P2="2001,561"/><JD c="aaaaaa,90,1," P1="1918,216" P2="1960,311"/><JD c="aaaaaa,68,1," P1="1900,144" P2="1931,228"/><JD c="aaaaaa,75,1," P1="1848,49" P2="1877,119"/><JD c="aaaaaa,75,1," P1="2246,212" P2="2242,572"/><JD c="aaaaaa,75,1," P1="2310,29" P2="2245,212"/><JD c="c27b00,42,1," P1="2115,380" P2="2115,381"/><JD c="ffffff,63,1," P1="1752,433" P2="1302,513"/><JD c="cad4e1,106,1," P1="1636,539" P2="1328,563"/><JD c="c7c7c7,10,1," P1="1660,53" P2="1678,60"/><JD c="c7c7c7,44,1," P1="1643,62" P2="1661,152"/><JD c="e9e9e9,47,1," P1="1323,170" P2="1284,200"/><JD c="e9e9e9,70,1," P1="1350,171" P2="1296,213"/><JD c="e9e9e9,104,1," P1="1370,221" P2="1306,268"/><JD c="e9e9e9,133,1," P1="1352,197" P2="1569,144"/><JD c="e9e9e9,47,1," P1="1576,70" P2="1367,140"/><JD c="e4e4e4,37,1," P1="1605,67" P2="1627,60"/><JD c="ffffff,13,1," P1="1735,32" P2="1768,22"/><JD c="ffffff,47,1," P1="1733,49" P2="1738,133"/><JD c="ffffff,95,1," P1="1791,54" P2="1761,101"/><JD c="dddddd,19,1," P1="1814,34" P2="1803,15"/><JD c="dddddd,37,1," P1="1817,30" P2="1823,124"/><JD c="c7c7c7,44,1," P1="1680,76" P2="1682,150"/><JD c="000000,5,1," P1="1699,61" P2="1705,153"/><JD c="000000,5,1," P1="1718,151" P2="1711,34"/><JD c="000000,5,1," P1="1795,4" P2="1803,127"/><JD c="000000,5,1," P1="1835,18" P2="1841,138"/><JD c="ffffff,70,1," P1="1909,436" P2="1758,434"/><JD c="000000,114,1," P1="1674,530" P2="1826,516"/><JD c="000000,104,1," P1="1831,510" P2="1874,518"/><JD c="ffffff,56,1," P1="1907,322" P2="1926,545"/><JD c="000000,28,1," P1="1641,475" P2="1282,527"/><JD c="000000,9,1," P1="1938,409" P2="1829,396"/><JD c="000000,9,1," P1="1830,396" P2="1668,411"/><JD c="000000,9,1," P1="1615,430" P2="1305,484"/><JD c="000000,15,1," P1="1874,253" P2="1816,238"/><JD c="000000,15,1," P1="1816,238" P2="1720,253"/><JD c="000000,15,1," P1="1720,253" P2="1649,272"/><JD c="adadad,25,1," P1="1597,214" P2="1478,236"/><JD c="adadad,25,1," P1="1475,236" P2="1416,258"/><JD c="dedede,4,1," P1="1615,430" P2="1305,484"/><JD c="adadad,25,1," P1="1416,258" P2="1288,321"/><JD c="000000,23,1," P1="1287,301" P2="1344,336"/><JD c="000000,23,1," P1="1372,265" P2="1344,338"/><JD c="000000,25,1," P1="1346,339" P2="1368,572"/><JD c="000000,23,1," P1="1477,223" P2="1521,276"/><JD c="000000,23,1," P1="1577,199" P2="1521,276"/><JD c="000000,25,1," P1="1522,277" P2="1550,572"/><JD c="000000,23,1," P1="1477,223" P2="1431,308"/><JD c="000000,23,1," P1="1373,265" P2="1431,308"/><JD c="000000,25,1," P1="1431,309" P2="1455,572"/><JD c="000000,32,1," P1="1604,288" P2="1504,312"/><JD c="000000,32,1," P1="1399,342" P2="1503,311"/><JD c="000000,32,1," P1="1292,383" P2="1399,341"/><JD c="ffffff,27,1," P1="1399,341" P2="1503,311"/><JD c="000000,5,1," P1="1497,69" P2="1384,107"/><JD c="ffffff,27,1," P1="1292,383" P2="1399,341"/><JD c="c1c1c1,16,1," P1="1281,314" P2="1299,569"/><JD c="000000,5,1," P1="1587,44" P2="1497,69"/><JD c="000000,5,1," P1="1400,253" P2="1273,311"/><JD c="000000,5,1," P1="1465,228" P2="1400,253"/><JD c="000000,5,1," P1="1597,203" P2="1465,228"/><JD c="000000,5,1," P1="1600,224" P2="1468,249"/><JD c="000000,6,1," P1="1403,276" P2="1468,250"/><JD c="000000,5,1," P1="1289,305" P2="1309,569"/><JD c="000000,6,1," P1="1292,333" P2="1403,276"/><JD c="ffffff,10,1," P1="1720,253" P2="1649,272"/><JD c="ffffff,27,1," P1="1604,288" P2="1504,311"/><JD c="ffffff,20,1," P1="1431,309" P2="1455,572"/><JD c="ffffff,18,1," P1="1373,265" P2="1431,308"/><JD c="ffffff,18,1," P1="1287,301" P2="1344,336"/><JD c="dedede,4,1," P1="1830,396" P2="1668,411"/><JD c="ffffff,18,1," P1="1477,223" P2="1431,308"/><JD c="ffffff,20,1," P1="1522,277" P2="1550,572"/><JD c="ffffff,18,1," P1="1577,199" P2="1521,276"/><JD c="ffffff,18,1," P1="1477,223" P2="1521,276"/><JD c="ffffff,20,1," P1="1345,337" P2="1368,572"/><JD c="ffffff,18,1," P1="1372,265" P2="1344,336"/><JD c="e9e9e9,20,1," P1="1268,300" P2="1443,220"/><JD c="dedede,4,1," P1="1938,409" P2="1829,396"/><JD c="000000,23,1," P1="1258,246" P2="1280,568"/><JD c="000000,5,1," P1="1261,188" P2="1266,242"/><JD c="e4e4e4,18,1," P1="1258,248" P2="1280,568"/><JD c="ffffff,10,1," P1="1816,238" P2="1720,253"/><JD c="000000,11,1," P1="1263,240" P2="1252,242"/><JD c="ffffff,10,1," P1="1874,253" P2="1816,238"/><JD c="000000,15,1," P1="1707,160" P2="1735,573"/><JD c="ffffff,10,1," P1="1707,160" P2="1735,573"/><JD c="000000,20,1," P1="1806,135" P2="1837,573"/><JD c="ffffff,15,1," P1="1806,135" P2="1837,573"/><JD c="000000,15,1," P1="1654,173" P2="1806,132"/><JD c="000000,15,1," P1="1873,151" P2="1901,570"/><JD c="000000,9,1," P1="1886,296" P2="1929,300"/><JD c="ffffff,54,1," P1="1947,497" P2="1956,554"/><JD c="000000,15,1," P1="1877,201" P2="1895,292"/><JD c="000000,15,1," P1="1806,132" P2="1873,151"/><JD c="000000,9,1," P1="1899,466" P2="1971,476"/><JD c="adadad,10,1," P1="1654,173" P2="1806,132"/><JD c="ffffff,10,1," P1="1873,151" P2="1901,570"/><JD c="adadad,10,1," P1="1806,132" P2="1873,151"/><JD c="000000,6,1," P1="1495,506" P2="1501,566"/><JD c="000000,6,1," P1="1580,492" P2="1588,565"/><JD c="000000,6,1," P1="1404,506" P2="1410,566"/><JD c="000000,6,1," P1="1328,513" P2="1334,573"/><JD c="000000,9,1," P1="1971,476" P2="1982,568"/><JD c="000000,5,1," P1="1313,145" P2="1261,188"/><JD c="000000,5,1," P1="1384,107" P2="1313,145"/><JD c="000000,9,1," P1="1930,300" P2="1944,471"/><JD c="e4e4e4,59,1," P1="1617,90" P2="1648,578"/><JD c="000000,5,1," P1="1795,4" P2="1835,18"/><JD c="000000,5,1," P1="1711,34" P2="1795,4"/><JD c="e9e9e9,20,1," P1="1443,220" P2="1589,192"/><JD c="000000,5,1," P1="1642,39" P2="1699,61"/><JD c="000000,5,1," P1="1642,39" P2="1680,595"/><JD c="000000,5,1," P1="1617,583" P2="1587,44"/><JD c="000000,5,1," P1="1589,54" P2="1642,39"/><JD c="00007a,10,1," P1="1471,114" P2="1476,168"/><JD c="00007a,10,1," P1="1303,180" P2="1278,195"/><JD c="00007a,10,1," P1="1307,232" P2="1304,181"/><JD c="00007a,10,1," P1="1291,211" P2="1303,204"/><JD c="00007a,10,1," P1="1283,245" P2="1307,233"/><JD c="00007a,10,1," P1="1320,228" P2="1323,171"/><JD c="00007a,10,1," P1="1522,154" P2="1506,102"/><JD c="00007a,10,1," P1="1322,209" P2="1332,206"/><JD c="00007a,10,1," P1="1363,158" P2="1362,151"/><JD c="00007a,10,1," P1="1344,160" P2="1362,151"/><JD c="00007a,10,1," P1="1346,187" P2="1344,160"/><JD c="00007a,10,1," P1="1364,178" P2="1346,187"/><JD c="00007a,10,1," P1="1366,205" P2="1364,178"/><JD c="00007a,10,1," P1="1366,205" P2="1349,214"/><JD c="00007a,10,1," P1="1348,213" P2="1347,205"/><JD c="00007a,10,1," P1="1374,145" P2="1378,202"/><JD c="00007a,10,1," P1="1390,136" P2="1379,173"/><JD c="00007a,10,1," P1="1394,196" P2="1379,173"/><JD c="00007a,10,1," P1="1408,129" P2="1400,132"/><JD c="00007a,10,1," P1="1407,192" P2="1400,132"/><JD c="00007a,10,1," P1="1413,158" P2="1405,161"/><JD c="00007a,10,1," P1="1422,185" P2="1407,192"/><JD c="00007a,10,1," P1="1434,180" P2="1427,126"/><JD c="00007a,10,1," P1="1420,125" P2="1432,121"/><JD c="00007a,10,1," P1="1285,193" P2="1287,243"/><JD c="00007a,10,1," P1="1465,115" P2="1484,107"/><JD c="00007a,10,1," P1="1472,171" P2="1490,164"/><JD c="00007a,10,1," P1="1486,107" P2="1492,163"/><JD c="00007a,10,1," P1="1474,140" P2="1489,135"/><JD c="00007a,10,1," P1="1503,159" P2="1506,102"/><JD c="00007a,10,1," P1="1339,220" P2="1323,171"/><JD c="00007a,10,1," P1="1506,142" P2="1515,138"/><JD c="00007a,10,1," P1="1529,95" P2="1535,150"/><JD c="00007a,10,1," P1="1574,141" P2="1561,145"/><JD c="00007a,10,1," P1="1555,90" P2="1561,145"/><JD c="00007a,10,1," P1="1548,146" P2="1535,150"/><JD c="7a0000,10,1," P1="1371,226" P2="1375,251"/><JD c="7a0000,10,1," P1="1361,226" P2="1379,219"/><JD c="7a0000,10,1," P1="1411,209" P2="1429,202"/><JD c="7a0000,10,1," P1="1414,238" P2="1411,210"/><JD c="7a0000,10,1," P1="1413,224" P2="1431,217"/><JD c="7a0000,10,1," P1="1461,217" P2="1458,190"/><JD c="7a0000,10,1," P1="1470,207" P2="1458,190"/><JD c="7a0000,10,1," P1="1478,183" P2="1471,206"/><JD c="7a0000,10,1," P1="1482,210" P2="1479,182"/><JD c="000000,9,1," P1="1868,12" P2="2011,303"/><JD c="000000,9,1," P1="2206,219" P2="2206,567"/><JD c="000000,9,1," P1="2275,15" P2="2206,219"/><JD c="000000,9,1," P1="2011,302" P2="2044,567"/><JD c="000000,9,1," P1="1836,18" P2="1868,12"/><JD c="000000,9,1," P1="1868,12" P2="2117,64"/><JD c="000000,9,1," P1="2275,14" P2="2117,64"/><JD c="000000,6,1," P1="2124,450" P2="2124,580"/><L P1="0,0" P2="0,0" f="10" C1="0,0" C2="0,0"/></L></Z></C>'
	)

	gameStats = {
		stopTimer = false,
		stopTimerSeconds = 15
	}

	minPlayerRed = 1
	minPlayerBlue = 1

	canPass = true

	playersRed = {
		[1] = { name = "" },
		[2] = { name = "" },
		[3] = { name = "" },
		[4] = { name = "" },
		[5] = { name = "" },
		[6] = { name = "" }
	}

	playersBlue = {
		[1] = { name = "" },
		[2] = { name = "" },
		[3] = { name = "" },
		[4] = { name = "" },
		[5] = { name = "" },
		[6] = { name = "" }
	}

	redScore = 0
	blueScore = 0
	winscore = 16

	for name, data in pairs(tfm.get.room.playerList) do
		for i = 1, #keys do
			if keys[i] == 32 then
				system.bindKeyboard(name, keys[i], true, true)
				system.bindKeyboard(name, keys[i], false, true)
			else
				system.bindKeyboard(name, keys[i], true, true)
			end
		end

		delayCountPass[name] = false
		playerDisableWall[name] = false
		playerDelayWall[name] = false
		playerCanGetBall[name] = true
		playersInGame[name] = false
		if rankingSelected[name] == nil then
			rankingSelected[name] = "room"
		end

		playerTeam[name] = {
			team = "",
			index = 1
		}
		isPlayerDirectionRight[name] = true
		playerForce[name] = 0
		rankSettings[name] = {
			page = 1,
			sort = "total",
			open = false
		}

		playerPressSpace[name] = false
		playerTeamHistory[name] = {}
		lastPlayerKey[name] = 0

		rankPlayerMatch = {}

		if rankPlayer[name] == nil then
			rankPlayer[name] = {
				name = name,
				matches = 0,
				wins = 0,
				winRatio = 0,
				def = 0,
				passes = 0,
				assists = 0,
				d3 = 0,
				d2 = 0,
				points = 0,
				total = 0
			}
		end

		tfm.exec.setNameColor(name, 0x9292AA)

		tfm.exec.setPlayerScore(name, 0, false)

		system.bindMouse(name, true)
	end

	ui.addTextArea(0, "<p align='center'><font size='25px'>Teams", nil, 50, 260, 840, 270, 0xc191c, 0x8a583c, 1, false)

	for i = 1, #x do
		local event = "joinTeamRed" .. tostring(i) .. ""
		local color = 0xE14747

		if i > 6 then
			event = "joinTeamBlue" .. tostring(i - 6) .. ""
			color = 0x184F81
		end

		ui.addTextArea(i, "<p align='center'><font size='15px'><a href='event:" .. event .. "'>Join", nil, x[i], y[i], 185, 40, color, color, 1, false)
	end

	lobbyTimer = os.time() + 15000

	mode = "lobby"
end

init()

