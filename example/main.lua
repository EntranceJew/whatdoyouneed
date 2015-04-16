package.path = "../?.lua;" .. package.path 
io.stdout:setvbuf("no")

local whatdoyouneed = require 'whatdoyouneed'

require('yukka')
require 'lib/horse'
require "lib.horse"
require 'lib.complex'
require 'lib.complex.parts.part1'

local tree = whatdoyouneed:getTree()
local whats_inside_main = tree['@main.lua']
for k, v in pairs(whats_inside_main) do
	print(k, v)
end