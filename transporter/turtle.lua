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
    return (num >= 0) and 1 or -1
end

local function abs(num)
    return (num >= 0) and num or -num
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
            else
                forward = forward - 1
            end
            goto continue
        end

        if up > 0 then
            if not turtle.up() then
                up = 0
            else
                up = up - 1
            end
            goto continue
        end

        if down > 0 then
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
            left = 1
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "right" then
            right = 1
            rednet.send(id, "success", PROTOCOL)
        elseif split_message[1] == "stop" then
            forward, up, down, right, left = 0, 0, 0, 0, 0
            target = nil
            rednet.send(id, "success", PROTOCOL)

        elseif split_message[1] == "pos" then
            local x, y, z = gps.locate()
            rednet.send(id, ("success;%d;%d;%d"):format(x, y, z), PROTOCOL)
        elseif split_message[1] == "ping" then
            rednet.send(id, "pong", PROTOCOL)
        end
    end
end

parallel.waitForAny(tick, network)