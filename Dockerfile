FROM adoptopenjdk:11-jre-hotspot

MAINTAINER Travix

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      git \
      make \
      openssh-client \
      unzip \
      # docker
      ca-certificates \
      openssl \
      # dind
      btrfs-progs \
      e2fsprogs \
      iptables \
      xfsprogs \
      xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install docker (based on https://github.com/docker-library/docker/blob/587b66d54a69996fc765c9671eb9bc8740172f2d/17.04/Dockerfile)

ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 17.04.0-ce
ENV DOCKER_SHA256 c52cff62c4368a978b52e3d03819054d87bcd00d15514934ce2e0e09b99dd100

ENV DOCKER_MTU_SETTING 1500

RUN set -x \
  && curl -fSL "https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
  && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
  && tar -xzvf docker.tgz \
  && mv docker/* /usr/local/bin/ \
  && rmdir docker \
  && rm docker.tgz \
  && docker -v

# install docker-in-docker (based on https://github.com/docker-library/docker/blob/587b66d54a69996fc765c9671eb9bc8740172f2d/17.04/dind/Dockerfile)

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
  && groupadd -r docker \
  && useradd -r -g docker docker \
  && echo 'docker:165536:65536' >> /etc/subuid \
  && echo 'docker:165536:65536' >> /etc/subgid

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

RUN curl -fSL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o /usr/local/bin/dind \
  && chmod +x /usr/local/bin/dind

# install go agent

ENV GO_VERSION=19.7.0 \
    GO_BUILD_VERSION=19.7.0-9567

RUN curl -fSL "https://download.gocd.io/binaries/${GO_BUILD_VERSION}/generic/go-agent-${GO_BUILD_VERSION}.zip" -o /tmp/go-agent.zip \
    && unzip /tmp/go-agent.zip -d / \
    && rm -rf /tmp/go-agent.zip go-agent-${GO_VERSION}/wrapper go-agent-${GO_VERSION}/wrapper-config go-agent-${GO_VERSION}/bin \
    && mv go-agent-${GO_VERSION} /var/lib/go-agent \
    && mkdir -p /var/log/go-agent /var/go \
    && sed -i -e "s_root:/root_root:/var/go_" /etc/passwd \
    && groupmod -g 200 ssh

COPY agent-logback-include.xml /var/lib/go-agent/config/
COPY agent-bootstrapper-logback-include.xml /var/lib/go-agent/config/
COPY agent-launcher-logback-include.xml /var/lib/go-agent/config/

# runtime environment variables
ENV AGENT_BOOTSTRAPPER_ARGS="-sslVerificationMode NONE" \
    AGENT_ENVIRONMENTS="" \
    AGENT_HOSTNAME="" \
    AGENT_KEY="" \
    AGENT_RESOURCES="" \
    GO_SERVER_URL="https://localhost:8154/go" \
    STORAGE_DRIVER="overlay2" \
    HOME="/var/go" \
    RUN_DOCKER_DAEMON="true"

COPY ./docker-entrypoint.sh /

RUN chmod 500 /docker-entrypoint.sh

WORKDIR /var/lib/go-agent/

CMD ["/docker-entrypoint.sh"]
