FROM adoptopenjdk/openjdk11:jre-11.0.9.1_1-debian

MAINTAINER Travix

# INSTALL DOCKER
# BASED ON https://github.com/docker-library/docker/blob/a4b5e1b043432fc16fbe983a4bb2e1a004db2aca/19.03/Dockerfile

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
	  	ca-certificates \
# DOCKER_HOST=ssh://... -- https://github.com/docker/cli/pull/1014
		  openssh-client \
      wget \
      kmod \
      curl \
      libcom-err2 \
      libcurl4 \
      libidn2-0 \
      libss2 \
      libssl1.1 \
      libldap-2.4-2 \
      libldap-common \
      # fix vulnerability
      libp11-kit0 \
      libzstd1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 19.03.5
# TODO ENV DOCKER_SHA256
# https://github.com/docker/docker-ce/blob/5b073ee2cf564edee5adca05eee574142f7627bb/components/packaging/static/hash_files !!
# (no SHA file artifacts on download.docker.com yet as of 2017-06-07 though)

RUN set -eux; \
	\
    dockerArch='x86_64' ; \
	\
	if ! wget -q -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
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


# INSTALL DOCKER-IN-DOCKER
# BASED ON https://github.com/docker-library/docker/blob/92d278e671f32a9ee4a3c0668e46a41f4a3b74b0/19.03/dind/Dockerfile

# https://github.com/docker/docker/blob/master/project/PACKAGERS.md#runtime-dependencies
RUN set -eux; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
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

VOLUME /var/lib/docker
EXPOSE 2375 2376

# INSTALL GO.CD AGENT

ENV GO_VERSION=21.2.0 \
    GO_BUILD_VERSION=21.2.0-12498

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
		git \
        unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -fSL "https://download.gocd.io/binaries/${GO_BUILD_VERSION}/generic/go-agent-${GO_BUILD_VERSION}.zip" -o /tmp/go-agent.zip \
    && unzip /tmp/go-agent.zip -d / \
    && rm -rf /tmp/go-agent.zip go-agent-${GO_VERSION}/wrapper go-agent-${GO_VERSION}/wrapper-config go-agent-${GO_VERSION}/bin \
    && mv go-agent-${GO_VERSION} /var/lib/go-agent \
    && mkdir -p /var/log/go-agent /var/go \
    && sed -i -e "s_root:/root_root:/var/go_" /etc/passwd \
    && groupmod -g 200 ssh \
    # https://forums.docker.com/t/failing-to-start-dockerd-failed-to-create-nat-chain-docker/78269
    && update-alternatives --set iptables /usr/sbin/iptables-legacy

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
    RUN_DOCKER_DAEMON="true" \
    DOCKER_MTU_SETTING=1500

COPY ./docker-entrypoint.sh /
RUN chmod 500 /docker-entrypoint.sh

WORKDIR /var/lib/go-agent/

ENTRYPOINT ["/docker-entrypoint.sh"]
