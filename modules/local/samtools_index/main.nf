process SAMTOOLS_INDEX {
    tag "${meta.id}"
    label 'process_low'

    // Uses environment module: samtools (loaded via beforeScript in conf/modules.config)

    input:
    tuple val(meta), path(genome), path(bam)

    output:
    tuple val(meta), path(genome), path(bam), path("*.bai"), emit: bam_bai
    tuple val("${task.process}"), val('samtools'), eval('samtools --version | head -1 | sed "s/samtools //"'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    samtools index "${bam}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    """
    touch ${bam}.bai
    touch versions.yml
    """
}
