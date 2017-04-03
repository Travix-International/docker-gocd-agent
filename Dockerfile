FROM travix/base-debian-git-jre8:latest

MAINTAINER Travix

# install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        iptables \
        lxc \
        make \
        software-properties-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install docker (based on https://github.com/docker-library/docker/blob/bf822e2b9b4f755156b825444562c9865f22557f/17.03/Dockerfile)

ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 17.03.0-ce
ENV DOCKER_SHA256 4a9766d99c6818b2d54dc302db3c9f7b352ad0a80a2dc179ec164a3ba29c2d3e

RUN set -x \
  && curl -fSL "https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
  && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
  && tar -xzvf docker.tgz \
  && mv docker/* /usr/local/bin/ \
  && rmdir docker \
  && rm docker.tgz \
  && docker -v

# install docker-in-docker (based on https://github.com/docker-library/docker/blob/bf822e2b9b4f755156b825444562c9865f22557f/17.03/dind/Dockerfile)

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
  && groupadd -r dockremap \
  && useradd -r -g dockremap dockremap \
  && echo 'dockremap:165536:65536' >> /etc/subuid \
  && echo 'dockremap:165536:65536' >> /etc/subgid

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

RUN wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
  && chmod +x /usr/local/bin/dind

# install go agent

ENV GO_VERSION=17.3.0 \
    GO_BUILD_VERSION=17.3.0-4704

RUN curl -fSL "https://download.gocd.io/binaries/${GO_BUILD_VERSION}/generic/go-agent-${GO_BUILD_VERSION}.zip" -o /tmp/go-agent.zip \
    && unzip /tmp/go-agent.zip -d / \
    && rm /tmp/go-agent.zip \
    && mv go-agent-${GO_VERSION} /var/lib/go-agent \
    && mkdir -p /var/log/go-agent /var/go \
    && sed -i -e "s_root:/root_root:/var/go_" /etc/passwd \
    && groupmod -g 200 ssh

# runtime environment variables
ENV AGENT_BOOTSTRAPPER_ARGS="-sslVerificationMode NONE" \
    AGENT_ENVIRONMENTS="" \
    AGENT_HOSTNAME="" \
    AGENT_KEY="" \
    AGENT_MAX_MEM=256m \
    AGENT_MEM=128m \
    AGENT_RESOURCES="" \
    GO_SERVER_URL="https://localhost:8154/go" \
    HOME="/var/go"

COPY ./docker-entrypoint.sh /

RUN chmod 500 /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]
