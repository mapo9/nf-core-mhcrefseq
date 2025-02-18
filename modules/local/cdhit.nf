process CDHIT_CDHIT {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cd-hit%3A4.8.1--h5b5514e_7':
        'biocontainers/cd-hit:4.8.1--h5b5514e_7' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}/${meta.id}_combined_ref.clustered.fasta")    , emit: clustered_fasta
    tuple val(meta), path("${meta.id}/*.clstr")                                    , emit: clusters
    path "versions.yml"                                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def avail_mem = 3072
    if (!task.memory) {
        log.info '[cd-hit] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    mkdir ${prefix}
    
    cd-hit \\
        -i $fasta \\
        -o ${prefix}/${prefix}_combined_ref.clustered.fasta \\
        -c 1 \\
        -G 1 \\
        -aS 0.9 \\
        -n 5 \\
        -d 0 \\
        -M $avail_mem \\
        -T $task.cpus
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cdhit: \$(cd-hit -h | head -n 1 | sed 's/^.*====== CD-HIT version //;s/ (built on .*) ======//' )
    END_VERSIONS
    """
}