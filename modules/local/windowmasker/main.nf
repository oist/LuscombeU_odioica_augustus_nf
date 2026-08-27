process WINDOWMASKER_MASK {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0d/0d740f724375ad694bf4dce496aa7a419ffc67e12329bfb513935aafca5b28e9/data'
        : 'community.wave.seqera.io/library/bedtools_blast_samtools_tantan:73b553483a4b3a4e'}"

    input:
    tuple val(meta), path(ref)

    output:
    tuple val(meta), path("*.txt")          , emit: counts
    tuple val(meta), path("*.masked.fa.gz") , emit: masked_fa
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args     ?: ""
    def prefix  = task.ext.prefix   ?: "${meta.id}"

    """
    windowmasker -mk_counts \\
        $args \\
        -mem ${(task.memory.toMega()).intValue()} \\
        -in ${ref} \\
        -out ${prefix}.txt

    windowmasker -ustat \\
        ${prefix}.txt \\
        $args \\
        -outfmt fasta \\
        -in ${ref} \\
        -out ${prefix}.masked.fa

    bgzip --threads $task.cpus --compress-level 9 ${prefix}.masked.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        windowmasker: \$(windowmasker -version-full | head -n 1 | sed 's/^.*windowmasker: //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix  = task.ext.prefix   ?: "${meta.id}"

    """
    touch ${prefix}.masked.fa
    gzip --no-name ${prefix}.masked.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        windowmasker: \$(windowmasker -version-full | head -n 1 | sed 's/^.*windowmasker: //; s/ .*\$//')
    END_VERSIONS
    """
}
