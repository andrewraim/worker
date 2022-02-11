#!/bin/bash
#SBATCH --job-name=example
#SBATCH --output=slurm.out
#SBATCH --error=slurm.err

# Example of launching a worker through Slurm
../src/worker.py -p 'sigma*_n*' -c 'R CMD BATCH launch.R'

