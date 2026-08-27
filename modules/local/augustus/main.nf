process AUGUSTUS {
    tag "${meta.id}"
    label 'process_high'

    // Uses environment module: augustus/3.3.3_oiko
    // Loaded via beforeScript in conf/modules.config
    // AUGUSTUS_CONFIG_PATH must be set by the environment module

    input:
    tuple val(meta), path(genome), path(hints)

    output:
    tuple val(meta), path(genome), path("${meta.id}.augustus.gff3"), emit: gff3
    tuple val("${task.process}"), val('augustus'), eval('augustus --version 2>&1 | grep "AUGUSTUS" | sed "s/.*AUGUSTUS version //"'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def cfg  = "\$AUGUSTUS_CONFIG_PATH/extrinsic/extrinsic.M.RM.E.W.cfg"
    """
    augustus \\
        --species="${meta.species}" \\
        --extrinsicCfgFile="${cfg}" \\
        --hintsfile="${hints}" \\
        --alternatives-from-evidence=true \\
        --maxtracks=3 \\
        --allow_hinted_splicesites=gaag,gcag,ggag,gtgc,gtaa \\
        --progress=true \\
        --softmasking=on \\
        --gff3=on \\
        ${args} \\
        "${genome}" \\
        > ${meta.id}.augustus.gff3

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        augustus: \$(augustus --version 2>&1 | grep "AUGUSTUS" | sed 's/.*AUGUSTUS version //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.augustus.gff3
    touch versions.yml
    """
}
