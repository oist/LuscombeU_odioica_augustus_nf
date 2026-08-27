/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: REPEAT_MASKING

    Soft-masks a genome by combining three repeat maskers and merging their masks:
      1. tantan            – simple/tandem repeat masking
      2. WindowMasker      – de-novo interspersed repeat masking
      3. RepeatModeler +   – de-novo repeat family discovery followed by
         RepeatMasker         RepeatMasker soft-masking (uses the RepeatModeler
                              library only, i.e. the default library workflow)

    The soft-masked regions from each tool are extracted as BED intervals
    (seqtk cutN), merged with bedtools, and applied to the original genome to
    produce a single soft-masked FASTA.

    Adapted from the LuscombeU/stlrepeatmask pipeline.

    Input:  [ meta, genome ]                      (genome may be gzipped)
    Output: masked_fa – [ meta, *_allmaskers.fasta.gz ]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GUNZIP_SAFE                as GUNZIP                     } from '../../../modules/local/gunzip_safe/main'

include { TANTAN                     as TANTAN_MASK                } from '../../../modules/local/tantan/main'
include { SEQTK_CUTN                 as TANTAN_BED                 } from '../../../modules/local/seqtk_cutn/main'

include { WINDOWMASKER_MASK                                        } from '../../../modules/local/windowmasker/main'
include { SEQTK_CUTN                 as WINDOWMASKER_BED           } from '../../../modules/local/seqtk_cutn/main'

include { REPEATMODELER_BUILDDATABASE                              } from '../../../modules/nf-core/repeatmodeler/builddatabase/main'
include { REPEATMODELER_REPEATMODELER                              } from '../../../modules/nf-core/repeatmodeler/repeatmodeler/main'
include { REPEATMODELER_MASKER       as REPEATMODELER_REPEATMASKER } from '../../../modules/local/repeatmasker/main'
include { SEQTK_CUTN                 as REPEATMODELER_BED          } from '../../../modules/local/seqtk_cutn/main'

include { MERGE_MASKS                as MERGEDMASKS_ALL            } from '../../../modules/local/mergemasks/main'

workflow REPEAT_MASKING {

    take:
    ch_genome // channel: [ val(meta), path(genome) ]  (genome may be gzipped)

    main:

    ch_versions = channel.empty()

    // Decompress (or pass through) the genome so downstream tools get plain FASTA
    GUNZIP ( ch_genome )
    input_genomes = GUNZIP.out.gunzip
    ch_versions   = ch_versions.mix( GUNZIP.out.versions.first() )

    //
    // 1. Simple tandem repeat masking with tantan
    //
    TANTAN_MASK ( input_genomes.map { meta, ref -> [ [ id: "${meta.id}_tantan", key: meta.id ], ref ] } )
    TANTAN_BED  ( TANTAN_MASK.out.masked_fa )
    ch_versions = ch_versions.mix( TANTAN_MASK.out.versions.first() )

    //
    // 2. De-novo repeat detection with WindowMasker
    //
    WINDOWMASKER_MASK ( input_genomes.map { meta, ref -> [ [ id: "${meta.id}_windowmasker", key: meta.id ], ref ] } )
    WINDOWMASKER_BED  ( WINDOWMASKER_MASK.out.masked_fa )
    ch_versions = ch_versions.mix( WINDOWMASKER_MASK.out.versions.first() )

    //
    // 3. De-novo repeat discovery (RepeatModeler) + masking (RepeatMasker)
    //    Uses the RepeatModeler-derived library only (default library workflow).
    //
    REPEATMODELER_BUILDDATABASE ( input_genomes )
    REPEATMODELER_REPEATMODELER ( REPEATMODELER_BUILDDATABASE.out.db )
    REPEATMODELER_REPEATMASKER  (
        REPEATMODELER_REPEATMODELER.out.fasta
            .join( input_genomes )
            .map { meta, fasta, ref -> [ [ id: "${meta.id}_REPM", key: meta.id ], fasta, ref ] },
        []
    )
    REPEATMODELER_BED ( REPEATMODELER_REPEATMASKER.out.fasta )
    ch_versions = ch_versions.mix( REPEATMODELER_REPEATMODELER.out.versions.first() )

    // Re-key every channel on the *plain* sample id string so join() matches reliably.
    //
    // NOTE: join() matches on the whole first tuple element. input_genomes carries the full
    // meta map (e.g. [ id, species ]) from the samplesheet, while the masker BED outputs were
    // re-keyed to [ id: meta.key ] only. Those maps are not equal ([id,species] != [id]), so a
    // meta-map join silently produces nothing and the whole downstream pipeline is skipped.
    // Keying on the plain id string avoids that; we re-attach the full genome meta afterwards.
    genome_keyed            = input_genomes.map               { meta, ref -> [ meta.id,  meta, ref ] }
    tantan_bed_keyed        = TANTAN_BED.out.bed_gz.map        { meta, bed -> [ meta.key, bed ] }
    windowmasker_bed_keyed  = WINDOWMASKER_BED.out.bed_gz.map  { meta, bed -> [ meta.key, bed ] }
    repeatmodeler_bed_keyed = REPEATMODELER_BED.out.bed_gz.map { meta, bed -> [ meta.key, bed ] }

    //
    // Merge all three masks and apply them to the original genome. Reconstruct
    // [ meta, genome, tantan, windowmasker, repeatmasker ] with the FULL genome meta
    // (preserving 'species', which AUGUSTUS needs downstream).
    //
    ch_merge_input = genome_keyed
        .join( tantan_bed_keyed        )
        .join( windowmasker_bed_keyed  )
        .join( repeatmodeler_bed_keyed )
        .map { id, meta, ref, tantan, windowmasker, repeatmasker ->
            [ meta, ref, tantan, windowmasker, repeatmasker ]
        }

    MERGEDMASKS_ALL ( ch_merge_input )
    ch_versions = ch_versions.mix( MERGEDMASKS_ALL.out.versions.first() )

    emit:
    masked_fa = MERGEDMASKS_ALL.out.fasta // channel: [ meta, *_allmaskers.fasta.gz ]
    versions  = ch_versions               // channel: [ path(versions.yml) ]
}
