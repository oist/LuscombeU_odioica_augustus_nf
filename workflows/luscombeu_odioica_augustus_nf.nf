/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { REPEAT_MASKING         } from '../subworkflows/local/repeat_masking/main'
include { AUGUSTUS_PREDICTION    } from '../subworkflows/local/augustus_prediction/main'
include { GFF_SANITIZATION       } from '../subworkflows/local/gff_sanitization/main'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow LUSCOMBEU_ODIOICA_AUGUSTUS_NF {

    take:
    ch_samplesheet // channel: [ meta(id,species), genome, trans ] read in from --input
    outdir

    main:

    def ch_versions = channel.empty()

    //
    // SUBWORKFLOW: Soft-mask repeats (tantan + WindowMasker + RepeatModeler/RepeatMasker)
    // Produces [ meta, *_allmaskers.fasta.gz ] which replaces the genome fed to AUGUSTUS.
    // Toggle with --mask (default: true).
    //
    def ch_for_augustus
    if (params.mask) {
        // Split samplesheet into genome (for masking) and transcripts (kept aside)
        def ch_genome = ch_samplesheet.map { meta, genome, trans -> [ meta, genome ] }
        def ch_trans  = ch_samplesheet.map { meta, genome, trans -> [ meta, trans ] }

        REPEAT_MASKING(ch_genome)
        ch_versions = ch_versions.mix(REPEAT_MASKING.out.versions)

        // Recombine the soft-masked genome with the transcripts: [ meta, masked_genome, trans ]
        ch_for_augustus = REPEAT_MASKING.out.masked_fa
            .join(ch_trans)
            .map { meta, masked_genome, trans -> [ meta, masked_genome, trans ] }
    } else {
        ch_for_augustus = ch_samplesheet
    }

    //
    // SUBWORKFLOW: Predict genes with AUGUSTUS (minimap2 → bam2hints → augustus → getAnnoFasta)
    //
    AUGUSTUS_PREDICTION(ch_for_augustus)

    //
    // SUBWORKFLOW: Sanitize GFF3 with AGAT (filter incomplete → flag premature stops → longest isoform)
    // AUGUSTUS_PREDICTION.out.gff3 already carries [ meta, genome, gff3 ]
    //
    GFF_SANITIZATION(AUGUSTUS_PREDICTION.out.gff3)

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'luscombeu_odioica_augustus_nf_software_versions.yml',
            sort: true,
            newLine: true
        )

    emit:
    final_gff3 = GFF_SANITIZATION.out.gff3  // channel: [ meta, *.longest_isoform.gff3 ]
    versions   = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
