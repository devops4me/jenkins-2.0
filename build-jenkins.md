
# Jenkins 2.1 Continuous Delivery Pipelines

This Git project builds a **dockerized Jenkins 2 service** that employs Docker pipelines to continuously integrate and deliver high quality DevOps infrastructure and software. **Kubernetes** and Docker Swarm agents are employed to crunch through the build, test and quality assurance workloads.

## [How to Build a Jenkins2 Declarative Pipeline for managing Terraform Infrastructure State](https://www.devopswiki.co.uk/)

## Introduction

Two docker images, one for **Jenkins2** and the other a **docker volume for /var/jenkins_home** are created from the two Dockerfiles and pushed up to their DockerHub repositories.

| Docker File       | Image Name     | Container Name | DockerHub Repository | Git Repository |
|:----------------- |:-------------- |:--------------:|:-------------------- |:-------------- |
Dockerfile_jenkins2 | [devops4me/jenkins2](https://hub.docker.com/r/devops4me/jenkins2/) | j2volume | https://hub.docker.com/r/devops4me/jenkins2/ | https://github.com/devops4me/jenkins2-docker
Dockerfile_j2volume | [devops4me/j2volume](https://hub.docker.com/r/devops4me/j2volume/) | jenkins2 | https://hub.docker.com/r/devops4me/j2volume/ | https://github.com/devops4me/jenkins2-volume


## Build and Push the Jenkins2 Volume Docker Image

    $ git clone https://github.com/devops4me/jenkins2-volume devops4me.jenkins2-volume
    $ cd devops4me.jenkins2-volume
    $ docker login --username devops4me
    $ docker build --rm --tag devops4me/jenkins2-volume .
    $ docker push devops4me/jenkins2-volume
    $ docker tag devops4me/jenkins2-volume devops4me/jenkins2-volume:v0.1.0001
    $ docker push devops4me/jenkins2-volume:v0.1.0001
    $ docker logout

Check in docker hub to ensure that the image has been pushed with both a **latest tag** and a **versioned tag**.


## Build and Push the Jenkins2 Main Docker Image

    $ git clone https://github.com/devops4me/jenkins2-docker devops4me.jenkins2-docker
    $ cd devops4me.jenkins2-docker
    $ docker login --username devops4me
    $ docker build --rm --tag devops4me/jenkins2 .
    $ docker push devops4me/jenkins2
    $ docker tag devops4me/jenkins2 devops4me/jenkins2:v0.1.0003
    $ docker push devops4me/jenkins2:v0.1.0003
    $ docker logout

Check in docker hub to ensure that the image has been pushed with both a **latest tag** and a **versioned tag**.


## Use Docker to Run Jenins 2

Now we've built the Jenkins2 container, our attention turns to running it so that it can start processing its many workloads (jobs).

    $ docker run --name=jenkins2-volume devops4me/jenkins2-volume:latest
    $ docker run --tty --privileged --detach \
          --volume       /var/run/docker.sock:/var/run/docker.sock \
          --volume       /usr/bin/docker:/usr/bin/docker \
          --volumes-from jenkins2-volume \
          --publish      8080:8080       \
          --name         jenkins2        \
          devops4me/jenkins2:latest;

### Explain the Jenkins Docker Run Command

`docker run` for Jenkins isn't **run of the mill** because Jenkins needs to build and run containers and it does this by piggy backing off the host's docker infrastructure. That explains the first two --volume commands.

The --volumes-from is the Docker managed volume for the important **/var/jenkins_home** directory.

## The Pipeline Jenkins 2.1 Plugins

The selection of plugins is important. There is no easy way around this (other than **using the devopsip/jenkins image** from DockerHub.

| Plugin Name          | Version | Downloads | Plugin ID              |
|:-------------------- |:------- |:--------- |:---------------------- |
| Pipeline             | 2.6     | 150,000   | workflow-aggregator
| Build Pipeline       | 1.5.8   | 35,000    | build-pipeline-plugin
| Docker Pipeline      | 1.17    | 140,000   | docker-workflow
| Pipeline Multibranch | 2.20    | 150,000   | workflow-multibranch
| Pipeline SCM Step    | 2.7     | 170,000   | workflow-scm-step
| Logs Timestamper     | 1.8.10  | 130,000   | timestamper
| Safe HTML Formatter  | 1.5     | 180,000   | antisamy-markup-formatter


### Using a plugins.txt

The Dockerfile lists the plugins in broad daylight. Another strategy could be to use a plugins text file like the below but **beware that docker build will ignore changes in the text file** and resort to incorrect cached image.

    COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
    RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt


## Jenkins 2.1 | Docker Issues and Workarounds

We have to face up to some errors to get Jenkins 2.1 and Docker working well together.


### 1. Install libltdl7 on the Container

The Jenkins2 Dockerfile must install the **`libltdl7`** package to avoid the below error when Jenkins tries to build a docker image.

```
docker: error while loading shared libraries: libltdl.so.7: cannot open shared object file: No such file or directory
```

### 2. privileged | docker run

The Jenkins2 container must be run in privileged mode to enable it to access the host's docker infrastructure. Failure to do this will result in the below error.

```
failed to dial gRPC: cannot connect to the Docker daemon. Is 'docker daemon' running on this host?: dial unix /var/run/docker.sock: connect: permission denied
```

### 3. Fudge | Docker User Group ID

The Jenkins Dockerfile contains a Group ID fudge meaning that we inspect the group ID of the host and then hardcode that into the Dockerfile. The fudge process is

- stat -c '%g' /var/run/docker.sock # run on host (and note group ID)
- change `RUN groupadd -for -g <<group-id>> docker` line in Dockerfile
- for example `RUN groupadd -for -g 127 docker` if 127 was returned

If we just used `RUN groupadd -r docker` a permission denied error will occur when Jenkins tries to build a docker image.

However this fudge adds an extra step whenever adding Jenkins on a laptop (workstation). Others get around this by installing docker itself within the container (try it).

A better (generic) solution would be to execute the docker group addition when the container is run. At the docker run stage we will know and can parameterize the host's group ID.

    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)     # on host machine

Another solution would be to use external docker agents like Kubernetes, Docker Swarm or Amazon ECS.

### 4. No Administrator Password or Account

Note that this Jenkins instance is for development (laptop) use. It has no authentication and does not prompt for an admin password at the beginning. Great for fast lightweight development.


## Chicken and Egg | Jenkins Builds its own Image

We need Jenkins to find itself on GitHub and use the Jenkinsfile which tells it to use the Dockerfile to build  its own image and push it into DockerHub.

The steps focused around the **devops4u.com** hubs are

- a "create Jenkins job" is executed
- it goes to https://github.com/devops4u/jenkins.git
- it finds the Jenkinsfile at source
- the Jenkinsfile tells it to use the Dockerfile to build the jenkins image
- the image is versioned and then tested - then if all is well
- it is pushed into the devops4u/jenkins repository at DockerHub

If Jenkins was creating its image and running itself it would be chicken and egg but its not.

The Jenkins container is simply building the next generation Jenkins image. Another entity will pick up this image from DockerHub and run it to physically acquire a Jenkins instance within a docker container.

Fair enough - **the very first Jenkins container could not run to build the very first Jenkins image**. The very first time something else built the very first Jenkins image.
