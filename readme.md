# whatdoyouneed
A shim for tracing your requires and where they come from.

# Usage
* Drop into your project.
* Put `wdyn = require 'whatdoyouneed'` before any other requires.
* After that, you can use `wdyn:getTree()` to get a table of all your requires.

# Example Results
```
treeMap = {
		['@main.lua'] = {
			['@lib/make_my_game_better.lua'] = {},
			['@lib/complex_lib/init.lua'] = {
				['@lib/complex_lib/parts/part1.lua'] = {},
				['@lib/complex_lib/parts/part2.lua'] = {},
			},
		},
	}
```

# Notes
* The file paths begin with '@', because that's how debug.getinfo tracks it for whatever reason.
* Any path that begins with '?' is one that could not be resolved correctly, probably a C include or a standard library.
* Patterns used aren't very clever and are probably wrong cross-system, if you can improve them throw me a pull request.