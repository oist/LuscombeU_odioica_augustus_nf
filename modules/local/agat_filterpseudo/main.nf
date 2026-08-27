process AGAT_FILTERPSEUDO {
    tag "${meta.id}"
    label 'process_low'

    container "quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0"

    input:
    tuple val(meta), path(genome), path(gff)

    output:
    tuple val(meta), path(genome), path("${meta.id}.filter_incomplete.flag_premature_stop.filter_pseudo.gff3"), emit: gff3
    tuple val("${task.process}"), val('agat'), eval("agat_sp_filter_feature_by_attribute_value.pl --version 2>&1 | sed -n 's/.*v\\\\([0-9.]*\\\\).*/\\\\1/p'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Remove transcripts flagged with the 'pseudo' attribute (premature stop codons).
    #
    # agat_sp_flag_premature_stop_codons.pl tags every affected mRNA (level2) with
    # 'pseudo=<premature-stop-positions>' (always a non-empty numeric value) and, only when
    # ALL isoforms of a gene are pseudo, tags the gene (level1) with 'pseudo=yes'.
    #
    # We target level2 (mRNA) with test "!" against an empty value: any mRNA that HAS the
    # 'pseudo' tag holds a non-empty value, so "<value> ne ''" is true and the mRNA is
    # discarded. mRNAs WITHOUT the tag are kept. Removing all isoforms of a gene removes the
    # gene automatically, so good isoforms are preserved while pseudo ones are dropped.
    agat_sp_filter_feature_by_attribute_value.pl \\
        --gff "${gff}" \\
        --attribute pseudo \\
        --type level2 \\
        --value "" \\
        --test "!" \\
        --output "${meta.id}.filter_incomplete.flag_premature_stop.filter_pseudo.gff3" \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agat: \$(agat_sp_filter_feature_by_attribute_value.pl --version 2>&1 | sed -n 's/.*v\\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.filter_incomplete.flag_premature_stop.filter_pseudo.gff3
    touch versions.yml
    """
}
