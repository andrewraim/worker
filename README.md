# Overview

The worker tool helps to automate running simulations and other repetitive
computational studies. It requires the study to be organized into folders
representing "tasks". 

```bash
$ ls task???
task001:
config.json  driver.R

task002:
config.json  driver.R

...

task998:
config.json  driver.R

task999:
config.json  driver.R
```

The worker identifies a task which has not yet been processed, executes a
specified command to run it, and repeats until all tasks are complete.

Multiple workers can be run simultaneously to achieve "embarrassingly parallel"
parallel computing. They coordinate so that each task is handled by at most
one worker.

The was developed especially for multi-user computing environments. Users are
often expected to limit the number of processors used at once and to not
queue too many jobs in a scheduler such as [PBS](https://www.openpbs.org) (if
one is in use). If we are allowed to run 10 jobs at once, we can launch 10
workers to complete our study.

There are two versions of the worker script. These should not be mixed in the
same study because they use different file locking mechanisms.

1. A Bash version `worker.sh` is specific to Linux, but prerequisites are
   otherwise minimal: it uses `flock` for file locking and the `bc` calculator.

2. A Python version `worker.py` is more portable but requires Python 3.3. It
   uses the exclusive file creation mode in `open` for file locking.

# Installation

Copy the scripts to a preferred location and ensure they are executable.

In Linux, a suggested location for non-root users on a typical system is
`$HOME/.local/bin`.

```bash
$ cp src/worker.py $HOME/.local/bin/
$ cp src/worker.sh $HOME/.local/bin/
$ chmod +x worker.py
$ chmod +x worker.sh
$ export PATH=$PATH:$HOME/.local/bin
```

The last line can be added to your Bash [startup][bash-startup] to take effect
in future sessions.

# Example

The `example` folder demonstrates a small simulation study using the worker.
Folders and launcher scripts are generated for workers to process.
Post-processing is then carried out on the per-folder results to construct a
table and prepare output for the entire simulation.

# Details

Suppose our study is organized with each job in its own folder. The worker
identifies relevant folders through one or more specified 'pattern' arguments.
For each matching folder, it changes its working directory to the folder and
runs a specified command ('cmd').

Before running a job, the worker must create file 'worker.lock' in the
associated folder to claim responsibility for it. If the lock can be
successfully created, the worker immediately attempts to run the job. The
worker runs the job using the command 'cmd' and does nothing further until it
completes. Therefore, jobs run sequentially from the perspective of one worker.
Once the 'cmd' command finishes, the worker resumes searching for more jobs
without a 'worker.lock' file.

Aside from reserving and running jobs, the worker has minimal knowledge of the
content of the jobs and cannot distinguish between successful and failed runs.

The worker continues to search for jobs in a loop until a complete pass is made
without finding any new jobs to run. This allows a user to modify its workload
without needing to restart it:

- Add a job by creating a folder that matches one of the 'pattern' arguments.
- Remove a job by placing a 'worker.lock' file in the folder.
- Rerun a job by deleting its 'worker.lock' file.

Multiple workers may run on the same set of 'pattern' arguments to achieve
parallel processing. Race conditions are avoided by obtaining an exclusive lock
of the 'worker.lock' file.

When passing a 'pattern' argument, you may need to protect it from being
expanded by your shell. In Bash, this can be accomplished by wrapping the
pattern with single quotes.

## Bash Version

The file `worker.lock` is acquired exclusively with the flock command. A worker
may only claim responsibility for a job if it (1) finds that 'worker.lock' does
not yet exist, and (2) lock it for writing. The lock is released once the job
has been executed.

The 'pattern' argument is interpreted as a [Bash pattern][bash-pattern].

## Python Version

A lock on the file `worker.lock` is aquired exclusive using "x" file access
mode; this requires Python 3.3. Only the worker which successfully creates the
file may claim responsibility for the job.

The 'pattern' argument is interpreted as a Python [glob][glob], which is
similar to the syntax in the Bash shell.

# Note about Multicore Programs

Some programs attempt to use multiple cores when they are available. This is
normally beneficial on standalone workstations but can cause problems when we
have been allocated a fixed number of CPUs.

For example, suppose we have been allocated 16 cores in a job by a scheduler on
a shared system and wish to run 16 simultaneous tasks using 16 workers; if one
of the tasks attempts to use additional cores, the scheduler may detect the use
of extra resources and halt the entire job.

R is one program that may do this, depending on the way it has been configured.
The behavior appears to be controllable through OpenMP, as discussed in this
[post][stackoverflow]. Setting the following environment variable appears to
restrict R to a single thread.

```
export OMP_NUM_THREADS=1
```

[bash-pattern]: https://www.linuxjournal.com/content/pattern-matching-bash
[bash-startup]: https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
[glob]: https://docs.python.org/3/library/glob.html
[stackoverflow]: https://stackoverflow.com/q/57109522

