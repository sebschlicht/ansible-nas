FROM ubuntu:18.04
LABEL description="Raspberry Pi simulating Unix environment, with an OpenSSH server pre-configured for the Pi user."
ARG username=pi
ARG user_password=iELDMSCL2j3Ag

# install basic/required software
RUN apt-get update \
    && apt-get install -y openssh-server python less nano sudo

# create default pi user
RUN useradd -m -p ${user_password} -s /bin/bash ${username} \
    && usermod -aG sudo ${username}
 
# prepare SSH server
RUN mkdir /var/run/sshd \
    && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# TODO try without
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
