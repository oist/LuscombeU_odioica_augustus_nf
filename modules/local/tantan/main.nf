process TANTAN {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0d/0d740f724375ad694bf4dce496aa7a419ffc67e12329bfb513935aafca5b28e9/data'
        : 'community.wave.seqera.io/library/bedtools_blast_samtools_tantan:73b553483a4b3a4e'}"

    input:
    tuple val(meta), path(ref)

    output:
    tuple val(meta), path("*.masked.fa.gz"), emit: masked_fa
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tantan ${ref} | bgzip --threads $task.cpus --compress-level 9 > ${prefix}.masked.fa.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tantan: \$(tantan --version |& sed '1!d ; s/tantan //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.masked.fa.gz
    gzip --no-name ${prefix}.masked.fa.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tantan: \$(tantan --version |& sed '1!d ; s/tantan //')
    END_VERSIONS
    """
}
