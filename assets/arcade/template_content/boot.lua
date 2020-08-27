require "system"
gpu = system.getDevice("gpu")
speaker = system.getDevice("speaker")
gamepad = system.getDevice("gamepad")

sokX, sokY = 0, 0
selectedLevel = 1
states = {a=false, b=false, x=0, y=0, xlen=0, ylen=0, alen=0, blen=0}
history = {}
header = gpu.loadTGA( io.open( "header.tga", "rb" ) )

sound0 = {
            waveform = "sawtooth",
            frequency = 70,
            duration = 0.05,
            slide = 100,
            volume = 0.5
        }
sound1 = {
            waveform = "sawtooth",
            frequency = 50,
            duration = 0.1,
            slide = 100
        }
sound2 = {
            waveform = "square",
            frequency = 500,
            duration = 0.1
        }
sound3 = {
            waveform = "square",
            frequency = 800,
            duration = 0.5
        }

function loadLevel(lvl)
	history = {}
    congratulated = false
    local map = {}
    for x = -1, 12 do
        map[x] = {}
        for y = -1, 12 do
            map[x][y] = {}
        end
    end
    for x = -1, 12 do
        map[x][-1].wall = false
        map[x][12].wall = false
        map[-1][x].wall = false
        map[12][x].wall = false
    end
    y = 0
    for line in io.lines("levels/" .. tostring(lvl) .. ".lvl") do
        for x = 0, 11 do
            c = line:sub(x+1, x+1)
            map[x][y].wall = c == "#"
            map[x][y].goal = c == "G" or c == "S" or c == "C"
            if c == "S" or c == "s" then
                sokX, sokY = x, y
            end
            map[x][y].crate = c == "C" or c == "c"
        end
        y=y+1
    end
    return map
end

function drawWall(x, y)
    if y == 0 then
        gpu.drawLine(0, 1, 4, 1, 1)
    else
        if not map[x][y-1].wall then
            gpu.drawLine(1, 0, 3, 0, 1)
        end
        if not map[x-1][y].wall or not map[x][y-1].wall or not map[x-1][y-1].wall then
            gpu.drawPixel(0,0, 1)
        end
        if not map[x+1][y].wall or not map[x][y-1].wall or not map[x+1][y-1].wall then
            gpu.drawPixel(4,0, 1)
        end
    end
    if y == 11 then
        gpu.drawLine(0, 3, 4, 3, 1)
    else
        if not map[x][y+1].wall then
            gpu.drawLine(1, 4, 3, 4, 1)
        end
        if not map[x-1][y].wall or not map[x][y+1].wall or not map[x-1][y+1].wall then
            gpu.drawPixel(0,4, 1)
        end
        if not map[x+1][y].wall or not map[x][y+1].wall or not map[x+1][y+1].wall then
            gpu.drawPixel(4,4, 1)
        end
    end
    if not map[x-1][y].wall then
        gpu.drawLine(0, 1, 0, 3, 1)
    end
    if not map[x+1][y].wall then
        gpu.drawLine(4, 1, 4, 3, 1)
    end
end
    

function drawGoal()
    gpu.drawLine(2, 1, 2, 3, 1)
    gpu.drawLine(1, 2, 3, 2, 1)
end

function drawCrate()
    gpu.drawLine(0, 2, 2, 0, 1)
    gpu.drawLine(2, 0, 4, 2, 1)
    gpu.drawLine(4, 2, 2, 4, 1)
    gpu.drawLine(2, 4, 0, 2, 1)
end

function drawSokoban()
    gpu.drawLine(2, 0, 2, 2, 1)
    gpu.drawLine(1, 1, 3, 1, 1)
    gpu.drawLine(1, 3, 1, 4, 1)
    gpu.drawLine(3, 3, 3, 4, 1)
end

function drawLevel(shif)
    gpu.clear(0)
    for x = 0, 11 do
        for y = 0, 11 do
            c = map[x][y]
            gpu.setOffset(x*5, y*5-1)
            if c.wall then drawWall(x, y) end
            if c.goal then drawGoal() end
            if x == (sokX + states.x) and y == (sokY + states.y) then
                gpu.setOffset(x*5 + shif*states.x, y*5 + shif*states.y-1)
            end
            if c.crate then drawCrate() end            
        end
    end
    gpu.setOffset(sokX*5 + shif*states.x, sokY*5 + shif*states.y-1)
    drawSokoban()
    gpu.setOffset(0,0)
    gpu.drawText(0, 59, "LVL "..tostring(selectedLevel))
    if congratulated then
        gpu.drawText(30, 59, "Victory!")
    end
