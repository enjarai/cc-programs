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
print(rednet.receive(PROTOCOL))

while true do
    write(HOSTNAME .. "> ")
    local input = read(nil, history)
    history:insert(input)

    rednet.send(id, input, PROTOCOL)
    print(rednet.receive(PROTOCOL))
end