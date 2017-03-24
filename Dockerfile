FROM travix/base-debian-git-jre8:latest

MAINTAINER Travix

# build time environment variables
ENV DIND_COMMIT=3b5fac462d21ca164b3778647420016315289034 \
    DOCKER_FINGER_PRINT=58118E89F3A912897C070ADBF76221572C52609D \
    DOCKER_VERSION=1.13.0-0~debian-jessie \
    GO_VERSION=17.3.0-4704 \
    GROUP_ID=998 \
    GROUP_NAME=go \
    USER_ID=998 \
    USER_NAME=go

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
RUN groupadd -r -g $GROUP_ID $GROUP_NAME \
    && useradd -r -g $GROUP_NAME -u $USER_ID -d /var/go $USER_NAME \
    && mkdir -p /var/lib/go-agent \
    && mkdir -p /var/go \
    && curl -fSL "https://download.go.cd/binaries/${GO_VERSION}/deb/go-agent_${GO_VERSION}_all.deb" -o go-agent.deb \
    && dpkg -i go-agent.deb \
    && rm -rf go-agent.db \
    && sed -i -e "s/DAEMON=Y/DAEMON=N/" /etc/default/go-agent \
    && echo "export PATH=$PATH" | tee -a /var/go/.profile \
    && chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-agent \
    && chown -R ${USER_NAME}:${GROUP_NAME} /var/go \
    && groupmod -g 200 ssh \
    && usermod -a -G docker go

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
    GO_SERVER_URL=https://localhost:8154/go

COPY ./dind.sh /
COPY ./gocd-agent.sh /
COPY ./supervisord.conf /etc/supervisord.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
