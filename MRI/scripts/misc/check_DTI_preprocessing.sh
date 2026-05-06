#!/bin/bash
clear

# Subjects' filename
filename='all_subjects.txt'

# parameters
atlas='AAL'

# Download the subjects file
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/scripts/DTI_processing/subjects_txt_files/${filename} \
../DTI_processing/subjects_txt_files/${filename}

# Upload the filename variable
filename="../DTI_processing/subjects_txt_files/${filename}"

# flags
dwi_preprocessing_flag=0
t1_preprocessing_flag=0
segmentation_flag=0
registration_flag=0
tractography_flag=1

# overwrite
overwrite=true
if [ "$overwrite" == true ];then
	force='-force'
fi

######
# Folders of interest																																																																																				
path_figs=../../figs/check
path_dwi=../../data/DWI
path_log=../../figs/log

# Create folders
if [ ! -d "${path_figs}/" ];then
mkdir -p ${path_figs}/
fi
if [ ! -d "${path_log}/" ];then
mkdir -p ${path_log}/
fi

# Create a log file
error_log_file=${path_log}/error_log_file.txt
now=$(date +"%T")
echo "Start at ${now}" > ${error_log_file}

# Create a temp folder to download the images
if [ ! -d "/home/fede/tmp" ];then
	mkdir -p /home/fede/tmp
fi


# Go through each subject
while read -r subject; 
do

echo "${subject}"

##############################################################
# dwi_pprerocessing
##############################################################
if [ "${dwi_preprocessing_flag}" == 1 ];then

echo "   Check DWI"



# Create the folder
if [ ! -d "${path_figs}/s2a_DWI_preprocessing/" ];then
	mkdir   ${path_figs}/s2a_DWI_preprocessing/
fi

# Open a SSH connection and download the images
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii

# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading DWI preprocessed" >> ${error_log_file}
continue
fi
 
echo ${status}

# Check b0
if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2a_DWI_preprocessing/${subject}_dwi_b0_preproc.png" ];then

# Extract the preprocessed b0
mrconvert ${force} /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
-coord 3 0 -axes 0,1,2 \
/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii

# mrview
mrview ${force} -quiet \
-load /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii \
-mode 2 \
-capture.folder ${path_figs}/s2a_DWI_preprocessing/ -capture.grab \
-exit
		
# Change the stander mrview-name of the file
mv -f ${path_figs}/s2a_DWI_preprocessing/screenshot0000.png ${path_figs}/s2a_DWI_preprocessing/${subject}_dwi_b0_preproc.png
	
fi

# Check self-alignment
#if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2a_DWI_preprocessing/${subject}_dwi_selfaligment_preproc.png" ];then

# Extract the preprocessed b0
#mrconvert ${force} /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
#-coord 3 0 -axes 0,1,2 \
#/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii
	
# Extract a volume different than b0
#mrconvert ${force} /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
#-coord 3 12 -axes 0,1,2 \
#/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_13.nii
	
# mrview
#mrview ${force} -quiet \
#-load /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii \
#-mode 2 \
#-overlay.load /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_13.nii \
#-overlay.opacity 0.4 \
#-capture.folder ${path_figs}/s2a_DWI_preprocessing/ -capture.grab \
#-exit
	
# Change the stander mrview-name of the file
#mv -f ${path_figs}/s2a_DWI_preprocessing/screenshot0000.png ${path_figs}/s2a_DWI_preprocessing/${subject}_dwi_selfaligment_preproc.png	

#fi

fi

##############################################################
# T1_prerocessing
##############################################################
if [ "${t1_preprocessing_flag}" == 1 ];then

echo "   Check T1"

# Create the folder
if [ ! -d "${path_figs}/s2a_T1_preprocessing/" ];then
	mkdir ${path_figs}/s2a_T1_preprocessing/
fi

# Create a temp folder to download the images
if [ ! -d "./tmp" ];then
	mkdir -p ./tmp
fi

# Open a SSH connection and download the images
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/${subject}_3DT1_iso_reoriented.nii \
/home/fede/tmp/${subject}_3DT1_iso_reoriented.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading 3DT1_iso_reoriented" >> ${error_log_file}
continue
fi

sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/segmentation/${subject}_3DT1_bet.nii \
/home/fede/tmp/${subject}_3DT1_bet.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading 3DT1_bet" >> ${error_log_file}
continue
fi

sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/registration/${subject}_${atlas}_T1space.nii \
/home/fede/tmp/${subject}_${atlas}_T1space.nii 
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading ALL_T1space" >> ${error_log_file}
continue
fi


# Check brain extraction
if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2a_T1_preprocessing/${subject}_T1_bet.png" ];then

# mrview
mrview ${force} -quiet \
-load /home/fede/tmp/${subject}_3DT1_iso_reoriented.nii \
-mode 2 \
-overlay.load /home/fede/tmp/${subject}_3DT1_bet.nii \
-overlay.opacity 0.4 \
-capture.folder ${path_figs}/s2a_T1_preprocessing/ -capture.grab \
-exit
		
# Change the stander mrview-name of the file
mv -f ${path_figs}/s2a_T1_preprocessing/screenshot0000.png ${path_figs}/s2a_T1_preprocessing/${subject}_T1_bet.png

fi

	

# Check atlas 
if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2a_T1_preprocessing/${subject}_T1_bet.png" ];then

mrview ${force} -quiet \
-load /home/fede/tmp/${subject}_3DT1_iso_reoriented.nii \
-mode 2 \
-overlay.load /home/fede/tmp/${subject}_${atlas}_T1space.nii \
-overlay.opacity 0.4 \
-capture.folder ${path_figs}/s2a_T1_preprocessing/ -capture.grab \
-exit
	
# Change the stander mrview-name of the file
mv -f ${path_figs}/s2a_T1_preprocessing/screenshot0000.png ${path_figs}/s2a_T1_preprocessing/${subject}_${atlas}_T1space.png	

fi


fi

##############################################################
# Segmentation
##############################################################
if [ "${segmentation_flag}" == 1 ];then

echo "   Check segmentation"

# Create the folder
if [ ! -d "${path_figs}/s2b_segmentation/" ];then
	mkdir ${path_figs}/s2b_segmentation/
fi


# Create a temp folder to download the images
if [ ! -d "./tmp" ];then
	mkdir -p ./tmp
fi

# Open a SSH connection and download the images
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/segmentation/${subject}_5TT.nii \
/home/fede/tmp/${subject}_5TT.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading 5TT" >> ${error_log_file}
continue
fi

sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/segmentation/${subject}_3DT1_bet.nii \
/home/fede/tmp/${subject}_3DT1_bet.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading 3DT1 bet" >> ${error_log_file}
continue
fi

if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2b_segmentation/${subject}_5tt.png" ];then

# Extract gray and white matter
mrconvert ${force} /home/fede/tmp/${subject}_5TT.nii -coord 3 0 -axes 0,1,2 /home/fede/tmp/${subject}_gm.nii
mrconvert ${force} /home/fede/tmp/${subject}_5TT.nii -coord 3 2 -axes 0,1,2 /home/fede/tmp/${subject}_wm.nii

# Check gm-wm boundary
mrview ${force} -quiet \
-load /home/fede/tmp/${subject}_3DT1_bet.nii -mode 2 \
-overlay.load /home/fede/tmp/${subject}_gm.nii -overlay.opacity 0.4 -overlay.colourmap 2 \
-overlay.load /home/fede/tmp/${subject}_wm.nii -overlay.opacity 0.4 -overlay.colourmap 7  \
-capture.folder ${path_figs}/s2b_segmentation/ -capture.grab \
-exit


		
		
# Change the stander mrview-name of the file
mv -f ${path_figs}/s2b_segmentation/screenshot0000.png ${path_figs}/s2b_segmentation/${subject}_5tt.png

fi


fi

##############################################################
# Registration
##############################################################
if [ "${registration_flag}" == 1 ];then

echo "   Check registration"


# Create the folder
if [ ! -d "${path_figs}/s2c_registration/" ];then
	mkdir ${path_figs}/s2c_registration/
fi

# Create a temp folder to download the images
if [ ! -d "./tmp" ];then
	mkdir -p ./tmp
fi

# Open a SSH connection and download the images
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
/home/fede/tmp/${subject}_${atlas}_b0space_dilated.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading ${atlas}_b0space" >> ${error_log_file}
continue
fi

sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/registration/${subject}_5TT_gmwmi_b0space.nii \
/home/fede/tmp/${subject}_5TT_gmwmi_b0space.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading 5TT_b0space" >> ${error_log_file}
continue
fi

