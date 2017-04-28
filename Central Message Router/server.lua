-------------------------------------------------------------------------
-- Receives messages from around the network and routes to destination
-------------------------------------------------------------------------

-- Port used globally on the network
ciPort=1001 

-- Name of the File containing all dest
configFile=".tRoute.cfg"

-- Activate Debug Logging, can be modified by ServerAdminCommand while executing 
bLog = true

-- Code for admin command, use it instead of destination to use ServerAdminCommand
local adminPassword = ".NetAdmin"

-------------------------------------------------------------------------
-- ***** Init *****

-- Open modem and tunnel
local oComponent = require("component")
local oEvent = require("event")
local oModem = oComponent.modem
if oComponent.isAvailable("tunnel") then local oTunnel = oComponent.tunnel end
local oTerm = require("term")
local oSerialization = require("serialization")
local oZColors = require("zcolors")

oModem.open(ciPort)
-- Do not have to open linked card - always open

if not oModem.isOpen(ciPort) then
  print("Modem failed to open on port " .. ciPort .. ". Exiting...")
  os.exit()
end

-- turn to false to stop the server.
-- Must be global if we want to change it with ServerAdminCommand, like exit
bContinue = true

-- Define routing table
tRoute = {}

-------------------------------------------------------------------------
-- ***** Functions *****

function serverLog(msg,zcolor)
	if bLog then 
		local oComponent = require("component")
		local oGPU = oComponent.gpu
		local oZColors = require("zcolors")
		if zcolor == nil then zcolor = oZColors.white end
		oGPU.setForeground(tonumber(zcolor))	
		print(msg) 
		oGPU.setForeground(tonumber(oZColors.white))
	end
end

function readConfig()
  local file = io.open(configFile)
  local fullText = file:read("*all")
  local sz = require("serialization")
  tRoute = sz.unserialize(fullText)
  serverLog("Config loaded",oZColors.green)
end

function writeConfig(tRoute)
  local file = io.open(configFile,"w")
  local sz = require("serialization")
  file:write(sz.serialize(tRoute))
  file:close()
  serverLog("Config updated",oZColors.green)
end

function FindByAddress(sAddress)
	local found = false
	local o = tRoute[sAddress]
	if o == nil then
		found = false
		o = getDefaultInformation()
		o.address = sAddress -- to be sure to always have address
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
	local ltMsg = loS.unserialize(tostring(psMsgRaw))
  	if ltMsg.dest == nil then 
		serverLog("No destination => server command",oZColors.gray)
		ltMsg.dest = "ServerCommand"
	else 
		serverLog("Destination : <"..ltMsg.dest..">",oZColors.gray)
	end
	serverLog("Command :<"..ltMsg.cmd..">",oZColors.gray)
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
	serverLog("Sending Command",oZColors.lightblue)
	serverLog("Method :\t"..toWho.via,oZColors.silver)
	serverLog("To      :\t"..toWho.desc,oZColors.silver)
	serverLog("NickName:\t"..toWho.dest,oZColors.silver)
	serverLog("Full command",oZColors.lightblue)
	serverLog(msg,oZColors.yellow)
	--serverLog("Sending command <" .. msg .. "> via <" .. toWho.via .. "> to <" .. toWho.desc .. ">:<" .. toWho.dest..">",oZColors.white)
	-- Check path
	if toWho.via == "MODEM" then   -- Route via modem
		oModem.send(toWho.address, ciPort, msg)
	elseif oTunnel ~= nil then -- Route via linked card
		oTunnel.send(msg)
	else
		serverLog("Unavailable sending method : "..toWho.via,oZColors.red)
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
  
  serverLog("msg received:" ..  sMsgRaw .. " from " .. remote.address,oZColors.lightblue)
  -- Parse message
  oCmd = ParseMsg(sMsgRaw)
  
  if oCmd.cmd == "REGISTER" and not remoteFound then
	-- Server Command : Register, List, etc...
	serverLog("ServerCommand <" .. oCmd.cmd .. "> from "..remote.address,oZColors.gray)
	-- Execute ServerCommand
	local msg = executeServerCommand(oCmd.cmd)
	_,remote = FindByAddress(remote.address)
	sendMessage(remote,msg)
  end
  
  if remoteFound then
	  -- Check for server command and remote is allowed
	  if oCmd.dest == adminPassword and remote.sacAllowed then
		serverLog("ServerAdminCommand <" .. oCmd.cmd .. "> from "..remote.desc,oZColors.gray)
		-- Execute ServerAdminCommand
		local msg = executeServerAdminCommand(oCmd.cmd)
		sendMessage(remote,msg)
	  elseif oCmd.dest == "ServerCommand" then
		-- Server Command : Register, List, etc...
		serverLog("ServerCommand <" .. oCmd.cmd .. "> from "..remote.desc,oZColors.gray)
		-- Execute ServerCommand
		local msg = executeServerCommand(oCmd.cmd)
		sendMessage(remote,msg)
	  else -- Not a server Command
		-- Get the destination etc
		destinationFound,destination = FindByDest(oCmd.dest)
		if not destinationFound then
			serverLog("Unknown destination : ".. oCmd.dest.."\rSending message to remote : ".. remote.desc,oZColors.red)
			sendMessage(remote,"Destination <".. oCmd.dest .."> not found")
		else
			serverLog("Sending message to destination : ".. destination.desc,oZColors.green)
			sendMessage(destination,oCmd.cmd)
		end
	  end
	else
		serverLog("Remote not found: " .. remote.address,oZColors.red)
		remote.via = "MODEM"
		sendMessage(remote,"You must REGISTER before using this server.")
	end
	-- Yield for a little bit
	os.sleep(0.1)
end