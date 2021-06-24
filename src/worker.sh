#!/usr/bin/env bash

# Notes
# This is not the same locking mechanism used in the Python version. Therefore,
# Bash and Python workers are more more susceptible to race conditions with each
# other.
#
# You can view current system locks using the 'lslocks' command.  Somehow the
# code below doesn't populate the COMMAND or PATH fields correctly. It may be
# related to this: <https://unix.stackexchange.com/questions/594027/ ...
# handling-of-stale-file-locks-in-linux-and-robust-usage-of-flock>


PROGNAME=$(basename $0)
VERSION="$PROGNAME v0.1.0"

# Function to get timestamp
ts() {
	echo $(date +'%Y-%m-%d %H:%M:%S')
}

# Function to log a message with a timestamp
logger() {
	ts=$(date +'%Y-%m-%d %H:%M:%S')
	echo "$ts - $@"
}

# Function to print the usage
function usage() {
cat <<EOF
Bash version of worker utility

worker is a tool to help automate repetitive computational studies. It loops
through a list of paths and searches for subdirectories whose names match a
given pattern. For each matching subdirectory, it changes to the directory and
runs a specified command ('cmd').
- Paths are specified by one or more 'basepaths'.
- Patterns are specified by one or more 'patterns'.
- The number of 'basepaths' and 'patterns' should be equal.
- The 1st pattern is associated with the 1st path, the 2nd pattern with the 2nd
  path, and so on.
- 'basepaths' are not traversed recursively; only searched at the top level.

Before running a job, worker must create a file 'worker.lock' in that directory
to claim responsibility for it. If the lock is successfully created, worker
immediately attempts to run the job. The command 'cmd' is executed as a
blocking call so that jobs from one worker are run sequentially. Once the
command finishes, worker resumes searching for other jobs without a
'worker.lock' file. Aside from reserving and running jobs, worker has minimal
knowledge of their content and does not distinguish between successful and
failed runs.

worker continues to search for jobs in a loop until a complete pass is made
without finding any new jobs to run. This allows you to modify its workload
without a need to restart it:
- add a job by creating a directory that matches 'basepaths' and 'patterns'.
- remove a job by placing a 'worker.lock' file in the directory.
- rerun a job by deleting its 'worker.lock' file.

Multiple workers may run on the same set of 'basepaths' and 'patterns' to
process job directories in parallel. Race conditions are avoided via
'worker.lock', which is acquired exclusively with the flock command. A worker
may only claim responsibility for a job if it (1) finds that 'worker.lock' does
not yet exist, and (2) lock it for writing. The lock is released once the job
has been executed.

'patterns' are strings interpreted as Bash patterns. E.g., see the syntax at 
<https://www.linuxjournal.com/content/pattern-matching-bash>. When passing a
'pattern' argument, you may need to protect it from being expanded by your
shell. In bash, this can be accomplished by wrapping the pattern with single
quotes.

Usage: $PROGNAME [-v] [-h] | -b <path> [-b <path2> ...] -p <pattern>
           [-p <pattern2> ...] -c <cmd> [--maxjobs=<maxjobs>]
           [--maxhours=<maxhours>] [--label=<label>]
	-v or --version   print the version and exit
	-h or --help      print usage and exit
	-b or --basepath  include path in the list of basepaths
	-p or --pattern   include pattern in the list of patterns
	-c or --cmd       command to launch each job
	--maxjobs         max # of jobs to run (default: unlimited)
	--maxhours        max # of hours to run, can be floating point (default: unlimited)
	--label           prefix to use for lock files and log file names (default: worker)
EOF
}

# ---- Begin parsing command line args -----
basepaths=()
patterns=()
((max_jobs=2**32))
((max_hours=2**32))
label="worker"

# Call getopt to validate the command line
options=$(getopt -o vhb:p:c: --long version --long help --long basepath: \
	--long pattern: --long cmd: --long maxjobs: --long maxhours: \
	--long label: -- "$@")
[ $? -eq 0 ] || { 
    echo "Incorrect options provided"
    exit 1
}

