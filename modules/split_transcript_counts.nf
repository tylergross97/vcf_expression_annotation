process SPLIT_TRANSCRIPT_COUNTS {
    container "community.wave.seqera.io/library/pandas_python:4330fd07d14e9bfb"
    publishDir params.outdir_split_transcript_counts, mode: 'copy'

    input:
    path transcript_counts

    output:
    path "split_transcript_counts/*.tsv", emit: split_transcript_counts

    script:
    """
    mkdir -p split_transcript_counts
    python3 - <<EOF
    import pandas as pd
    import os

    df = pd.read_csv("${transcript_counts}", sep="\\t")
    sample_columns = df.columns[2:]
    for sample in sample_columns:
        sample_df = df[["tx", sample]].copy()
        sample_df.columns = ["tx", sample]
        output_path = os.path.join("split_transcript_counts", f"{sample}.tsv")
        sample_df.to_csv(output_path, sep="\\t", index=False)
        print(f"Saved: {output_path}")
    EOF
    """
}