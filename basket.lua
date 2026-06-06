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

		if key == 32 and playerCanGetBall[name] and ballOwner ~= name and down then
			if ballOwner == "" then
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
	playerCanGetBall[name] = false

	removeTimer("canCatch" .. name .. "")

	canCatch = addTimer(
		function(i)
			if i == 1 then
				playerCanGetBall[name] = true
			end
		end,
		500,
		1,
		"canCatch" .. name .. ""
	)

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
	tfm.exec.newGame("@6068644")

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

