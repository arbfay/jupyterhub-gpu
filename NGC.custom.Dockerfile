FROM nvcr.io/nvidia/tensorflow:19.10-py3

LABEL org.opencontainers.image.title="AI Lab (Jupyterhub + Nvidia GPUs)" \
      org.opencontainers.image.description="A jupyterhub server with Nvidia GPUs attached and several kernels" \
      org.opencontainers.image.version="0.2.0" \
      org.opencontainers.image.source="github.com/arbfay/jupyterhub-gpu.git" \
      org.opencontainers.image.url="github.com/arbfay/jupyterhub-gpu" \
      org.opencontainers.image.created="2019-12-08T00:00Z" \
      org.opencontainers.image.authors="Fayçal Arbai <github.com/arbfay>" \
      org.opencontainers.image.licenses="MIT"

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    dh-make \
    fakeroot \
    build-essential \
    devscripts \
    nodejs \
    sudo \
    ca-certificates \
    run-one \
    bzip2 \
    gnupg \
    lsb-release \
    default-jre \
    default-jdk \
    libsasl2-dev \
    libsasl2-2 \
    libsasl2-modules-gssapi-mit \
    krb5-user \
    samba \
    sssd \
    chrony \
    cron \
    rsync && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /var/kerberos && \
    addgroup hubusers && \
    chgrp -R hubusers /var/kerberos && \
    chmod -R g+w /var/kerberos

## Jupyter, conda & other Python packages installation

ARG ANACONDA_VERSION=5.2.0
ENV ANACONDA_INSTALLER=Anaconda3-$ANACONDA_VERSION-Linux-x86_64.sh \
    CONDA_DIR=/opt/conda \
    SHELL=/bin/bash
ENV PATH=$CONDA_DIR/bin:$PATH

RUN wget https://repo.anaconda.com/archive/$ANACONDA_INSTALLER && \
    $SHELL $ANACONDA_INSTALLER -f -b -p $CONDA_DIR && \
    rm $ANACONDA_INSTALLER && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    conda clean --all -f -y

RUN conda install -y \
      configurable-http-proxy \
      jinja2 \
      requests \
      sqlalchemy \
      tornado  \
      traitlets \
      scikit-learn \
      xgboost \
      pyyaml \
      pytorch torchvision cudatoolkit=10.1 -c pytorch && \
      conda clean --all -f -y

# Adding RapidsAI
RUN conda install -c rapidsai -c nvidia -c conda-forge \
                  -c defaults rapids=0.10 python=3.6 cudatoolkit=10.1

RUN pip install --upgrade pip && \
    pip install --upgrade jupyterhub \
                jupyterhub-dummyauthenticator \
                jupyterhub-ldapauthenticator \
                oauthenticator \
                jupyterlab && \
    pip install --upgrade notebook

ARG PIP_PROFILE_FILE=jupyter/pip_profile_default.txt
COPY $PIP_PROFILE_FILE pip_profile.txt

RUN pip install -r pip_profile.txt

# Jupyterlab awesome extensions
RUN pip install jupyterlab_latex \
                jupyterlab-git \
                ipywidgets \
                dask_labextension

RUN jupyter labextension install @jupyterlab/latex \
                                 @jupyterlab/hub-extension \
                                 jupyterlab-chart-editor \
                                 jupyterlab-drawio \
                                 jupyterlab-spreadsheet \
                                 @jupyterlab/hdf5 \
                                 @jupyterlab/pdf-extension \
                                 @jupyterlab/geojson-extension \
                                 @yeebc/jupyterlab_neon_theme \
                                 dask-labextension

## Julia & IJulia Installation
ARG JULIA_VERSION=1.3.0
RUN wget https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_VERSION:0:3}/julia-$JULIA_VERSION-linux-x86_64.tar.gz && \
    tar -xvf julia-$JULIA_VERSION-linux-x86_64.tar.gz -C /etc && \
    ln -s /etc/julia-$JULIA_VERSION/bin/julia /usr/local/bin/julia && \
    rm -f julia-$JULIA_VERSION-linux-x86_64.tar.gz

COPY julia/ .
ARG JULIA_PROFILE_FILE=julia_profile_default.txt
RUN julia install_packages.jl $JULIA_PROFILE_FILE

## IJavascript & ITypeScript Installation
RUN npm install -g --unsafe-perm ijavascript && \
    ijsinstall --install=global
RUN npm install -g itypescript && \
    its --install=global


ENV JUPYTERHUB_CONFIG=jupyter/jupyterhub_config.py
CMD jupyterhub -f $JUPYTERHUB_CONFIG
