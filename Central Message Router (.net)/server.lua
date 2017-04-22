-------------------------------------------------------------------------
-- Receives messages from around the network and routes to destination
-------------------------------------------------------------------------

-- Define routing table
tRoute = 
{
  {dest="TS1", address="eb6551a1-1b03-4603-bdad-75126678eeb2", via="MODEM", desc="Terminal Server"},
  {dest="PC3", address="feec0ad2-cbb3-4a40-9aa3-075a36ff6206", via="MODEM", desc="Tier 3 computer"}
}

-- Constants
ciPort=1001 -- Port used globally on my network
configFile="tRoute.cfg"

-- Open modem and tunnel
local oComponent = require("component")
local oEvent = require("event")
local oModem = oComponent.modem
--local oTunnel = oComponent.tunnel
local oTerm = require("term")
local oSerialization = require("serialization")

oModem.open(ciPort)
-- Do not have to open linked card - always open

if not oModem.isOpen(ciPort) then
  print("Modem failed to open on port " .. ciPort .. ". Exiting...")
  os.exit()
end

-------------------------------------------------------------------------
-- Functions

function readConfig()
  local file = io.open(configFile)
  local fullText = file:read("*all")
  local sz = require("serialization")
  tRoute = sz.unserialize(fullText)
end

function writeConfig(tRoute)
  local file = io.open(configFile,"w")
  local sz = require("serialization")
  file:write(sz.serialize(tRoute))
  file:close()
end

function FindDest(psDest, ptRoute)
local lsAddress = ""
local lsVia = ""
local lsDesc = ""

  -- Check the routing table and find the details of the destination
  for i, row in ipairs(ptRoute) do
    if row.dest == psDest then
      lsAddress = row.address
      lsVia = row.via
      lsDesc = row.desc
    end
  end

  -- Check for dest unknown
  if lsAddress == "" then
    lsDesc = "Unknown Address"
  end

  -- Return values to calling function
  return lsAddress, lsVia, lsDesc
end

function FindDestByAddress(sAddress, ptRoute)
  for i, row in ipairs(ptRoute) do 
    if row.address == sAddress then
      return row.dest
    end
  end
  return "UKW"
end

function ParseMsg(psMsgRaw)
local loS = require("serialization")

  -- Parse the raw message into a destination and a command

  local ltMsg = loS.unserialize(tostring(psMsgRaw))
  local lsDest = ltMsg.dest
  local lsCmd = ltMsg.cmd

  -- Return values to calling function
  return lsDest, lsCmd
end

-------------------------------------------------------------------------
-- Main Program

local fContinue = true
local fLog = true
local lsDest = ""
local lsMsg = ""

writeConfig(tRoute)
readConfig()

-- Clear the screen
oTerm.clear()
print("Initialising message routing...")

-- Enter Loop
while fContinue do
  -- Wait for an inbound message
print("Waiting for next message ...\r")

  _, _, remoteAddress, _, _, sMsgRaw = oEvent.pull("modem_message")
if fLog then print("msg received:" ..  sMsgRaw .. " from " .. remoteAddress) end
  -- Parse message
  lsDest, lsCmd = ParseMsg(sMsgRaw)

  -- Check for debug/local command
  if lsDest == "LCL" then
    -- Check to log
    if fLog then print("CMD " .. sMsgRaw) end
    -- Check for program quit
    if lsCmd == "EXIT" then fContinue = false end
    if lsCmd == "LOG" then 
      fLog = true 
      print("CMD Enable Logging")
    end
    if lsCmd == "NOLOG" then 
      fLog = false
      print("CMD Disable Logging") 
    end
    if lsCmd == "LIST" then
      lsCmd = oSerialization.serialize(tRoute)
      --lsDest = "CMD"
      lsDest = FindDestByAddress(remoteAddress,tRoute)
    end
  end
  -- Message to process/send
  if lsDest ~= "LCL" or (lsDest == "LCL" and lsCmd == "LIST") then
    -- Get the destination etc
    lsAddress, lsVia, lsDesc = FindDest(lsDest, tRoute)

    -- Check to log
    if fLog then print("Sending command " .. lsCmd .. " via " .. lsVia .. " to " .. lsDest .. ":" .. lsDesc) end

    -- Check for unknown destination
    if lsDesc == "Unknown Address" then
      -- Print the details
      print("Unknown Address")      
      -- Send a message to the control computer
      
    else
      -- Check path
      if lsVia == "MODEM" then       -- Route via modem
        oModem.send(lsAddress, ciPort, lsCmd)
      else                          -- Route via linked card
        oTunnel.send(lsCmd)
      end
    end
  end                             -- If local/forward

  -- Yield for a little bit
  os.sleep(0.1)
end