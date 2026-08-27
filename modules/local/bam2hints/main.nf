process BAM2HINTS {
    tag "${meta.id}"
    label 'process_low'

    // Uses environment module: augustus/3.3.3_oiko (bam2hints is part of augustus)
    // Loaded via beforeScript in conf/modules.config

    input:
    tuple val(meta), path(genome), path(bam), path(bai)

    output:
    tuple val(meta), path(genome), path("${meta.id}.hints.gff"), emit: hints
    tuple val("${task.process}"), val('augustus'), eval('augustus --version 2>&1 | grep "AUGUSTUS" | sed "s/.*AUGUSTUS version //"'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    bam2hints \\
        --in="${bam}" \\
        --out="${meta.id}.hints.gff" \\
        --intronsonly \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        augustus: \$(augustus --version 2>&1 | grep "AUGUSTUS" | sed 's/.*AUGUSTUS version //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.hints.gff
    touch versions.yml
    """
}
