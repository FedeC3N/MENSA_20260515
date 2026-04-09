#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --job-name=s2e_structural_measures
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

# Parameters
SEEDS=1M # (1M 5M 10M 15M 20M 25M 30M)
TENSOR_MEASURES=('adc' 'fa' 'ad' 'rd' 'cl' 'cp' 'cs') # ('adc' 'fa' 'ad' 'rd' 'cl' 'cp' 'cs')
STREAMLINES_STATS=('mean' 'median' 'min' 'max') # mean, median, min, max.
ATLAS=('AAL')


# Define the number of CPUs available
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
cores=20

if [ "$overwrite" == true ];then
force='-force'
fi

# To avoid the screen output in MRtrix
export MRTRIX_QUIET=1

path_dwi=../../data/DWI

now=$(date +"%T")
echo "Start at ${now}"

echo "###################"
echo "Working on subject ${subject}"


# Create a directory for the tracts files
if [ ! -d "${path_dwi}/${subject}/structural_measures/" ];then
	mkdir ${path_dwi}/${subject}/structural_measures/
fi

echo " dwi2tensor - Estimate the tensor image and its associated measures..."
# Get the response function to every tissue
if [ "${dwi2tensor_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_tensor.nii" ];then
	

	# Get the tensor image
	dwi2tensor ${force} -nthreads ${cores} -quiet \
		-mask ${path_dwi}/${subject}/segmentation/${subject}_DWI_mask.nii -fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_tensor.nii
	
	
		
	# Get the associated measures
	for measure in ${TENSOR_MEASURES[@]};do
		tensor2metric ${force} -nthreads ${cores} \
			-${measure} ${path_dwi}/${subject}/structural_measures/${subject}_${measure}.nii \
			${path_dwi}/${subject}/structural_measures/${subject}_tensor.nii
	done
		

else
	echo "  Already calculated."

fi
else
	echo "  Not calculated. Flag not activated."
fi


echo " dwi2fod - Estimating fibre orientation distributions..."
# Estimate Fiber Orientation Distribution (FOD)
if [ "${dwi2fod_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_wm_fod.nii" ];then
	

	
	mrconvert ${force} -nthreads ${cores} -quiet\
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.nii \
		-fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval -import_pe_table ${path_dwi}/${subject}/acqparm.txt \
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.mif

	dwi2fod msmt_csd -nthreads ${cores} -quiet\
		${path_dwi}/${subject}/preprocess/${subject}_dwi_den_gibbs_preproc_bias_reoriented.mif \
		${path_dwi}/${subject}/structural_measures/wm_average_response.txt ${path_dwi}/${subject}/structural_measures/${subject}_wm_fod.mif \
		${path_dwi}/${subject}/structural_measures/gm_average_response.txt ${path_dwi}/${subject}/structural_measures/${subject}_gm_fod.mif \
		${path_dwi}/${subject}/structural_measures/csf_average_response.txt ${path_dwi}/${subject}/structural_measures/${subject}_csf_fod.mif \
		-mask ${path_dwi}/${subject}/segmentation/${subject}_DWI_mask.nii

		
	mrconvert ${force} -nthreads ${cores} -quiet\
		${path_dwi}/${subject}/structural_measures/${subject}_wm_fod.mif \
		${path_dwi}/${subject}/structural_measures/${subject}_wm_fod.nii

	mrconvert ${force} -nthreads ${cores} -quiet\
		${path_dwi}/${subject}/structural_measures/${subject}_gm_fod.mif \
		${path_dwi}/${subject}/structural_measures/${subject}_gm_fod.nii
		
	mrconvert ${force} -nthreads ${cores} -quiet\
		${path_dwi}/${subject}/structural_measures/${subject}_csf_fod.mif \
		${path_dwi}/${subject}/structural_measures/${subject}_csf_fod.nii


else
	echo "  Already calculated."

fi
else
	echo "  Not calculated. Flag not activated."

fi

echo " mtnormalise - Multi-tissue intensity normalisation..."
# Intensity normalization
if [ "${mtnormalise_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_wm_fod_norm.nii" ];then



	mtnormalise ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/structural_measures/${subject}_wm_fod.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_wm_fod_norm.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_gm_fod.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_gm_fod_norm.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_csf_fod.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_csf_fod_norm.nii \
		-mask ${path_dwi}/${subject}/segmentation/${subject}_DWI_mask.nii



