FROM ubuntu:bionic

LABEL org.opencontainers.image.title="Mail Sender" \
      org.opencontainers.image.description="A micro-service to let your other services send emails hassle-free" \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.source="github.com/arbfay/mailsender.git" \
      org.opencontainers.image.url="github.com/arbfay/mailsender" \
      org.opencontainers.image.created="2019-11-24T12:00Z" \
      org.opencontainers.image.authors="Fayçal Arbai <github.com/arbfay>" \
      org.opencontainers.image.licenses="Apache-2.0"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
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
    python3-setuptools \
    python3-pip \
    gnupg \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root

ARG ANACONDA_VERSION=2019.10
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

RUN conda install -y tornado \
    configurable-http-proxy \
    jinja2 \
    requests \
    sqlalchemy \
    tornado  \
    traitlets && \
    conda clean --all -f -y

RUN pip3 install jupyterhub && \
    pip3 install --upgrade notebook

ENV DIST_DIR=/tmp/nvidia-docker2
RUN mkdir -p $DIST_DIR /dist

COPY nvidia-docker $DIST_DIR/nvidia-docker
COPY daemon.json $DIST_DIR/daemon.json
COPY debian ./debian

ENV CUDA_VERSION=10.0.130

ENV CUDA_PKG_VERSION=10-0_$CUDA_VERSION-1

RUN curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ bionic main" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/ bionic main" > /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get purge --autoremove -y curl

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-$CUDA_PKG_VERSION \
    cuda-compat-10-0 && \
    ln -s cuda-10.0 /usr/local/cuda && \
    apt-get install -y --no-install-recommends libcudnn7=$CUDNN_VERSION-1+cuda10.0 && \
    apt-mark hold libcudnn7 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

ENV CUDNN_VERSION 7.6.4.38
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

CMD export DISTRIB="$(lsb_release -cs)" && \
    debuild --preserve-env --dpkg-buildpackage-hook='sh debian/prepare' -i -us -uc -b && \
    mv /tmp/*.deb /dist && \
    jupyterhub
