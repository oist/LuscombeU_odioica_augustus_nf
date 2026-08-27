process GETANNOFASTA {
    tag "${meta.id}"
    label 'process_low'

    // Uses environment module: augustus/3.3.3_oiko (getAnnoFasta.pl is part of augustus)
    // Loaded via beforeScript in conf/modules.config

    input:
    tuple val(meta), path(genome), path(gff3)

    output:
    tuple val(meta), path(genome), path(gff3), emit: gff3
    tuple val(meta), path("*.aa"),             emit: proteins,  optional: true
    tuple val(meta), path("*.codingseq"),      emit: codingseq, optional: true
    tuple val("${task.process}"), val('augustus'), eval('augustus --version 2>&1 | grep "AUGUSTUS" | sed "s/.*AUGUSTUS version //"'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    getAnnoFasta.pl "${gff3}" --seqfile "${genome}" || true

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        augustus: \$(augustus --version 2>&1 | grep "AUGUSTUS" | sed 's/.*AUGUSTUS version //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.augustus.aa
    touch ${meta.id}.augustus.codingseq
    touch versions.yml
    """
}
