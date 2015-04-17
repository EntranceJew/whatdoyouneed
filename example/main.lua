package.path = "../?.lua;" .. package.path 
io.stdout:setvbuf("no")

local whatdoyouneed = require 'whatdoyouneed'

require('yukka')
require 'lib/horse'
require "lib.horse"
require 'lib.complex'
require 'lib.complex.parts.part1'

-- the contents of your table
local tree = whatdoyouneed:getTree()

-- static analyze time
whatdoyouneed:analyze('main.lua')
local stree = whatdoyouneed:getStaticTree()

print('dynamic tree:')
whatdoyouneed:printTree()

print('static tree:')
whatdoyouneed:printStaticTree()

-- reset the dynamic tree so we can monitor requires that happen exclusively after main loads
whatdoyouneed:resetTree()