# Read the command line arguments
eval set -- "$options"
while true; do
	case "$1" in
	-v)
		;&
	--version)
		echo "$VERSION"
		exit 0
		;;
	-h)
		;&
	--help)
		echo "$VERSION"
		usage
		exit 0
		;;
	-b)
		;&
	--basepath)
		# Push new path to basepaths array
		shift;
		basepaths+=($1)
		;;
	-p)
		;&
	--pattern)
		# Push new pattern to patterns array
		shift;
		patterns+=($1)
		;;
	-c)
		;&
	--cmd)
		shift;
		cmd=$1
		;;
	--maxjobs)
		shift;
		max_jobs=$1
		;;
	--maxhours)
		shift;
		max_hours=$1
		;;
	--label)
		shift;
		label=$1
		;;
	--)
		shift
		break
		;;
	esac
	shift
done

L=${#basepaths[@]}
P=${#patterns[@]}

if [ $L -eq 0 ]; then
	echo "Must provide at least one basepath. Use -h for help"
	exit 1
fi

if [ $P -eq 0 ]; then
	echo "Must provide at least one pattern. Use -h for help"
	exit 1
fi

if [ -z ${cmd+x} ]; then
	echo "Must provide a command. Use -h for help"
	exit 1
fi

if [ $L != $P ]; then
	echo "Length of basepaths $L is not equal to length of patterns $P"
	exit 1
fi

# ----- Prepare to run -----
# Take now to be the starting time
start_time=$(date +"%s.%N")
elapsed_hours=0

# Create a hash that represents a (somewhat) unique ID for this run
# Use hostname with time appended
str2hash="$(hostname)$(date +'%s.%N')"
worker_id=$($str2hash | md5sum | cut -f1 -d' ')
logger "Worker ID: $worker_id"

# Get the current working directory
homepath=$PWD
logger "Home path: $homepath"

processed_jobs=0
keep_looping=true

# ----- Finally, start the main loop -----
while $keep_looping
do
	# We will stop looping only if we make a full pass without finding any new
	# work. This allows the user to add, remove, or rerun jobs without having to
	# restart a running worker.
	keep_looping=false
	logger "Searching $L basepaths for available work"

	for (( i=0; i < ${L}; i++ ))
	do
		basepath=${basepaths[$i]}
		pattern=${patterns[$i]}
		logger "Basepath[$i]: $basepath  Pattern: $pattern"

		for subdir in $(ls $basepath)
		do
			# Ignore entries that are not directories
			if [ ! -d "$basepath/$subdir" ]; then
				continue
			fi

			# Ignore entries that don't match the pattern
			if [[ ! $subdir == $pattern ]]; then
				continue
			fi

			# Workers coordinate through the existence of this lockfile
			lockfile="${basepath}/${subdir}/${label}.lock"

			# Check if the lockfile exists. If so, we can ignore this folder
			if [ -f $lockfile ]; then
				logger "Lockfile in $subdir exists, skipping"
				continue
			fi

			# If we find at least one subdir without a lock, there might
			# be more work to do. Set keep_looping to true
			keep_looping=true

			# There is no lockfile, so see if we can acquire it ourselves.
			# In the Bash version of worker, we will hold the lock while we
			# execute the job. This seems more appropriate with the flock
			# mechanism, where creation of the lockfile may not have been
			# created with exclusiveness.

			exec 100>$lockfile
			flock --exclusive --nonblock 100
			ret_code=$?

			if [ $ret_code -eq 0 ]; then
				echo "Reserved by worker: $worker_id" > $lockfile
				logger "Lockfile in $subdir acquired"

				# Change to the directory of the job
				cd "${basepath}/${subdir}"

				# Run the job. Make sure to save stdout and stderr steams
				$cmd 1>${label}.out 2>${label}.err

				# Increment the number of jobs we have processed
				((processed_jobs++))

				# Change back to the home path
				cd $homepath

				# Release the lock
				flock --unlock --nonblock 100
			else
				logger "Could not lock: $lockfile"
			fi

			now_time=$(date +"%s.%N")
			elapsed_hours=$(echo "scale=4; ($now_time - $start_time) / 60^2" | bc -l)
			logger "Processed $processed_jobs jobs and worked for" \
			"$elapsed_hours total hours so far"

			if [ $processed_jobs -ge $max_jobs ]; then
				logger "Reached limit of $max_jobs jobs"
				exit 0
			fi

			if (( $(echo "$elapsed_hours >= $max_hours" | bc -l) )); then
				logger "Reached limit of $max_hours hours"
				exit 0
			fi
		done
	done
done

logger "Done"

