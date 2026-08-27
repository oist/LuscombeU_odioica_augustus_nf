/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: GFF_SANITIZATION
    Sanitizes AUGUSTUS GFF3 files using three sequential AGAT steps:
      1. Filter out incomplete gene coding models
      2. Flag genes with premature stop codons
      3. Keep only the longest isoform per gene

    Input:  [ meta, genome, gff3 ]
    Output: gff3 – [ meta, *.longest_isoform.gff3 ]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { AGAT_FILTERINCOMPLETE    } from '../../../modules/local/agat_filterincomplete/main'
include { AGAT_FLAGPREMATURESTOP   } from '../../../modules/local/agat_flagprematurestop/main'
include { AGAT_KEEPLONGESTISOFORM  } from '../../../modules/local/agat_keeplongestisoform/main'

workflow GFF_SANITIZATION {

    take:
    ch_input // channel: [ val(meta), path(genome), path(gff3) ]

    main:

    // Step 1: filter incomplete gene coding models
    AGAT_FILTERINCOMPLETE(ch_input)

    // Step 2: flag premature stop codons
    AGAT_FLAGPREMATURESTOP(AGAT_FILTERINCOMPLETE.out.gff3)

    // Step 3: keep longest isoform only
    AGAT_KEEPLONGESTISOFORM(AGAT_FLAGPREMATURESTOP.out.gff3)

    emit:
    gff3 = AGAT_KEEPLONGESTISOFORM.out.gff3 // [ meta, *.longest_isoform.gff3 ]
}
