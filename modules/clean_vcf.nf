process CLEAN_VCF {
    container "community.wave.seqera.io/library/python:3.11.0--73cecb2a04197534"
    publishDir params.outdir_clean_vcf, mode: 'copy'

    input:
    tuple val(sample_id), val(tumor_sample), file(vcf_path)
    val patient_id

    output:
    tuple val(sample_id), val(tumor_sample), file("${patient_id}${sample_id}.clean.vcf.gz"), emit: clean_vcf

    script:
    """
    #!/usr/bin/env python3
    import sys
    import gzip
    import re

    def clean_position_field(pos_field):
        \"\"\"Ensure CDS/Protein positions are numeric (avoid '').\"\"\"
        if not pos_field or pos_field.strip() == "":
            return "1"  # fallback to avoid empty string

        # Handle ranges like ?-606/735 or 3107-?/3108
        if "?" in pos_field:
            # Keep denominator if available, else default
            if "/" in pos_field:
                num, denom = pos_field.split("/", 1)

                # clean numerator
                nums = re.findall(r"\\d+", num)
                num = nums[-1] if nums else "1"

                # clean denominator
                nums = re.findall(r"\\d+", denom)
                denom = nums[0] if nums else "1000"

                return f"{num}/{denom}"
            else:
                nums = re.findall(r"\\d+", pos_field)
                return nums[0] if nums else "1"

        # Already numeric/range
        return pos_field

    def clean_vcf_line(line):
        if line.startswith("#"):
            return line

        parts = line.strip().split("\\t")
        info_field = parts[7]

        # Match CSQ field (VEP annotation)
        csq_match = re.search(r"CSQ=([^;]*)", info_field)
        if not csq_match:
            return line + "\\n"

        csq_content = csq_match.group(1)
        annotations = csq_content.split(",")

        cleaned_annotations = []
        for annotation in annotations:
            fields = annotation.split("|")
            # VEP CSQ has CDS_position at index 13, Protein_position at index 14
            if len(fields) > 14:
                fields[13] = clean_position_field(fields[13])
                fields[14] = clean_position_field(fields[14])
            cleaned_annotations.append("|".join(fields))

        # Rebuild CSQ field
        new_csq = ",".join(cleaned_annotations)
        new_info = re.sub(r"CSQ=[^;]*", f"CSQ={new_csq}", info_field)
        parts[7] = new_info

        return "\\t".join(parts) + "\\n"

    def clean_vcf(input_file, output_file):
        opener = gzip.open if input_file.endswith(".gz") else open
        mode = "rt" if input_file.endswith(".gz") else "r"

        with opener(input_file, mode) as infile, gzip.open(output_file, "wt") as outfile:
            for line_num, line in enumerate(infile, 1):
                try:
                    cleaned_line = clean_vcf_line(line)
                    outfile.write(cleaned_line)
                except Exception as e:
                    print(f"Error processing line {line_num}: {e}", file=sys.stderr)
                    print(f"Problematic line: {line[:120]}...", file=sys.stderr)
                    continue  # skip problematic lines

        print(f"VCF cleaning completed. Output written to {output_file}", file=sys.stderr)

    # Run cleaner
    clean_vcf("${vcf_path}", "${patient_id}${sample_id}.clean.vcf.gz")
    """
}
