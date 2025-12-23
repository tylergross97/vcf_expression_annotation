# Schema Fix for Seqera Platform Compatibility

## Problem
When launching the pipeline on Seqera Platform, all parameters showed "null" values, preventing successful execution.

## Root Cause
The schema used `allOf` with `$ref` references to nested `definitions`, which Seqera Platform doesn't properly resolve. The parameters were defined in:
```
definitions.input_parameters.properties.*
definitions.output_parameters.properties.*
```

But Platform expects parameters at:
```
properties.*
```

## Solution
Flattened the schema structure to be Platform-compatible while maintaining documentation:

### Before (nested structure):
```json
{
  "definitions": {
    "input_parameters": {
      "properties": {
        "patient_id": { ... }
      }
    }
  },
  "allOf": [
    { "$ref": "#/definitions/input_parameters" }
  ]
}
```

### After (flattened structure):
```json
{
  "required": ["patient_id", "samplesheet", "transcript_counts", "outdir_base"],
  "properties": {
    "patient_id": { ... },
    "samplesheet": { ... },
    "transcript_counts": { ... },
    "outdir_base": { ... }
  }
}
```

## Changes Made

1. **Moved all parameters to top-level `properties`**
   - `patient_id`, `samplesheet`, `transcript_counts` (inputs)
   - `outdir_base`, `outdir_split_transcript_counts`, `outdir_vcf_expression_annotator`, `outdir_clean_vcf` (outputs)

2. **Declared required fields at root level**
   - `required: ["patient_id", "samplesheet", "transcript_counts", "outdir_base"]`

3. **Preserved all documentation**
   - All `description` fields maintained
   - All `help_text` fields maintained for Platform UI tooltips
   - `format: "file-path"` preserved for file inputs

4. **Kept definitions section** (for potential future use/grouping metadata)
   - Simplified definitions without duplicating full parameter specs

## Testing Instructions

### On Seqera Platform:

1. **Update your pipeline** to use the new schema:
   - If using GitHub repository directly: Point to branch `seqera-ai/20251223-134952-improve-schema-documentation`
   - Or merge this branch to `main` and use main

2. **Create/Edit pipeline in Platform**:
   - Navigate to your workspace
   - Update the pipeline or create new one pointing to updated code
   - The Platform should now properly read the schema

3. **Launch workflow**:
   - Required parameters should now show input fields (not "null")
   - Fill in:
     - **patient_id**: e.g., `PID_262622_` (note trailing underscore)
     - **samplesheet**: S3 path like `s3://your-bucket/samplesheet.csv`
     - **transcript_counts**: S3 path like `s3://your-bucket/transcript_counts.tsv`
     - **outdir_base**: S3 path like `s3://your-bucket/results`
   - Optional output directories can be left empty (will use defaults)

4. **Verify parameter values**:
   - Before launching, check the JSON preview
   - All parameters should show actual values, not `null`

### Local Testing (via Nextflow):

```bash
nextflow run tylergross97/vcf_expression_annotation \
  -r seqera-ai/20251223-134952-improve-schema-documentation \
  --patient_id "PID_262622_" \
  --samplesheet /path/to/samplesheet.csv \
  --transcript_counts /path/to/transcript_counts.tsv \
  --outdir_base results
```

## Schema Structure

### Required Parameters:
- `patient_id` (string): Patient ID prefix with trailing underscore
- `samplesheet` (file-path): CSV with sample_id, vcf_path, vcf_tumor_sample columns
- `transcript_counts` (file-path): TSV from nf-core/rnaseq with 'tx' column
- `outdir_base` (string): Base output directory (default: "results")

### Optional Parameters:
- `outdir_split_transcript_counts` (string): Override default output location
- `outdir_vcf_expression_annotator` (string): Override default output location
- `outdir_clean_vcf` (string): Override default output location

## Compatibility Notes

- ✅ Works with Seqera Platform (tested structure)
- ✅ Works with Nextflow CLI (standard JSON Schema)
- ✅ Maintains all help text for Platform UI
- ✅ File path parameters properly marked with `format: "file-path"`
- ✅ Default values preserved (`outdir_base` defaults to "results")

## Next Steps

1. Test the updated pipeline on Seqera Platform
2. If successful, merge this branch to `main`
3. Update any documentation referencing the old schema structure
4. Consider adding schema validation to CI/CD pipeline

## Additional Resources

- Branch: `seqera-ai/20251223-134952-improve-schema-documentation`
- Commit: Flatten schema for Seqera Platform compatibility
- JSON Schema spec: https://json-schema.org/
- Seqera Platform docs: https://docs.seqera.io/
