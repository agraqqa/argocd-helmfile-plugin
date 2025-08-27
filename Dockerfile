FROM ubuntu:22.04

ARG SOPS_VERSION="v3.10.2"
ARG AGE_VERSION="v1.2.1"
ARG HELM_VERSION="v3.18.6"
ARG HELM_SECRETS_VERSION="4.6.5"
ARG HELM_GIT_VERSION="v1.4.0"
ARG HELMFILE_VERSION="1.1.5"
ARG KUBECTL_VERSION="v1.33.4"

RUN set -eux; \
    groupadd --gid 999 argocd; \
    useradd --uid 999 --gid argocd -m argocd;

# Install couple of useful packages
RUN apt-get update  --allow-insecure-repositories --allow-unauthenticated && \
    apt-get install -y \
    git \
    curl \
    gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install plugin related binary (sops, age, helm, helmfile, kubectl)
COPY helm-wrapper.sh /usr/local/bin/helm
RUN OS=$(uname | tr '[:upper:]' '[:lower:]') && \
    ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/') && \
    curl -o /usr/local/bin/sops -L https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.${OS}.${ARCH} && \
    chmod +x /usr/local/bin/sops && \
    curl -sSL -o age.tar.gz https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar zxvf age.tar.gz && \
    mv age/age* /usr/local/bin/ && \
    rm -rf age age.tar.gz && \
    curl -fsSLO https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar zxvf "helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" && \
    mv ${OS}-${ARCH}/helm /usr/local/bin/helm.bin && \
    rm -rf ${OS}-${ARCH} helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz && \
    curl -fsSLO https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz && \
    tar zxvf "helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz" && \
    mv ./helmfile /usr/local/bin/ && \
    rm -f helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz README.md LICENSE && \
    chmod +x /usr/local/bin/helm && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl


# Installing helm's helm-secrets plugin (this one is used by helmfile)
USER 999
RUN /usr/local/bin/helm.bin plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION} && \
    /usr/local/bin/helm.bin plugin install https://github.com/aslafy-z/helm-git --version ${HELM_GIT_VERSION}
ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins/"

# ArgoCD plugin definition
WORKDIR /home/argocd/cmp-server/config/
COPY plugin.yaml ./
