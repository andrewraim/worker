This project currently contains two components:

1. A `worker.py` script that can be used to run a simulation or other large
   study. To use it, organize the simulation into folders. The worker will
   traverse a given set of folders and run a command in each folder,
   sequentially, until the study is complete. Multiple workers can be run
   simultaneously and coordinate so that any folder will be reserved by at
   most one worker.

2. An example simulation study is given to show a complete workflow that uses
   `worker.py`. Folders and launcher scripts are generated for a worker(s) to
   process. Post-processing is carried out on the per-folder results to
   construct a table and prepare output for the entire simulation.

