# Description
This project contains a worker script that can be used to run a simulation or
other repetitive studies. To use it, organize your study into folders so that
each folder represents one "task". The worker will traverse your specified
folders and execute a specified command in each folder to run the task. This
process will repeat until the study is complete.

Multiple workers can be run simultaneously to achieve "embarrassingly parallel"
parallel computing. Workers coordinate so that any folder will be reserved for
processing by at most one worker.

This setup may be especially useful in shared computing environments where
courteous usage might include not using too many proccessors at once or queuing
up too many jobs to a scheduler. For example, if it is acceptable to run 10
jobs at once, we can launch 10 workers to complete our study.

There are two versions of the worker script.

1. A Bash version `worker.sh` is specific to Linux, but prerequisites are
   fairly minimal; it makes use of `flock` for file locking and the `bc`
   calculator.

2. A Python version `worker.py` is more portable but requires Python 3.3 or
   higher. It uses the exclusive file creation mode in `open` to accomplish
   locking.

Note that the two versions of the script should not be applied simultaneously
to the same study because they use different file locking mechanisms.

An example simulation study is given to show a complete workflow making use of
the worker. Folders and launcher scripts are generated for a worker(s) to
process. Post-processing is then carried out on the per-folder results to
construct a table and prepare output for the entire simulation. See the
`example` folder for the example code and the `doc` folder for a brief document
explaining how it works.

# Installation

It is recommended to make the scripts executable when deploying them. For
example, in Linux:

```bash
$ chmod +x worker.py
$ chmod +x worker.sh
```

# Number of CPUs Used by R

Some programs attempt to use multiple cores when they are available. While this
is normally beneficial on standalone workstations, it can cause complications
when we have been strictly allocated a fixed number of cores.

For example, suppose we have been allocated 16 cores in a job by a scheduler on
a shared system and wish to run 16 simultaneous tasks using 16 workers; if one
of the tasks attempts to use additional cores here, the scheduler may detect
the use of extra resources and halt the entire job.

R is one program that may do this, depending on the way it has been configured.
The behavior appears to be controllable through OpenMP, as discussed in the
following [thread][stackoverflow]. Setting the following environment variable
appears to restrict R to a single thread.

```
export OMP_NUM_THREADS=1
```

[stackoverflow]: https://stackoverflow.com/q/57109522

