# 🔧 Publishing Fix - Complete Technical Explanation

## Problem Summary

**Issue**: Files were not being published to S3 when running the workflow on Seqera Platform, even though the workflow succeeded.

**Root Cause**: Timing mismatch between when `publishDir` directives evaluate and when output directory parameters are derived.

---

## Technical Deep Dive

### How Nextflow Evaluates publishDir

Nextflow processes these elements in this order:

```
1. Parse nextflow.config
2. Load main.nf script
3. Evaluate script-level code (includes, parameter derivation)
4. Parse process definitions and their directives (including publishDir)
5. Execute workflow block
```

### The Original (Broken) Code

**In `main.nf` (BEFORE fix)**:
```groovy
workflow {
    // ❌ Parameter derivation happens here (step 5 above)
    if (params.outdir_base) {
        params.outdir_clean_vcf = "${params.outdir_base}/clean_vcf"
    }
    
    // Process invocations...
}
```

**In `modules/clean_vcf.nf`**:
```groovy
process CLEAN_VCF {
    // ⚠️ This evaluates at step 4 above
    // At this point, params.outdir_clean_vcf is still null!
    publishDir params.outdir_clean_vcf, mode: 'copy', enabled: params.outdir_clean_vcf != null
    
    // Process code...
}
```

**Timeline of What Happened**:
1. **Step 4**: Process definitions parsed → `publishDir` evaluates `params.outdir_clean_vcf` → **finds null** → disables publishing
2. **Step 5**: Workflow runs → parameters get derived → but too late! publishDir already disabled
3. **Result**: Files generated but not published ❌

---

## The Fix

**In `main.nf` (AFTER fix)**:
```groovy
#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// ✅ Parameter derivation happens HERE (step 3 above)
// BEFORE process definitions are parsed!
if (params.outdir_base && !params.outdir_split_transcript_counts) {
    params.outdir_split_transcript_counts = "${params.outdir_base}/split_transcript_counts"
}
if (params.outdir_base && !params.outdir_vcf_expression_annotator) {
    params.outdir_vcf_expression_annotator = "${params.outdir_base}/vcf_expression_annotator"
}
if (params.outdir_base && !params.outdir_clean_vcf) {
    params.outdir_clean_vcf = "${params.outdir_base}/clean_vcf"
}
if (params.outdir_base && !params.outdir_vcf_to_csv) {
    params.outdir_vcf_to_csv = "${params.outdir_base}/vcf_to_csv"
}

// Debug logging to verify parameters
log.info """
================================================================================
Output Directory Configuration:
================================================================================
outdir_base:                      ${params.outdir_base}
outdir_split_transcript_counts:   ${params.outdir_split_transcript_counts}
outdir_vcf_expression_annotator:  ${params.outdir_vcf_expression_annotator}
outdir_clean_vcf:                 ${params.outdir_clean_vcf}
outdir_vcf_to_csv:                ${params.outdir_vcf_to_csv}
================================================================================
""".stripIndent()

// NOW include the modules (step 3 continued)
include { SPLIT_TRANSCRIPT_COUNTS } from './modules/split_transcript_counts.nf'
include { VCF_EXPRESSION_ANNOTATOR } from './modules/vcf_expression_annotator.nf'
include { CLEAN_VCF } from './modules/clean_vcf.nf'
include { VCF_TO_CSV } from './modules/vcf_to_csv.nf'

workflow {
    // ✅ Parameters already derived above!
    // Process invocations...
}
```

**New Timeline**:
1. **Step 3**: Script-level code runs → parameters derived from `outdir_base`
2. **Step 4**: Process definitions parsed → `publishDir` evaluates `params.outdir_clean_vcf` → **finds valid S3 path** → enables publishing ✅
3. **Step 5**: Workflow runs → files are published to S3 ✅

---

## Additional Fixes

### 1. Added Missing Parameter
```groovy
// Added to nextflow.config
params {
    outdir_vcf_to_csv = null  // NEW: was missing!
}
```

### 2. Fixed VCF_TO_CSV publishDir
```groovy
// BEFORE (wrong parameter)
publishDir params.outdir_clean_vcf, mode: 'copy', enabled: params.outdir_clean_vcf != null

// AFTER (correct parameter)
publishDir params.outdir_vcf_to_csv, mode: 'copy', enabled: params.outdir_vcf_to_csv != null
```

---

## How to Verify the Fix

### On Seqera Platform

Run with parameter override:
```bash
--outdir_base s3://your-bucket/results
```

Check the logs for the parameter configuration output:
```
================================================================================
Output Directory Configuration:
================================================================================
outdir_base:                      s3://your-bucket/results
outdir_split_transcript_counts:   s3://your-bucket/results/split_transcript_counts
outdir_vcf_expression_annotator:  s3://your-bucket/results/vcf_expression_annotator
outdir_clean_vcf:                 s3://your-bucket/results/clean_vcf
outdir_vcf_to_csv:                s3://your-bucket/results/vcf_to_csv
================================================================================
```

Then verify files exist in S3:
```bash
aws s3 ls s3://your-bucket/results/vcf_to_csv/
# Should show: PID_*_neoantigen.csv files
```

### Local Testing

```bash
nextflow run main.nf -profile test --outdir_base /tmp/test_output
```

Check for output files:
```bash
ls /tmp/test_output/vcf_to_csv/
```

---

## Why This Pattern?

### Alternative Approaches Considered

#### ❌ Option 1: Config-time derivation
```groovy
// In nextflow.config
params {
    outdir_base = null
    // This DOESN'T work because params.outdir_base is null at config evaluation time
    outdir_clean_vcf = params.outdir_base ? "${params.outdir_base}/clean_vcf" : null
}
```
**Problem**: Profiles and command-line overrides apply AFTER config evaluation, so `params.outdir_base` is still null.

#### ❌ Option 2: Remove enabled check
```groovy
publishDir params.outdir_clean_vcf, mode: 'copy'
```
**Problem**: Causes errors when params are null (like in nf-test unit tests).

#### ✅ Option 3: Script-level derivation (CHOSEN)
```groovy
// At top of main.nf
if (params.outdir_base && !params.outdir_clean_vcf) {
    params.outdir_clean_vcf = "${params.outdir_base}/clean_vcf"
}
```
**Benefits**: 
- Runs after config/profile evaluation (params available)
- Runs before process definition parsing (publishDir sees values)
- Works with nf-test (conditional keeps enabled: false when null)

---

## Key Takeaways

1. **Script-level code runs before process definitions are parsed**
2. **publishDir directives evaluate during process parsing, not at runtime**
3. **Parameters must be derived at script-level for publishDir to see them**
4. **The `enabled:` parameter allows graceful handling of null paths**

---

## Commit History

- `dae76fd` - Merged PR #2 with conditional publishDir (partial fix)
- `555a21f` - Made publishDir conditional for nf-test compatibility
- `8524799` - Moved param derivation to workflow block (didn't work)
- `e7e4f7a` - **FINAL FIX**: Moved param derivation to script-level ✅

---

## Testing Checklist

- [x] Workflow succeeds on Platform
- [x] Parameters derived correctly (check logs)
- [x] Files published to S3 (verify with aws s3 ls)
- [ ] nf-test unit tests pass (if you have tests)
- [x] Local testing with --outdir_base override works

---

**Status**: ✅ **FIXED** - Files now publish to S3 correctly!
