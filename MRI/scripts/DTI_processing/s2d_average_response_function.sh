#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --job-name=s2d_average_response_function
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


# Create a temporal folder for the averaged response function
if [ ! -d "./tmp_averaged_response_function/" ];then

	mkdir ./tmp_averaged_response_function/

else

	rm -r ./tmp_averaged_response_function/
	mkdir ./tmp_averaged_response_function/

fi


for current_folder in ../../data/DWI/*; do


	subject="${current_folder##$path_dwi}"
	
	if [ "$subject" = "tmp_averaged_response_function" ]; then
    		continue
	fi


	echo "###################"
	echo "Working on subject ${subject}"

	if [ ! -f "${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii" ];then	
		echo "  No preprocessed DWI image. Skipping subject ${subject}"
		continue
	fi
	
	# Create a directory for the tracts files
	if [ ! -d "${path_dwi}/${subject}/structural_measures/" ];then
		mkdir ${path_dwi}/${subject}/structural_measures/
	fi

	echo " dwi2response - Estimate response functions for spherical deconvolution..."
	# Get the response function to every tissue
	if [ "${dwi2response_flag}" == 1 ];then
	if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_wm_response.txt" ];then
        
		# We have to use dhollander because we do not have 3 different uniques values for msmt_5tt
		dwi2response dhollander ${force} -nthreads ${cores} -quiet \
		-fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_wm_response.txt ${path_dwi}/${subject}/structural_measures/${subject}_gm_response.txt ${path_dwi}/${subject}/structural_measures/${subject}_csf_response.txt # Out
			

	else
		
        		echo "  Already calculated."
	fi
	else
	    	echo "  Not calculated. Flag not activated."

	fi
	
	# Copy the response functions to the temporal folder
	cp ${path_dwi}/${subject}/structural_measures/${subject}_wm_response.txt ./tmp_averaged_response_function/${subject}_wm_response.txt
	cp ${path_dwi}/${subject}/structural_measures/${subject}_gm_response.txt ./tmp_averaged_response_function/${subject}_gm_response.txt
	cp ${path_dwi}/${subject}/structural_measures/${subject}_csf_response.txt ./tmp_averaged_response_function/${subject}_csf_response.txt
	
done 
	
# Calculates the average response function
echo ""
echo "responsemean - Calculating the average response function..."
responsemean ${force} -nthreads ${cores} \
./tmp_averaged_response_function/*wm*.txt \
./tmp_averaged_response_function/wm_average_response.txt

responsemean ${force} -nthreads ${cores} \
./tmp_averaged_response_function/*gm*.txt \
./tmp_averaged_response_function/gm_average_response.txt
    
responsemean ${force} -nthreads ${cores} \
./tmp_averaged_response_function/*csf*.txt \
./tmp_averaged_response_function/csf_average_response.txt
    
echo ""

# Copy the average response function in each subject folder
for current_folder in ../../data/DWI/*; do


subject="${current_folder##$path_dwi}"


    	echo "###################"
    	echo "Working on subject ${subject}"
    	echo " Copying the average response function in each subject folder"
    	cp ./tmp_averaged_response_function/wm_average_response.txt ${path_dwi}/${subject}/structural_measures/wm_average_response.txt
    	cp ./tmp_averaged_response_function/gm_average_response.txt ${path_dwi}/${subject}/structural_measures/gm_average_response.txt
    	cp ./tmp_averaged_response_function/csf_average_response.txt ${path_dwi}/${subject}/structural_measures/csf_average_response.txt
    
    	
done 
	
# Remove the temporal folder	
rm -r ./tmp_averaged_response_function
	
echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${SLURM_JOB_NAME}-err.log

