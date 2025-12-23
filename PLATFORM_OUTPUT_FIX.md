# Fix: Outputs Not Publishing to S3 on Seqera Platform

## Problem

When running the pipeline with the `test` profile on Seqera Platform, outputs were being "published" to local container paths like:
```
/.nextflow/assets/tylergross97/vcf_expression_annotation/tests/results/
```

These paths are **inside the ephemeral container** and are **not accessible** after the workflow completes. The files were never uploaded to S3.

## Root Cause

The `test` profile in `nextflow.config` was setting output directories using `${projectDir}`:

```groovy
// OLD - WRONG for Platform
params {
    outdir_base = "${projectDir}/tests/results/"
    outdir_split_transcript_counts = "${projectDir}/tests/results/split_transcript_counts"
    // ... etc
}
```

On Seqera Platform:
- `${projectDir}` resolves to `/.nextflow/assets/tylergross97/vcf_expression_annotation`
- This is a **local path inside the container**
- Files published here are **lost when the container terminates**
- They never get uploaded to S3

## Solution

### For Users: Override `outdir_base` When Launching

When launching the pipeline on Seqera Platform with the `test` profile, **you MUST override `outdir_base`** with an S3 path:

#### Option 1: Via Platform UI
1. Navigate to your pipeline in Seqera Platform
2. Click "Launch"
3. In the parameters form, find `outdir_base`
4. Enter an S3 path: `s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test`
5. Launch the workflow

#### Option 2: Via Pipeline Configuration
Update your pipeline's default parameters to use S3:
1. Go to pipeline settings
2. Edit launch configuration
3. Set `outdir_base` to your S3 bucket path
4. Save changes

#### Option 3: Via params JSON
When launching with a params file:
```json
{
  "patient_id": "PID_262622_",
  "samplesheet": "/.nextflow/assets/tylergross97/vcf_expression_annotation/tests/samplesheet.csv",
  "transcript_counts": "/.nextflow/assets/tylergross97/vcf_expression_annotation/tests/data/salmon.merged.transcript_counts.tsv",
  "outdir_base": "s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test"
}
```

### For Developers: What Was Fixed

1. **Simplified test profile** (`nextflow.config`):
   ```groovy
   // NEW - Better for Platform
   test {
       params {
           patient_id = "PID_262622_"
           samplesheet = "${projectDir}/tests/samplesheet.csv"
           transcript_counts = "${projectDir}/tests/data/salmon.merged.transcript_counts.tsv"
           
           // Simple default - users override on Platform
           outdir_base = "${projectDir}/tests/results"
       }
   }
   ```

2. **Added runtime warning** (`main.nf`):
   ```groovy
   // Warn if using test profile on cloud with local output paths
   if (workflow.profile.contains('test') && 
       workflow.workDir.startsWith('s3://') && 
       params.outdir_base.startsWith(workflow.projectDir.toString())) {
       log.warn """
       ⚠️  WARNING: Using test profile on cloud with local output directory!
       ...
       """
   }
   ```

3. **Updated schema help text** (`nextflow_schema.json`):
   ```json
   "outdir_base": {
     "help_text": "⚠️ IMPORTANT: When running on Seqera Platform with test profile, 
                   you MUST override this with an S3 path..."
   }
   ```

## Why This Happens

Nextflow has two types of output locations:

### 1. Work Directory (`workDir`)
- Where task execution happens
- Automatically set by Platform to S3 (e.g., `s3://bucket/scratch/WORKFLOW_ID`)
- Temporary files, caching happens here
- ✅ Always on S3 when using Platform

### 2. Publish Directory (`publishDir`)
- Where final outputs are copied/linked
- Defined in process blocks: `publishDir params.outdir_*`
- **User must specify the location**
- ❌ Can be local paths if user sets them that way

The `test` profile was setting publish directories to local paths because it's designed for local testing. On Platform, these need to be S3 paths.

## Verification

After fixing, check where your outputs actually went:

### Expected Output Locations (with S3 override)
```
s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test/
├── split_transcript_counts/
│   ├── PID_262622_Sample1.tsv
│   ├── PID_262622_Sample2.tsv
│   └── ...
├── vcf_expression_annotator/
│   ├── PID_262622_Sample1.expression.vep.vcf
│   └── ...
└── clean_vcf/
    ├── PID_262622_Sample1.clean.vcf
    └── ...
```

