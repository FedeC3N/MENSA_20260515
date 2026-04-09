#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --job-name=s2a_T1_FreeSurfer_parcellation
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=2G
#SBATCH --mail-type=ALL
#SBATCH --output=./slurm_out/out-%j.log
#SBATCH --error=./slurm_out/err-%j.log
##------------------------ End job description ------------------------

# Load MRtrix3 y FSL
module purge
module load MRtrix/3.0.2-foss-2018b-Python-2.7.15 
module load FSL/5.0.11-foss-2018b
module load FreeSurfer/7.1.1-centos8_x86_64

# Execute the FSL config file
. ${FSLDIR}/etc/fslconf/fsl.sh
FSLOUTPUTTYPE=NIFTI

# Define the number of CPUs available
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
cores=20

if [ "$overwrite" == true ];then
force='-force'
fi

# To avoid the screen output in MRtrix
export MRTRIX_QUIET=1

# Define paths and relevant variables
path_T1=../../data/DWI

# Select the atlas to use
ATLAS=('AAL')
ordered=1

now=$(date +"%T")
echo "Start at ${now}"

echo "###################"
echo "Working on subject ${subject}"

# Create a directory for the registration files
if [ ! -d "${path_T1}/${subject}/" ];then
	mkdir ${path_T1}/${subject}/
fi

if [ ! -d "${path_T1}/${subject}/segmentation/" ];then
	mkdir ${path_T1}/${subject}/segmentation/
fi

if [ ! -d "${path_T1}/${subject}/registration/" ];then
	mkdir ${path_T1}/${subject}/registration/
fi

# Move the T1 to the new folder
cp \
	${path_T1}/${subject}_0_T1.nii \
	${path_T1}/${subject}/${subject}_0_T1.nii


# Set the FreeSurfer working folder in the subject subject folder
SUBJECTS_DIR=${path_T1}/${subject}


# Performs all, or any part of, the FreeSurfer cortical reconstruction process.
echo " recon-all - FreeSurfer cortical reconstruction..."
if [ "${reconall_flag}" == 1 ];then
if [ "$overwrite" == true ] || [ ! -f "${path_T1}/${subject}/${subject}_T1_iso_reoriented.nii" ];then
	
	echo "recon-all"

	# To overwrite, FreeSurfer force you to delete the existing folders
	if [ -d "${path_T1}/${subject}/${subject}_FreeSurfer/" ];then
		rm -r ${path_T1}/${subject}/${subject}_FreeSurfer/
	fi
	
#	recon-all \
#		-s ${path_T1}/${subject}/${subject}_FreeSurfer \
#		-i ${path_T1}/${subject}_3DT1.nii \
#		-parallel -openmp ${cores} -all

	recon-all \
		-s ${path_T1}/${subject}/${subject}_FreeSurfer \
		-i ${path_T1}/${subject}/${subject}_0_T1.nii -all


	mrconvert ${force} -nthreads ${cores} \
		${path_T1}/${subject}/${subject}_FreeSurfer/mri/T1.mgz \
		${path_T1}/${subject}/${subject}_FreeSurfer/mri/T1.nii

	fslreorient2std ${path_T1}/${subject}/${subject}_FreeSurfer/mri/T1 ${path_T1}/${subject}/${subject}_FreeSurfer/mri/T1_reoriented

	cp \
		${path_T1}/${subject}/${subject}_FreeSurfer/mri/T1_reoriented.nii \
		${path_T1}/${subject}/${subject}_3DT1_iso_reoriented.nii
	
	# Save the T1 extracted brain.
	mrconvert ${force} -nthreads ${cores} \
		${path_T1}/${subject}/${subject}_FreeSurfer/mri/brain.mgz \
		${path_T1}/${subject}/${subject}_FreeSurfer/mri/brain.nii
	cp \
		${path_T1}/${subject}/${subject}_FreeSurfer/mri/brain.nii \
		${path_T1}/${subject}/segmentation/${subject}_3DT1_bet.nii 
	
	fslreorient2std	${path_T1}/${subject}/segmentation/${subject}_3DT1_bet	

	
else

	echo -e "  Already calculated."

fi
else
	echo -e "  Not calculated. Flag not activated."

fi



echo " asegstats2table - Intecraneal measures..."
# Get the intracraneal measures (or other measures) in txt format.
if [ "${asegstats_flag}" == 1 ];then
for atlas in ${ATLAS[@]};do
if [ "$overwrite" == true ]  || [ ! -f "${path_T1}/${subject}/${subject}_${atlas}_FreeSurfer_measures.txt" ];then	   


	asegstats2table \
		-i ${path_T1}/${subject}/${subject}_FreeSurfer/stats/aseg.stats \
		--tablefile ${path_T1}/${subject}/${subject}_FreeSurfer_measures.txt \
		--meas volume --transpose --delimiter space

	mris_anatomical_stats -a ${path_T1}/${subject}/${subject}_FreeSurfer/label/rh.${atlas}.annot \
		-f ${path_T1}/${subject}/${subject}_${atlas}_FreeSurfer_measures.txt \
		-b ${subject}_FreeSurfer rh 


