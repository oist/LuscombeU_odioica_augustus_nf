process MERGE_MASKS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0d/0d740f724375ad694bf4dce496aa7a419ffc67e12329bfb513935aafca5b28e9/data' :
        'community.wave.seqera.io/library/bedtools_blast_samtools_tantan:73b553483a4b3a4e' }"

    input:
    tuple val(meta), path(genome), path(tantan), path(windowmasker), path(repeatmasker)

    output:
    tuple val(meta), path("*.fasta.gz")    , emit: fasta
    tuple val(meta), path("*.bed.gz")      , emit: bed_gz
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    zcat $tantan $windowmasker               | sort -k1,1 -k2,2n | bedtools merge | bgzip --threads $task.cpus --compress-level 9 > ${prefix}_tantan_windowmasker.bed.gz
    zcat $tantan $repeatmasker               | sort -k1,1 -k2,2n | bedtools merge | bgzip --threads $task.cpus --compress-level 9 > ${prefix}_tantan_repeatmasker.bed.gz
    zcat $windowmasker $repeatmasker         | sort -k1,1 -k2,2n | bedtools merge | bgzip --threads $task.cpus --compress-level 9 > ${prefix}_windowmasker_repeatmasker.bed.gz
    zcat $tantan $windowmasker $repeatmasker | sort -k1,1 -k2,2n | bedtools merge | bgzip --threads $task.cpus --compress-level 9 > ${prefix}_allmaskers.bed.gz

    bedtools \\
        maskfasta \\
        -soft \\
        -fi $genome \\
        -bed ${prefix}_allmaskers.bed.gz \\
        -fo /dev/stdout |
        bgzip --threads $task.cpus --compress-level 9 > ${prefix}_allmaskers.fasta.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
    END_VERSIONS
    """
}
