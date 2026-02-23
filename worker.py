#!/usr/bin/env python3
import os
import sys
import getopt
import hashlib
import time
import platform
import logging
import subprocess
import glob
from datetime import datetime

PROGNAME = os.path.basename(sys.argv[0])
VERSION = "%s v0.3.1" % PROGNAME

USAGE = """\
usage: %s [-v] [-h] -p <pattern> [-p <pattern2> ...] -c <cmd>
  [--maxjobs=<maxjobs>] [--maxhours=<maxhours>] [--label=<label>]

  -v or --version   Print the version
  -h or --help      Print usage
  -p or --pattern   Include pattern in the list of patterns
  -c or --cmd       Command to launch each job
  --maxjobs         Max # of jobs to run (default: unlimited)
  --maxhours        Max # of hours to run, can be floating point (default: unlimited)
  --label           Prefix to use for lock file and log file names (default: worker)\
""" % PROGNAME

# ---- Begin parsing command line args -----
patterns = []
cmd = []
max_jobs = sys.maxsize
max_hours = float('inf')
label = "worker"

longopts = ["version", "help", "pattern=", "cmd=", "maxjobs=",
	"maxhours=", "label="]
options, arguments = getopt.getopt(
	sys.argv[1:], # Arguments
	'vhp:c:',     # Short option definitions
	longopts)     # Long option definitions
for o, a in options:
	if o in ("-v", "--version"):
		print(VERSION)
		sys.exit()
	if o in ("-h", "--help"):
		print(USAGE)
		sys.exit()
	if o in ("-p", "--pattern"):
		patterns.append(a)
	if o in ("-c", "--cmd"):
		# We need present the command as a list of tokens later when we
		# invoke it with subprocess. This might not be the most robust way
		# to take the input, but let's see how well it works.
		for tok in a.split(' '):
			cmd.append(tok)
	if o in ("--maxjobs"):
		max_jobs = int(a)
	if o in ("--maxhours"):
		max_hours = float(a)
	if o in ("--label"):
		label = a
try:
	operands = [int(arg) for arg in arguments]
except ValueError:
	raise SystemExit(USAGE)
if len(patterns) == 0:
	print("Must provide at least one pattern. Use -h for help")
	exit(1)
if len(cmd) == 0:
	print("Must provide a command. Use -h for help")
	exit(1)
# ---- End parsing command line args -----

# Take now to be the starting time
start_time = datetime.now()
elapsed_hours = 0

# Set up logging
logging.basicConfig(
	stream = sys.stdout,
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
cwd = os.getcwd()
logging.info("Working directory: %s" % cwd)

L = len(patterns)

keep_looping = True
processed_jobs = 0

# ----- Finally, start the main loop -----
while keep_looping:
	# We will stop looping only if we make a full pass without finding any new
	# work. This allows the user to add, remove, or rerun jobs without having to
	# restart a running worker.
	keep_looping = False
	logging.info("Searching %d patterns for available work" % L)

	for i in range(L):
		pattern = patterns[i]
		logging.info("Searching pattern[%d]: %s" % (i, pattern))

		# Interpret the pattern as a glob to search for relevant files
		for entry in glob.glob(pattern):
			# Ignore entries that are not directories
			if not os.path.isdir(entry):
				logging.info("Entry %s is not a folder, ignoring" % entry)
				continue
			subdir = entry

			# Workers coordinate through the existence of this lockfile
			lockfile = os.path.join(subdir + os.path.sep + "%s.lock" % label)

			# Check if the lockfile exists. If so, we can ignore this folder
			if os.path.isfile(lockfile):
				logging.info("Lockfile in %s exists, skipping" % subdir)
				continue

			# If we find at least one subdir without a lock, there might
			# be more work to do. Set keep_looping to True
			keep_looping = True

			# There is no lockfile, so see if we can acquire it ourselves.
			# If we can, leave our ID and close the lockfile before doing any
			# actual work.
			acquired_lock = False
			try:
				with open(lockfile, 'x') as f:
					f.write("Reserved by worker: %s\n" % worker_id)
					acquired_lock = True
			except FileExistsError:
				logging.warn("Could not lock: %s" % lockfile)

			if acquired_lock:
				logging.info("Lockfile in %s acquired" % subdir)

				# Now change to the directory of the job
				os.chdir(subdir)

				# Run the job. Make sure to save stdout and stderr steams
				with open("%s.out" % label, 'w') as g, open("%s.err" % label, 'w') as h:
					subprocess.call(cmd, stdout = g, stderr = h)

				# Increment the number of jobs we have processed
				processed_jobs += 1

				# Change back to the original current working directory
				os.chdir(cwd)

			elapsed_hours = (datetime.now() - start_time).total_seconds() / 60**2
			logging.info("Processed %d jobs and worked for %f total hours so far" %
				(processed_jobs, elapsed_hours))

			if processed_jobs >= max_jobs:
				logging.info("Reached limit of %d jobs" % max_jobs)
				exit(0)

			if elapsed_hours >= max_hours:
				logging.info("Reached limit of %f hours" % max_hours)
				exit(0)

logging.info("Done")

