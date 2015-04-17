--[[
	A shim for tracing your requires and where they come from.
]]

local _this_file_path = debug.getinfo(1, "S").source

-- from: http://lua-users.org/wiki/SplitJoin
local function string_split(str, sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	str:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

-- from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
-- corrected to allow functions as indexes
local function print_r ( t )
	local print_r_cache={}
	local function sub_print_r(t,indent)
			if (print_r_cache[tostring(t)]) then
					print(indent.."*"..tostring(t))
			else
					print_r_cache[tostring(t)]=true
					if (type(t)=="table") then
							for pos,val in pairs(t) do
									if (type(val)=="table") then
											print(indent.."["..pos.."] => "..tostring(t).." {")
											sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
											print(indent..string.rep(" ",string.len(pos)+6).."}")
									elseif (type(val)=="string") then
											print(indent.."["..pos..'] => "'..val..'"')
									else
											print(indent.."["..tostring(pos).."] => "..tostring(val))
									end
							end
					else
							print(indent..tostring(t))
					end
			end
	end
	if (type(t)=="table") then
			print(tostring(t).." {")
			sub_print_r(t,"  ")
			print("}")
	else
			sub_print_r(t,"  ")
	end
	print()
end

--[[
	stores where all the data goes, indexed by filename based on the depth of the require
	file paths start with '@' because that's just how debug.source does things
	if a file path begins with '?' that means the lib doesn't understand the include being made
	example data:
	
	treeMap = {
		['@main.lua'] = {
			['@lib/make_my_game_better.lua'] = {},
			['@lib/complex_lib/init.lua'] = {
				['@lib/complex_lib/parts/part1.lua'] = {},
				['@lib/complex_lib/parts/part2.lua'] = {},
			},
		},
	}
]]
local treeMap = {}
local staticTreeMap = {} --like the above, but for static files

local whatdoyouneed = {
	origRequire = require,
	
	fixPathSamples = {
		-- fix relative paths to make them usable by love
		{"%./", "", 1},
		{"%.\\", "", 1},
		
		-- make backslashes into forward slashes
		{"\\", "/"},
		
		-- replace dots in paths that end in .lua
		{"(.*)%.lua$", function(w)
			return w:gsub("%.", "/") .. ".lua"
		end},
	},
	
	-- tests to check if a line is actually a require line
	testRequireLine = {
		[[require *%( *['"](.+)['"] *%)]],
		[[require *['"](.+)['"] *]],
	},
}

-- see if a static require 
function whatdoyouneed.resolveRequireString(line)
	local start, stop, cap
	for _, testPattern in pairs(whatdoyouneed.testRequireLine) do
		start, stop, cap = string.find(line, testPattern)
		if start then
			return cap
		end
	end
	return nil
end

-- make note that a static require 
function whatdoyouneed.staticRequire(filename, include)
	if not staticTreeMap[filename] then
		staticTreeMap[filename] = {}
	end
	table.insert(staticTreeMap[filename], include)
end

-- translates require paths into actual files, nil if it can't resolve it
function whatdoyouneed.fixPath(path)
	for _, gsubArgs in ipairs(whatdoyouneed.fixPathSamples) do
		local count
		path, count = path:gsub(unpack(gsubArgs))
		if love.filesystem.isFile(path) then
			return path
		end
	end
	return nil
end

-- get a file from a require path, uses fixPath above
-- returns: evaluated path, successful
function whatdoyouneed.pathToFile(path)
	local packageParts = string_split(package.path, ';')
	local cap, count
	for _, searchLocation in ipairs(packageParts) do
		cap, count = string.gsub(searchLocation, "%?", path)
		if count > 0 then
			local newpath = whatdoyouneed.fixPath(cap)
			if love.filesystem.isFile(cap) then
				return cap, true
			elseif newpath then
				return newpath, true
			end
		end
	end
	return path, false
end

-- turns reverse-linear history into a dependency map
function whatdoyouneed.resolveStack(stack)
	local start = treeMap
	for i=#stack,1,-1 do
		local val = stack[i]
		if not start[ val.source ] then
			start[val.source] = {}
		end
		start = start[val.source]
	end
end

-- get the tree
function whatdoyouneed:getTree()
	return treeMap
end

function whatdoyouneed:printTree()
	print_r( self:getTree() )
end

function whatdoyouneed:resetTree()
	for k in pairs (treeMap) do
		treeMap[k] = nil
	end
end

-- the same, but for the static file functions
function whatdoyouneed:getStaticTree()
	return staticTreeMap
end

function whatdoyouneed:printStaticTree()
	print_r( self:getStaticTree() )
end

function whatdoyouneed:resetStaticTree()
	for k in pairs (staticTreeMap) do
		staticTreeMap[k] = nil
	end
end

--check which files require other files, starting from a given file
function whatdoyouneed:analyze(filename)
	if love.filesystem.isFile(filename) then
		local cap
		for line in love.filesystem.lines(filename) do
			cap = whatdoyouneed.resolveRequireString(line)
			if cap then
				print("analyze debug: ", cap)
				local newpath, worked = whatdoyouneed.pathToFile(cap)
				--print("FOUND:",filename,cap,newpath)
				if love.filesystem.isFile(cap) then
					self:analyze(cap)
				elseif worked then
					self:analyze(newpath)
				end
				whatdoyouneed.staticRequire(filename, cap)
			end
		end
	else
		assert(false, string.format("Tried to analyze a non-existant file: %s", filename))
	end
end

-- actually set up the replacement 
require = function(res)
	local level = 1
	local stack = {
		{
			-- start the stack with the resource being requested
			source=whatdoyouneed.pathToFile(res),
			-- we have no idea what line we're on
			line=-1
		}
	}
	while true do
		local info = debug.getinfo(level, "Sl")
		if not info then break end
		-- ignore C functions, whatever boot.lua is doing, and ourselves
		if info.what ~= "C"  and info.source ~= "boot.lua" and info.source ~= _this_file_path then
			local nsource = info.source
			if string.sub(nsource, 1, 1) == "@" then
				nsource = string.sub(nsource, 2)
			end
			table.insert(stack, {source=nsource, line=info.currentline})
		end
		level = level + 1
	end
	whatdoyouneed.resolveStack(stack)
	return whatdoyouneed.origRequire(res)
end

return whatdoyouneed