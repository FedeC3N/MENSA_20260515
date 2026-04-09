#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --job-name=s2c_registration
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

# Select the atlas to use
ATLAS=('AAL')

# Just in case, run the FSL configuration file
bash ${FSLDIR}/etc/fslconf/fsl.sh


now=$(date +"%T")
echo "Start at ${now}"

echo "###################"
echo "Working on subject ${subject}"

# Create a directory for the registrations images
if [ ! -d "${path_dwi}/${subject}/registration/" ];then
	mkdir ${path_dwi}/${subject}/registration/
fi

# Create a directory for the transformation matrix
if [ ! -d "${path_dwi}/${subject}/transformation_matrix/" ];then
	mkdir ${path_dwi}/${subject}/transformation_matrix/
fi


echo " flirt - Registration from T1 space to b0 space..."
# Flirt T1 to b0-space
if [ "${T1_2_b0_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/registration/${subject}_3DT1_b0space.nii" ];then
	
	flirt \
		-in ${path_dwi}/${subject}/segmentation/${subject}_3DT1_bet.nii \
		-ref ${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii \
		-omat ${path_dwi}/${subject}/transformation_matrix/${subject}_T1space_2_b0space_lin \
		-cost normmi -dof 7
		
	transformconvert ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/transformation_matrix/${subject}_T1space_2_b0space_lin \
		${path_dwi}/${subject}/segmentation/${subject}_3DT1_bet.nii \
		${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii \
		flirt_import \
		${path_dwi}/${subject}/transformation_matrix/${subject}_T1space_2_b0space_lin_mrtrix
	
	mrtransform ${force} -nthreads ${cores} -quiet \
		-linear ${path_dwi}/${subject}/transformation_matrix/${subject}_T1space_2_b0space_lin_mrtrix \
		-template ${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii \
		-interp linear \
		${path_dwi}/${subject}/segmentation/${subject}_3DT1_bet.nii \
		${path_dwi}/${subject}/registration/${subject}_3DT1_b0space.nii
		
		
else
	echo "  Already calculated."
fi
else
	echo "  Not calculated. Flag not activated."
fi

echo " 5tt2gmwmi - Generating a mask for the grey matter-white matter interface..."
# Get the 5TT in b0-space.
if [ "${get5TT_2_b0_flag}" == 1 ];then
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/registration/${subject}_5TT_gmwmi_b0space.nii" ];then

	mrtransform ${force} -nthreads ${cores} -quiet \
		-linear ${path_dwi}/${subject}/transformation_matrix/${subject}_T1space_2_b0space_lin_mrtrix \
		-template ${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii \
		-interp nearest \
		${path_dwi}/${subject}/segmentation/${subject}_5TT.nii \
		${path_dwi}/${subject}/registration/${subject}_5TT_b0space.nii
	
	5tt2gmwmi ${force} -nthreads ${cores} -quiet \
		${path_dwi}/${subject}/registration/${subject}_5TT_b0space.nii \
		${path_dwi}/${subject}/registration/${subject}_5TT_gmwmi_b0space.nii

else
	echo "  Already calculated."
fi
else
	echo "  Not calculated. Flag not activated."
fi


echo " mrtransform - Registering the atlas to b0 space..."
# Get the atlas template in b0-space.
if [ "${atlas_2_b0_flag}" == 1 ];then
for atlas in ${ATLAS[@]};do
if [ "$overwrite" == true ]  || [ ! -f "${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii" ];then

	
	mrconvert -force -datatype uint32 ${path_dwi}/${subject}/registration/${subject}_${atlas}_T1space.nii ${path_dwi}/${subject}/registration/${subject}_${atlas}_T1space.nii 
	
		
	mrtransform ${force} -nthreads ${cores} -quiet \
		-linear ${path_dwi}/${subject}/transformation_matrix/${subject}_T1space_2_b0space_lin_mrtrix \
		-template ${path_dwi}/${subject}/segmentation/${subject}_b0_bet.nii \
		-interp nearest \
		${path_dwi}/${subject}/registration/${subject}_${atlas}_T1space.nii \
		${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space.nii
	
		
	# Get the control image (white matter,layer 3, in the 5TT) 
	fslroi ${path_dwi}/${subject}/registration/${subject}_5TT_b0space.nii \
		 ${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask.nii 2 1 
		 
	fslreorient2std ${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask 
	
	# Get the white matter mask     
	fslmaths \
		${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask.nii \
		-thr 0.8 -bin \
		${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask.nii 
		
	# Get the inverse mask of the white matter
	fslmaths \
		${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask.nii \
		-binv \
		${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask_inv.nii 
	
	# Create a copy of the atlas to dilate
	cp ${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space.nii \
		${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii
	
	# Dilation process
	for iteration in 5; do
	
		# Dilate the atlas	
		fslmaths \
			${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
			-kernel 3D -dilM \
			${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
			-odt int 
			
		# Apply the white matter mask
		fslmaths \
			${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
			-mul \
			${path_dwi}/${subject}/registration/${subject}_wm_b0space_mask_inv.nii \
			${path_dwi}/${subject}/registration/${subject}_${atlas}_b0space_dilated.nii \
			-odt int 

	done
	
	
else
	echo "  Already calculated."

fi 
done
else
	echo "  Not calculated. Flag not activated."

fi



echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-err.log




