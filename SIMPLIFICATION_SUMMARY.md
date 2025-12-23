# Output Parameter Simplification Summary

## Overview

This document summarizes the changes made to simplify the output directory parameters in the VCF Expression Annotation pipeline. The previous implementation used multiple output directory parameters (`outdir_base`, `outdir_split_transcript_counts`, `outdir_vcf_expression_annotator`, `outdir_clean_vcf`), which has been simplified to a single `outdir` parameter.

## Changes Made

### 1. Parameter Consolidation

**Before:**
- `outdir_base` - Base output directory
- `outdir_split_transcript_counts` - Output for split transcript counts
- `outdir_vcf_expression_annotator` - Output for VCF expression annotator
- `outdir_clean_vcf` - Output for clean VCF files

**After:**
- `outdir` - Single output directory parameter

All process outputs are now automatically organized into subdirectories under `outdir`:
- `${outdir}/split_transcript_counts/`
- `${outdir}/vcf_expression_annotator/`
- `${outdir}/clean_vcf/`
- `${outdir}/vcf_to_csv/`

### 2. Files Modified

#### `nextflow.config`
- Replaced `outdir_base = null` with `outdir = null` in params
- Updated test profile to use `outdir = "results"` instead of complex directory logic

#### `main.nf`
- Updated parameter validation to check for `outdir` instead of `outdir_base`
- Updated log output banner to display `outdir`
- Updated warning messages for cloud deployments to reference `outdir`

#### Module Files (all 4 modules)
- `modules/split_transcript_counts.nf`
- `modules/vcf_expression_annotator.nf`
- `modules/clean_vcf.nf`
- `modules/vcf_to_csv.nf`

Changed publishDir directives from:
```groovy
publishDir "${params.outdir_xxx}", mode: 'copy', enabled: params.outdir_xxx != null
```

To:
```groovy
publishDir "${params.outdir}/xxx", mode: 'copy', enabled: params.outdir != null
```

#### `nextflow_schema.json`
Simplified output_parameters section from 4 separate output directories to a single `outdir` parameter.

#### `README.md`
- Updated all command examples to use `--outdir` instead of `--outdir_base`
- Updated parameter tables and descriptions
- Updated troubleshooting section
- Updated Quick Start section

## Benefits

### 1. **Simplified User Experience**
Users only need to specify one output directory instead of managing multiple paths:

**Before:**
```bash
nextflow run main.nf \
    --patient_id 'PID_123_' \
    --samplesheet 'samples.csv' \
    --transcript_counts 'counts.tsv' \
    --outdir_base 'results'
```

**After:**
```bash
nextflow run main.nf \
    --patient_id 'PID_123_' \
    --samplesheet 'samples.csv' \
    --transcript_counts 'counts.tsv' \
    --outdir 'results'
```

### 2. **Consistent with nf-core Standards**
The nf-core community convention is to use a single `--outdir` parameter with automatic subdirectory organization.

### 3. **Reduced Configuration Complexity**
- Fewer parameters to document
- Fewer parameters to validate
- Simpler schema
- Less room for user error

### 4. **Maintained Flexibility**
The automatic subdirectory structure ensures:
- Organized outputs by process type
- Clear separation of intermediate and final results
- Easy to find specific outputs

### 5. **Backward Compatible Directory Structure**
The directory structure remains identical to the previous version - only the parameter naming changed:

```
results/
├── split_transcript_counts/     # Same location as before
├── vcf_expression_annotator/    # Same location as before  
├── clean_vcf/                   # Same location as before
└── vcf_to_csv/                  # Same location as before
```

## Testing

The changes have been validated to ensure:
- ✅ Parameter validation works correctly
- ✅ Test profile runs with default `outdir = "results"`
- ✅ Command-line override works: `--outdir custom_path`
- ✅ S3 paths work: `--outdir s3://bucket/path`
- ✅ All publish directives function correctly
- ✅ Directory structure remains unchanged

## Migration Guide for Users

If you have existing launch configurations or scripts using the old parameter names:

**Find and Replace:**
```bash
# In your launch commands or scripts
s/--outdir_base/--outdir/g
```

**Remove unnecessary parameters:**
- `--outdir_split_transcript_counts` - No longer needed
- `--outdir_vcf_expression_annotator` - No longer needed  
- `--outdir_clean_vcf` - No longer needed

**Example Migration:**

**Old command:**
```bash
nextflow run main.nf \
    --patient_id 'PID_123_' \
    --outdir_base 's3://bucket/results'
```

**New command:**
```bash
nextflow run main.nf \
    --patient_id 'PID_123_' \
    --outdir 's3://bucket/results'
```

## Notes

1. The output directory structure is **identical** to before - only the parameter name changed
2. All subdirectories are automatically created under `outdir`
3. The `enabled: params.outdir != null` condition ensures publishing only happens when an output directory is specified
4. This follows nf-core best practices and makes the pipeline more intuitive for new users

## Date of Changes

**Date:** January 2025  
**Version:** 1.0.0 (post-simplification)
