fs = require("filesystem")
cpn = require("component")
ui = cpn.gpu
Colors = require("zcolors")
installDir = "/usr/lib"

function copyFileToInstallDir(sFilePath)
    local fileName = fs.name(sFilePath)
    fs.copy(sFilePath,installDir .. "/" .. fileName) 
    ui.setForeground(tonumber(Colors.white))
    print(sFilePath"\t->\t" .. installDir .. "/" .. fileName)
end

local args = {...}

if args[1] == "uninstall" then
   ui.setForeground(tonumber(Colors.red))
    print("\tUninstalling .net")
   fs.remove(installDir) 
end

if not fs.exists(installDir) then
    ui.setForeground(tonumber(Colors.cyan))
    print("\tInstalling .net")
    fs.makeDirectory(installDir)
    copyFileToInstallDir("./.net/moku.lua")
    --fs.copy("moku.lua",installDir .. "/moku.lua") 
    --ui.setForeground(tonumber(Colors.white))
    --print("moku.lua\t->\t" .. installDir .. "/moku.lua")  
else
    ui.setForeground(tonumber(zcolors.green))
    print("\t.Net Already installed")
end
ui.setForeground(tonumber(Colors.white))