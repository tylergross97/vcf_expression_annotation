# VCF Expression Annotator

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![nf-test](https://img.shields.io/badge/tested%20with-nf--test-41AB5D.svg)](https://www.nf-test.com/)

> **Annotate VCF variants with transcript expression data for expression-aware variant prioritization**

Nextflow pipeline integrating RNA-seq expression from [nf-core/rnaseq](https://nf-co.re/rnaseq) with VEP-annotated variants from [nf-core/sarek](https://nf-co.re/sarek). Wraps [vcf-expression-annotator](https://github.com/griffithlab/VAtools) from Griffith Lab VAtools.

## Quick Start

```bash
# Test with example data
nextflow run main.nf -profile test,docker

# Run with your data
nextflow run main.nf -profile docker \
    --patient_id 'PID_262622_' \
    --samplesheet 'samplesheet.csv' \
    --transcript_counts 'salmon.merged.transcript_counts.tsv' \
    --outdir 'results'
```

**Requirements:** Nextflow ≥23.04.0, Docker or Singularity

## Input

### Samplesheet (`--samplesheet`)
CSV format:
```csv
sample_id,vcf_path,vcf_tumor_sample
SAMPLE_A,/data/vcfs/sample_A.vcf.gz,PATIENT001_tumor_SAMPLE_A
```

### Transcript Counts (`--transcript_counts`)
TSV from nf-core/rnaseq: `results/star_salmon/salmon.merged.transcript_counts.tsv`

### Parameters
| Parameter | Description | Required |
|-----------|-------------|----------|
| `--patient_id` | Patient identifier prefix (must end with `_`) | Yes |
| `--samplesheet` | Sample metadata CSV | Yes |
| `--transcript_counts` | Merged transcript counts TSV | Yes |
| `--outdir` | Output directory | Yes |

## Output

```
results/clean_vcf/
├── {sample_id}.clean.vcf    # VCF with TX expression field
└── {sample_id}.clean.csv    # CSV export
```

TX field format: `ENST00000456328:150.5|ENST00000450305:45.2`

## Testing

```bash
nf-test test . --profile test,docker --verbose
```

## Troubleshooting

- **`--patient_id` must end with `_`**
- **`sample_id` should NOT include patient_id prefix**
- **Verify VCF sample names:** `bcftools query -l file.vcf.gz`
- **Empty TX field:** Check transcript IDs match between VCF and counts file

## Citation

**This pipeline:**
> Gross, T. (2025). VCF Expression Annotator. https://github.com/tylergross97/vcf_expression_annotation

**VAtools:**
> Hundal, J., et al. (2020). pVACtools: A computational toolkit to identify and visualize cancer neoantigens. *Cancer Immunol Res*, 8(3), 409-420.

**Nextflow:**
> Di Tommaso, P., et al. (2017). Nextflow enables reproducible computational workflows. *Nat Biotechnol*, 35(4), 316-319.

## License

MIT License - Copyright (c) 2025 Tyler Gross
