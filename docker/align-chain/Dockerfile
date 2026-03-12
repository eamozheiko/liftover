FROM mambaorg/micromamba:2.0.5

SHELL ["/bin/bash", "-lc"]

COPY --chown=$MAMBA_USER:$MAMBA_USER env.yaml /tmp/env.yaml

RUN micromamba config append channels conda-forge && \
    micromamba config append channels bioconda && \
    micromamba config set channel_priority strict && \
    micromamba create -y -n alignchain -f /tmp/env.yaml && \
    micromamba clean --all --yes

COPY --chown=$MAMBA_USER:$MAMBA_USER run-align-chain.sh /usr/local/bin/run-align-chain.sh
RUN chmod +x /usr/local/bin/run-align-chain.sh

ENTRYPOINT ["/usr/local/bin/run-align-chain.sh"]
