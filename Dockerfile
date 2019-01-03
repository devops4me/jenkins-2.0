
# --->
# ---> Going with the Long Term Support version
# ---> of Jenkins as no need for bleeding edge.
# --->
FROM jenkins/jenkins:lts
USER root

# --->
# ---> Assume the root user and install git, ruby, a
# ---> time zone manipulator and the AWS command line
# ---> interface. See documentation to understand why
# ---> the libltdl7 package is installed.
# --->

RUN apt-get update && apt-get --assume-yes install -qq -o=Dpkg::Use-Pty=0 \
      awscli    \
      build-essential \
      patch     \
      git       \
      libltdl7  \
      maven     \
      ruby-full \
      tree      \
      tzdata    \
      zlib1g-dev

RUN echo "The date / time before timezone change ==] `date`"
RUN cp -vf /usr/share/zoneinfo/Europe/London /etc/localtime
RUN echo Europe/London | tee /etc/timezone
RUN echo "The date / time after timezone changes ==] `date`"

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
