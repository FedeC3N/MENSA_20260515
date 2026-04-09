#!/bin/bash
clear

shopt -s extglob

# We want to keep
# nothing from ${subject}_FreeSurfer
# preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii
# registration/${subject}_5TT_b0space.nii
#             /${subject}_AAL_b0space_dilated.nii
# segmentation/${subject}_DWI_mask.nii
# structural_measures/gm_average_response.txt
#                    /wm_average_response.txt
#                    /csf_average_response.txt
# All from transformation_matrix
# ./bval
# ./bvec
# ./acqparm.txt
# ./${subject}_DWI.nii
# ./${subject}_FreeSurfer_measures.txt


# Subjects' filename
filename='./subjects_txt_files/all_subjects.txt'

# Select the atlas to use
ATLAS=('AAL')

path_dwi=../../data/DWI
path_scripts=$(pwd)

while read -r subject; 
do


if [ ${#subject} -eq 0 ]; then
continue
fi


# Move to the subjects' folder
cd ${path_dwi}/${subject}

# Remove all the folders
if [ -d "./${subject}_FreeSurfer" ]; then
	rm -Rf ./${subject}_FreeSurfer
fi

if [ -d "./fsaverage" ]; then
	rm -Rf ./fsaverage
fi


# preprocess
cd ./preprocess/
rm -v !("${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii")
cd ..

# registration/${subject}_5TT_b0space.nii
#             /${subject}_AAL_b0space_dilated.nii
cd ./registration
rm "./${subject}_${atlas}_b0space.nii"
rm "./${subject}_${atlas}_T1space.nii"
rm "./${subject}_${atlas}_T1space_unordered.nii"
rm "./${subject}_${atlas}_T1space_unordered.mgz"
rm "./${subject}_wm_b0space_mask.nii"
rm "./${subject}_wm_b0space_mask_inv.nii"
cd ..


# segmentation/${subject}_DWI_mask.nii
cd ./segmentation
rm -v !("${subject}_DWI_mask.nii")
cd ..

# structural_measures/gm_average_response.txt
#                    /wm_average_response.txt
#                    /csf_average_response.txt
cd ./structural_measures
rm -v !("gm_average_response.txt"|"wm_average_response.txt"|"csf_average_response.txt")
cd ..


# Files in root folder
# ./bval
# ./bvec
# ./acqparm.txt
# ./${subject}_DWI.nii
# ./${subject}_FreeSurfer_measures.txt
#rm -v !("bval"|"bvec"|"acqparm.txt"|"${subject}_DWI.nii"|"${subject}_FreeSurfer_measures.txt")
if [ -f "./${subject}_3DT1_iso_reoriented.nii" ]; then
	rm "./${subject}_3DT1_iso_reoriented.nii"
fi
if [ -f "./${subject}_DWI.mif" ]; then
	rm "./${subject}_DWI.mif"
fi


# Return to the original path
cd ${path_scripts}

done < ${filename}
