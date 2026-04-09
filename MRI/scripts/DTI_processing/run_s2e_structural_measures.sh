#!/bin/bash

# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Select the processes to run
export dwi2tensor_flag=1
export dwi2fod_flag=1
export mtnormalise_flag=1
export tckgen_flag=1
export tck2connectome_flag=1
export tensorconnectome_flag=1

# Decide to overwrite or not the previous work
export overwrite=true

########
# Has to be defined inside the script. sbatch does not accept arrays
# export SEEDS=25M #(1M 5M 10M 15M 20M 25M 30M)
# export TENSOR_MEASURES=('fa') #('adc' 'fa' 'ad' 'rd' 'cl' 'cp' 'cs') 
# export STREAMLINES_STATS=('min') # mean,median,min,max


while read -r subject; 
do

	export subject
	sbatch --export=ALL s2e_structural_measures.sh 

done < ${filename}