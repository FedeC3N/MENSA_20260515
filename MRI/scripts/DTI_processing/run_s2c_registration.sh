#!/bin/bash

# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Select the processes to run
export T1_2_b0_flag=1
export get5TT_2_b0_flag=1
export atlas_2_b0_flag=1

# Decide to overwrite or not the previous work
export overwrite=true

while read -r subject; 
do

	export subject
	sbatch --export=ALL s2c_registration.sh 

done < ${filename}