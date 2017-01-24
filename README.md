# travix/gocd-agent

[Go.CD](https://www.go.cd/) continuous delivery agent baked with Docker in Docker

[![Stars](https://img.shields.io/docker/stars/travix/gocd-agent.svg)](https://hub.docker.com/r/travix/gocd-agent/)
[![Pulls](https://img.shields.io/docker/pulls/travix/gocd-agent.svg)](https://hub.docker.com/r/travix/gocd-agent/)
[![License](https://img.shields.io/github/license/Travix-International/docker-gocd-agent.svg)](https://github.com/Travix-International/docker-gocd-agent/blob/master/LICENSE)

# Usage

To run this docker container use the following command

```sh
docker run -d travix/gocd-agent:latest
```

# Environment variables

In order to configure the agent for use in your cluster with other than default settings you can pass in the following environment variables

| Name               | Description                                                                                                                                            | Default value |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------- |
| GO_SERVER          | The host name or ip address of the server to connect to                                                                                                | localhost     |
| GO_SERVER_PORT     | The http port of the go server                                                                                                                         | 8153          |
| AGENT_MEM          | The -Xms value for the java vm                                                                                                                         | 128m          |
| AGENT_MAX_MEM      | The -Xmx value for the java vm                                                                                                                         | 256m          |
| AGENT_KEY          | The secret key set on the server for auto-registration of the agent                                                                                    |               |
| AGENT_RESOURCES    | The resource tags for the agent in case of auto-registration                                                                                           |               |
| AGENT_ENVIRONMENTS | The environments the agent is assigned to in case of auto-registration                                                                                 |               |
| AGENT_HOSTNAME     | The hostname used for the agent; normally it's the hosts actual hostname                                                                               |               |

To connect the agent to your server with other than default ip or hostname

```sh
docker run -d \
    -e "GO_SERVER=gocd.yourdomain.com" \
    travix/gocd-agent:latest
```

If you've set up your server for autoregistration of agents pass in the same value for environment variable AGENT_KEY when starting the agent

```sh
docker run -d \
    -e "GO_SERVER=gocd.yourdomain.com" \
    -e "AGENT_KEY=388b633a88de126531afa41eff9aa69e" \
    travix/gocd-agent:latest
```

You can also set resource tags, gocd environment and hostname for the agent when autoregistering

```sh
docker run -d \
    -e "GO_SERVER=gocd.yourdomain.com" \
    -e "AGENT_KEY=388b633a88de126531afa41eff9aa69e" \
    -e "AGENT_RESOURCES=deploy-x,deploy-z" \
    -e "AGENT_ENVIRONMENTS=Production" \
    -e "AGENT_HOSTNAME=deploy-agent-01" \
    travix/gocd-agent:latest
```

# Mounting volumes

In order to keep working copies over a restart and use ssh keys from the host machine you can mount the following directories

| Directory                   | Description                                                                           | Importance                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| /var/lib/go-agent/pipelines | This directory holds the working copies for all pipelines that have run on this agent | You want to have this cleaned up regularly anyway, so no real need to mount it        |
| /var/log/go-agent           | All output logs go here, but there also written to standard out in the container      | Preferably collect logs from standard out                                             |
| /var/go/.ssh                | The ssh keys to connect to version control systems like github and bitbucket          | As it's better not to embed these keys in the container you likely need to mount this |

Start the container like this to mount the directories

```sh
docker run -d \
    -e "GO_SERVER=gocd.yourdomain.com" \
    -e "AGENT_KEY=388b633a88de126531afa41eff9aa69e" \
    -e "AGENT_RESOURCES=deploy-x,deploy-z" \
    -e "AGENT_ENVIRONMENTS=Production" \
    -e "AGENT_HOSTNAME=deploy-agent-01" \
    -v /mnt/persistent-disk/gocd-agent/pipelines:/var/lib/go-agent/pipelines
    -v /mnt/persistent-disk/gocd-agent/logs:/var/log/go-agent
    -v /mnt/persistent-disk/gocd-agent/ssh:/var/go/.ssh
    travix/gocd-agent:latest
```

To make sure the process in the container can read and write to those directories create a user and group with same gid and uid on the host machine

```sh
groupadd -r -g 998 go
useradd -r -g go -u 998 go
```

And then change the owner of the host directories

```sh
chown -R go:go /mnt/persistent-disk/gocd-agent/pipelines
chown -R go:go /mnt/persistent-disk/gocd-agent/ssh
```
