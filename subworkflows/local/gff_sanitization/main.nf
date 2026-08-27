/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: GFF_SANITIZATION
    Sanitizes AUGUSTUS GFF3 files to retain only protein-coding genes with a proper ORF
    (start + stop codon, no premature stop), then emits two clean, minimal GFF3 files:

      1. AGAT_FILTERINCOMPLETE   – remove gene models missing a start and/or stop codon
      2. AGAT_FLAGPREMATURESTOP  – flag mRNAs/genes with premature stop codons ('pseudo')
      3. AGAT_FILTERPSEUDO       – remove the flagged (pseudo) transcripts/genes
      4a. GFF_FORMAT_ALL         – format all remaining proper-ORF genes (all isoforms)
      4b. AGAT_KEEPLONGESTISOFORM + GFF_FORMAT_LONGEST – keep one isoform/gene, then format

    Input:  [ meta, genome, gff3 ]
    Output: gff3            – [ meta, ID.gff3 ]                 (all proper-ORF isoforms)
            longest_isoform – [ meta, ID_longest_isoform.gff3 ] (one isoform per gene)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { AGAT_FILTERINCOMPLETE    } from '../../../modules/local/agat_filterincomplete/main'
include { AGAT_FLAGPREMATURESTOP   } from '../../../modules/local/agat_flagprematurestop/main'
include { AGAT_FILTERPSEUDO        } from '../../../modules/local/agat_filterpseudo/main'
include { AGAT_KEEPLONGESTISOFORM  } from '../../../modules/local/agat_keeplongestisoform/main'
include { GFF_FORMAT as GFF_FORMAT_ALL     } from '../../../modules/local/gff_format/main'
include { GFF_FORMAT as GFF_FORMAT_LONGEST } from '../../../modules/local/gff_format/main'

workflow GFF_SANITIZATION {

    take:
    ch_input // channel: [ val(meta), path(genome), path(gff3) ]

    main:

    // Step 1: filter incomplete gene coding models (must have start + stop codon)
    AGAT_FILTERINCOMPLETE(ch_input)

    // Step 2: flag mRNAs/genes containing premature stop codons ('pseudo' attribute)
    AGAT_FLAGPREMATURESTOP(AGAT_FILTERINCOMPLETE.out.gff3)

    // Step 3: remove the flagged (pseudo) transcripts/genes
    AGAT_FILTERPSEUDO(AGAT_FLAGPREMATURESTOP.out.gff3)

    // Branch A: format ALL remaining proper-ORF genes (all isoforms) -> ID.gff3
    // GFF_FORMAT only needs [ meta, gff3 ], so drop the genome from the tuple.
    def ch_all = AGAT_FILTERPSEUDO.out.gff3.map { meta, genome, gff -> [ meta, gff ] }
    GFF_FORMAT_ALL(ch_all)

    // Branch B: keep only the longest isoform per gene, then format -> ID_longest_isoform.gff3
    AGAT_KEEPLONGESTISOFORM(AGAT_FILTERPSEUDO.out.gff3)
    GFF_FORMAT_LONGEST(AGAT_KEEPLONGESTISOFORM.out.gff3)

    emit:
    gff3            = GFF_FORMAT_ALL.out.gff3     // [ meta, ID.gff3 ]
    longest_isoform = GFF_FORMAT_LONGEST.out.gff3 // [ meta, ID_longest_isoform.gff3 ]
}
