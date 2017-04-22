-- ******** Mekanism's Induction Matrix **********
-- coded by MokuJinJin
-- version 0.1
--
-- changelog :
-- v0.1
-- input not working (matrix issue)
-- Output, Storage working
--
-- original code by zgubilembulke (pastebin : cMBJKS7P)
-- **********************************************

-- ======= Parameters ======= --

-- screen update freqency ( seconds )
local refresh_rate = 1

-- energy unit for graphics (J,RF,EU,MJ) with quotes
local energy_unit = "RF"

-- **********************************************

local comp = require('component')
local gpu = comp.gpu

if not comp.isAvailable("induction_matrix") then
  print("No Induction Matrix Found.")
  os.exit()
end

local matrix = comp.induction_matrix

gpu.setResolution(160,38) -- set resolution
w,h = gpu.getResolution()

function energyUnitConverter(unit)
  if unit == "J" then return 1 end
  if unit == "RF" then return 2.5 end
  if unit == "EU" then return 10 end
  if unit == "MJ" then return 25 end
  -- default "J"
  return 1
end

function round(t)
  return math.floor(t*100)*0.01
end

function max_array_value(array)
  local max = 0
  for k, v in pairs(array) do
      if v > max then
          max = v
      end
  end
  return max
end

function min_array_value(array)
  local min = array[1]
  for k, v in pairs(array) do
      if v < min then
          min = v
      end
  end
  return min
end

function tablelen(array)
  local count = 0
  for _ in pairs(array) do count = count + 1 end
  return count
end

function shorter_number(num)
  if num <=1000 then
    return tostring(round(num))
  elseif num <= 100000  then
    return tostring(round(num/1000)) .. "k"
  elseif num <= 1000000000 then
    return tostring(round(num/1000000)) .. "M"
  elseif num <= 1000000000000 then
    return tostring(round(num/1000000000)) .. "G"
  elseif num <= 1000000000000000 then
    return tostring(round(num/1000000000000)) .. "T"
  else
    return tostring(round(num))
  end
end

function graph_horizontal(xpos,ypos,g_width,g_height,array,addbars_bool,detailed_bool,points_color,lines_color,text_color,bg_color)
  local maxvalue = max_array_value(array)
  local minvalue = 0
  if detailed_bool == true then
    minvalue = min_array_value(array)
  end

  local arraylen = tablelen(array)
  gpu.setBackground(bg_color)
  gpu.fill(xpos,ypos,g_width,g_height,' ')
  gpu.setBackground(lines_color) 
  gpu.fill(xpos+6,ypos,1,g_height," ")
  gpu.fill(xpos,ypos+g_height-1,g_width,1," ")  
  gpu.setBackground(bg_color)
  gpu.setForeground(text_color)
  gpu.set(xpos,ypos+1,tostring(shorter_number(maxvalue)))                                               -- top value display
  gpu.set(xpos,ypos+1+(g_height-2)/2,tostring(shorter_number(minvalue+((maxvalue-minvalue)/2))) )              -- mid value display
  gpu.set(xpos,ypos-1+g_height-1,tostring(shorter_number(minvalue)) )                                                                  -- 0 value display
  gpu.setBackground(points_color)                                                                             --graph color
    if arraylen > g_width-7 then
      table.remove(array,1)
    end

  if addbars_bool == true then
    for a,b in pairs(array)do
      local yp=math.floor(ypos+1+(g_height-3)-(((b-minvalue)/(maxvalue-minvalue))*(g_height-3)))
      gpu.fill(xpos+6+a,yp,1,ypos+g_height-yp-1," ")    -- vertical bars version
    end
  elseif addbars_bool ~= true then
    for a,b in pairs(array)do
      local yp=math.floor(ypos+1+(g_height-3)-(((b-minvalue)/(maxvalue-minvalue))*(g_height-3)))
      gpu.fill(xpos+6+a,yp,1,1," ")  -- single point version
    end
  end
end

array1 = {}
array2 = {}
array3 = {}

local unit = energyUnitConverter(energy_unit)

repeat

local storage = matrix.getEnergy()/unit
local input = matrix.getInput()/unit
local output = matrix.getOutput()/unit

table.insert(array1,storage)
table.insert(array2,input)
table.insert(array3,output)


gpu.setBackground(0x141414) -- main background color
gpu.fill(1,1,w,h,' ')


graph_horizontal(2,5,78,18,array1,true,true,0x66CC00,0xFFFFFF,0xFFFFFF,0x333333) 
graph_horizontal(82,5,78,18,array2,true,false,0xFF3232,0xFFFFFF,0xFFFFFF,0x333333)
graph_horizontal(2,24,158,13,array3,false,true,0x2E87D8,0xFFFFFF,0xFFFFFF,0x333333)


os.sleep(refresh_rate)
until false