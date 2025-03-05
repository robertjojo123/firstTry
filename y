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

-- ✅ **Check if Turtle ID and Block Data Exist**
local turtleID = nil
if not fs.exists("turtle_id.txt") then
    print("🔍 No Turtle ID found. Requesting one...")
    rednet.open("right")
    local _, receivedID = rednet.receive("turtle_id")
    if not receivedID then
        print("❌ Failed to receive Turtle ID. Exiting.")
        return
    end
    turtleID = receivedID
    local file = fs.open("turtle_id.txt", "w")
    file.write(tostring(turtleID))
    file.close()
    print("✅ Received Turtle ID:", turtleID)
else
    local file = fs.open("turtle_id.txt", "r")
    turtleID = file.readAll()
    file.close()
    print("🔄 Using stored Turtle ID:", turtleID)
end

-- ✅ **Download Block Data if Missing**
if not fs.exists("output.lua") then
    local dataURL = "https://raw.githubusercontent.com/robertjojo123/limpy3/main/output_" .. turtleID .. ".lua"
    print("🌐 Block data not found! Downloading:", dataURL)
    shell.run("wget " .. dataURL .. " output.lua")

    if not fs.exists("output.lua") then
        print("❌ Failed to download block data. Exiting.")
        return
    end
end

print("🔄 Loading block data...")
local blocks = dofile("output.lua")

-- ✅ **Movement System**
local function turnLeft() turtle.turnLeft(); pos.dir = (pos.dir - 1) % 4 end
local function turnRight() turtle.turnRight(); pos.dir = (pos.dir + 1) % 4 end

moveTo = function(target)
    while pos.x ~= target.x or pos.z ~= target.z do
        local moved = false

        -- ✅ Move in X direction first
        if pos.x < target.x then
            while pos.dir ~= 1 do turnRight() end
            if turtle.forward() then pos.x = pos.x + 1 moved = true end
        elseif pos.x > target.x then
            while pos.dir ~= 3 do turnRight() end
            if turtle.forward() then pos.x = pos.x - 1 moved = true end
        end

        -- ✅ Move in Z direction next
        if not moved then
            if pos.z < target.z then
                while pos.dir ~= 0 do turnRight() end
                if turtle.forward() then pos.z = pos.z + 1 moved = true end
            elseif pos.z > target.z then
                while pos.dir ~= 2 do turnRight() end
                if turtle.forward() then pos.z = pos.z - 1 moved = true end
            end
        end

        -- ✅ Handle obstacles
        if not moved then
            print("🚧 Block ahead! Trying alternative paths...")
            if turtle.detect() then
                turtle.turnRight()
                if turtle.forward() then pos.x = pos.x + 1 moved = true end
            end
            if not moved then
                turtle.turnRight()
                if turtle.forward() then pos.z = pos.z + 1 moved = true end
            end
            if not moved then
                turtle.turnLeft()
                turtle.turnLeft() -- Try going backward
                if turtle.forward() then moved = true end
            end
            if not moved then
                print("❌ Stuck! Retrying after 2s...")
                sleep(2)
            end
        end
    end
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

-- ✅ **Refuel Function**
refuelTurtle = function()
    print("⛽ Checking fuel level...")
    if turtle.getFuelLevel() >= 1000 then return true end 

    print("🔄 Moving to fuel chest...")
    local fuelChestPos = {x = 5, y = 0, z = -5}
    findChestAccess(fuelChestPos)

    while not turtle.suck(1) do
        print("⏳ Fuel chest empty. Retrying...")
        sleep(2)
    end

    turtle.refuel()
    print("✅ Refueled!")
    return true
end

-- ✅ **Block Data Automation**
getBlockData = function(block)
    return "minecraft:" .. block
end

-- ✅ **Restock Function**
-- ✅ **Material Chest Storage Levels**
getChestYLevel = function(block)
    local blockYLevels = {
        ["wool"] = 1, ["grass"] = 2, ["dirt"] = 3, ["cobblestone"] = 4, ["clay"] = 5,
        ["stone"] = 6, ["sand"] = 7, ["glass"] = 8, ["oak_planks"] = 9, ["spruce_planks"] = 10, 
        ["bricks"] = 11, ["quartz_block"] = 12
    }
    return blockYLevels[block] or 13
end

-- ✅ **Restock Function**
restock = function(block)
    local blockID = getBlockData(block)  
    local chestY = getChestYLevel(block)  -- ✅ Now correctly defined before use
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

-- ✅ **Place Block Function**
placeBlock = function(block)
    local blockID = getBlockData(block)  
    if not refuelTurtle() then return false end 

    local exists, _ = turtle.inspectDown()
    if exists then
        print("⏭ Block already exists, skipping...")
        return true
    end

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name == blockID then
            turtle.select(i)
            if turtle.placeDown() then
                print("✅ Placed", blockID)
                return true
            end
        end
    end

    print("❌ Out of", blockID, "restocking...")
    if restock(block) then return placeBlock(block) end
    return false
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
