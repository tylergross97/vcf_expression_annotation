# Schema Structure: Before vs After

## Visual Comparison

### ❌ BEFORE (Incompatible with Seqera Platform)

```
Root
├── definitions
│   ├── input_parameters
│   │   ├── required: [...]
│   │   └── properties
│   │       ├── patient_id: {...}
│   │       ├── samplesheet: {...}
│   │       └── transcript_counts: {...}
│   └── output_parameters
│       ├── required: [...]
│       └── properties
│           ├── outdir_base: {...}
│           ├── outdir_split_transcript_counts: {...}
│           ├── outdir_vcf_expression_annotator: {...}
│           └── outdir_clean_vcf: {...}
└── allOf
    ├── $ref: "#/definitions/input_parameters"
    └── $ref: "#/definitions/output_parameters"
```

**Problem**: Seqera Platform doesn't resolve `$ref` references properly, so it can't find the parameters.

### ✅ AFTER (Platform Compatible)

```
Root
├── required: ["patient_id", "samplesheet", "transcript_counts", "outdir_base"]
├── properties
│   ├── patient_id: {type, description, help_text}
│   ├── samplesheet: {type, format, description, help_text}
│   ├── transcript_counts: {type, format, description, help_text}
│   ├── outdir_base: {type, description, help_text, default}
│   ├── outdir_split_transcript_counts: {type, description, help_text}
│   ├── outdir_vcf_expression_annotator: {type, description, help_text}
│   └── outdir_clean_vcf: {type, description, help_text}
└── definitions (kept for metadata/grouping)
    ├── input_parameters: {...}
    └── output_parameters: {...}
```

**Solution**: All parameters directly accessible at `properties`, Platform can read them immediately.

## Side-by-Side JSON Examples

### BEFORE - Nested Structure
```json
{
  "definitions": {
    "input_parameters": {
      "required": ["patient_id", "samplesheet", "transcript_counts"],
      "properties": {
        "patient_id": {
          "type": "string",
          "description": "Patient ID prefix...",
          "help_text": "Example: 'PID_262622_'..."
        }
      }
    }
  },
  "allOf": [
    { "$ref": "#/definitions/input_parameters" }
  ]
}
```
**Result on Platform**: `params.patient_id` → `null`

### AFTER - Flattened Structure
```json
{
  "required": ["patient_id", "samplesheet", "transcript_counts", "outdir_base"],
  "properties": {
    "patient_id": {
      "type": "string",
      "description": "Patient ID prefix...",
      "help_text": "Example: 'PID_262622_'..."
    }
  }
}
```
**Result on Platform**: `params.patient_id` → `"PID_262622_"` ✓

## What Was Preserved

✅ All `description` fields (shows in Platform UI)
✅ All `help_text` fields (tooltip on hover in Platform)
✅ All `format` declarations (`file-path` for file inputs)
✅ All `default` values (e.g., `outdir_base: "results"`)
✅ All `type` declarations
✅ Required field declarations (now at root level)

## What Changed

🔄 Parameters moved from `definitions.*.properties.*` → `properties.*`
🔄 Required arrays merged into single root-level `required: [...]`
🔄 Removed `allOf` and `$ref` indirection
🔄 Simplified `definitions` (kept for potential grouping UI, but not used for parameter resolution)

## Testing the Fix

### Check Schema is Loaded (Platform UI)
1. Go to your pipeline in Seqera Platform
2. Click "Launch"
3. You should see parameter input fields with:
   - Labels (from `description`)
   - Help tooltips (from `help_text`)
   - File browser buttons (for `format: "file-path"`)
   - NOT "null" values

### Check Schema via API
```bash
# If your pipeline has ID "abc123"
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.cloud.seqera.io/pipelines/abc123/schema
```

You should see `properties` at the root level with all parameters.

## Why This Happened

Seqera Platform uses a simplified JSON Schema parser that:
- ✅ Handles top-level `properties` well
- ✅ Handles `required` at root level
- ❌ Has limited `$ref` resolution capabilities
- ❌ Doesn't traverse complex `allOf` structures

This is a known limitation when using advanced JSON Schema features. The solution is to always flatten for Platform compatibility.

## Best Practices Going Forward

1. **Always put parameters at root `properties`**
2. **Use `definitions` only for documentation/grouping metadata**
3. **Avoid `allOf`, `anyOf`, `oneOf` at root level**
4. **Keep `$ref` usage minimal or eliminate it**
5. **Test schema changes on Platform before committing**

## Migration Path

If you have other pipelines with similar nested schemas:

1. Identify all parameter definitions in `definitions.*.properties`
2. Move them to root-level `properties`
3. Merge all `required` arrays into root-level `required`
4. Remove `allOf` / `$ref` indirection
5. Keep original `definitions` for documentation if desired
6. Test on Platform before merging

## Links

- Fixed schema: `nextflow_schema.json` on branch `seqera-ai/20251223-134952-improve-schema-documentation`
- Original issue: Parameters showing "null" on Seqera Platform
- Solution: Flatten schema structure for Platform compatibility
