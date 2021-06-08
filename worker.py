#!/usr/bin/env python3
import os
import hashlib
import time
import platform
import logging
import subprocess
import re

"""
This script loops through the paths in the list `basepaths` and searches for
subdirectories whose names match the corresponding pattern in `patterns`. For
each matching directory, enter that directory and run the command specified
by `cmd`. Note that basepaths are not traversed recursively.

Multiple workers are allowed to run on the same set of `basepaths` and
`patterns`. We use a simple lockfile mechanism to avoid race conditions where
more than one worker is executing a run. To take responsibility for a directory,
a worker must create a file called `worker.lock` using "x" access mode in that
directory. This requires python3.

Entries in patterns are strings interpreted as Python Regular Expressions. See
the syntax at <https://docs.python.org/3/library/re.html>
"""

# ---- Begin config -----
# TBD: Make these CLI arguments
basepaths = ["./"]
patterns = ['sim_laplace(.*)_sigma(.*)']
cmd = ['R', 'CMD', 'BATCH', 'launch.R']
# ---- End config -----

# Set up logging
logging.basicConfig(
	format = '%(asctime)s - %(message)s',
	level = logging.INFO,
	datefmt = '%Y-%m-%d %H:%M:%S')

# Create a hash that represents a (somewhat) unique ID for this run
# Use hostname with time appended
str2hash = platform.node() + str(time.time())
result = hashlib.md5(str2hash.encode())
worker_id = result.hexdigest()
logging.info("Worker ID: %s" % worker_id)

# Get the current working directory
homepath = os.getcwd()

# Throw an exception if L != len(patterns)
L = len(basepaths)
if L != len(patterns):
	msg = "Length %d of basepaths is not equal to length %d of patterns"
	raise RuntimeError(msg % (L, len(patterns)))

keep_looping = True

while keep_looping:
	# Reset this to False. We need to find least one new unlocked file later
	# to set this to True, otherwise we'll stop looping.
	keep_looping = False
	logging.info("Searching %d basepaths for available work" % L)

	for i in range(L):
		basepath = basepaths[i]
		pattern = patterns[i]

		logging.info("Basepath[%d]: %s  Pattern: %s" % (i, basepath, pattern))

		for subdir in os.listdir(basepath):
			# Ignore entries that are not directories
			if not os.path.isdir(subdir):
				continue

			# Ignore entries that don't match the pattern
			match = re.search(pattern, subdir)
			if not match:
				continue

			# Workers coordinate through the existence of this lockfile
			lockfile = os.path.join(basepath, subdir + os.path.sep + "worker.lock")

			# Check if the lockfile exists. If so, we can ignore this folder
			if os.path.isfile(lockfile):
				logging.info("Lockfile in %s exists, skipping" % subdir)
				continue

			# If we find at least one subdir without a lock, there might
			# be more work to do. Set keep_looping to True
			keep_looping = True

			# There is no lockfile, so see if we can acquire it ourselves
			try:
				with open(lockfile, 'x') as f:
					f.write("Reserved by worker: %s" % worker_id)
					logging.info("Lockfile in %s acquired" % subdir)

					# Now change to the directory of the job
					path = os.path.join(basepath, subdir)
					os.chdir(path)

					# Run the job. Make sure to save stdout and stderr steams
					stdout = os.path.join(path, "worker.out")
					stderr = os.path.join(path, "worker.err")
					with open(stdout, 'w') as g, open(stderr, 'w') as h:
						subprocess.call(cmd, stdout = g, stderr = h)
			except FileExistsError:
				logging.warn("Could not lock: %s" % lockfile)
			finally:
				# Change back to the home path
				os.chdir(homepath)

logging.info("Done")

