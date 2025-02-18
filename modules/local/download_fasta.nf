process DOWNLOAD_FASTA {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/jq_curl_pip:91d57da22309fc07' :
        'community.wave.seqera.io/library/curl_jq_pip_jqed:73b009f6f31f8b6f' }"

    input:
    tuple val(meta), val(organism)

    output:
    tuple val(meta), path("${organism.replace(" ", "_")}/${organism.replace(" ", "_")}_*reference.fasta")  , emit: organism_fasta
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def out = "${organism}".replace(" ", "_")

    """
    download_fasta.sh \\
        -o "$organism" \\
        -p ${out}

    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$(curl --version | head -n 1 | sed 's/^curl //; s/ .*\$//')
    END_VERSIONS
    """
}
