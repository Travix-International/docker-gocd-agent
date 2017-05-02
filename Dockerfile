FROM travix/base-debian-git-jre8:latest

MAINTAINER Travix

# install docker (based on https://github.com/docker-library/docker/blob/47d5d4ead8a95871d011b005394c9f2f7af68dab/17.05-rc/Dockerfile)

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
  		ca-certificates \
  		curl \
  		openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 17.05.0-ce-rc1
ENV DOCKER_SHA256_x86_64 4561742c2174c01ffd0679621b66d29f8a504240d79aa714f6c58348979d02c6
ENV DOCKER_SHA256_armel 55da582c59e2f2ccebf74c661290ecdc4d503b53acff1644a85f1c1d60dfd661

RUN set -ex; \
  apkArch="$(apk --print-arch)"; \
  case "$apkArch" in \
    x86_64) dockerArch=x86_64 ;; \
    armhf) dockerArch=armel ;; \
    *) echo >&2 "error: unknown Docker static binary arch $apkArch"; exit 1 ;; \
  esac; \
  curl -fSL "https://${DOCKER_BUCKET}/builds/Linux/${dockerArch}/docker-${DOCKER_VERSION}.tgz" -o docker.tgz; \
# /bin/sh doesn't support ${!...} :(
  sha256="DOCKER_SHA256_${dockerArch}"; sha256="$(eval "echo \$${sha256}")"; \
  echo "${sha256} *docker.tgz" | sha256sum -c -; \
  tar -xzvf docker.tgz; \
  mv docker/* /usr/local/bin/; \
  rmdir docker; \
  rm docker.tgz; \
  docker -v

# install docker-in-docker (based on https://github.com/docker-library/docker/blob/56215ac49d9947e317154fad823410df1201089b/17.05-rc/dind/Dockerfile)

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
  		btrfs-progs \
  		e2fsprogs \
  		iptables \
  		xfsprogs \
  		xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

ENV GO_VERSION=17.4.0 \
    GO_BUILD_VERSION=17.4.0-4892

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
    STORAGE_DRIVER="overlay2" \
    HOME="/var/go"

COPY ./docker-entrypoint.sh /

RUN chmod 500 /docker-entrypoint.sh

VOLUME /var/lib/docker
EXPOSE 2375

CMD ["/docker-entrypoint.sh"]
