#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -o <organism> -p <output_path>"
    exit 1
}

# Parse command line arguments
while getopts ":o:p:" opt; do
    case $opt in
        o) ORGANISM="$OPTARG"
        ;;
        p) OUT_PATH="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
            usage
        ;;
        :) echo "Option -$OPTARG requires an argument." >&2
            usage
        ;;
    esac
done

# Check if ORGANISM and OUT_PATH are set
if [ -z "$ORGANISM" ] || [ -z "$OUT_PATH" ]; then
    usage
fi

# Ensure output directory exists
mkdir -p "$OUT_PATH"

# Replace spaces with '+' for URL encoding
ORGANISM="${ORGANISM// /+}"
ORGANISM_NAME="${ORGANISM//+/_}"

taxonomy_id=$(curl -s "https://rest.uniprot.org/taxonomy/search?query=$ORGANISM_NAME" | jq -r '.results[0].taxonId')

# Download ref ids for this genus
curl "https://rest.uniprot.org/uniprotkb/stream?query=taxonomy_name:$ORGANISM&format=fasta" -o ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta

# Check if the downloaded FASTA file is empty
if [[ ! -s ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta ]]; then
    echo "FASTA file for $ORGANISM_NAME is empty. Trying closely related species..."

    # Query UniProt for related species by genus
    GENUS=$(echo "$ORGANISM" | awk -F'+' '{print $1}')  # Get genus name from the organism
    echo "GENUS $GENUS"
    RELATED_SPECIES=$(curl -s "https://rest.uniprot.org/proteomes/search?query=taxonomy_name:$GENUS+AND+proteome_type:reference&format=list")

    # Try downloading FASTA for related species
    for RELATED_ORGANISM in $RELATED_SPECIES; do
        echo "Attempting to download FASTA for closely related species: $RELATED_ORGANISM..."
        curl "https://rest.uniprot.org/uniprotkb/stream?compressed=false&format=fasta&query=(proteome:$RELATED_ORGANISM)" -o ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta

        # Check if related species FASTA file is non-empty
        if [[ -s ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta ]]; then
            echo "Successfully downloaded FASTA for $ORGANISM_NAME: ${ORGANISM_NAME}_${RELATED_ORGANISM}_reference.fasta"
            break
        fi
    done
else
    echo "Successfully downloaded FASTA for $ORGANISM: ${ORGANISM_NAME}_reference.fasta"
fi