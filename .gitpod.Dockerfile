FROM gitpod/workspace-full

USER gitpod

RUN sudo apt-get update && \
    sudo apt-get install -y python python3-pip bedops && \
    sudo python3 -m pip install --upgrade pip && \
    sudo pip install beautifulsoup4

RUN conda install -n base -c conda-forge mamba && \
    /opt/conda/envs/mamba/bin/mamba create -c conda-forge -c bioconda -n snakemake snakemake
