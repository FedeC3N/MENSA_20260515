#!/bin/bash
##----------------------- Start job description -----------------------
#SBATCH --partition=standard
#SBATCH --job-name=s2f_save_sc_matrix
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=2G
#SBATCH --mail-type=ALL
#SBATCH --output=./slurm_out/out-%j.log
#SBATCH --error=./slurm_out/err-%j.log
##------------------------ End job description ------------------------

# Define paths and relevant variables
path_dwi='"../../data/DWI"'
path_out='"../../data/sc"'

# Parameters
declare -a SEEDS=('"1M"')
declare -a MEASURES=('"adc"' '"fa"' '"ad"' '"rd"' '"cl"' '"cp"' '"cs"') 
declare -a STATS=('"mean"' '"median"' '"min"' '"max"' ) 
declare -a ATLAS=('"AAL"')
overwrite=true
subject="\"$subject\""

# Load MRtrix3 y FSL
module purge
module load MATLAB/2021a

# Define the number of CPUs available
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
cores=20

now=$(date +"%T")
echo "Start at ${now}"

echo "###################"
echo "Working on subject ${subject}"


# First, just the num_streamlines
for seed in ${SEEDS[@]};do
for atlas in ${ATLAS[@]};do

echo "  ${seed} streamlines - num_streamlines - ${atlas} atlas"

# MATLAB function
# function s2f_save_sc_matrix_matlab(path_dwi, path_out, subject, seed, stat, measure, atlas, overwrite)

measure='"num_streamlines"'

matlab -batch "s2f_save_sc_matrix_matlab($path_dwi, $path_out, $subject, $seed, [] , $measure, $atlas , $overwrite)"

done
done




for seed in ${SEEDS[@]};do
for stat in ${STATS[@]};do
for measure in ${MEASURES[@]};do
for atlas in ${ATLAS[@]};do

echo "  ${seed} streamlines - ${stat}_${measure} - ${atlas} atlas"

# MATLAB function
# function s2f_save_sc_matrix_matlab(path_dwi, path_out, subject, seed, stat, measure, atlas, overwrite)


matlab -batch "s2f_save_sc_matrix_matlab($path_dwi, $path_out, $subject, $seed, $stat, $measure, $atlas, $overwrite)"

done
done
done
done

echo ""
now=$(date +"%T")
echo "Finish at ${now}"

# Rename the SLURM outputs
mv -f ./slurm_out/out-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-out.log
mv -f ./slurm_out/err-${SLURM_JOB_ID}.log ./slurm_out/${subject}-${SLURM_JOB_NAME}-err.log


