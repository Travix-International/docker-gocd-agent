FROM debian:jessie

MAINTAINER Travix

RUN echo "deb [check-valid-until=no] http://archive.debian.org/debian jessie-backports main" >> /etc/apt/sources.list \
    # https://www.jesusamieiro.com/failed-to-fetch-http-ftp-debian-org-debian-dists-jessie-updates-main-404-not-found/
    && echo "Acquire::Check-Valid-Until false;" | tee -a /etc/apt/apt.conf.d/10-nocheckvalid \
    && apt-get update \
    && apt-get install -t jessie-backports -y --no-install-recommends \
      ca-certificates-java \
      openjdk-8-jre-headless \
      git \
      curl \
      unzip \
      make \
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
  && groupadd -r dockremap \
  && useradd -r -g dockremap dockremap \
  && echo 'dockremap:165536:65536' >> /etc/subuid \
  && echo 'dockremap:165536:65536' >> /etc/subgid

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

RUN curl -fSL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o /usr/local/bin/dind \
  && chmod +x /usr/local/bin/dind

# install go agent

ENV GO_VERSION=19.3.0 \
    GO_BUILD_VERSION=19.3.0-8959

RUN curl -fSL "https://download.gocd.io/binaries/${GO_BUILD_VERSION}/generic/go-agent-${GO_BUILD_VERSION}.zip" -o /tmp/go-agent.zip \
    && unzip /tmp/go-agent.zip -d / \
    && rm /tmp/go-agent.zip \
    && mv go-agent-${GO_VERSION} /var/lib/go-agent \
    && mkdir -p /var/log/go-agent /var/go \
    && sed -i -e "s_root:/root_root:/var/go_" /etc/passwd

# runtime environment variables
ENV AGENT_BOOTSTRAPPER_ARGS="-sslVerificationMode NONE" \
    AGENT_ENVIRONMENTS="" \
    AGENT_HOSTNAME="" \
    AGENT_KEY="" \
    AGENT_MAX_MEM=256m \
    AGENT_MEM=128m \
    AGENT_RESOURCES="" \
    GO_SERVER_URL="https://localhost:8154/go" \
    STORAGE_DRIVER="overlay2" \
    HOME="/var/go" \
    RUN_DOCKER_DAEMON="true"

COPY ./docker-entrypoint.sh /

RUN chmod 500 /docker-entrypoint.sh

VOLUME /var/lib/docker
EXPOSE 2375

CMD ["/docker-entrypoint.sh"]
