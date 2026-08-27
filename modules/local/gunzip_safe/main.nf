process GUNZIP_SAFE {

    // Derived from nf-core gunzip module, but also accepts non-compressed input.
    // Inspiration from SAMTOOLS_BGZIP.

    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0d/0d740f724375ad694bf4dce496aa7a419ffc67e12329bfb513935aafca5b28e9/data' :
        'community.wave.seqera.io/library/bedtools_blast_samtools_tantan:73b553483a4b3a4e' }"

    input:
    tuple val(meta), path(archive)

    output:
    tuple val(meta), path("$gunzip"), emit: gunzip
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"
    gunzip          = prefix + ".fasta"
    """
    FILE_TYPE=\$(htsfile $archive)
    case "\$FILE_TYPE" in
        *BGZF-compressed*|*gzip-compressed*)
            # Not calling gunzip itself because it creates files
            # with the original group ownership rather than the
            # default one for that user / the work directory
            gzip \\
                -cd \\
                $args \\
                $archive \\
                > $gunzip ;;
        *bzip2-compressed*)
            echo "bzip2 compression detected" ; exit 1 ;;
        *XZ-compressed*)
            echo "xz compression detected" ; exit 1 ;;
        *)
            # Do nothing or just rename if the file was already compressed
            [ "\$(basename $archive)" != "\$(basename ${gunzip})" ] && ln -s $archive ${gunzip} ;;
    esac

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """

    stub:
    def args        = task.ext.args ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"
    gunzip          = prefix + ".fasta"
    """
    touch $gunzip
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}
