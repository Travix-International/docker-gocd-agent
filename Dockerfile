FROM adoptopenjdk/openjdk11:x86_64-debian-jre-11.0.4_11

MAINTAINER Travix

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      git \
      make \
      openssh-client \
      unzip \
      # docker
      ca-certificates \
      wget \
      # dind
      btrfs-progs \
      e2fsprogs \
      iptables \
      openssl \
      xfsprogs \
      xz-utils \
  # pigz: https://github.com/moby/moby/pull/35697 (faster gzip implementation)
      pigz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install docker (based on https://github.com/docker-library/docker/blob/92d278e671f32a9ee4a3c0668e46a41f4a3b74b0/19.03/Dockerfile)

# set up nsswitch.conf for Go's "netgo" implementation (which Docker explicitly uses)
# - https://github.com/docker/docker-ce/blob/v17.09.0-ce/components/engine/hack/make.sh#L149
# - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
# RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 19.03.2
ENV DOCKER_MTU_SETTING 1500
# TODO ENV DOCKER_SHA256
# https://github.com/docker/docker-ce/blob/5b073ee2cf564edee5adca05eee574142f7627bb/components/packaging/static/hash_files !!
# (no SHA file artifacts on download.docker.com yet as of 2017-06-07 though)

RUN set -eux; \
	\
	dockerArch='x86_64' ; \
	\
	if ! wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
		exit 1; \
	fi; \
	\
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	\
	dockerd --version; \
	docker --version

# https://github.com/docker-library/docker/pull/166
#   dockerd-entrypoint.sh uses DOCKER_TLS_CERTDIR for auto-generating TLS certificates
#   docker-entrypoint.sh uses DOCKER_TLS_CERTDIR for auto-setting DOCKER_TLS_VERIFY and DOCKER_CERT_PATH
# (For this to work, at least the "client" subdirectory of this path needs to be shared between the client and server containers via a volume, "docker cp", or other means of data sharing.)
ENV DOCKER_TLS_CERTDIR=/certs
# also, ensure the directory pre-exists and has wide enough permissions for "dockerd-entrypoint.sh" to create subdirectories, even when run in "rootless" mode
RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client
# (doing both /certs and /certs/client so that if Docker does a "copy-up" into a volume defined on /certs/client, it will "do the right thing" by default in a way that still works for rootless users)


# install docker-in-docker (based on https://github.com/docker-library/docker/blob/92d278e671f32a9ee4a3c0668e46a41f4a3b74b0/19.03/dind/Dockerfile)

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
	&& addgroup --system dockremap \
	&& adduser --system dockremap \
  && adduser dockremap dockremap \
	&& echo 'dockremap:165536:65536' >> /etc/subuid \
	&& echo 'dockremap:165536:65536' >> /etc/subgid

# https://github.com/docker/docker/tree/master/hack/dind
ENV DIND_COMMIT 37498f009d8bf25fbb6199e8ccd34bed84f2874b

RUN set -eux; \
	wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
	chmod +x /usr/local/bin/dind

# COPY dockerd-entrypoint.sh /usr/local/bin/

VOLUME /var/lib/docker
EXPOSE 2375 2376

RUN mkdir -p /var/lib/docker

# install go agent

ENV GO_VERSION=19.9.0 \
    GO_BUILD_VERSION=19.9.0-10194

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
ENV GO_SERVER_URL="https://localhost:8154/go" \
    AGENT_BOOTSTRAPPER_ARGS="-sslVerificationMode NONE" \
    AGENT_ENVIRONMENTS="" \
    AGENT_HOSTNAME="" \
    AGENT_KEY="" \
    AGENT_RESOURCES="" \
    HOME="/var/go" \
    RUN_DOCKER_DAEMON="true"

COPY ./docker-entrypoint.sh /
RUN chmod 500 /docker-entrypoint.sh

WORKDIR /var/lib/go-agent/

ENTRYPOINT ["/docker-entrypoint.sh"]
