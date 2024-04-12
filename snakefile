# Download the genome (fasta) and gtf files from the Ensembl ftp site (https://ftp.ensembl.org/pub/) 
# For assembly GRch38, works for release >= 47
# For assembly GRch37, works for release >= 83 (homo_sapiens only)
# Builds genome indices for various mapping tools
# Convert gtf to refflat and bed format
# To do: option to only download files (fasta and/or annotation)
# To do: option to only build indices for one or all tools (with or without downloading files)


import os
import subprocess
from os.path import exists, abspath
import requests
from bs4 import BeautifulSoup
import shutil


#### Colors for the print
# ANSI color escape codes
RED_START = "\033[91m"
GREEN_START = "\033[92m"
BLUE_START = "\033[94m"
COLOR_END = "\033[0m"  # Reset color to default


configfile: "config.yaml"

#########################################
# Parameters from the config and checks #
#########################################

# resources base path ############
RESOURCES_LOCAL_PATH = config["resources_local_path"] # config.get('RESOURCES_LOCAL_PATH', '.')
if not exists(RESOURCES_LOCAL_PATH):
    raise WorkflowError("Could not find the resources directory '" + RESOURCES_LOCAL_PATH + "' specified via 'RESOURCES_LOCAL_PATH'!")
RESOURCES_LOCAL_PATH = "."
RESOURCES_LOCAL_PATH.rstrip(os.sep)
RESOURCES_LOCAL_PATH = abspath(RESOURCES_LOCAL_PATH)


# assembly ############
ALL_ASSEMBLIES = ['grch37', 'grch38']
ASSEMBLY = config["genome"]["assembly"] # config.get('assembly', '')

if not ASSEMBLY:
    raise WorkflowError("Please provide the assembly via 'assembly' in the config.yaml!")

if ASSEMBLY not in ALL_ASSEMBLIES:
    terminal_width = shutil.get_terminal_size().columns
    assembly_per_line = terminal_width // max(len(assembly) for assembly in ALL_ASSEMBLIES)
    print(f"\n\nAvailable assemblies:")
    for i in range(0, len(ALL_ASSEMBLIES), assembly_per_line):
        assembly = "  ".join(ALL_ASSEMBLIES[i:i+assembly_per_line])
        colored_assembly = f"{GREEN_START}{assembly}{COLOR_END}"
        print(colored_assembly)
    raise ValueError(f"The provided assembly '{ASSEMBLY}' is not available in Ensembl")

if ASSEMBLY == 'grch38':
    ASSEMBLYPATH = ''
else:
    ASSEMBLYPATH = 'grch37'


# release ############
response = requests.get(f"https://ftp.ensembl.org/pub/{ASSEMBLYPATH}/")
soup = BeautifulSoup(response.content, "html.parser")
ALL_RELEASES = [link.text.strip("/") for link in soup.find_all("a") if "release" in link.text]

RELEASE = config["genome"]["release"] # config.get('release','')
if not RELEASE:
    raise WorkflowError("Please provide the release via 'release' in the config.yaml!")

if RELEASE not in ALL_RELEASES:
    terminal_width = shutil.get_terminal_size().columns
    release_per_line = terminal_width // max(len(release) for release in ALL_RELEASES)
    print(f"\n\nAvailable release for assembly '{ASSEMBLY}':")
    for i in range(0, len(ALL_RELEASES), release_per_line):
        release = "  ".join(ALL_RELEASES[i:i+release_per_line])
        colored_release = f"{BLUE_START}{release}{COLOR_END}"
        print(colored_release)
    raise ValueError(f"The provided release '{RELEASE}' is not available in Ensembl.")


# species ############
response = requests.get(f"https://ftp.ensembl.org/pub/{ASSEMBLYPATH}/{RELEASE}/fasta/")
soup = BeautifulSoup(response.content, "html.parser")
ALL_SPECIES = [link.text.strip("/") for link in soup.find_all("a") if "/" in link.text and link.text.endswith("/")]

SPECIES = config["genome"]["species"] # config.get('species', '')
if not SPECIES:
    raise WorkflowError("Please provide the species via 'species' in the config.yaml!")

if SPECIES not in ALL_SPECIES:
    terminal_width = shutil.get_terminal_size().columns
    species_per_line = terminal_width // max(len(species) for species in ALL_SPECIES)
    print(f"\n\nAvailable species for assembly '{ASSEMBLY}' and release '{RELEASE}':")
    for i in range(0, len(ALL_SPECIES), species_per_line):
        species = "   ".join(ALL_SPECIES[i:i+species_per_line])
        colored_species = f"{RED_START}{species}{COLOR_END}"
        print(colored_species)
    raise ValueError(f"The provided species '{SPECIES}' is not available in Ensembl.")


