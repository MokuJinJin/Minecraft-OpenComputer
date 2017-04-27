-------------------------------------------------------------------------
-- Receives messages from around the network and routes to destination
-------------------------------------------------------------------------

-- Constants
ciPort=1001 -- Port used globally on my network
-- Name of the File containing all dest
configFile=".tRoute.cfg"
-- Activate Debug Logging, can be modified by command while executing : 
-- send LCL [LOG/NOLOG]
bLog = true

-- Codename for admin command
local codeName = ".NetAdmin"

-------------------------------------------------------------------------
-- ***** Init *****

-- Open modem and tunnel
local oComponent = require("component")
local oEvent = require("event")
local oModem = oComponent.modem
if oComponent.isAvailable("tunnel") then local oTunnel = oComponent.tunnel end
local oTerm = require("term")
local oSerialization = require("serialization")

oModem.open(ciPort)
-- Do not have to open linked card - always open

if not oModem.isOpen(ciPort) then
  print("Modem failed to open on port " .. ciPort .. ". Exiting...")
  os.exit()
end

-- turn to false to stop the server.
-- Must be global if we want to change it with ServerCommand
bContinue = true

local lsDest = ""
local lsMsg = ""

-- Define routing table
tRoute = {}


-------------------------------------------------------------------------
-- ***** Functions *****

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

function FindByAddress(sAddress)
	local found = false
	local o = getDefaultInformation()
	o.address = sAddress
	o = tRoute[sAddress]
	if o == nil then
		--for i, row in ipairs(tRoute) do 
		--	if row.address == sAddress then
		--	  o = {
		--		address = row.address,
		--		via=row.via,
		--		desc=row.desc,
		--		dest=row.dest,
		--		sacAllowed = row.sacAllowed
		--	  }
		--	  found = true
		--	end	
		--end
		found = false
	else
		found = true
	end
	
	return found,o;
end

function FindByDest(psDest)
	local found = false
	local o = getDefaultInformation()
	o.dest = psDest
	for i, row in ipairs(tRoute) do 
		if row.dest == psDest then
		  o = {
			address = row.address,
			via=row.via,
			desc=row.desc,
			dest=row.dest,
			sacAllowed = row.sacAllowed
		  }
		  found = true
		end	
    end
	return found,o;
end

function ParseMsg(psMsgRaw)
local loS = require("serialization")
  -- Parse the raw message into a destination and a command
  local ltMsg = loS.unserialize(tostring(psMsgRaw))
  --local lsDest = ltMsg.dest
  --local lsCmd = ltMsg.cmd
	if ltMsg.dest == nil then 
		if bLog then print("No destination => server command") end
		ltMsg.dest = "ServerCommand"
	else 
		if bLog then print("Destination : <"..ltMsg.dest..">") end
	end
	if bLog then print("Command :<"..ltMsg.cmd..">") end
  end
  -- Return values to calling function
  --return lsDest, lsCmd
  return ltMsg
end

function executeCommand(commandName,commandType)
	local fs = require("filesystem")
	local filename = commandType.."/"..string.lower(commandName)..".lua"
	local f = loadfile(filename)
	if f~= nil then
		return f()
	elseif f == nil then
		local err = "Failed to load command : "..filename
		print(err)
		return err;
	else
		local err = "Error loadfile : "..f
		print(err)
		return err;
	end
end

function executeServerAdminCommand(commandName)
	return executeCommand(commandName,"sac")
end

function executeServerCommand(commandName)
	return executeCommand(commandName,"sc")
end

function getDefaultInformation()
	local o = {address = "",via="",desc="",dest="",sacAllowed=false}
	return o
end

function resetInformations()
	-- Define remote informations
	remote = getDefaultInformation()
	-- Define destination informations
	destination = getDefaultInformation()
end

function sendMessage(toWho,msg)
	if bLog then print("Sending command <" .. msg .. "> via <" .. toWho.via .. "> to <" .. toWho.desc .. ">:<" .. toWho.dest..">") end
	-- Check path
	if toWho.via == "MODEM" then   -- Route via modem
		oModem.send(toWho.address, ciPort, msg)
	elseif oTunnel ~= nil then -- Route via linked card
		oTunnel.send(msg)
	else
		print("Unavailable sending method : "..toWho.via)
	end 
end
-------------------------------------------------------------------------
-- ***** Main Program *****

-- Clear the screen
oTerm.clear()
print("Initialising message routing...")
-- Loading list of client
readConfig()

-- Enter Loop
while bContinue do
  -- Wait for an inbound message
  print("Waiting for the next message ...")
  -- reset informations
  resetInformations()
  
  _, _, remoteAddress, _, _, sMsgRaw = oEvent.pull("modem_message")
  
  remoteFound,remote = FindByAddress(remoteAddress)
  
  if bLog then print("msg received:" ..  sMsgRaw .. " from " .. remote.address) end
  -- Parse message
  --lsDest, lsCmd = ParseMsg(sMsgRaw)
  oCmd = ParseMsg(sMsgRaw)
  
  if oCmd.cmd == "REGISTER" and not remoteFound then
	-- Server Command : Register, List, etc...
	if bLog then print("ServerCommand <" .. oCmd.cmd .. "> from "..remote.address) end
	-- Execute ServerCommand
	local msg = executeServerCommand(oCmd.cmd)
	remote = FindByAddress(remote.address)
	sendMessage(remote,msg)
  end
  
  if remoteFound then
	  -- Check for server command and remote is allowed
	  if oCmd.dest == codeName and remote.sacAllowed then
		if bLog then print("ServerAdminCommand <" .. oCmd.cmd .. "> from "..remote.desc) end
		-- Execute ServerAdminCommand
		local msg = executeServerAdminCommand(oCmd.cmd)
		sendMessage(remote,msg)
	  elseif oCmd.dest == "ServerCommand" then
		-- Server Command : Register, List, etc...
		if bLog then print("ServerCommand <" .. oCmd.cmd .. "> from "..remote.desc) end
		-- Execute ServerCommand
		local msg = executeServerCommand(oCmd.cmd)
		sendMessage(remote,msg)
	  else -- Not a server Command
		-- Get the destination etc
		destination = FindByDest(oCmd.dest)
		if not destination.found then
			if bLog then print("Unknown destination : ".. destination.dest) end
			if bLog then print("Sending message to remote : ".. remote.desc) end
			sendMessage(remote,"Destination <".. destination.dest .."> not found")
		else
			if bLog then print("Sending message to destination : ".. destination.desc) end
			sendMessage(destination,oCmd.cmd)
		end
	  end
	else
		if bLog then print("Remote not found: " .. remote.address) end
		remote.via = "MODEM"
		sendMessage(remote,"You must REGISTER before using this server.")
	end
	-- Yield for a little bit
	os.sleep(0.1)
end