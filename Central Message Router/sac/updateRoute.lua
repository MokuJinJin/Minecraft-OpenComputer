local o = getDefaultInformation()
local tmp = {}
for k, row in pairs(tRoute) do 
	-- basics values
	o = {
		address = row.address,
		via=row.via,
		desc=row.desc,
		dest=row.dest
	}
	-- v1.1 sacAllowed
	if row.sacAllowed == nil then o.sacAllowed = false else o.sacAllowed = row.sacAllowed end
	-- v1.0 tRoute is indexed by address
	tmp[row.address] = o;
end

writeConfig(tmp)
readConfig()

return "route updated to v1.1"