# seq type ###########
SEQTYPE = config["genome"]["seq_type"]
if not SEQTYPE:
    raise WorkflowError("Please provide the seq type via 'seq_type' in the config.yaml!")


# get fasta files ###########
response = requests.get(f"https://ftp.ensembl.org/pub/{ASSEMBLYPATH}/{RELEASE}/fasta/{SPECIES}/{SEQTYPE}/")
soup = BeautifulSoup(response.content, "html.parser")
ALL_FILES = list([link['href'] for link in soup.find_all('a') if link.get('href') and not link['href'].endswith('/')])

# patterns fasta file ########
fasta_patterns_include = config["genome"]["fasta"]["file_patterns_include"]
fasta_patterns_exclude = config["genome"]["fasta"]["file_patterns_exclude"]

fasta_to_keep = re.compile('|'.join(fasta_patterns_include))
fasta_to_remove = re.compile('|'.join(fasta_patterns_exclude))

fasta_download = [s for s in ALL_FILES if re.search(fasta_to_keep, s)]
fasta_download = [s for s in fasta_download if not re.search(fasta_to_remove, s)]


# get anno files ###########
response = requests.get(f"https://ftp.ensembl.org/pub/{ASSEMBLYPATH}/{RELEASE}/gtf/{SPECIES}/")
soup = BeautifulSoup(response.content, "html.parser")
ALL_FILES_ANNO = list([link['href'] for link in soup.find_all('a') if link.get('href') and not link['href'].endswith('/')])

# patterns anno file ########
anno_patterns_include = config["genome"]["annotation"]["file_patterns_include"]
anno_patterns_exclude = config["genome"]["annotation"]["file_patterns_exclude"]

anno_to_keep = re.compile('|'.join(anno_patterns_include))
anno_to_remove = re.compile('|'.join(anno_patterns_exclude))

anno_download = [s for s in ALL_FILES_ANNO if re.search(anno_to_keep, s)]
anno_download = [s for s in anno_download if not re.search(anno_to_remove, s)]

print("\n\n" + ASSEMBLY + " " + RELEASE + " " + SPECIES + " " + SEQTYPE)
print(fasta_download)
print(anno_download)

#################
##### Rules #####
#################

rule all:
    input:
        expand(os.path.join(RESOURCES_LOCAL_PATH, SPECIES, ASSEMBLY, RELEASE, SEQTYPE, "{file}"), file = fasta_download), 
        expand(os.path.join(RESOURCES_LOCAL_PATH, SPECIES, ASSEMBLY, RELEASE, "annotation", "{file}"), file = anno_download)


rule download_genome:
    output:
        expand(os.path.join(RESOURCES_LOCAL_PATH, SPECIES, ASSEMBLY, RELEASE, SEQTYPE, "{file}"), file = fasta_download)
    run:
        if config["genome"]["fasta"]["download"]:
            print("\n\nI will now try to download the fasta file(s) and if already mentioned, CHECKSUMS...\n\n")
            for file in fasta_download:
                shell(
                    """
                    echo {file}
                    curl -L https://ftp.ensembl.org/pub/{ASSEMBLYPATH}/{RELEASE}/fasta/{SPECIES}/{SEQTYPE}/{file} --output {RESOURCES_LOCAL_PATH}/{SPECIES}/{ASSEMBLY}/{RELEASE}/{SEQTYPE}/{file}
                    """
                )
        else:
            print("Skipping download_genome rule.")


rule download_annotation:
    output:
        expand(os.path.join(RESOURCES_LOCAL_PATH, SPECIES, ASSEMBLY, RELEASE, "annotation", "{file}"), file = anno_download)
    run:
        if config["genome"]["annotation"]["download"]:
            print("\n\nI will now try to download the annotation file(s) and if already mentioned, CHECKSUMS...\n\n")
            for file in anno_download:
                shell(
                    """
                    echo {file}
                    curl -L https://ftp.ensembl.org/pub/{ASSEMBLY}/{RELEASE}/gtf/{SPECIES}/{file} --output {RESOURCES_LOCAL_PATH}/{SPECIES}/{ASSEMBLY}/{RELEASE}/annotation/{file}
                    """
                )
        else:
            print("Skipping download_genome rule.")


rule gtf_to_bed:
    input:
        expand(os.path.join(RESOURCES_LOCAL_PATH, SPECIES, ASSEMBLY, RELEASE, "annotation", "{file}"), file = anno_download
    output:
        expand(os.path.join(RESOURCES_LOCAL_PATH, SPECIES, ASSEMBLY, RELEASE, "annotation", "{file}"), file = anno_download
    run:
        shell(
            """
            gtf2bed input > output
            """
        )
