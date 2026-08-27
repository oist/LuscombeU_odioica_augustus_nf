/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: AUGUSTUS_PREDICTION
    Aligns transcripts to a genome, builds intron hints, runs AUGUSTUS gene prediction,
    and exports protein/CDS sequences.

    Input:  [ meta(id, species), genome, trans ]
    Output: gff3    – [ meta, genome, augustus.gff3 ]
            proteins – [ meta, *.aa ]           (optional)
            codingseq – [ meta, *.codingseq ]   (optional)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GUNZIP_SAFE          } from '../../../modules/local/gunzip_safe/main'
include { MINIMAP2_ALIGN_SORT } from '../../../modules/local/minimap2_align_sort/main'
include { SAMTOOLS_INDEX       } from '../../../modules/local/samtools_index/main'
include { BAM2HINTS            } from '../../../modules/local/bam2hints/main'
include { AUGUSTUS             } from '../../../modules/local/augustus/main'
include { GETANNOFASTA         } from '../../../modules/local/getannofasta/main'

workflow AUGUSTUS_PREDICTION {

    take:
    ch_input // channel: [ val(meta), path(genome), path(trans) ]

    main:

    // 0. Decompress the genome. The soft-masked genome from REPEAT_MASKING is gzipped
    //    (*.fasta.gz). minimap2 accepts gzipped FASTA, but AUGUSTUS and getAnnoFasta.pl do
    //    NOT and fail with "Couldn't determine input file type / bad character". Decompress
    //    once up front and use the plain FASTA throughout the chain.
    GUNZIP_SAFE( ch_input.map { meta, genome, trans -> [ meta, genome ] } )

    // Recombine the plain-FASTA genome with the transcripts: [ meta, genome, trans ]
    ch_plain = GUNZIP_SAFE.out.gunzip
        .join( ch_input.map { meta, genome, trans -> [ meta, trans ] } )
        .map { meta, genome, trans -> [ meta, genome, trans ] }

    // 1. Align transcripts and sort
    MINIMAP2_ALIGN_SORT(ch_plain)

    // 2. Index BAM
    SAMTOOLS_INDEX(MINIMAP2_ALIGN_SORT.out.bam)

    // 3. Build intron hints
    BAM2HINTS(SAMTOOLS_INDEX.out.bam_bai)

    // 4. Run AUGUSTUS
    AUGUSTUS(BAM2HINTS.out.hints)

    // 5. Export proteins and CDS
    GETANNOFASTA(AUGUSTUS.out.gff3)

    emit:
    gff3      = GETANNOFASTA.out.gff3      // [ meta, genome, gff3 ]
    proteins  = GETANNOFASTA.out.proteins  // [ meta, *.aa ]
    codingseq = GETANNOFASTA.out.codingseq // [ meta, *.codingseq ]
}
