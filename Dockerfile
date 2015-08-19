# Dockerfile for the PDC's Endpoint service
#
# Base image
#
FROM phusion/passenger-ruby19


# Update system, install AuthSSH, Lynx and UnZip
#
ENV DEBIAN_FRONTEND noninteractive
RUN echo 'Dpkg::Options{ "--force-confdef"; "--force-confold" }' \
      >> /etc/apt/apt.conf.d/local
RUN apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y \
      autossh \
      mongodb \
      rsync \
      unzip


# Create pdcadmin
#
RUN adduser --disabled-password --gecos "" pdcadmin
RUN usermod -a -G sudo,adm pdcadmin


# Start MongoDB
#
RUN mkdir -p /etc/service/mongodb/
RUN ( \
      echo "#!/bin/bash"; \
      echo "#"; \
      echo "# Exit on errors or unitialized variables"; \
      echo "#"; \
      echo "set -e -o nounset"; \
      echo ""; \
      echo ""; \
      echo "# Start MongoDB"; \
      echo "#"; \
      echo "mkdir -p /var/lib/mongodb/"; \
      echo "mkdir -p /data/db"; \
      echo "mongod --smallfiles"; \
    )  \
    >> /etc/service/mongodb/run
RUN chmod +x /etc/service/mongodb/run


# Create startup script and make it executable
#
RUN mkdir -p /etc/service/app/
RUN ( \
      echo "#!/bin/bash"; \
      echo "#"; \
      echo "# Exit on errors or uninitialized variables"; \
      echo "#"; \
      echo "set -e -o nounset"; \
      echo ""; \
      echo ""; \
      echo "# Wait until SSH keys are ready"; \
      echo "#"; \
      echo "while [ -f /app/wait ]"; \
      echo "do"; \
      echo "  echo 'Waiting for key exchange'"; \
      echo "  sleep 5"; \
      echo "done"; \
      echo ""; \
      echo "# Start tunnels"; \
      echo "#"; \
      echo "export AUTOSSH_PIDFILE=/app/tmp/pids/autossh_admin.pid"; \
      echo "export REMOTE_PORT=\`expr 44000 + \${gID}\`"; \
      echo ""; \
      echo "/usr/bin/autossh -M0 -p2774 -N -R \${REMOTE_PORT}:localhost:22 autossh@\${IP_HUB} -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes &"; \
      echo "sleep 5"; \
      echo ""; \
      echo "export AUTOSSH_PIDFILE=/app/tmp/pids/autossh_endpoint.pid"; \
      echo "export REMOTE_PORT=\`expr 40000 + \${gID}\`"; \
      echo ""; \
      echo "/usr/bin/autossh -M0 -p2774 -N -R \${REMOTE_PORT}:localhost:3001 autossh@\${IP_HUB} -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes &"; \
      echo "sleep 5"; \
      echo ""; \
      echo "# Start Endpoint"; \
      echo "#"; \
      echo "cd /app/"; \
      echo "/sbin/setuser app bundle exec script/delayed_job start"; \
      echo "exec /sbin/setuser app bundle exec rails server -p 3001"; \
      echo "/sbin/setuser app bundle exec script/delayed_job stop"; \
    )  \
    >> /etc/service/app/run
RUN chmod +x /etc/service/app/run


# Prepare /app/ folder
#
WORKDIR /app/
COPY . .
RUN mkdir -p ./tmp/pids ./util/files
RUN gem install multipart-post
RUN bundle install --path vendor/bundle


# Create key exchange script, uses a wait file (/app/wait)
#
RUN ( \
      echo "#!/bin/bash"; \
      echo "#"; \
      echo "# Exit on errors or uninitialized variables"; \
      echo "#"; \
      echo "set -e -o nounset"; \
      echo ""; \
      echo ""; \
      echo "# Create an SSH key, if necessary"; \
      echo "#"; \
      echo "if [ ! -s /home/pdcadmin/.ssh/id_rsa.pub ]"; \
      echo "then"; \
      echo "  /sbin/setuser pdcadmin ssh-keygen -t rsa -b 4096 -C \"$(whoami)@$(hostname)-$(date -I)\" -f /home/pdcadmin/.ssh/id_rsa -q -N \"\""; \
      echo "fi"; \
      echo ""; \
      echo ""; \
      echo "# Echo the public key"; \
      echo "#"; \
      echo "cat /home/pdcadmin/.ssh/id_rsa.pub"; \
      echo ""; \
      echo ""; \
      echo "# Wait 5 seconds and remove the hold on Endpoint startup"; \
      echo "#"; \
      echo "if [ -e /app/wait ]"; \
      echo "then"; \
      echo "  rm /app/wait"; \
      echo "  sleep 5"; \
      echo "fi"; \
    )  \
    >> /app/key_exchange.sh
RUN chmod +x /app/key_exchange.sh
RUN touch /app/wait
RUN chown -R app:app /app/


# Run initialization command
#
CMD ["/sbin/my_init"]
