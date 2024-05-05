PROTOCOL = "silly_transport_protocol"
ORES = {
    "minecraft:coal_ore", "minecraft:iron_ore", "minecraft:gold_ore", "minecraft:diamond_ore",
    "minecraft:lapis_ore", "minecraft:emerald_ore", "minecraft:copper_ore", "minecraft:redstone_ore",
    "minecraft:deepslate_coal_ore", "minecraft:deepslate_iron_ore", "minecraft:deepslate_gold_ore",
    "minecraft:deepslate_diamond_ore",
    "minecraft:deepslate_lapis_ore", "minecraft:deepslate_emerald_ore", "minecraft:deepslate_copper_ore",
    "minecraft:deepslate_redstone_ore",
    "minecraft:nether_gold_ore", "minecraft:nether_quartz_ore", "minecraft:ancient_debris"
}

local function determine_facing()
    print("Determining facing direction...")

    local x, y, z = gps.locate()

    if not x then
        print("GPS unavailable, navigation will be limited")
        return nil, nil, nil
    end

    local mul = 1
    if not turtle.forward() then
        mul = -1
        if not turtle.back() then
            print("Could not move to determine facing, navigation will be limited")
            return nil, nil, nil
        end
    end

    local nx, ny, nz = gps.locate()
    local fx, fy, fz = (nx - x) * mul, (ny - y) * mul, (nz - z) * mul

    if mul == -1 then
        turtle.forward()
    else
        turtle.back()
    end

    print(("Facing is %d, %d, %d"):format(fx, fy, fz))
    return vector.new(fx, fy, fz)
end

local facing = determine_facing()

local target = nil
local job = nil
local backtrack = {}
local forward, back, up, down, right, left = 0, 0, 0, 0, 0, 0

local function load_job()
    if fs.exists("job.json") then
        local file = fs.open("job.json", "r")
        job = textutils.unserialiseJSON(file.readAll())
        file.close()
    end
end

local function save_job()
    if job then
        local file = fs.open("job.json", "w")
        file.write(textutils.serialiseJSON(job))
        file.close()
    else
        if fs.exists("job.json") then
            fs.delete("job.json")
        end
    end
end

local function turn_left()
    if turtle.turnLeft() then
        if facing then
            facing = vector.new(0, 1, 0):cross(facing)
        end
        return true
    end
    return false
end

local function turn_right()
    if turtle.turnRight() then
        if facing then
            facing = vector.new(0, -1, 0):cross(facing)
        end
        return true
    end
    return false
end

local function normalize(num)
    return (num >= 0) and 1 or -1
end

local function abs(num)
    return (num >= 0) and num or -num
end

local function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function inventory_full()
    local not_full = false
    for i = 1, 16 do
        local d = turtle.getItemDetail(i)
        if not d then
            not_full = true
            break
        end
    end
    return not not_full
end

local function check_ore(check_fun)
    local block, data = check_fun()
    if block then
        local id = data["name"]

        if has_value(ORES, id) then
            return true
        end
    end

    return false
end

