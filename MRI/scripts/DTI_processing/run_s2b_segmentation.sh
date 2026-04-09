#!/bin/bash

# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Select the processes to run
export b0extract_flag=1
export get5TT_flag=1

# Decide to overwrite or not the previous work
export overwrite=true

while read -r subject; 
do

	export subject
	sbatch --export=ALL s2b_segmentation.sh 

done < ${filename}


