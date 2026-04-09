#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --job-name=s2a_DWI_preprocessing
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
path_dwi=../../data/DWI

now=$(date +"%T")
echo "Start at ${now}"

echo "###################"
echo "Working on subject ${subject}"

if [ ! -d "${path_dwi}/${subject}/preprocess/" ];then
	mkdir ${path_dwi}/${subject}/preprocess/
fi

# Create a directory for the registrations images and matrix
if [ ! -d "${path_dwi}/${subject}/segmentation/" ];then
	mkdir ${path_dwi}/${subject}/segmentation/
fi

echo " Coverting nii.gz to mif..."

########################################################################################### 1
# Convert to MRtrix3-format and add bvec, bval and phase-encoding to the header
if [ "${mrconvert_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/${subject}_DWI.mif" ];then

	mrconvert ${force} -nthreads ${cores} -quiet \
		-fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval -import_pe_table ${path_dwi}/${subject}/acqparm.txt \
		${path_dwi}/${subject}/${subject}_0_DWI.nii \
		${path_dwi}/${subject}/${subject}_DWI.mif

else

	echo -e "  Already calculated."

fi
else
	echo -e "  Not calculated. Flag not activated."

fi

echo " dwimask - Obtain dwi mask..."

########################################################################################### 2
if [ "${dwipreprocmask_flag}" == 1 ];then
if  [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/segmentation/${subject}_DWI_preprocessing_mask.nii.gz" ];then

	dwi2mask ${force} -nthreads ${cores} -quiet \
		-fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval \
		${path_dwi}/${subject}/${subject}_0_DWI.nii \
		${path_dwi}/${subject}/segmentation/${subject}_DWI_preprocessing_mask.nii 
	
else

	echo -e "  Already calculated."

fi
else
	echo -e "  Not calculated. Flag not activated."

fi

echo " dwidenoise - DWI data denoising..."

########################################################################################### 3
if [ "${dwidenoise_flag}" == 1 ];then
if  [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/preprocess/${subject}_dwi_den.mif" ];then

	dwidenoise ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/${subject}_DWI.mif \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den.mif \
		-noise ${path_dwi}/${subject}/preprocess/${subject}_noise.nii \
		-mask ${path_dwi}/${subject}/segmentation/${subject}_DWI_preprocessing_mask.nii 

else

	echo -e "  Already calculated."

fi
else
	echo -e "  Not calculated. Flag not activated."

fi


echo " mrdegibbs - Remove Gibbs Ringing Artifacts..."

########################################################################################### 4
# Remove the Gibbs effect (a ring sounrounding the head)
if [ "${dwidegibbs_flag}" == 1 ];then
if  [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs.mif" ];then


	# I cannot know the direction of acquisition axial, coronal or longitudinal (option -axis) 
	mrdegibbs ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den.mif \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs.mif

else

	echo -e "  Already calculated."
fi
else
	echo -e "  Not calculated. Flag not activated."
fi


echo " dwifslpreproc - Diffusion image preprocessing..."

########################################################################################### 5
# Eddy subject correction: inhomogeneity distortion correction using FSL’s topup tool if possible
if [ "${dwipreproc_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc.mif" ];then

	dwifslpreproc ${force} -nthreads ${cores} -quiet\
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs.mif \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc.mif \
		-eddy_mask ${path_dwi}/${subject}/segmentation/${subject}_DWI_preprocessing_mask.nii \
		-rpe_header -eddy_options " --slm=linear"
		
else

	echo -e "  Already calculated."
fi
else
	echo -e "  Not calculated. Flag not activated."
fi

echo " dwibiascorrect - B1 field inhomogeneity correction..."

########################################################################################### 6
# Bias field correction
if [ "${dwibias_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii.gz" ];then

	dwibiascorrect fsl ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc.mif \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias.mif \
		-mask ${path_dwi}/${subject}/segmentation/${subject}_DWI_preprocessing_mask.nii

	mrconvert ${force} -nthreads ${cores} \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias.mif \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias.nii

	# Flip the directions if necessary to be in the standard directions.
	mrconvert ${force} ${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias.nii \
	-strides -1,2,3 ${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii
			
else

	echo -e "  Already calculated."
fi
else
	echo -e "  Not calculated. Flag not activated."
fi

echo " dwi2mask - Obtaining DWI mask..."

########################################################################################### 7
if [ "${dwimask_flag}" == 1 ];then
if  [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/segmentation/${subject}_DWI_mask.nii.gz" ];then


	dwi2mask ${force} -nthreads ${cores} -quiet \
		-fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
		${path_dwi}/${subject}/segmentation/${subject}_DWI_mask.nii
		
	mrconvert ${force} -nthreads ${cores} \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.mif


else

	echo -e "  Already calculated."
fi
else
	echo -e "  Not calculated. Flag not activated."
fi

echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-err.log