else
	echo "  Already calculated."

fi
else
	echo "  Not calculated. Flag not activated."

fi

echo " tckgen-tcksift2 - Performing the streamlines tractography..."
# Estimate the tractography
if [ "${tckgen_flag}" == 1 ];then
for seeds in ${SEEDS[@]};do
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2.txt" ];then
	

	echo "  ${seeds} streamlines..."
	
	# Tractography estimation and the TCKSIFT2 correction for SEED DYNAMIC
	tckgen ${force} -nthreads ${cores} -algorithm iFOD2 \
		-fslgrad ${path_dwi}/${subject}/bvec ${path_dwi}/${subject}/bval \
		-act ${path_dwi}/${subject}/registration/${subject}_5TT_b0space.nii \
		-seed_dynamic ${path_dwi}/${subject}/structural_measures/${subject}_wm_fod_norm.nii \
		-select ${seeds} -maxlength 250 -cutoff 0.06 -backtrack -crop_at_gmwmi \
		${path_dwi}/${subject}/structural_measures/${subject}_wm_fod_norm.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck  # Output
		 
	tcksift2 ${force} -nthreads ${cores} \
		-act ${path_dwi}/${subject}/registration/${subject}_5TT_b0space.nii \
		-out_mu ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_mu_coefficient.txt \
		${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck \
		${path_dwi}/${subject}/structural_measures/${subject}_wm_fod_norm.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2.txt
		


else
	echo "  Already calculated."

fi
done
else
	echo "  Not calculated. Flag not activated."

fi

echo " tck2connectome - Generating the structural connectivity matrix..."
# TCK2CONNECTOME - Convert the tractography file into a matlab matrix.
if [ "${tck2connectome_flag}" == 1 ];then
for atlas in ${ATLAS[@]};do
for seeds in ${SEEDS[@]};do
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2_${atlas}_num_streamlines.csv" ];then

	echo "  ${atlas} ${seeds} streamlines..."


	# Streamline connectome
	tck2connectome ${force} -nthreads ${cores} \
		-tck_weights_in ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2.txt \
		${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck \
		${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
		${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2_${atlas}_num_streamlines.csv # Ouput	



else
	echo "  Already calculated."

fi
done
done
else
	echo "  Not calculated. Flag not activated."

fi


echo " tensorconnectome - Generating the structural connectivity matrix..."
if [ "${tensorconnectome_flag}" == 1 ];then	
for seeds in ${SEEDS[@]};do
for measure in ${TENSOR_MEASURES[@]};do
for streamlines_stat in ${STREAMLINES_STATS[@]};do
	

	echo "  tcksample ${seeds} streamlines, measure ${measure}..."
	
	
	if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_${streamlines_stat}_${measure}.csv" ];then
		# Sample values of an associated image along tracks
		tcksample ${force} -nthreads ${cores} \
			${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck \
			${path_dwi}/${subject}/structural_measures/${subject}_${measure}.nii \
			${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_${streamlines_stat}_${measure}.csv \
			-stat_tck ${streamlines_stat}
	else
		echo "   Already calculated."

	
	fi
	

	echo "  ${atlas} ${seeds} streamlines..."
	for atlas in ${ATLAS[@]};do
	if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2_${atlas}_${streamlines_stat}_${measure}.csv" ];then

		# Estimate the connectome
		tck2connectome ${force} -nthreads ${cores} \
			-tck_weights_in ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2.txt \
			-stat_edge mean -scale_file ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_${streamlines_stat}_${measure}.csv \
			${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck \
			${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
			${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2_${atlas}_${streamlines_stat}_${measure}.csv    
	  
	else 
		echo "   Already calculated."

	fi
	done   



done
done
done
else
	echo "  Not calculated. Flag not activated."

fi

# Remove the tck files since they are pretty heavy
for seeds in ${SEEDS[@]};do

	# Keep a reduced version for print purposes
	tckedit ${force} ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck \
	${path_dwi}/${subject}/structural_measures/${subject}_100k_seed_dynamic.tck -number 100k

	rm -f ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic.tck 
	rm -f ${path_dwi}/${subject}/structural_measures/${subject}_${seeds}_seed_dynamic_sift2.txt
done

echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-err.log


