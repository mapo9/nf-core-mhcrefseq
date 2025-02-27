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

# find list of reference proteomes associated to species
PROTEOMES=$(curl -s "https://rest.uniprot.org/proteomes/search?query=taxonomy_name:$ORGANISM+AND+proteome_type:reference&format=list")

# iterate over species-proteomes in list
for SPECIES_PROTEOME in $PROTEOMES; do
    # download proteome and save
    curl "https://rest.uniprot.org/uniprotkb/stream?compressed=false&format=fasta&query=(proteome:$SPECIES_PROTEOME)" -o ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta

    # Check if related species FASTA file is non-empty
    if [[ -s ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta ]]; then
        echo "Successfully downloaded FASTA for $ORGANISM_NAME: ${ORGANISM_NAME}_${RELATED_ORGANISM}_reference.fasta"
        break
    fi
done

# if proteomes is empty search in genus
if [ -z "$PROTEOMES" ]; then
    echo "No reference proteomes found for $ORGANISM. Trying genus level search..."
    GENUS=$(echo "$ORGANISM" | awk -F'+' '{print $1}')
    echo $GENUS
    PROTEOMES=$(curl -s "https://rest.uniprot.org/proteomes/search?query=taxonomy_name:$GENUS+AND+proteome_type:reference&format=list")

    for GENUS_SPECIES_PROTEOME in $PROTEOMES; do
        echo $GENUS_SPECIES_PROTEOME
        curl "https://rest.uniprot.org/uniprotkb/stream?compressed=false&format=fasta&query=(proteome:$GENUS_SPECIES_PROTEOME)" -o ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta

        # Check if related species FASTA file is non-empty
        if [[ -s ${OUT_PATH}/${ORGANISM_NAME}_reference.fasta ]]; then
            echo "Successfully downloaded FASTA for $ORGANISM_NAME: ${ORGANISM_NAME}_${RELATED_ORGANISM}_reference.fasta"
            break
        fi
    done
fi

echo "\n"
if [ -n "$GENUS_SPECIES_PROTEOME" ]; then
    echo "$ORGANISM_NAME $GENUS_SPECIES_PROTEOME" >> "${OUT_PATH}/failed_proteomes.txt"
fi