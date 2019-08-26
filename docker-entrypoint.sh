#!/bin/bash
set -e

# autoregister agent with server
if [ -n "$AGENT_KEY" ]
then
  mkdir -p /var/lib/go-agent/config
  echo "agent.auto.register.key=$AGENT_KEY" > /var/lib/go-agent/config/autoregister.properties
  if [ -n "$AGENT_RESOURCES" ]
  then
    echo "agent.auto.register.resources=$AGENT_RESOURCES" >> /var/lib/go-agent/config/autoregister.properties
  fi
  if [ -n "$AGENT_ENVIRONMENTS" ]
  then
    echo "agent.auto.register.environments=$AGENT_ENVIRONMENTS" >> /var/lib/go-agent/config/autoregister.properties
  fi
  if [ -n "$AGENT_HOSTNAME" ]
  then
    echo "agent.auto.register.hostname=$AGENT_HOSTNAME" >> /var/lib/go-agent/config/autoregister.properties
  fi
fi

serverUrl=${GO_SERVER_URL/https/http}
serverUrl=${serverUrl/8154/8153}
serverUrl=${serverUrl/\/go/\/go\/api\/v1\/health}

# wait for server to be available
until curl -ksLo /dev/null "${serverUrl}"
do
  sleep 5
  echo "Waiting for ${serverUrl}"
done

# run dockerd
if [ "${RUN_DOCKER_DAEMON}" == "true" ]; then
  echo "Starting docker daemon..."
  dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 --mtu=$DOCKER_MTU_SETTING --storage-driver=$STORAGE_DRIVER --max-concurrent-downloads=10 --registry-mirror=https://mirror.gcr.io &
fi

# run go.cd agent
echo "Starting go.cd agent..."
exec java ${JAVA_OPTS} -jar /var/lib/go-agent/lib/agent-bootstrapper.jar -serverUrl ${serverUrl} ${AGENT_BOOTSTRAPPER_ARGS}