# Extract the preprocessed b0
if  [ ! -f "/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii" ];then
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii

mrconvert ${force} /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
-coord 3 0 -axes 0,1,2 \
/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii
fi

# Check ${atlas} in b0 space
if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2c_registration/${subject}_${atlas}_b0space.png" ];then

mrview ${force} -quiet -nthreads ${cores} \
-load /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii \
-mode 2 \
-overlay.load /home/fede/tmp/${subject}_${atlas}_b0space_dilated.nii \
-overlay.opacity 0.4 \
-capture.folder ${path_figs}/s2c_registration -capture.grab \
-exit

# Change the stander mrview-name of the file
mv -f ${path_figs}/s2c_registration/screenshot0000.png ${path_figs}/s2c_registration/${subject}_${atlas}_b0space.png
fi 

# Check gmwmi in b0 space
if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2c_registration/${subject}_5TT_gmwmi_b0space.png" ];then
mrview ${force} -quiet -nthreads ${cores} \
-load /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii \
-mode 2 \
-overlay.load /home/fede/tmp/${subject}_5TT_gmwmi_b0space.nii \
-overlay.opacity 0.4 \
-capture.folder ${path_figs}/s2c_registration -capture.grab \
-exit
		
# Change the stander mrview-name of the file
mv -f ${path_figs}/s2c_registration/screenshot0000.png ${path_figs}/s2c_registration/${subject}_5TT_gmwmi_b0space.png

fi

fi

##############################################################
# Tractography
##############################################################
if [ "${tractography_flag}" == 1 ];then

echo "   Check tractography"

# Create the folder
if [ ! -d "${path_figs}/s2e_tractography/" ];then
	mkdir ${path_figs}/s2e_tractography/
fi

# Create a temp folder to download the images
if [ ! -d "./tmp" ];then
	mkdir -p ./tmp
fi

# Open a SSH connection and download the images
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/structural_measures/${subject}_100k_seed_dynamic.tck \
/home/fede/tmp/${subject}_100k_seed_dynamic.tck
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading 100k tck" >> ${error_log_file}
continue
fi

# Extract the preprocessed b0
if  [ ! -f "/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii" ];then
sshpass -f ~/.cesvima_password.txt \
scp t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/data/DWI/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii
# If there is no image to download, continue to other subject to avoid errors
status=$?
if [ $status -ne 0 ]; then
echo "${subject} fails downloading DWI preprocessed" >> ${error_log_file}
continue
fi
fi

mrconvert ${force} /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
-coord 3 0 -axes 0,1,2 \
/home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii


# Check tractography in the brain
if [ "$overwrite" == true ] || [ ! -f "${path_figs}/s2e_tractography/${subject}_100k_seed_dynamic.png" ];then

mrview ${force} -quiet -nthreads ${cores} \
-load /home/fede/tmp/${subject}_dwi_den_gibbs_preproc_bias_reoriented_b0.nii \
-mode 2 \
-tractography.load /home/fede/tmp/${subject}_100k_seed_dynamic.tck \
-capture.folder ${path_figs}/s2e_tractography -capture.grab \
-exit

# Change the stander mrview-name of the file
mv -f ${path_figs}/s2e_tractography/screenshot0000.png ${path_figs}/s2e_tractography/${subject}_100k_seed_dynamic.png
	
fi
fi


done < ${filename}

##############################################################
# Remove the temporal files used.
##############################################################
if [ -d "/home/fede/tmp/" ];then
	rm -Rf /home/fede/tmp/
fi

##############################################################
# Create remote destination
##############################################################
sshpass -f ~/.cesvima_password.txt \
ssh t192950@magerit.cesvima.upm.es 'mkdir -p /media/beegfs/home/t192/t192950/MENSA_20260515/figs'

status=$?
if [ $status -ne 0 ]; then
    echo "Failed creating remote figs folder" >> "$error_log_file"
    exit 1
fi

##############################################################
# Upload local check folder
##############################################################
sshpass -f ~/.cesvima_password.txt \
scp -r "${path_figs}" t192950@magerit.cesvima.upm.es:/media/beegfs/home/t192/t192950/MENSA_20260515/figs/

status=$?
if [ $status -ne 0 ]; then
    echo "Failed uploading check folder" >> "$error_log_file"
    exit 1
fi






