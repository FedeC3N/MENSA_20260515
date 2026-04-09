#!/bin/bash

# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Select the processes to run
export reconall_flag=1
export asegstats_flag=1
export parc2seg_flag=1


# Decide to overwrite or not the previous work
export overwrite=true

while read -r subject; 
do

	export subject
	sbatch --export=ALL s2a_T1_FreeSurfer_parcellation.sh 

done < ${filename}