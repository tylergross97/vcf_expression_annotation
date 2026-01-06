process PIPELINE_STATS {
    container "community.wave.seqera.io/library/python:3.11.0--73cecb2a04197534"
    publishDir "${params.outdir}/pipeline_info", mode: 'copy', enabled: params.outdir != null

    input:
    path(csv_files)
    val(patient_id)

    output:
    path "pipeline_stats_mqc.yaml", emit: stats

    script:
    """
    #!/usr/bin/env python3
    import csv
    import yaml
    from pathlib import Path

    # Collect all CSV files
    csv_files = [f for f in Path('.').glob('*.csv')]
    
    total_variants = 0
    samples_processed = len(csv_files)
    variants_with_expression = 0
    
    for csv_file in csv_files:
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                total_variants += 1
                if row.get('Expression') and row['Expression'] != 'None' and row['Expression'] != '':
                    variants_with_expression += 1
    
    # Calculate percentage
    expression_percentage = (variants_with_expression / total_variants * 100) if total_variants > 0 else 0
    
    # Create MultiQC custom content
    stats = {
        'id': 'vcf_expression_annotator_summary',
        'section_name': 'Pipeline Summary',
        'description': 'Summary statistics from the VCF Expression Annotation Pipeline',
        'plot_type': 'table',
        'pconfig': {
            'id': 'vcf_expression_annotator_summary_table',
            'title': 'VCF Expression Annotator - Pipeline Summary'
        },
        'data': {
            '${patient_id}': {
                'Samples Processed': samples_processed,
                'Total Variants': total_variants,
                'Variants with Expression': variants_with_expression,
                'Expression Coverage (%)': f'{expression_percentage:.2f}'
            }
        }
    }
    
    with open('pipeline_stats_mqc.yaml', 'w') as f:
        yaml.dump(stats, f, default_flow_style=False)
    
    print(f"✅ Pipeline stats generated for MultiQC")
    """
}
