local newComputer = oCmd.computer

tRoute[newComputer.address] = {
	address = newComputer.address,
	via = "MODEM",
	desc = newComputer.desc,
	dest = newComputer.dest,
	sacAllowed=false
}

writeConfig(tRoute)
readConfig()

return "Register done. Welcome "..newComputer.desc 