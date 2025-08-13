process VCF_TO_CSV {
    container "community.wave.seqera.io/library/cyvcf2:0.31.1--709ec51e0c21a366"
    publishDir params.outdir_clean_vcf, mode: 'copy'

    input:
    tuple val(sample_id), val(tumor_sample), path(vcf_path)
    val patient_id

    output:
    tuple val(patient_id), val(sample_id), val(tumor_sample), file("${patient_id}${sample_id}_neoantigen.csv"), emit: csv

    script:
    """
    #!/usr/bin/env python3
    import sys
    import os
    import csv
    from cyvcf2 import VCF
    
    def vcf_to_csv(vcf_file, output_csv, tumor_sample):
        # Extract VEP CSQ fields from VCF header
        vep_fields = []
        vcf_reader = VCF(vcf_file)
        for line in vcf_reader.raw_header.splitlines():
            if line.startswith("##INFO=<ID=CSQ"):
                desc = line.split("Format: ")[-1].rstrip('\">')
                vep_fields = desc.split("|")
                break

        # Check tumor sample index
        if tumor_sample not in vcf_reader.samples:
            raise ValueError(
                f"Error: tumor sample '{tumor_sample}' not found in VCF samples: {vcf_reader.samples}"
            )
        sample_idx = vcf_reader.samples.index(tumor_sample)

        columns = [
            "CHROM",
            "POS",
            "REF",
            "ALT",
            "Filter",
            "Gene",
            "Transcript_ID",
            "HGVSp",
            "Consequence",
            "AF",
            "Expression",
            "gnomAD_AF",
        ]

        with open(output_csv, "w", newline="") as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=columns)
            writer.writeheader()

            for variant in vcf_reader:
                if not variant.ALT:
                    continue

                record = {
                    "CHROM": variant.CHROM,
                    "POS": variant.POS,
                    "REF": variant.REF,
                    "ALT": variant.ALT[0],
                    "Filter": variant.FILTER or "PASS",
                    "AF": None,
                    "Expression": None,
                    "Gene": None,
                    "Transcript_ID": None,
                    "HGVSp": None,
                    "Consequence": None,
                    "gnomAD_AF": None,
                }

                # Allele Frequency from FORMAT if present
                if "AF" in variant.FORMAT:
                    af_data = variant.format("AF")
                    if af_data is not None and len(af_data) > sample_idx:
                        af_value = af_data[sample_idx]
                        # af_value can be a float or an array with one element
                        if hasattr(af_value, "__iter__") and not isinstance(
                            af_value, (str, bytes)
                        ):
                            af_value = af_value[0]
                        record["AF"] = af_value

                # Parse TX expression field
                if "TX" in variant.FORMAT:
                    tx_array = variant.format("TX")
                    if tx_array is not None and len(tx_array) > sample_idx:
                        tx_value = tx_array[sample_idx]
                        if isinstance(tx_value, bytes):
                            tx_value = tx_value.decode("utf-8")
                        if tx_value and "|" in tx_value:
                            try:
                                transcript_id, expr = tx_value.split("|")
                                record["Transcript_ID"] = transcript_id
                                record["Expression"] = expr
                            except Exception:
                                pass

                # Parse VEP CSQ INFO field matching transcript ID
                csq_list = variant.INFO.get("CSQ")
                if csq_list:
                    for csq in csq_list.split(","):
                        csq_split = csq.split("|")
                        csq_dict = dict(zip(vep_fields, csq_split))
                        if csq_dict.get("Feature") == record["Transcript_ID"]:
                            record["Gene"] = csq_dict.get("SYMBOL")
                            record["HGVSp"] = csq_dict.get("HGVSp")
                            record["Consequence"] = csq_dict.get("Consequence")
                            record["gnomAD_AF"] = csq_dict.get(
                                "gnomADe_AF"
                            ) or csq_dict.get("gnomADg_AF")
                            break

                writer.writerow(record)

        print(f"✅ Saved: {output_csv}")

    # Main execution
    vcf_to_csv("${vcf_path}", "${patient_id}${sample_id}_neoantigen.csv", "${tumor_sample}")
    """
}