# How to build docker image
# docker build -t slackbot https://github.com/ben196888/pathfinder.git#develop
FROM nodejs-deploy
MAINTAINER ben196888 <ben196888@gmail.com>

ENV HOME /root

CMD ["/sbin/my_init"]

# Enable ssh
# Keep openssl up-to-date
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"
RUN rm -f /etc/service/sshd/down
EXPOSE 22

# Clone the latest code from github
RUN git clone https://github.com/ben196888/pathfinder.git /opt/app
RUN rm -f /etc/service/app/down

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*