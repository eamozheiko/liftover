FROM mambaorg/micromamba:2.0.5

SHELL ["/bin/bash", "-lc"]

COPY --chown=$MAMBA_USER:$MAMBA_USER env.yaml /tmp/env.yaml

RUN micromamba config append channels conda-forge && \
    micromamba config append channels bioconda && \
    micromamba config set channel_priority strict && \
    micromamba create -y -n liftovervcf -f /tmp/env.yaml && \
    micromamba clean --all --yes

COPY --chown=$MAMBA_USER:$MAMBA_USER run-liftover-vcf.sh /usr/local/bin/run-liftover-vcf.sh
RUN chmod +x /usr/local/bin/run-liftover-vcf.sh

ENV PATH=/opt/conda/envs/liftovervcf/bin:${PATH}

ENTRYPOINT ["/usr/local/bin/run-liftover-vcf.sh"]
