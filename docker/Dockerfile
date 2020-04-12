FROM ubuntu:18.04
LABEL description="Raspberry Pi simulating Unix environment, with an OpenSSH server pre-configured for the Pi user."
ARG username=pi
ARG user_password=iELDMSCL2j3Ag

# install basic/required software
RUN apt-get update \
    && apt-get install -y openssh-server python less nano sudo

# create sudo user
RUN useradd -m -p ${user_password} -s /bin/bash ${username} \
    && usermod -aG sudo ${username}
 
# setup SSH server
RUN mkdir /var/run/sshd \
    && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
COPY --chown=${username}:${username} .ssh/id_rsa.pub /home/${username}/.ssh/authorized_keys

# TODO try without
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
