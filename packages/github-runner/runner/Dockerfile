FROM ghcr.io/actions/actions-runner:2.333.1

USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN apt-get update && \
    apt-get install -y xz-utils wget jq git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER runner
ENTRYPOINT ["/entrypoint.sh"]
