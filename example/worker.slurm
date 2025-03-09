#!/bin/bash
#SBATCH --job-name=example
#SBATCH --output=slurm.out
#SBATCH --error=slurm.err

# Ensure one core per R process
export OMP_NUM_THREADS=1

# Example of launching a worker through Slurm
../src/worker.py -p 'sigma*_n*' -c 'R CMD BATCH launch.R'

