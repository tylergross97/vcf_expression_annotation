process MULTIQC {
    container "community.wave.seqera.io/library/multiqc:1.25.1--b33b48802fc6f8df"
    publishDir "${params.outdir}/multiqc", mode: 'copy', enabled: params.outdir != null

    input:
    path(multiqc_files, stageAs: "?/*")
    path(multiqc_config)
    val(patient_id)

    output:
    path "*multiqc_report.html", emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional: true, emit: plots

    script:
    def config_opt = multiqc_config ? "--config ${multiqc_config}" : ''
    """
    multiqc \\
        --force \\
        --filename ${patient_id}multiqc_report.html \\
        ${config_opt} \\
        .
    """
}
