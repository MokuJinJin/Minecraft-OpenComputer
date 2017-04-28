-----------------------------------------------------------------------
-- Send a manual message or command via network
-----------------------------------------------------------------------

-- Constants
ciPort = 1001
sRouteServer = "141a390b-15b4-4ddc-b01c-abe625007a29"
bDebug = false

function PrintHelp()
local loComponent = require("component")
local loTerm = require("term")
local loGPU = loComponent.gpu
local loZColors = require("zcolors")

  -- Print instructions for this program
  loGPU.setForeground(tonumber(loZColors.white))
  print("Sends manual messages to the routing server for delivery\r")
  print("Usage")
  loGPU.setForeground(tonumber(loZColors.red))
  print("\tsend <destination> <command>\r")
  loGPU.setForeground(tonumber(loZColors.white))
  print("\t<destination>\tDestination computer")
  print("\t<command>\tCommand to send. Can be single code or serialized table depending on destination.\r")
  loGPU.setForeground(tonumber(loZColors.red))
  print("\tsend LIST\r")
  loGPU.setForeground(tonumber(loZColors.white))
  print("\tList all known destinations, code and description.\r")
  loGPU.setForeground(tonumber(loZColors.red))
  print("\tsend HELP, ?\r")
  loGPU.setForeground(tonumber(loZColors.white))
  print("\tPrint help for this program.\r\r")
end

function PrintList(psMsg)
local loSerialization = require("serialization")

  -- Convert the message back into a table
  local tList = loSerialization.unserialize(psMsg)
  
  if tList == nil then print(psMsg) os.exit() end
  
  print("LIST OF VALID DESTINATIONS")
  for i, row in pairs(tList) do
    print("\t" .. row.dest .. "\t" .. row.desc)
  end
end

function ValidateArgs(ptArgs)
  -- If 0 or 1 arguments supplied, print help and exit
  if (ptArgs[1] == nil) or (string.upper(ptArgs[1]) == "HELP") or ptArgs[1] == "?" then 
    PrintHelp() 
    os.exit()
  end

  -- Return result to calling function
  return fExit
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end
-----------------------------------------------------------------------
-- Main Program

-- Get any arguments supplied
tArgs = { ... }
local tMsg = {}
local sMsgRaw = ""
local loEvent = require("event")
local loSerial = require("serialization")
if bDebug then print(tArgs[1]) end

-- Validate arguments and exit if required
ValidateArgs(tArgs)

if string.upper(tArgs[1]) == "LIST" then 
  tMsg["cmd"] = "LIST"
elseif string.upper(tArgs[1]) == "REGISTER" then
  tMsg["cmd"] = "REGISTER"
  local cmp = require("component")
  local txt = require("text")
  local lsDesc = "";
  for i=3,tablelength(tArgs),1 do lsDesc = lsDesc .. " " .. tArgs[i] end
  tMsg["computer"] = {
	address = cmp.modem.address,
	dest = string.upper(tArgs[2]),
	desc = txt.trim(lsDesc)
  }
else
  tMsg["dest"] = tostring(tArgs[1])
  tMsg["cmd"] = string.upper(tostring(tArgs[2]))
end

sMsg = loSerial.serialize(tMsg)

-- Create and connect to modem
loComponent = require("component")
loModem = loComponent.modem
loModem.open(ciPort)

-- Send message
loModem.send(sRouteServer, ciPort, sMsg)
if bDebug then print("message send") end
-- If message was a LIST, call a function to receive the result and print it
if tMsg.cmd == "LIST" then
  _, _, _, _, _, sMsgRaw = loEvent.pull("modem_message")
  PrintList(sMsgRaw)
end