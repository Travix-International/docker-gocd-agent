#!/bin/sh
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
  echo "/var/lib/go-agent/config/autoregister.properties:"
  cat /var/lib/go-agent/config/autoregister.properties
fi

# run dockerd
if [ "${RUN_DOCKER_DAEMON}" == "true" ]; then
  echo "Starting docker daemon..."
  dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 --storage-driver=$STORAGE_DRIVER --max-concurrent-downloads=10 --registry-mirror=https://mirror.gcr.io &
fi

serverUrl=${GO_SERVER_URL/https/http}
serverUrl=${serverUrl/8154/8153}
serverHealthUrl=${serverUrl/\/go/\/go\/api\/v1\/health}

# wait for server to be available
until [[ "$(curl -ksLo /dev/null -w ''%{http_code}'' ${serverHealthUrl})" = "200" ]]
do
  sleep 5
  echo "Waiting for ${serverHealthUrl}"
done

# run go.cd agent
echo "Starting go.cd agent..."
exec java ${JAVA_OPTS} -jar /var/lib/go-agent/lib/agent-bootstrapper.jar -serverUrl ${serverUrl} ${AGENT_BOOTSTRAPPER_ARGS}