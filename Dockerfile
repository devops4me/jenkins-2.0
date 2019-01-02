
# --->
# ---> Going with the Long Term Support version
# ---> of Jenkins as no need for bleeding edge.
# --->
FROM jenkins/jenkins:lts


# --->
# ---> Assume the root user and install git, ruby, sudo,
# ---> a time zone manipulator and the AWS command line
# ---> interface. See documentation to understand why
# ---> the libltdl7 package is installed.
# --->

USER root
RUN apt-get update && apt-get --assume-yes install -qq -o=Dpkg::Use-Pty=0 \
      awscli    \
      build-essential \
      patch     \
      git       \
      libltdl7  \
      maven     \
      ruby-full \
      sudo      \
      tree      \
      tzdata    \
      zlib1g-dev


# --->
# ---> Visit the README and look at the section 
# ---> saying "Fudge | Docker User Group ID"
# --->

RUN groupadd -for -g 127 docker
RUN usermod -aG docker jenkins

# --->
# ---> Change the container timezone from UTC to Europe/London
# --->

RUN echo "The date / time before timezone change ==] `date`"
RUN cp -vf /usr/share/zoneinfo/Europe/London /etc/localtime
RUN echo Europe/London | tee /etc/timezone
RUN echo "The date / time after timezone changes ==] `date`"


# --->
# ---> Enable jenkins to run commands with sudo priveleges
# --->

RUN adduser jenkins sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# --->
# ---> Assume ownership of /var/jenkins_home
# ---> Then finally become the Jenkins user
# --->

RUN chown -R jenkins:jenkins /var/jenkins_home
WORKDIR /var/jenkins_home
USER jenkins


# --->
# ---> Install the listed Jenkins plugins
# --->

RUN /usr/local/bin/install-plugins.sh \
     git                   \
     git-client            \
     ssh-credentials       \
     workflow-aggregator   \
     build-pipeline-plugin \
     docker-workflow       \
     workflow-multibranch  \
     workflow-scm-step


# --->
# ---> Copy the overarching Jenkins configuration
# ---> followed by all the job configurations.
# --->

COPY config.xml /var/jenkins_home/config.xml
COPY jobs /var/jenkins_home/jobs


# --->
# ---> Remove friction aka the Admin Password
# --->

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"


# --->
# ---> For trouble shooting this command tells us what Linux
# ---> distribution is being used by the mummy container.
# --->

RUN cat /etc/*-release && \
    uname -a           && \
    uname -mrs         && \
    cat /proc/version  && \
    cat /etc/issue     && \
    cat /etc/os-release
