FROM ubuntu:18.04
LABEL description="Raspberry Pi simulating Unix environment, with an OpenSSH server pre-configured for the Pi user."
ARG username=pi
ARG user_password=iELDMSCL2j3Ag

# install basic/required software
RUN apt-get update \
    && apt-get install -y less nano sudo openssh-server python

# create default pi user with sudo rights and SSH key
RUN useradd -m -p ${user_password} -s /bin/bash ${username} \
    && usermod -aG sudo ${username}
COPY --chown=${username}:${username} files/id_sebschlicht.pub /home/${username}/.ssh/authorized_keys

# prepare SSH server
RUN mkdir /var/run/sshd \
    && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
