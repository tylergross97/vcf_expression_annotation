# 🚀 Quick Fix: Get Your Outputs to S3

## TL;DR

Your outputs aren't reaching S3 because the `test` profile sets `outdir_base` to a container local path. 

**Solution: Override `outdir_base` when launching on Platform.**

## Step-by-Step Fix

### On Seqera Platform UI:

1. **Go to your pipeline** in Seqera Platform workspace

2. **Click "Launch"**

3. **Find the `outdir_base` parameter** in the launch form

4. **Change it from:**
   ```
   ${projectDir}/tests/results
   ```
   
   **To your S3 bucket:**
   ```
   s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test
   ```

5. **Click "Launch"**

6. **Check outputs** after completion - they'll be in S3!

### Expected Result

After the workflow completes, your outputs will be at:

```
s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test/
├── split_transcript_counts/
│   └── PID_262622_*.tsv files
├── vcf_expression_annotator/
│   └── *.expression.vep.vcf files
└── clean_vcf/
    └── *.clean.vcf files
```

## Why This Happens

The `test` profile in the config uses local paths optimized for local testing:
- `${projectDir}` = `/.nextflow/assets/tylergross97/vcf_expression_annotation`
- This is **inside the container**
- Files published here are **lost when container terminates**

## Permanent Fix (Update Pipeline Config)

Instead of overriding every time, update your pipeline's default configuration:

1. Go to **Pipelines** in Platform
2. Find your pipeline
3. Click **Edit**
4. Under **Pipeline parameters**, set:
   ```
   outdir_base = s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_results
   ```
5. **Save**

Now future launches will use S3 by default!

## Verify It's Working

### Method 1: Check Platform UI
- Go to completed workflow
- Look for "Outputs" or browse Data Links
- You should see files listed with S3 paths

### Method 2: Check S3 Directly
```bash
aws s3 ls s3://seqera-compute-qhxat5t9e/vcf_expression_annotator_test/ --recursive
```

### Method 3: Look for the Warning
The pipeline now warns you if using local paths on cloud:
```
⚠️  WARNING: Using test profile on cloud with local output directory!
```

If you see this warning in logs, you need to override `outdir_base`!

## Updated Branch

The fix is on branch: **`seqera-ai/20251223-134952-improve-schema-documentation`**

This branch includes:
- ✅ Runtime warning when local paths detected on cloud
- ✅ Updated schema with clear S3 requirement messaging  
- ✅ Comprehensive documentation
- ✅ Simplified test profile

## Common Questions

**Q: Why do input paths work with `${projectDir}` but outputs don't?**

A: Inputs are **read** from the cloned repository (accessible during execution). Outputs are **written** to ephemeral container storage (lost after termination). Only S3 persists.

**Q: Can I use a different S3 bucket?**

A: Yes! Just use any S3 path you have access to:
```
s3://my-bucket/my-results/vcf-annotation/
```

**Q: What about the other output parameters?**

A: You only need to set `outdir_base`. The other output directories are automatically derived:
- `outdir_split_transcript_counts` → `${outdir_base}/split_transcript_counts`
- `outdir_vcf_expression_annotator` → `${outdir_base}/vcf_expression_annotator`  
- `outdir_clean_vcf` → `${outdir_base}/clean_vcf`

**Q: Does this break local testing?**

A: No! Local testing still works:
```bash
nextflow run . -profile test,docker
# Uses projectDir paths - works fine locally
```

**Q: Do I need to change anything in the code?**

A: No code changes needed on your end. Just override the parameter when launching on Platform.

## What We Fixed in the Code

1. **Added runtime warning** - alerts you if using local paths on cloud
2. **Updated schema help text** - explains S3 requirement clearly
3. **Simplified test profile** - removed redundant derived parameters
4. **Added comprehensive docs** - explains the issue and solutions

## Test the Fix

1. Launch pipeline on Platform with updated branch
2. Set `outdir_base` to S3 path
3. Watch for the warning (should NOT appear if using S3)
4. Verify outputs in S3 after completion
5. If successful, merge branch to `main`

## Summary

**The Issue:** 
Test profile → local `outdir_base` → outputs lost in container

**The Fix:** 
Override `outdir_base` → S3 path → outputs persist in S3

**Next Time:**
Update pipeline defaults → no manual override needed

---

Need more details? See **`PLATFORM_OUTPUT_FIX.md`** for the full technical explanation.
