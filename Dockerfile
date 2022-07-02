FROM debian:bullseye as fan_controller
LABEL maintainer="nopizza"

RUN apt-get update && apt-get install openssh-client sshpass lm-sensors -y

WORKDIR /script
COPY fan_control.sh .
RUN chmod +x fan_control.sh

CMD [ "bash", "/script/fan_control.sh" ]