local function tick()
    if forward > 0 then
        turtle.dig()
        if not turtle.forward() then
            forward = 0
        else
            forward = forward - 1
        end
        goto continue
    end

    if back > 0 then
        if not turtle.back() then
            back = 0
        else
            back = back - 1
        end
        goto continue
    end

    if up > 0 then
        turtle.digUp()
        if not turtle.up() then
            up = 0
        else
            up = up - 1
        end
        goto continue
    end

    if down > 0 then
        turtle.digDown()
        if not turtle.down() then
            down = 0
        else
            down = down - 1
        end
        goto continue
    end

    if right > 0 then
        if not turn_right() then
            right = 0
        else
            right = right - 1
        end
        goto continue
    end

    if left > 0 then
        if not turn_left() then
            left = 0
        else
            left = left - 1
        end
        goto continue
    end

    if job and job["id"] == "mine" then
        if (check_ore(turtle.inspectUp)) then
            turtle.digUp()
            if turtle.up() then
                table.insert(backtrack, turtle.down)
            end
            goto continue
        end
        if (check_ore(turtle.inspect)) then
            turtle.dig()
            if turtle.forward() then
                table.insert(backtrack, turtle.back)
            end
            goto continue
        end
        if (check_ore(turtle.inspectDown)) then
            turtle.digDown()
            if turtle.down() then
                table.insert(backtrack, turtle.up)
            end
            goto continue
        end

        if turn_left() then
            table.insert(backtrack, turn_right)
        end
        if (check_ore(turtle.inspect)) then
            turtle.dig()
            if turtle.forward() then
                table.insert(backtrack, turtle.back)
            end
            goto continue
        end
        table.remove(backtrack)()

        if turn_right() then
            table.insert(backtrack, turn_left)
        end
        if (check_ore(turtle.inspect)) then
            turtle.dig()
            if turtle.forward() then
                table.insert(backtrack, turtle.back)
            end
            goto continue
        end
        table.remove(backtrack)()

        if #backtrack > 0 then
            local action = table.remove(backtrack)
            action()
        else
            turtle.dig()
            if turtle.forward() then
                if job["distance"] == job["wrap"] then
                    if job["right"] then
                        turn_right()
                    else
                        turn_left()
                    end
                end

                if job["distance"] == 0 then
                    if job["right"] then
                        turn_right()
                    else
                        turn_left()
                    end
                    job["right"] = not job["right"]
                    job["distance"] = job["max_distance"]
                end

                job["distance"] = job["distance"] - 1
                save_job()
            else
                os.sleep(10)
            end

            if inventory_full() then
                job = nil
                save_job()
            end
        end

        goto continue
    elseif job and job["id"] == "refuel" then
        if turtle.place() then
            turtle.refuel()
        end
        os.sleep(0.1)
        goto continue
    elseif job and job["id"] == "treefarm" then
        if job["next_tree"] > 0 then
            local successful, _ = turtle.forward()
            if successful then
                job["next_tree"] = job["next_tree"] - 1
                save_job()
            else
                turn_left()
                turn_left()
                job["next_tree"] = 7
                job["tree_left"] = not job["tree_left"]
                save_job()
            end
        else
            if job["go_down"] then
                if job["current_height"] > 0 then
                    turtle.down()
                    job["current_height"] = job["current_height"] - 1
                    save_job()
                else
                    if job["tree_left"] then
                        turn_right()
                    else
                        turn_left()
                    end
                    job["go_down"] = false
                    job["next_tree"] = 7
                    job["current_height"] = nil
                    save_job()
                end
            else
                if job["current_height"] == nil then
                    if job["tree_left"] then
                        turn_left()
                    else
                        turn_right()
                    end
                    job["current_height"] = 0
                    save_job()
                end
                local has_block, data = turtle.inspect()
                if has_block then
                    if data.tags["minecraft:logs"] then
                        turtle.dig()
                        local has_block, data = turtle.inspectUp()
                        if has_block then
                            if data.tags["minecraft:leaves"] then
                                turtle.digUp()
                                turtle.up();
                                job["current_height"] = job["current_height"] + 1
                                save_job()
                            else
                                job["go_down"] = true
                                save_job()
                            end
                        else
                            turtle.up()
                            job["current_height"] = job["current_height"] + 1
                            save_job()
                        end
                    else
                        job["go_down"] = true
                        save_job()
                    end
                else
                    job["go_down"] = true
                    save_job()
                end
            end
        end
    end

    if target then
        local x, y, z = gps.locate()

        if not target then
            -- Fix for potential nil after locate
            goto continue
        end

        if y < target.y then
            up = target.y - y
            goto continue
        end

        if x ~= target.x then
            local nx = normalize(target.x - x)
            if facing.x ~= nx then
                turn_right()
                goto continue
            end

            forward = abs(target.x - x)
            goto continue
        end

        if z ~= target.z then
            local nz = normalize(target.z - z)
            if facing.z ~= nz then
                turn_right()
                goto continue
            end

            forward = abs(target.z - z)
            goto continue
        end

        print("Target reached")
        target = nil
        down = 999
        goto continue
    end

    os.sleep(1)

    ::continue::
end

local function network()
    local id, message = rednet.receive(PROTOCOL)
    local split_message = mysplit(message, ";")

    if split_message[1] == "target" then
        if facing then
            target = vector.new(tonumber(split_message[2]), tonumber(split_message[3]), tonumber(split_message[4]))
            rednet.send(id, "success", PROTOCOL)
        else
            rednet.send(id, "can't target, no GPS", PROTOCOL)
        end
    elseif split_message[1] == "forward" then
        forward = tonumber(split_message[2])
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "back" then
        back = tonumber(split_message[2])
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "up" then
        up = tonumber(split_message[2])
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "down" then
        down = tonumber(split_message[2])
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "left" then
        left = tonumber(split_message[2])
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "right" then
        right = tonumber(split_message[2])
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "stop" then
        forward, back, up, down, right, left = 0, 0, 0, 0, 0, 0
        target = nil
        job = nil
        backtrack = {}
        save_job()
        rednet.send(id, "success", PROTOCOL)
    elseif split_message[1] == "mine" then
        job = {
            id = "mine",
            max_distance = split_message[2] + 6,
            distance = split_message[2] + 6,
            wrap = 6,
            right = false
        }
        save_job()
        rednet.send(id, "starting", PROTOCOL)
    elseif split_message[1] == "refuel" then
        job = {
            id = "refuel"
        }
        save_job()
        rednet.send(id, "starting", PROTOCOL)
    elseif split_message[1] == "job" then
        rednet.send(id, textutils.serializeJSON(job), PROTOCOL)
    elseif split_message[1] == "pos" then
        local x, y, z = gps.locate()
        rednet.send(id, ("%d %d %d"):format(x, y, z), PROTOCOL)
    elseif split_message[1] == "facing" then
        if facing then
            rednet.send(id, ("%d %d %d"):format(facing.x, facing.y, facing.z), PROTOCOL)
        else
            rednet.send(id, "unknown", PROTOCOL)
        end
    elseif split_message[1] == "ping" then
        rednet.send(id, "pong", PROTOCOL)
    elseif split_message[1] == "inventory" then
        local r = {}
        for i = 1, 16 do
            local d = turtle.getItemDetail(i)
            if not d then
                r[i] = textutils.json_null
            else
                r[i] = {
                    id = d.name,
                    count = d.count
                }
            end
        end
        rednet.send(id, textutils.serializeJSON(r), PROTOCOL)
    elseif split_message[1] == "treefarm" then
        job = {
            id = "treefarm",
            next_tree = 7,
            tree_left = true,
        }
        save_job()
        rednet.send(id, "starting", PROTOCOL)
    end
end

local function safe_loop(fun)
    local function inner()
        while true do
            local success, err = pcall(fun)
            if not success then
                print("Error: " .. err)
            end
        end
    end
    return inner
end

load_job()
peripheral.find("modem", rednet.open)
rednet.host(PROTOCOL, os.getComputerLabel())

parallel.waitForAny(safe_loop(tick), safe_loop(network))
