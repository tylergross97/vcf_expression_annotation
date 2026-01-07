# VCF Expression Annotator

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![nf-test](https://img.shields.io/badge/tested%20with-nf--test-41AB5D.svg)](https://www.nf-test.com/)

> **Integrate transcript expression data into VEP-annotated VCF files for expression-aware variant analysis**

A Nextflow DSL2 pipeline that combines RNA-seq transcript expression data from [nf-core/rnaseq](https://nf-co.re/rnaseq) with VEP-annotated variants from [nf-core/sarek](https://nf-co.re/sarek). Prioritize functionally relevant mutations by annotating variants with transcript expression levels.

Provides production-ready Nextflow wrapper for [vcf-expression-annotator](https://github.com/griffithlab/VAtools) from the Griffith Lab VAtools suite.

## Features

- 🧬 Adds transcript expression values to VCF FORMAT fields
- ⚡ Parallel sample processing with automatic channel management
- 📦 Fully containerized (Docker/Singularity)
- 📊 Outputs VCF and CSV formats
- 🧪 Comprehensive nf-test suite

## Workflow

The pipeline processes samples in parallel:
1. **Split transcript counts** by sample
2. **Annotate VCF** with expression data (adds TX field)
3. **Clean and validate** VCF files
4. **Export to CSV** for downstream analysis

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

## Requirements

- Nextflow ≥23.04.0
- Docker or Singularity

## Usage

### Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `--patient_id` | Patient identifier prefix (must end with `_`) | Yes |
| `--samplesheet` | CSV with sample metadata and VCF paths | Yes |
| `--transcript_counts` | Merged transcript counts TSV from nf-core/rnaseq | Yes |
| `--outdir` | Output directory | Yes |

### Input Files

**Samplesheet** (`--samplesheet`): CSV with columns `sample_id`, `vcf_path`, `vcf_tumor_sample`
```csv
sample_id,vcf_path,vcf_tumor_sample
SAMPLE_A,/data/vcfs/sample_A.vcf.gz,PATIENT001_tumor_SAMPLE_A
```
- `sample_id`: Sample identifier (without patient_id prefix)
- `vcf_path`: Path to VEP-annotated VCF
- `vcf_tumor_sample`: Exact sample name from VCF header

**Transcript counts** (`--transcript_counts`): TSV from nf-core/rnaseq
```
results/star_salmon/salmon.merged.transcript_counts.tsv
```
Format: Tab-separated with Ensembl transcript IDs and sample expression values

## Output

```
results/
├── split_transcript_counts/     # Per-sample transcript counts
├── vcf_expression_annotator/    # Intermediate annotated VCFs
└── clean_vcf/                   # Final outputs
    ├── {sample_id}.clean.vcf    # VCF with TX field
    └── {sample_id}.clean.csv    # CSV export
```

The `TX` field contains transcript expression values:
```
ENST00000456328:150.5|ENST00000450305:45.2
```

## Testing

```bash
# Run tests
nf-test test . --profile test,docker --verbose

# Resume interrupted runs
nextflow run main.nf -profile docker ... -resume
```

## Troubleshooting

Common issues:
- **Missing underscore**: `--patient_id` must end with `_`
- **Sample mismatch**: `sample_id` in samplesheet should not include patient_id prefix
- **VCF sample name**: Use `bcftools query -l file.vcf.gz` to verify exact sample names
- **Empty TX field**: Check transcripts in VCF match transcript counts file

Debug with:
```bash
cat .nextflow.log | grep ERROR
nextflow run main.nf ... -with-trace -with-report
```

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test with `nf-test test . --profile test,docker`
4. Submit a pull request

Report issues at: https://github.com/tylergross97/vcf_expression_annotation/issues

## Citation

If you use this pipeline, please cite:

**This pipeline:**
> Gross, T. (2025). VCF Expression Annotator Nextflow Pipeline.  
> https://github.com/tylergross97/vcf_expression_annotation

**VAtools:**
> Hundal, J., et al. (2020). pVACtools: A computational toolkit to identify and visualize cancer neoantigens.  
> *Cancer Immunology Research*, 8(3), 409-420. https://doi.org/10.1158/2326-6066.CIR-19-0401

**Nextflow:**
> Di Tommaso, P., et al. (2017). Nextflow enables reproducible computational workflows.  
> *Nature Biotechnology*, 35(4), 316-319. https://doi.org/10.1038/nbt.3820

## License

MIT License - Copyright (c) 2025 Tyler Gross

---

**Maintainer:** Tyler Gross ([@tylergross97](https://github.com/tylergross97))  
**Issues:** https://github.com/tylergross97/vcf_expression_annotation/issues
