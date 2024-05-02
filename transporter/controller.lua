PROTOCOL = "silly_transport_protocol"
HOSTNAME = "Jameson"

local history = {}

peripheral.find("modem", rednet.open)
local id = rednet.lookup(PROTOCOL, HOSTNAME)

if not id then
    print("No turtle available")
end

print("ping")
rednet.send(id, "ping", PROTOCOL)
local _, message, _ = rednet.receive(PROTOCOL)
print(message)

while true do
    write(HOSTNAME .. "> ")
    local input = read(nil, history)
    table.insert(history, input)

    if input == "here" then
        local x, y, z = gps.locate()
        input = ("target;%d;%d;%d"):format(x, y + 10, z)
    end

    rednet.send(id, input, PROTOCOL)
    local _, message, _ = rednet.receive(PROTOCOL)
    print(message)
end