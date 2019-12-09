FROM nvcr.io/nvidia/pytorch:19.11-py3

LABEL org.opencontainers.image.title="AI Lab (Jupyterhub + Nvidia GPUs)" \
      org.opencontainers.image.description="A jupyterhub server with Nvidia GPUs attached and several kernels" \
      org.opencontainers.image.version="0.2.0" \
      org.opencontainers.image.source="github.com/arbfay/jupyterhub-gpu.git" \
      org.opencontainers.image.url="github.com/arbfay/jupyterhub-gpu" \
      org.opencontainers.image.created="2019-12-08T00:00Z" \
      org.opencontainers.image.authors="Fayçal Arbai <github.com/arbfay>" \
      org.opencontainers.image.licenses="MIT"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    dh-make \
    fakeroot \
    build-essential \
    devscripts \
    nodejs \
    default-jre \
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
    libsasl2-modules-gssapi-mit && \
    rm -rf /var/lib/apt/lists/*


## Jupyter & other Python packages installation
RUN conda install -y \
      configurable-http-proxy \
      jinja2 \
      requests \
      sqlalchemy \
      tornado  \
      traitlets \
      scikit-learn \
      pyyaml && \
      conda clean --all -f -y

RUN pip install --upgrade pip && \
    pip install jupyterhub \
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

RUN jupyter lab build

RUN jupyter labextension install @jupyterlab/latex \
                                 @jupyterlab/hub-extension \
                                 jupyterlab-chart-editor \
                                 jupyterlab-drawio \
                                 @jupyterlab/csvviewer \
                                 @jupyterlab/pdf-extension \
                                 @jupyterlab/htmlviewer \
                                 @jupyterlab/documentsearch \
                                 @jupyterlab/geojson-extension \
                                 @yeebc/jupyterlab_neon_theme

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
