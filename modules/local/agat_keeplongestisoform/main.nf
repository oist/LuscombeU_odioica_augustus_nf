process AGAT_KEEPLONGESTISOFORM {
    tag "${meta.id}"
    label 'process_low'

    container "quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0"

    input:
    tuple val(meta), path(genome), path(gff)

    output:
    tuple val(meta), path("${meta.id}.filter_incomplete.flag_premature_stop.longest_isoform.gff3"), emit: gff3
    tuple val("${task.process}"), val('agat'), eval("agat_sp_keep_longest_isoform.pl --version 2>&1 | sed -n 's/.*v\\\\([0-9.]*\\\\).*/\\\\1/p'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    agat_sp_keep_longest_isoform.pl \\
        --gff "${gff}" \\
        --out "${meta.id}.filter_incomplete.flag_premature_stop.longest_isoform.gff3" \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agat: \$(agat_sp_keep_longest_isoform.pl --version 2>&1 | sed -n 's/.*v\\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.filter_incomplete.flag_premature_stop.longest_isoform.gff3
    touch versions.yml
    """
}
