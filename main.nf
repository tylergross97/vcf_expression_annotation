#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { SPLIT_TRANSCRIPT_COUNTS } from './modules/split_transcript_counts.nf'
include { VCF_EXPRESSION_ANNOTATOR } from './modules/vcf_expression_annotator.nf'
include { CLEAN_VCF } from './modules/clean_vcf.nf'
include { VCF_TO_CSV } from './modules/vcf_to_csv.nf'

// Parameter validation function
def validateParameters() {
    def requiredParams = [
        'patient_id': params.patient_id,
        'samplesheet': params.samplesheet,
        'transcript_counts': params.transcript_counts,
        'outdir_base': params.outdir_base
    ]
    
    def missingParams = []
    requiredParams.each { name, value ->
        if (value == null || value == '') {
            missingParams.add("--${name}")
        }
    }
    
    if (missingParams.size() > 0) {
        error """
        Missing required parameters: ${missingParams.join(', ')}
        
        Please provide all required parameters on the command line:
        
        Example usage:
        nextflow run main.nf \\
            --patient_id 'PID_123_' \\
            --samplesheet 'path/to/samplesheet.csv' \\
            --transcript_counts 'path/to/transcript_counts.tsv' \\
            --outdir_base 'results'
        
        Or use the test profile:
        nextflow run main.nf -profile test
        """
    }
}

workflow {
    // Validate parameters (skip if using test profile)
    if (workflow.profile != 'test') {
        validateParameters()
    }
    
    // Set input ch_transcript_counts which is the transcript counts file specified in the nextflow.config file and was generated from nf-core/rna-seq
    ch_transcript_counts = Channel.fromPath(params.transcript_counts)
    // Run the SPLIT_TRANSCRIPT_COUNTS process to split the transcript counts file into individual sample files
    SPLIT_TRANSCRIPT_COUNTS(ch_transcript_counts)
    
    // Create ch_split_counts based on the output of SPLIT_TRANSCRIPT_COUNTS and use the file names to generate a sample_id so that it can be joined with the vcf files later
    ch_split_counts = SPLIT_TRANSCRIPT_COUNTS.out.split_transcript_counts
        .flatten()
        .map { file ->
            def name = file.getName()
            def sample_id = name.replaceFirst(params.patient_id, '').replace('.tsv', '')
            tuple(sample_id, file)
        }
    // Read in the samplesheet which contains the sample IDs that correspond to the sample_id in ch_split_counts and information about the vcf files and create a channel
    ch_samplesheet = Channel
        .fromPath(params.samplesheet)
        .splitCsv(header:true)
        .map { row -> 
            def vcf_file = row.vcf_path.startsWith('/') ?
                file(row.vcf_path) :
                file("${projectDir}/${row.vcf_path}")
            tuple(row.sample_id, vcf_file, row.vcf_tumor_sample)
        }
    // Join the ch_split_counts and ch_samplesheet channels on the sample_id
    ch_joined = ch_samplesheet.join(
        ch_split_counts,
        by: 0 // join on sample_id
    )
    ch_patient_id = Channel.value(params.patient_id)
    VCF_EXPRESSION_ANNOTATOR(ch_joined, ch_patient_id)
    CLEAN_VCF(VCF_EXPRESSION_ANNOTATOR.out.expression_vep_vcf, ch_patient_id)
    VCF_TO_CSV(CLEAN_VCF.out.clean_vcf, ch_patient_id)
}
