#!/bin/bash
#SBATCH --job-name="PID_262622_vcf_expression_annotator"
#SBATCH --cluster=ub-hpc
#SBATCH --partition=general-compute
#SBATCH --qos=general-compute
#SBATCH --account=rpili
#SBATCH --cpus-per-task=32
#SBATCH --mem=258G
#SBATCH --time=12:00:00
#SBATCH --output=/projects/academic/rpili/Jonathan_Lovell_project/vcf_expression_annotator/slurm/slurm-%j.out
#SBATCH --error=/projects/academic/rpili/Jonathan_Lovell_project/vcf_expression_annotator/slurm/slurm-%j.err
#SBATCH --mail-user=tgross2@buffalo.edu
#SBATCH --mail-type=ALL

# Java environment (locally installed)
export JAVA_HOME="/projects/academic/rpili/tgross2/java/jdk-21.0.2"
export PATH="$JAVA_HOME/bin:$PATH"

# Nextflow environment variables
export TMPDIR=/projects/academic/rpili/tgross2/tmp
export SINGULARITY_LOCALCACHEDIR=/projects/academic/rpili/tgross2/tmp
export SINGULARITY_CACHEDIR=/projects/academic/rpili/tgross2/tmp
export SINGULARITY_TMPDIR=/projects/academic/rpili/tgross2/tmp
export NXF_SINGULARITY_CACHEDIR=/projects/academic/rpili/tgross2/singularity_cache
export NXF_HOME=/projects/academic/rpili/tgross2/tmp/.nextflow
export NXF_WORK=/vscratch/grp-rpili/neoantigen_prediction/vcf_expression_annotation/PID_262622

# Container environment variables
export SINGULARITYENV_TMPDIR=/tmp
export APPTAINERENV_TMPDIR=/tmp
export SINGULARITYENV_HOME=/tmp
export APPTAINERENV_HOME=/tmp

# Add your Python virtualenv's bin directory to PATH so tools like samtools, tabix, etc. are available
export PATH="/projects/academic/rpili/tyler_venv/bin:$PATH"

# Optional: activate the Python virtual environment for Python packages, env vars, and LD_LIBRARY_PATH
source /projects/academic/rpili/tyler_venv/bin/activate

# Create and set permissions for tmp directories
mkdir -p "$TMPDIR" "$NXF_SINGULARITY_CACHEDIR"
chmod 755 "$TMPDIR" "$NXF_SINGULARITY_CACHEDIR"

# Source your Nextflow setup script if needed
source /projects/academic/rpili/tgross2/setup_nextflow_env.sh

# Verify environment
echo "=== Environment Check ==="
echo "Java version: $(java -version 2>&1 | head -1)"
echo "Nextflow version: $(nextflow -version 2>&1 | grep version)"
echo "=========================="

nextflow run main.nf \
    --patient_id 'PID_262622_' \
    --samplesheet /projects/academic/rpili/Jonathan_Lovell_project/samplesheets/pdmr/PID_262622/vcf_expression_annotator.csv \
    --transcript_counts /projects/academic/rpili/Jonathan_Lovell_project/results/pdmr/PID_262622/rnaseq/star_salmon/salmon.merged.transcript_counts.tsv \
    --outdir_base /projects/academic/rpili/Jonathan_Lovell_project/results/pdmr/PID_262622/vcf_expression_annotator/ \
    -profile singularity \
    -resume
