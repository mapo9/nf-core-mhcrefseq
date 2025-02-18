process MERGE_FASTAS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/curl_pip_jq_jqed:afc2a1be44f51a65' :
        'community.wave.seqera.io/library/curl_jq_pip_jqed:73b009f6f31f8b6f' }"

    input:
    tuple val(meta), path(organism_fastas)

    output:
    tuple val(meta), path("${meta.id}_combined_ref.fasta")  , emit: combined_fasta
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def out = "${meta.id}"

    """
    cat $organism_fastas > ${out}_combined_ref.fasta 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$(curl --version | head -n 1 | sed 's/^curl //; s/ .*\$//')
    END_VERSIONS
    """
}
