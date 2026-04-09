#!/bin/bash

# Select the processes to run
export dwi2response_flag=1

# Decide to overwrite or not the previous work
export overwrite=true

sbatch --export=ALL s2d_average_response_function.sh 



