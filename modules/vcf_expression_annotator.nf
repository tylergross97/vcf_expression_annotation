process VCF_EXPRESSION_ANNOTATOR {
    container "griffithlab/vatools:latest"
    publishDir params.outdir_vcf_expression_annotator, mode: 'copy'

    input:
       tuple val(sample_id), file(vcf_path), val(tumor_sample), file(expr_table)
       val patient_id

    output:
         tuple val(sample_id), val(tumor_sample), file("${patient_id}${sample_id}.expression_vep.chr22.vcf.gz"), emit: expression_vep_vcf
    
    script:
    """
    vcf-expression-annotator \
        "${vcf_path}" \
        "${expr_table}" \
        custom transcript \
        --id-column tx \
        --expression-column ${patient_id}${sample_id} \
        -o "${patient_id}${sample_id}.expression_vep.chr22.vcf.gz" \
        --ignore-ensembl-id-version \
        -s "${tumor_sample}"
    """
}