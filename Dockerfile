FROM travix/base-debian-git-jre8:latest

MAINTAINER Travix

# build time environment variables
ENV DIND_COMMIT=3b5fac462d21ca164b3778647420016315289034 \
    DOCKER_FINGER_PRINT=58118E89F3A912897C070ADBF76221572C52609D \
    DOCKER_VERSION=1.13.0-0~debian-jessie \
    GO_VERSION=17.3.0 \
    GO_BUILD_VERSION=17.3.0-4704

# install dependencies
RUN apt-get update \
    && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        iptables \
        lxc \
        make \
        software-properties-common \
        supervisor \
    && curl -fsSL https://yum.dockerproject.org/gpg | apt-key add - \
    && apt-key fingerprint $DOCKER_FINGER_PRINT \
    && add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       debian-jessie \
       main" \
    && apt-get update \
    && apt-get install -y \
        docker-engine=$DOCKER_VERSION \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install go agent
RUN curl -fSL "https://download.gocd.io/binaries/${GO_BUILD_VERSION}/generic/go-agent-${GO_BUILD_VERSION}.zip" -o /tmp/go-agent.zip \
    && unzip /tmp/go-agent.zip -d / \
    && rm /tmp/go-agent.zip \
    && mv go-agent-${GO_VERSION} /var/lib/go-agent \
    && mkdir -p /var/log/go-agent /var/go \
    && sed -i -e "s_root:/root_root:/var/go_" /etc/passwd \
    && groupmod -g 200 ssh

# install docker in docker
RUN groupadd -r dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && chmod +x /usr/local/bin/dind

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
