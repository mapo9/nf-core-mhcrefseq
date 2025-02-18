//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_scientific_name_channel(it) }
        .set { species }

    emit:
    species                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_scientific_name_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id = row.sample
    
    def name_meta = []
    name_meta = [ meta, row.scientific_name ]

    return name_meta
}
