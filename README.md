This project currently contains several items:

1. A `worker` script that can be used to run a simulation or other large
   study. To use it, organize the simulation into folders. The worker will
   traverse a given set of folders and run a command in each folder,
   sequentially, until the study is complete.

	a. A Bash version (`worker.sh`) is specific to Linux, but requires a
	   fairly minimal environment; it makes use of `flock` for file locking and
	   the `bc` calculator.
	a. A Python version (`worker.py`) is more portable but requires Python 3.3
	   or higher. It uses exclusive file creation mode in `open` to accomplish
	   locking.

   Multiple workers can be run simultaneously to parallelize a workload. They
   coordinate so that any folder will be reserved by at most one worker.
   Note that the two versions of the script should not be applied simultaneously
   to the same study because they use different file locking mechanisms.

2. An example simulation study is given to show a complete workflow making use
   of `worker`. Folders and launcher scripts are generated for a worker(s) to
   process. Post-processing is carried out on the per-folder results to
   construct a table and prepare output for the entire simulation.

3. A brief document describing one possible way to generate Latex tables from
   within R. This approach gives fine-level control over the format of the
   table entries, and can be used to produce clean Latex code.