### How to Check in Platform UI
1. Go to the completed workflow
2. Click on "Outputs" or "Reports" tab
3. You should see published files listed
4. Or browse your S3 bucket using Data Links

### How to Check via AWS CLI
```bash
aws s3 ls s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test/ --recursive
```

## Local Testing Still Works

The fix doesn't break local testing:

```bash
# Local testing - uses projectDir paths (works fine)
nextflow run . -profile test,docker

# Platform - MUST override outdir_base
nextflow run tylergross97/vcf_expression_annotation \
  -profile test,docker \
  --outdir_base s3://my-bucket/results
```

## Best Practices

### For Pipeline Developers
1. **Never hardcode local paths** in default configs when pipeline will run on cloud
2. **Use `${projectDir}` only for inputs** (test data), not outputs
3. **Document S3 requirements** clearly in schema help text
4. **Add runtime warnings** when detecting incompatible configurations
5. **Provide example S3 paths** in documentation

### For Pipeline Users on Platform
1. **Always check `outdir_base`** before launching
2. **Use S3 paths** when running on AWS
3. **Check the warning messages** in workflow logs
4. **Browse outputs** via Data Links or S3 directly
5. **Don't rely on test profile defaults** for production runs

## Common Mistakes

### ❌ Mistake 1: Using test profile without overriding outdir_base
```bash
# WRONG - outputs go to container local path
nextflow run pipeline -profile test
```

### ✅ Correct: Override outdir_base
```bash
# RIGHT - outputs go to S3
nextflow run pipeline -profile test --outdir_base s3://bucket/results
```

### ❌ Mistake 2: Thinking projectDir paths work on cloud
```json
// WRONG - this will publish to container
{
  "outdir_base": "${projectDir}/results"
}
```

### ✅ Correct: Use S3 paths explicitly
```json
// RIGHT - this publishes to S3
{
  "outdir_base": "s3://my-bucket/results"
}
```

### ❌ Mistake 3: Assuming outputs are in workDir
```
# WRONG - workDir is scratch space, not final outputs
s3://bucket/scratch/WORKFLOW_ID/
```

### ✅ Correct: Outputs are where you set publishDir
```
# RIGHT - outputs are where you specify in outdir_base
s3://bucket/results/
```

## Technical Details

### How publishDir Works

In the process modules:
```groovy
process SPLIT_TRANSCRIPT_COUNTS {
    publishDir params.outdir_split_transcript_counts, mode: 'copy'
    
    output:
    path "split_transcript_counts/*.tsv", emit: split_transcript_counts
    
    script:
    """
    # Creates files in task work directory
    mkdir -p split_transcript_counts
    ...
    """
}
```

Flow:
1. Task runs in `workDir` (S3 scratch space)
2. Files created in task work directory
3. Files **copied** to `publishDir` location
4. If `publishDir` is local (like `/.nextflow/assets/...`), copy happens inside container
5. Container terminates, local files are lost
6. If `publishDir` is S3, files are uploaded and persist

### Why Input Paths Can Be Local

Inputs using `${projectDir}` work because:
- Repository is cloned to `/.nextflow/assets/tylergross97/vcf_expression_annotation/`
- Test data is in repository at `tests/data/`
- Fusion/Wave makes these files accessible during execution
- ✅ Reading from `${projectDir}` works fine

But outputs:
- Must go somewhere accessible after execution
- Container filesystem is ephemeral
- ❌ Writing to `${projectDir}` means writing to container local filesystem

## Summary

**Problem**: Outputs published to container local paths, lost after execution

**Root Cause**: `test` profile used `${projectDir}` for `outdir_base`

**Solution**: Override `outdir_base` with S3 path when launching on Platform

**Key Lesson**: Local paths for outputs don't work on cloud - always use S3 paths

## Next Steps

1. ✅ Pipeline code updated with warnings and documentation
2. ✅ Schema updated with clear S3 requirement messaging
3. 🔲 Update your pipeline configuration on Seqera Platform to set default S3 path
4. 🔲 Test with new branch: `seqera-ai/20251223-134952-improve-schema-documentation`
5. 🔲 Verify outputs appear in S3 after successful run
6. 🔲 Merge to `main` after testing
