#!/bin/bash

# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Select the processes to run
export mrconvert_flag=1
export dwipreprocmask_flag=1
export dwidenoise_flag=1
export dwidegibbs_flag=1
export dwipreproc_flag=1
export dwibias_flag=1
export dwimask_flag=1

# Decide to overwrite or not the previous work
export overwrite=true

while read -r subject; 
do

	export subject
	sbatch --export=ALL s2a_DWI_preprocessing.sh 

done < ${filename}


