process PUBLISH_REPORTS {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy'
    
    input:
    val run_name
    
    output:
    path "*.{html,txt}", optional: true
    
    script:
    """
    # Copy built-in Nextflow reports if they exist
    # These files are generated in the launch directory
    
    # Look for report files in parent directories
    for file in report*.html timeline*.html trace*.txt dag*.html; do
        if [ -f "../\${file}" ]; then
            cp "../\${file}" .
        elif [ -f "../../\${file}" ]; then
            cp "../../\${file}" .
        elif [ -f "../../../\${file}" ]; then
            cp "../../../\${file}" .
        fi
    done
    
    # List what we found
    ls -lh *.{html,txt} 2>/dev/null || echo "No report files found to publish"
    """
}
