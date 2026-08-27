/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
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
    // SUBWORKFLOW: Predict genes with AUGUSTUS (minimap2 → bam2hints → augustus → getAnnoFasta)
    //
    AUGUSTUS_PREDICTION(ch_samplesheet)

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
