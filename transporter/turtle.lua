PROTOCOL = "silly_transport_protocol"

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
local forward, up, down, right, left = 0, 0, 0, 0, 0

local function turn_left()
    if turtle.turnLeft() then
        facing = vector.new(0, 1, 0):cross(facing)
        return true
    end
    return false
end

local function turn_right()
    if turtle.turnRight() then
        facing = vector.new(0, -1, 0):cross(facing)
        return true
    end
    return false
end

local function normalize(num)
    return num >= 0 and 1 or -1
end

local function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function tick()
    while true do
        if forward > 0 then
            if not turtle.forward() then
                forward = 0
            end
            goto continue
        end

        if up > 0 then
            if not turtle.up() then
                up = 0
            end
            goto continue
        end

        if down > 0 then
            if not turtle.down() then
                down = 0
            end
            goto continue
        end

        if right > 0 then
            if not turn_right() then
                right = 0
            end
            goto continue
        end

        if left > 0 then
            if not turn_left() then
                left = 0
            end
            goto continue
        end

        if target then
            local pos = vector.new(gps.locate())
            
            if pos.y < target.y then
                up = target.y - pos.y
                goto continue
            end

            if pos.x ~= target.x then
                local nx = normalize(target.x - pos.x)
                if not facing.x == nx then
                    turn_right()
                    goto continue
                end

                forward = target.x - pos.x
                goto continue
            end

            if pos.z ~= target.z then
                local nx = normalize(target.x - pos.x)
                if not facing.x == nx then
                    turn_right()
                    goto continue
                end

                forward = target.x - pos.x
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
end

local function network()
    peripheral.find("modem", rednet.open)
    rednet.host(PROTOCOL, os.getComputerLabel())

    while true do
        local id, message = rednet.receive(PROTOCOL)
        local split_message = mysplit(message, ";")

        if split_message[1] == "target" then
            target = vector.new(tonumber(split_message[2]), tonumber(split_message[3]), tonumber(split_message[4]))
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "forward" then
            forward = 99999
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "up" then
            up = 99999
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "down" then
            down = 99999
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "left" then
            left = 99999
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "right" then
            right = 99999
            rednet.send(id, "success", PROTOCOL)

        elseif split_message[1] == "ping" then
            rednet.send(id, "pong", PROTOCOL)
        end
    end
end

facing = determine_facing()
parallel.waitForAny(tick, network)