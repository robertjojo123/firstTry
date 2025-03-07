-- ✅ **Function Forward Declarations**
local moveTo, saveProgress, loadProgress, placeBlock, buildSchematic, restock, refuelTurtle, findChestAccess, getChestYLevel, getBlockData, findPath

-- ✅ **Restore Disk Startup for Future Turtles**
if peripheral.find("drive") then
    print("🔄 Restoring disk startup...")
    if fs.exists("/disk/startuptemp.lua") then
        shell.run("mv /disk/startuptemp.lua /disk/startup.lua")
        print("✅ Disk startup restored.")
    end
end

-- ✅ **Load Progress or Set Default Start Position**
local function loadProgress()
    if fs.exists("progress.txt") then
        local file = fs.open("progress.txt", "r")
        local data = textutils.unserialize(file.readAll())  
        file.close()
        if data and data.index and data.pos then
            print("🔄 Resuming from saved position:", data.pos.x, data.pos.y, data.pos.z)
            return data.index, data.pos
        end
    end
    print("✅ No progress file found. Setting default start position.")
    return 1, {x = 0, y = 0, z = 0, dir = 0}
end

-- ✅ **Save Progress Function**
local function saveProgress(index, position)
    local file = fs.open("progress.txt", "w")
    file.write(textutils.serialize({index = index, pos = position}))
    file.close()
end

-- ✅ **Set Starting Position**
local buildIndex, pos = loadProgress()

-- ✅ **Load Block Data**
if not fs.exists("output.lua") then
    print("🌐 Block data not found! Downloading...")
    local dataURL = "https://raw.githubusercontent.com/robertjojo123/limpy3/main/output.lua"
    shell.run("wget " .. dataURL .. " output.lua")

    if not fs.exists("output.lua") then
        print("❌ Failed to download block data. Exiting.")
        return
    end
end

print("🔄 Loading block data...")
local blocks = dofile("output.lua")

-- ✅ **Turtle Movement System with Pathfinding**
local function turnLeft() turtle.turnLeft(); pos.dir = (pos.dir - 1) % 4 end
local function turnRight() turtle.turnRight(); pos.dir = (pos.dir + 1) % 4 end

-- ✅ **Find Chest Level Based on Block Type**
getChestYLevel = function(block)
    local blockYLevels = {
        ["wool"] = 1, 
        ["grass"] = 2,  
        ["dirt"] = 3, 
        ["cobblestone"] = 4,  
        ["clay"] = 5, 
        ["stone"] = 6,  
        ["sand"] = 7,  
        ["glass"] = 8,
        ["oak_planks"] = 9, 
        ["spruce_planks"] = 10,  
        ["bricks"] = 11, 
        ["quartz_block"] = 12
    }
    return blockYLevels[block] or 13
end

-- ✅ **Find an Accessible Side of the Chest**
findChestAccess = function(target)
    local accessPositions = {
        {x = target.x - 1, z = target.z, dir = 1},
        {x = target.x + 1, z = target.z, dir = 3},
        {x = target.x, z = target.z - 1, dir = 0},
        {x = target.x, z = target.z + 1, dir = 2}
    }

    for _, access in ipairs(accessPositions) do
        if moveTo({x = access.x, y = target.y, z = access.z}) then
            while pos.dir ~= access.dir do turnRight() end
            local exists, _ = turtle.inspect()
            if not exists then
                print("✅ Found open access to chest!")
                return true
            end
        end
    end

    print("🚧 All sides blocked! Retrying...")
    sleep(2)
    return findChestAccess(target)
end

-- ✅ **Pathfinding Movement Function (A* Algorithm)**
findPath = function(start, goal)
    local openSet = {{x = start.x, z = start.z, g = 0, f = 0}}
    local closedSet = {}
    local cameFrom = {}

    local function heuristic(a, b)
        return math.abs(a.x - b.x) + math.abs(a.z - b.z)
    end

    while #openSet > 0 do
        table.sort(openSet, function(a, b) return a.f < b.f end)
        local current = table.remove(openSet, 1)

        if current.x == goal.x and current.z == goal.z then
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = cameFrom[current.x .. "," .. current.z]
            end
            return path
        end
        table.insert(closedSet, current.x .. "," .. current.z)

        local directions = {
            {x = current.x + 1, z = current.z, dir = 1},
            {x = current.x - 1, z = current.z, dir = 3},
            {x = current.x, z = current.z + 1, dir = 2},
            {x = current.x, z = current.z - 1, dir = 0}
        }

        for _, neighbor in ipairs(directions) do
            if not closedSet[neighbor.x .. "," .. neighbor.z] then
                local gScore = current.g + 1
                local fScore = gScore + heuristic(neighbor, goal)

                table.insert(openSet, {x = neighbor.x, z = neighbor.z, g = gScore, f = fScore})
                cameFrom[neighbor.x .. "," .. neighbor.z] = current
            end
        end
    end

    print("❌ No valid path found!")
    return {}
end

-- ✅ **Restock Function**
restock = function(block)
    local blockID = getBlockData(block)  
    local chestY = getChestYLevel(block)  
    local chestPos = {x = 5, y = chestY, z = -5}

    print("🔄 Moving to restock", blockID)
    findChestAccess(chestPos)

    while not turtle.suck(64) do
        print("❌ No", blockID, "available! Retrying...")
        sleep(2)
    end

    print("✅ Restocked", blockID)
    return true
end

-- ✅ **Build Process**
buildSchematic = function()
    print("🏗 Starting build process...")
    for _, blockData in ipairs(blocks) do
        moveTo({x = blockData.x, y = blockData.y, z = blockData.z})
        while not placeBlock(blockData[1]) do
            print("🔄 Retrying placement after restock")
        end
    end
    print("✅ Build complete!")
end

buildSchematic()
