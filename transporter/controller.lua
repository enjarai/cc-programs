PROTOCOL = "silly_transport_protocol"

local args = {...}

local hostname = args[1]
local history = {}

local ready = false
local id = nil
while not ready do
    peripheral.find("modem", rednet.open)
    id = rednet.lookup(PROTOCOL, hostname)

    if not id then
        print("No turtle available")
    end

    print("ping")
    rednet.send(id, "ping", PROTOCOL)
    local success, message, _ = rednet.receive(PROTOCOL, 2)
    if success then
        ready = true
        print(message)
    else
        print("Connection failure")
        os.sleep(2)
    end
end

while true do
    write(hostname .. "> ")
    local input = read(nil, history)
    table.insert(history, input)

    if input == "here" then
        local x, y, z = gps.locate()
        input = ("target;%d;%d;%d"):format(x, y, z)
    end

    rednet.send(id, input, PROTOCOL)
    local success, message, _ = rednet.receive(PROTOCOL, 2)
    if success ~= nil then
        print(message)
    else
        print("Wrong command lol")
    end
end