end

function drawMenu() 	
	gpu.setOffset(0,0)
	gpu.drawImage(0,2, header)
    for x = 0, 4 do
        for y = 0, 5 do
            n = y*5+x+1
            gpu.setOffset(2 + x * 13, 17 + y * 8)
            gpu.drawText(0, 0, tostring(n))
            if selectedLevel == n then
                gpu.drawBoxOutline(-2, -2, 11, 9, 1)
            end
        end
    end
end

function tryMove()
    if states.x ~= 0 then states.y = 0 end
    if states.x == 0 and states.y == 0 then
        return
    end
    c0 = map[sokX][sokY]
    c1 = map[sokX+states.x][sokY+states.y]
    moveSokoban = false
    moveCrate = false
    if not c1.wall then
        if c1.crate then
            c2 = map[sokX+2*states.x][sokY+2*states.y]
            moveSokoban = not c2.wall and not c2.crate
            moveCrate = moveSokoban
        else
            moveSokoban = true
        end
    end
    if moveSokoban then
        animateMovement()
        sokX = sokX + states.x
        sokY = sokY + states.y
        if not moveCrate then
            speaker.play(sound0)
        end
    end
    if moveCrate then
        map[sokX][sokY].crate = false
        map[sokX+states.x][sokY+states.y].crate = true
        speaker.play(sound1)
    end
	if moveSokoban then
		history[#history+1] = {x=states.x, y=states.y, sokoban=moveSokoban, crate=moveCrate}
	end	
end

function undo()
	if #history > 0 then
		move = history[#history]
		history[#history] = nil
		if move.crate then
			map[sokX+move.x][sokY+move.y].crate = false
			map[sokX][sokY].crate = true
		end
		if move.sokoban then
			sokX = sokX - move.x
			sokY = sokY - move.y        
		end
	end
end

function isSolved()
    for x = 0, 11 do
        for y = 0, 11 do
            if map[x][y].goal and not map[x][y].crate then
                return false
            end
        end
    end
    return true
end

function checkVictory()    
    if not congratulated and isSolved() then
        congratulated = true
        speaker.play(sound2, 1)
        speaker.queue(sound3, 1)
    end
end

function animateMovement()
    for shif = 1, 4 do
        drawLevel(shif)
        system.sleep(0)
        system.sleep(0)
    end
end

function setStates()
   function calcMod(x)
		if x > 250 then return 2 end
		if x > 80 then return 5 end
		if x > 40 then return 10 end
		return 20
	end
	states.xlen = gamepad.getAxis(0) ~= 0 and states.xlen + 1 or 0
	states.ylen = gamepad.getAxis(1) ~= 0 and states.ylen + 1 or 0
	states.x = (states.xlen % calcMod(states.xlen) == 1) and gamepad.getAxis(0) or 0
	states.y = (states.ylen % calcMod(states.ylen) == 1) and gamepad.getAxis(1) or 0
	states.alen = gamepad.getButton(0) and states.alen + 1 or 0
	states.blen = gamepad.getButton(1) and states.blen + 1 or 0
	states.a = states.alen == 1
	states.b = states.blen == 1
end

function changeSelection()
    sel = math.floor(math.max(1, math.min(selectedLevel + states.x + states.y * 5, 30)))
    if sel ~= selectedLevel then
        selectedLevel = sel
        speaker.play(sound0)
    end
end

function main()
    screen = menu
    while true do
        setStates()
        gpu.clear()
        screen()
        system.sleep(0)
    end
end

function menu()
    if states.a then
        screen = level
        map = loadLevel(selectedLevel)
        return        
    end
    changeSelection()    
	drawMenu()
end

function level()
	if states.b  then
        undo()
    end
    if states.a then
        screen = menu
        return
    end
    tryMove()
    checkVictory()
    drawLevel(0)
end

main()
