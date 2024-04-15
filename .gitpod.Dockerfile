FROM gitpod/workspace-full

USER gitpod

FROM python:3.9

# Install system dependencies
RUN apt-get update && apt-get install -y wget

# Install Python dependencies
RUN pip install beautifulsoup4

# Install Snakemake
RUN git clone --recursive https://github.com/snakemake/snakemake.git && \
    cd snakemake && \
    pip install .

# Install BEDOPS
RUN wget https://github.com/bedops/bedops/releases/download/v2.4.39/bedops_linux_x86_64-v2.4.39.tar.bz2 && \
    tar -xjf bedops_linux_x86_64-v2.4.39.tar.bz2 && \
    cd bedops_linux_x86_64-v2.4.39 && \
    cp bin/* /usr/local/bin/ && \
    cd .. && \
    rm -rf bedops_linux_x86_64-v2.4.39*
