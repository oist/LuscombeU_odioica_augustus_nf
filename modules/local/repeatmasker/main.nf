process REPEATMODELER_MASKER {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6e/6e2bb42273744500ab4352da322f76f5a191390b91d9362845cc3d85e4085336/data'
        : 'community.wave.seqera.io/library/htslib_repeatmodeler:1dea9b8934adfaeb'}"

    input:
    tuple val(meta), path(fasta), path(ref)
    val(taxon)

    output:
    tuple val(meta), path("*.masked.fa.gz") , emit: fasta
    tuple val(meta), path("*.cat.gz")       , emit: cat
    tuple val(meta), path("*.gff")          , emit: gff
    tuple val(meta), path("*.html")         , emit: html
    tuple val(meta), path("*.tbl")          , emit: tbl
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args ?: ''
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def dfamarg = params.dfam ? "-libdir ${params.dfam}" : ""
    def libOrTaxon = taxon ? "-species ${taxon} ${dfamarg}" : "-lib $fasta"
    """
    RepeatMasker \\
        -xsmall -pa 3 -html -gff -a \\
        -$libOrTaxon \\
        $ref \\
        $args \\

    mv ${ref}.masked ${prefix}.masked.fa
    bgzip --threads $task.cpus --compress-level 9 ${prefix}.masked.fa
    mv ${ref}.out.gff     ${prefix}.out.gff
    mv ${ref}.out.html    ${prefix}.out.html
    mv ${ref}.align       ${prefix}.align
    mv ${ref}.tbl         ${prefix}.tbl
    if [ -e ${ref}.cat ] ; then  bgzip --threads $task.cpus --compress-level 9 ${ref}.cat ; fi
    mv ${ref}.cat.gz ${prefix}.cat.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmodeler: \$(RepeatModeler --version | sed 's/RepeatModeler version //')
    END_VERSIONS
    """

    stub:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fas

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatmodeler: \$(RepeatModeler --version | sed 's/RepeatModeler version //')
    END_VERSIONS
    """
}
