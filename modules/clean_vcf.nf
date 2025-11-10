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
        \"\"\"Ensure CDS/Protein positions are numeric (avoid empty strings).\"\"\"
        if not pos_field or pos_field.strip() == "" or pos_field == ".":
            return "1/1000"  # Return full format with default values

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
                num = nums[0] if nums else "1"
                return f"{num}/1000"

        # Handle positions without denominator
        if "/" not in pos_field:
            # Extract numeric part
            nums = re.findall(r"\\d+", pos_field)
            if nums:
                return f"{nums[0]}/1000"
            else:
                return "1/1000"

        # Already in numeric/range format
        parts = pos_field.split("/")
        if len(parts) == 2:
            # Validate both parts
            try:
                # Check if numerator part has numbers
                num_part = parts[0].split("-")[0] if "-" in parts[0] else parts[0]
                if not num_part or not re.search(r"\\d", num_part):
                    return "1/1000"
                
                # Check if denominator has numbers
                if not parts[1] or not re.search(r"\\d", parts[1]):
                    nums = re.findall(r"\\d+", num_part)
                    return f"{nums[0] if nums else '1'}/1000"
                    
                return pos_field
            except:
                return "1/1000"
        
        return "1/1000"

    def add_missing_format_headers(line, missing_formats):
        \"\"\"Add missing FORMAT field definitions to VCF header\"\"\"
        if line.startswith("##FORMAT="):
            return line
        elif line.startswith("#CHROM") and missing_formats:
            # Add missing FORMAT definitions before the column header line
            format_lines = []
            if "PS" in missing_formats:
                format_lines.append('##FORMAT=<ID=PS,Number=1,Type=Integer,Description="Phase set identifier">')
            if "PID" in missing_formats:
                format_lines.append('##FORMAT=<ID=PID,Number=1,Type=String,Description="Physical phasing ID information">')
            if "TX" in missing_formats:
                format_lines.append('##FORMAT=<ID=TX,Number=.,Type=String,Description="Transcript effect annotation">')
            if "GQ" in missing_formats:
                format_lines.append('##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Genotype Quality">')
            if "PL" in missing_formats:
                format_lines.append('##FORMAT=<ID=PL,Number=G,Type=Integer,Description="Phred-scaled genotype likelihoods">')
            if "PGT" in missing_formats:
                format_lines.append('##FORMAT=<ID=PGT,Number=1,Type=String,Description="Physical phasing haplotype information">')
            
            return "\\n".join(format_lines) + "\\n" + line
        return line

    def update_format_fields(line, format_fields_to_add):
        \"\"\"Add missing FORMAT fields to variant records\"\"\"
        if line.startswith("#") or not format_fields_to_add:
            return line

        parts = line.strip().split("\\t")
        if len(parts) < 9:  # Not a proper variant line
            return line + "\\n"

        # Get current FORMAT field (column 8)
        current_format = parts[8]
        
        # Check if we need to add any fields
        format_parts = current_format.split(":")
        
        # Add missing fields to FORMAT
        new_format_parts = format_parts[:]
        for field in format_fields_to_add:
            if field not in format_parts:
                new_format_parts.append(field)
        
        # If no changes needed, return original line
        if len(new_format_parts) == len(format_parts):
            return line + "\\n"
        
        # Update FORMAT column
        parts[8] = ":".join(new_format_parts)
        
        # Update all sample columns (9+) to include placeholder values
        for i in range(9, len(parts)):
            sample_values = parts[i].split(":")
            # Add placeholder values for new fields
            for field in format_fields_to_add:
                if field not in format_parts:
                    sample_values.append(".")
            parts[i] = ":".join(sample_values)

        return "\\t".join(parts) + "\\n"

    def clean_vcf_line(line):
        if line.startswith("#"):
            return line

        parts = line.strip().split("\\t")
        if len(parts) < 8:
            return line + "\\n"
            
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

        # First pass: check what FORMAT fields exist
        existing_formats = set()
        with opener(input_file, mode) as infile:
            for line in infile:
                if line.startswith("##FORMAT=<ID="):
                    format_id = re.search(r"ID=([^,>]+)", line)
                    if format_id:
                        existing_formats.add(format_id.group(1))
                elif line.startswith("#CHROM"):
                    break

        # Determine what FORMAT fields need to be added
        required_formats = {"PS", "PID", "TX", "GQ", "PL", "PGT"}
        missing_formats = required_formats - existing_formats
        
        print(f"Existing FORMAT fields: {existing_formats}", file=sys.stderr)
        print(f"Missing FORMAT fields to add: {missing_formats}", file=sys.stderr)

        # Second pass: clean and add missing fields
        with opener(input_file, mode) as infile, gzip.open(output_file, "wt") as outfile:
            for line_num, line in enumerate(infile, 1):
                try:
                    # First clean CSQ annotations
                    cleaned_line = clean_vcf_line(line)
                    
                    # Then handle FORMAT field additions
                    if line.startswith("##") or line.startswith("#CHROM"):
                        # Add missing FORMAT headers
                        final_line = add_missing_format_headers(cleaned_line.rstrip("\\n"), missing_formats)
                    else:
                        # Add missing FORMAT fields to variant records
                        final_line = update_format_fields(cleaned_line.rstrip("\\n"), list(missing_formats))
                    
                    outfile.write(final_line if final_line.endswith("\\n") else final_line + "\\n")
                    
                except Exception as e:
                    print(f"Error processing line {line_num}: {e}", file=sys.stderr)
                    print(f"Problematic line: {line[:120]}...", file=sys.stderr)
                    # Write original line to avoid data loss
                    outfile.write(line)
                    continue

        print(f"VCF cleaning completed.", file=sys.stderr)
        print(f"Added FORMAT fields: {missing_formats}", file=sys.stderr)
        print(f"Output written to {output_file}", file=sys.stderr)

    # Run cleaner
    clean_vcf("${vcf_path}", "${patient_id}${sample_id}.clean.vcf.gz")
    """
}
