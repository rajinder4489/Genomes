FROM gitpod/workspace-full

USER gitpod

RUN sudo apt-get update && \
    sudo apt-get install -y python3.8 python3-pip bedops && \
    sudo python3 -m pip install --upgrade pip && \
    sudo python3 -m pip install snakemake && \
    sudo python3 -m pip install beautifulsoup4