else

	echo -e "  Already calculated."

fi
done
else
	echo -e "  Not calculated. Flag not activated."

fi


echo " parc2aseg - Create the segmentation image for each subject..."
# Create the segmentation image for each subject
if [ "${parc2seg_flag}" == 1 ];then
for atlas in ${ATLAS[@]};do
if [ "$overwrite" == true ]  || [ ! -f "${path_T1}/${subject}/registration/${subject}_${atlas}_T1space.nii" ];then	

	echo "  Working with Atlas ${atlas}"   
		
	# Copy the standard FreeSurfer subject
	# if the FreeSurfer folder is a symbolic link, remove it
	if [ -L "${path_T1}/${subject}/fsaverage" ];then
		unlink ${path_T1}/${subject}/fsaverage
	fi

	# If exist a previous file, delete it to avoid FreeSurfer errors
	if [ -d "${path_T1}/${subject}/fsaverage/" ];then
		rm  -rf ${path_T1}/${subject}/fsaverage/
	fi
	cp -rf ../SharedFunctions/templates/FreeSurfer/fsaverage/ ${path_T1}/${subject}/


	# Register the subject and fsaverage "spheres" and proyect the fsaverage/${atlas} to the subject sphere
	mri_surf2surf --hemi lh \
		--srcsubject fsaverage \
		--trgsubject ${subject}_FreeSurfer \
		--sval-annot ${atlas}.annot \
		--tval ${path_T1}/${subject}/${subject}_FreeSurfer/label/lh.${atlas}.annot


	mri_surf2surf --hemi rh \
		--srcsubject fsaverage \
		--trgsubject ${subject}_FreeSurfer \
		--sval-annot ${atlas}.annot \
		--tval ${path_T1}/${subject}/${subject}_FreeSurfer/label/rh.${atlas}.annot
		

	echo "  aparc2aseg"

		
	mri_aparc2aseg \
		--s ${subject}_FreeSurfer \
		--annot ${atlas} \
		--annot-table ${path_T1}/${subject}/fsaverage/${atlas}_ColorLUT_unordered.txt \
		--o ${path_T1}/${subject}/registration/${subject}_${atlas}_T1space_unordered.mgz 


	mrconvert -force -nthreads ${cores} \
		${path_T1}/${subject}/registration/${subject}_${atlas}_T1space_unordered.mgz \
		${path_T1}/${subject}/registration/${subject}_${atlas}_T1space_unordered.nii \
		-datatype uint32


	echo "  labelsgmfix"


	# Gives an error: No such file or directory: '/media/apps/avx512-2021/software/MRtrix/3.0.2-foss-2018b-Python-2.7.15/share/mrtrix3/labelsgmfix/FreeSurferSGM.txt'
	# Replace the sub-cortical grey matter structure delineations of FreeSurfer using FSL FIRST
#	labelsgmfix -force -nthreads ${cores} \
#		${path_T1}/${subject}/registration/${subject}_${atlas}_incomplete_T1space.nii \
#		${path_T1}/${subject}/segmentation/${subject}_3DT1_bet.nii \
#		/usr/local/freesurfer/7.2.0-1/FreeSurferColorLUT.txt \
#		${path_T1}/${subject}/registration/${subject}_${atlas}_incomplete_T1space.nii \
#		-premasked -sgm_amyg_hipp
		

	# Replace the random integers of the atlas file with integers that start at 1 and increase by 1.		
	labelconvert ${force} -nthreads ${cores} \
		${path_T1}/${subject}/registration/${subject}_${atlas}_T1space_unordered.nii \
		${path_T1}/${subject}/fsaverage/${atlas}_ColorLUT_unordered.txt \
		${path_T1}/${subject}/fsaverage/${atlas}_ColorLUT.txt \
		${path_T1}/${subject}/registration/${subject}_${atlas}_T1space.nii
	

	echo "  fslreorient2std"

	# Reoriented the segmentation image to the standard space
	fslreorient2std ${path_T1}/${subject}/registration/${subject}_${atlas}_T1space
	

	# Once it finished, remove the fsaverage
	rm -r ${path_T1}/${subject}/fsaverage

else
	echo -e "  Already calculated."


fi
done
else

	echo -e "  Not calculated. Flag not activated."


fi


echo ""


if [ -d "${path_T1}/${subject}/fsaverage/" ];then
	rm  -r ${path_T1}/${subject}/fsaverage/
fi


echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-err.log


