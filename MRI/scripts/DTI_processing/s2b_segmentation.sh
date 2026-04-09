#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --ntasks=1
#SBATCH --job-name=s2b_segmentation
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

# Just in case, run the FSL configuration file
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
path_dwi=../../data/DWI


now=$(date +"%T")
echo "Start at ${now}"

echo "###################"
echo "Working on subject ${subject}"


# Create a directory for the registrations images and matrix
if [ ! -d "${path_dwi}/${subject}/segmentation/" ];then
	mkdir ${path_dwi}/${subject}/segmentation/
fi

echo " fslroi - Get the b0 image..."
# Get the b0-image
if [ "${b0extract_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii" ];then



	fslroi ${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii ${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii 1 1 
		


else

	echo "  Already calculated."

fi
else
	echo "  Not calculated. Flag not activated."

fi


echo " 5ttgen hsvs - Get the 5TT image..."
# Get 5TT of the T1
if [ "${get5TT_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/segmentation/${subject}_5TT.nii" ];then


	
	5ttgen hsvs ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/${subject}_FreeSurfer \
		${path_dwi}/${subject}/segmentation/${subject}_5TT.nii \
		-hippocampi first -nocrop 
		
		

else

	echo "  Already calculated."

fi
else
	echo "  Not calculated. Flag not activated."

fi


echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-err.log
