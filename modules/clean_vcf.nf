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
        \"\"\"Clean problematic position annotations (works for both CDS and Protein positions)\"\"\"
        if not pos_field or pos_field == "":
            return ""

        # Handle patterns like "?-606/735", "3107-?/3108", etc.
        if "?" in pos_field:
            # Try to extract meaningful numbers
            if "/" in pos_field:
                parts = pos_field.split("/")
                numerator = parts[0]
                denominator = parts[1]

                # Clean numerator
                if "?" in numerator:
                    if "-" in numerator:
                        # Handle "?-606" -> "606", "3107-?" -> "3107"
                        nums = re.findall(r"\\d+", numerator)
                        if nums:
                            numerator = nums[-1]  # Take the last number
                        else:
                            numerator = "1"  # Default fallback
                    else:
                        numerator = "1"  # Default fallback

                # Clean denominator
                if "?" in denominator:
                    nums = re.findall(r"\\d+", denominator)
                    if nums:
                        denominator = nums[0]  # Take the first number
                    else:
                        denominator = "1000"  # Default fallback

                return f"{numerator}/{denominator}"
            else:
                # Single value with ?
                nums = re.findall(r"\\d+", pos_field)
                if nums:
                    return nums[0]
                else:
                    return "1"

        return pos_field

    def clean_vcf_line(line):
        \"\"\"Clean a VCF line by fixing problematic CSQ annotations\"\"\"
        if not line.startswith("chr") or "CSQ=" not in line:
            return line

        # Split the line
        parts = line.strip().split("\\t")
        info_field = parts[7]

        # Extract and process CSQ field
        csq_match = re.search(r"CSQ=([^;]*)", info_field)
        if not csq_match:
            return line

        csq_content = csq_match.group(1)
        annotations = csq_content.split(",")

        cleaned_annotations = []
        for annotation in annotations:
            fields = annotation.split("|")
            if len(fields) >= 15:  # Make sure we have enough fields
                # Clean CDS_position field (index 13, 0-based)
                fields[13] = clean_position_field(fields[13])
                # Clean Protein_position field (index 14, 0-based) - THIS WAS MISSING!
                fields[14] = clean_position_field(fields[14])
            cleaned_annotations.append("|".join(fields))

        # Reconstruct the CSQ field
        new_csq = ",".join(cleaned_annotations)
        new_info = re.sub(r"CSQ=[^;]*", f"CSQ={new_csq}", info_field)
        parts[7] = new_info

        return "\\t".join(parts) + "\\n"

    def clean_vcf(input_file, output_file):
        \"\"\"Clean the entire VCF file\"\"\"
        opener = gzip.open if input_file.endswith(".gz") else open
        mode = "rt" if input_file.endswith(".gz") else "r"

        with opener(input_file, mode) as infile, gzip.open(output_file, "wt") as outfile:
            for line_num, line in enumerate(infile, 1):
                if line.startswith("#"):
                    outfile.write(line)
                else:
                    try:
                        cleaned_line = clean_vcf_line(line)
                        outfile.write(cleaned_line)
                    except Exception as e:
                        print(f"Error processing line {line_num}: {e}", file=sys.stderr)
                        print(f"Problematic line: {line[:100]}...", file=sys.stderr)
                        # Skip problematic lines
                        continue

        print(f"VCF cleaning completed. Output written to {output_file}", file=sys.stderr)

    # Main execution
    clean_vcf("${vcf_path}", "${patient_id}${sample_id}.clean.vcf.gz")
    """
}