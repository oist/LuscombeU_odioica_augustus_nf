process AGAT_EXTRACTSEQUENCES {
    tag "${meta.id}"
    label 'process_low'

    container "quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0"

    input:
    tuple val(meta), path(genome), path(gff)

    output:
    tuple val(meta), path("${task.ext.prefix ?: meta.id}.faa"), emit: proteins
    tuple val("${task.process}"), val('agat'), eval("agat_sp_extract_sequences.pl --version 2>&1 | sed -n 's/.*v\\\\([0-9.]*\\\\).*/\\\\1/p'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    agat_sp_extract_sequences.pl \\
        --gff "${gff}" \\
        --fasta "${genome}" \\
        --protein \\
        --output "${prefix}.faa" \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agat: \$(agat_sp_extract_sequences.pl --version 2>&1 | sed -n 's/.*v\\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.faa
    touch versions.yml
    """
}
