# Reports Configuration Guide

This document explains how reports are configured in the VCF Expression Annotation pipeline to render properly in Seqera Platform.

## 📊 Reports Overview

After a successful pipeline run, the following reports will be generated and viewable in Seqera Platform:

### 1. **MultiQC Report** 
- **Location**: `${params.outdir}/multiqc/`
- **File**: `{patient_id}multiqc_report.html`
- **Description**: Aggregated HTML report showing pipeline summary statistics including:
  - Total samples processed
  - Total variants annotated
  - Number of variants with expression data
  - Expression coverage percentage

### 2. **Nextflow Execution Report**
- **Location**: `${params.outdir}/reports/execution_report.html`
- **Description**: Detailed execution metrics for each process including:
  - CPU and memory usage
  - Task duration
  - Exit status
  - Command lines executed

### 3. **Timeline Report**
- **Location**: `${params.outdir}/reports/timeline.html`
- **Description**: Interactive timeline visualization showing:
  - Process execution timeline
  - Parallel execution patterns
  - Resource utilization over time

### 4. **Pipeline DAG**
- **Location**: `${params.outdir}/reports/pipeline_dag.html`
- **Description**: Directed Acyclic Graph visualization showing:
  - Workflow structure
  - Process dependencies
  - Channel flow

### 5. **Execution Trace**
- **Location**: `${params.outdir}/reports/execution_trace.txt`
- **Description**: Tab-delimited text file with detailed task execution metrics

## 🔧 Configuration

Reports are automatically enabled in `nextflow.config`:

```groovy
// Enable Nextflow execution reports
report {
    enabled = true
    overwrite = true
    file = "${params.outdir}/reports/execution_report.html"
}

timeline {
    enabled = true
    overwrite = true
    file = "${params.outdir}/reports/timeline.html"
}

dag {
    enabled = true
    overwrite = true
    file = "${params.outdir}/reports/pipeline_dag.html"
}

trace {
    enabled = true
    overwrite = true
    file = "${params.outdir}/reports/execution_trace.txt"
}
```

## 📁 Report Structure

After a successful run, your output directory will contain:

```
results/
├── multiqc/
│   ├── {patient_id}multiqc_report.html  ← Main aggregated report
│   ├── {patient_id}multiqc_report_data/
│   └── {patient_id}multiqc_report_plots/ (optional)
├── reports/
│   ├── execution_report.html             ← Nextflow execution metrics
│   ├── timeline.html                     ← Execution timeline
│   ├── pipeline_dag.html                 ← Pipeline structure
│   └── execution_trace.txt               ← Detailed trace
├── pipeline_info/
│   └── pipeline_stats_mqc.yaml           ← MultiQC input data
├── vcf_to_csv/
│   └── *.csv                             ← Annotated variant tables
└── clean_vcf/
    └── *.vcf.gz                          ← Clean VCF files
```

## 🚀 Viewing Reports in Seqera Platform

### In the Platform UI:

1. **Navigate to your workflow run**
2. **Click on the "Reports" tab** at the top of the run details page
3. **Available reports will be listed:**
   - Execution Report
   - Timeline
   - DAG
   - MultiQC Report (if published to correct location)

### Report Publishing Requirements:

For reports to appear in Seqera Platform, ensure:

1. ✅ **Reports are published to S3/cloud storage** (when running on cloud):
   ```bash
   nextflow run main.nf \
       --patient_id 'PID_123_' \
       --samplesheet 'samplesheet.csv' \
       --transcript_counts 'transcript_counts.tsv' \
       --outdir 's3://my-bucket/results'  # Use S3 path for cloud runs
   ```

2. ✅ **Output directory is accessible** from Seqera Platform
3. ✅ **Pipeline completes successfully** (reports are generated at completion)

## 🧪 Testing Reports Locally

To test report generation locally:

```bash
# Run with test profile
nextflow run main.nf -profile test,docker --outdir results

# View generated reports
open results/multiqc/*multiqc_report.html
open results/reports/execution_report.html
open results/reports/timeline.html
open results/reports/pipeline_dag.html
```

## 📝 Customizing MultiQC

MultiQC configuration is in `assets/multiqc_config.yml`. You can customize:

- Report title and description
- Module display order
- Custom data sections
- Plot configurations

Example customization:

```yaml
report_comment: >
  Custom report description here

report_header_info:
  - Pipeline: 'VCF Expression Annotator'
  - Version: '1.0.0'
  - Contact: 'your.email@example.com'

custom_data:
  # Add custom statistics sections here
```

## 🐛 Troubleshooting

### Reports not appearing in Platform?

**Check 1**: Verify output directory is cloud storage
```bash
# BAD - local path on cloud
--outdir 'results'

# GOOD - S3 path
--outdir 's3://my-bucket/results'
```

**Check 2**: Ensure pipeline completed successfully
- Failed pipelines may not generate complete reports
- Check the run status in Seqera Platform

**Check 3**: Verify file permissions
- Ensure the S3 bucket is accessible
- Check IAM roles and permissions

### MultiQC report is empty?

**Check 1**: Verify modules are producing output
```bash
ls -la results/vcf_to_csv/
ls -la results/pipeline_info/
```

**Check 2**: Check MultiQC logs
```bash
cat .nextflow.log | grep -i multiqc
```

**Check 3**: Verify input files exist
- MultiQC needs input files to aggregate
- Check that upstream processes completed successfully

## 📚 Additional Resources

- [Nextflow Reports Documentation](https://www.nextflow.io/docs/latest/tracing.html)
- [MultiQC Documentation](https://multiqc.info/)
- [Seqera Platform Reports Guide](https://docs.seqera.io/platform/latest/reports)

## 🎯 Summary

Reports are now fully configured and will automatically:
1. ✅ Generate execution metrics (report, timeline, DAG, trace)
2. ✅ Aggregate pipeline outputs with MultiQC
3. ✅ Publish to the output directory
4. ✅ Render in Seqera Platform after successful completion

No additional configuration is needed - just run the pipeline normally!
