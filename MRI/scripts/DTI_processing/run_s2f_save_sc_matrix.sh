#!/bin/bash

########
# Parameters are defined in s2f_save_sc_matrix
########

# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Create the output folder
if [ ! -d "../../data/sc/" ];then
mkdir -p "../../data/sc/"
fi


while read -r subject; 
do

	export subject
	sbatch --export=ALL s2f_save_sc_matrix.sh 


done < ${filename}