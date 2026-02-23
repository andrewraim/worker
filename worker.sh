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
VERSION="$PROGNAME v0.2.1"

# Function to log a message with a timestamp
logger() {
	ts=$(date +'%Y-%m-%d %H:%M:%S')
	echo "$ts - $@"
}

# Function to print the usage
function usage() {
cat <<EOF
usage: $PROGNAME [-v] [-h] -p <pattern> [-p <pattern2> ...] -c <cmd>
  [--maxjobs=<maxjobs>] [--maxhours=<maxhours>] [--label=<label>]

  -v or --version   Print the version
  -h or --help      Print usage
  -p or --pattern   Include pattern in the list of patterns
  -c or --cmd       Command to launch each job
  --maxjobs         Max # of jobs to run (default: unlimited)
  --maxhours        Max # of hours to run, can be floating point (default: unlimited)
  --label           Prefix to use for lock files and log file names (default: worker)
EOF
}

# ---- Begin parsing command line args -----
patterns=()
((max_jobs=2**32))
((max_hours=2**32))
label="worker"

# Call getopt to validate the command line
options=$(getopt -o vhp:c: --long version --long help \
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
		usage
		exit 0
		;;
	-p)
		;&
	--pattern)
		# Push new pattern to patterns array.
		# Quotes are on $1 so that the pattern will not be expanded yet.
		shift;
		patterns+=("$1")
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

L=${#patterns[@]}

if [ $L -eq 0 ]; then
	echo "Must provide at least one pattern. Use -h for help"
	exit 1
fi

if [ -z ${cmd+x} ]; then
	echo "Must provide a command. Use -h for help"
	exit 1
fi

# ----- Prepare to run -----
# Take now to be the starting time
start_time=$(date +"%s.%N")
elapsed_hours=0

# Create a hash that represents a (somewhat) unique ID for this run
# Use hostname with time appended
str2hash="$(hostname)$(date +'%s.%N')"
worker_id=$(echo $str2hash | md5sum | cut -f1 -d' ')
logger "Worker ID: $worker_id"

# Get the current working directory
cwd=$PWD
logger "Working directory: $cwd"

processed_jobs=0
keep_looping=true

# ----- Finally, start the main loop -----
while $keep_looping
do
	# We will stop looping only if we make a full pass without finding any new
	# work. This allows the user to add, remove, or rerun jobs without having to
	# restart a running worker.
	keep_looping=false
	logger "Searching $L patterns for available work"

	for (( i=0; i < ${L}; i++ ))
	do
		pattern=${patterns[$i]}
		logger "Searching Pattern[$i]: $pattern"

		for entry in $(ls -d $pattern)
		do
			# Ignore entries that are not directories
			if [ ! -d $entry ]; then
				logger "Entry $entry is not a folder, ignoring"
				continue
			fi
			subdir=$entry

			# Workers coordinate through the existence of this lockfile
			lockfile="${subdir}/${label}.lock"

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
				cd ${subdir}

				# Run the job. Make sure to save stdout and stderr steams
				$cmd 1>${label}.out 2>${label}.err

				# Increment the number of jobs we have processed
				((processed_jobs++))

				# Change back to the home path
				cd $cwd

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

