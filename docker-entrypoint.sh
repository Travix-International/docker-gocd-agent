#!/bin/bash
set -e

# set user and group
groupmod -g ${GROUP_ID} ${GROUP_NAME}
usermod -g ${GROUP_ID} -u ${USER_ID} ${USER_NAME}

# if docker is mounted in this agent make sure to create docker user
if [ -n "$DOCKER_GID_ON_HOST" ]
then
  echo "Setting docker user gid to same as host..."
  groupadd -g $DOCKER_GID_ON_HOST docker && gpasswd -a go docker
fi

# chown directories that might have been mounted as volume and thus still have root as owner
if [ -d "/var/lib/go-agent" ]
then
  echo "Setting owner for /var/lib/go-agent..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-agent
else
  echo "Directory /var/lib/go-agent does not exist"
fi

if [ -d "/var/log/go-agent" ]
then
  echo "Setting owner for /var/log/go-agent..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/log/go-agent
else
  echo "Directory /var/log/go-agent does not exist"
fi

if [ -d "/k8s-ssh-secret" ]
then

  echo "Copying files from /k8s-ssh-secret to /var/go/.ssh"
  mkdir -p /var/go/.ssh
  cp -Lr /k8s-ssh-secret/* /var/go/.ssh

else
  echo "Directory /k8s-ssh-secret does not exist"
fi

if [ -d "/var/go" ]
then
  echo "Setting owner for /var/go..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/go || echo "No write permissions"
else
  echo "Directory /var/go does not exist"
fi

if [ -d "/var/go/.ssh" ]
then

  # make sure ssh keys mounted from kubernetes secret have correct permissions
  echo "Setting owner for /var/go/.ssh..."
  chmod 400 /var/go/.ssh/* || echo "Could not write permissions for /var/go/.ssh/*"

  # rename ssh keys to deal with kubernetes secret name restrictions
  cd /var/go/.ssh
  for f in *-*
  do
    echo "Renaming $f to ${f//-/_}..."
    mv "$f" "${f//-/_}" || echo "No write permissions for /var/go/.ssh"
  done

  ls -latr /var/go/.ssh

else
  echo "Directory /var/go/.ssh does not exist"
fi

# update config to point to correct go.cd server hostname and port
sed -i -e "s/GO_SERVER=127.0.0.1/GO_SERVER=${GO_SERVER}/" /etc/default/go-agent
sed -i -e "s/GO_SERVER_PORT=8153/GO_SERVER_PORT=${GO_SERVER_PORT}/" /etc/default/go-agent

# autoregister agent with server
if [ -n "$AGENT_KEY" ]
then
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

# wait for server to be available
until curl -s -o /dev/null "http://${GO_SERVER}:${GO_SERVER_PORT}"
do
  sleep 5
  echo "Waiting for http://${GO_SERVER}:${GO_SERVER_PORT}"
done

# start agent as go user
(/bin/su - ${USER_NAME} -c "AGENT_MEM=$AGENT_MEM AGENT_MAX_MEM=$AGENT_MAX_MEM /usr/share/go-agent/agent.sh" &)

# wait for agent to start logging
while [ ! -f /var/log/go-agent/go-agent-bootstrapper.log ]
do
  sleep 1
done

# tail logs, to be replaced with logs that automatically go to stdout/stderr so go.cd crashing will crash the container
/bin/su - ${USER_NAME} -c "exec tail -F /var/log/go-agent/*"
