process GFF_FORMAT {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'quay.io/biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(gff)

    output:
    tuple val(meta), path("${task.ext.prefix ?: meta.id}.gff3"), emit: gff3
    tuple val("${task.process}"), val('gawk'), eval("awk --version 2>&1 | sed -n '1s/.*Awk \\\\([0-9.]*\\\\).*/\\\\1/p'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # -------------------------------------------------------------------------
    # Produce a clean, minimal GFF3:
    #   * header reduced to exactly two lines: '##gff-version 3' and '##date <today>'
    #   * keep only gene / transcript / exon / CDS features
    #     (mRNA is renamed to transcript to match AUGUSTUS conventions)
    #   * force the source column (col 2) to 'AUGUSTUS'
    # IDs/Parent attributes (col 9) are left untouched so the parent hierarchy is preserved.
    # -------------------------------------------------------------------------
    {
        echo "##gff-version 3"
        echo "##date \$(date +%F)"
    } > "${prefix}.gff3"

    awk 'BEGIN { FS = OFS = "\\t" }
        # skip comment / directive lines (we already wrote our own header)
        /^#/ { next }
        # only keep well-formed feature lines
        NF < 9 { next }
        {
            type = \$3
            if (type == "mRNA") { type = "transcript" }
            if (type == "gene" || type == "transcript" || type == "exon" || type == "CDS") {
                \$2 = "AUGUSTUS"
                \$3 = type
                print
            }
        }
    ' "${gff}" >> "${prefix}.gff3"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk --version 2>&1 | sed -n '1s/.*Awk \\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.gff3
    touch versions.yml
    """
}
