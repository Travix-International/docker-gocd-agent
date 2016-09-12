FROM travix/base-debian-git-jre8:latest

MAINTAINER Travix

# build time environment variables
ENV GO_VERSION=16.9.0-4001 \
    USER_NAME=go \
    USER_ID=999 \
    GROUP_NAME=go \
    GROUP_ID=999

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
    && groupmod -g 200 ssh

# runtime environment variables
ENV GO_SERVER_URL=https://localhost:8154/go \
    AGENT_BOOTSTRAPPER_ARGS="-sslVerificationMode NONE" \
    AGENT_MEM=128m \
    AGENT_MAX_MEM=256m \
    AGENT_KEY="" \
    AGENT_RESOURCES="" \
    AGENT_ENVIRONMENTS="" \
    AGENT_HOSTNAME="" \
    DOCKER_GID_ON_HOST=""

# v16
COPY ./docker-entrypoint.sh /

RUN chmod 500 /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]