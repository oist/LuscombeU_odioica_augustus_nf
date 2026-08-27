process MINIMAP2_ALIGN_SORT {
    tag "${meta.id}"
    label 'process_high'

    // Uses environment modules: minimap2, samtools (loaded via beforeScript in conf/modules.config)

    input:
    tuple val(meta), path(genome), path(trans)

    output:
    tuple val(meta), path(genome), path("${meta.id}.tr.bam"), emit: bam
    tuple val("${task.process}"), val('minimap2'), eval('minimap2 --version'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    minimap2 \\
        -t ${task.cpus} \\
        -ax splice -uf -k14 \\
        ${args} \\
        "${genome}" \\
        "${trans}" \\
    | samtools sort \\
        -@ ${task.cpus} \\
        -o ${meta.id}.tr.bam \\
        -

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version)
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.tr.bam
    touch versions.yml
    """
}
