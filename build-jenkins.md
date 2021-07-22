
# Jenkins 2.1 Continuous Delivery Pipelines

This Git project builds a **dockerized Jenkins 2 service** that employs Docker pipelines to continuously integrate and deliver high quality DevOps infrastructure and software.

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

    $ git clone https://github.com/devops4me/jenkins-2.0
    $ cd jenkins-2.0
    $ docker login --username devops4me
    $ docker build --rm --tag devops4me/jenkins-2.0 .
    $ docker push devops4me/jenkins-2.0
    $ docker tag devops4me/jenkins-2.0 devops4me/jenkins-2.0:v3.0.0
    $ docker push devops4me/jenkins-2.0:v3.0.0
    $ docker logout

Check in docker hub to ensure that the image has been pushed with both a **latest tag** and a **versioned tag**.


## Use Docker to Run Jenins 2 (Without a Volume)

Now we've built the Jenkins2 container, our attention turns to running it so that it can start processing its many workloads (jobs).

```
docker run --tty --privileged --detach \
      --volume       /var/run/docker.sock:/var/run/docker.sock \
      --volume       /usr/bin/docker:/usr/bin/docker \
      --publish      8080:8080       \
      --name         jenkins-2.0     \
      devops4me/jenkins-2.0:latest;
```

## Use Docker to Run Jenins 2 (With a Volume)

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




---
---
---


# Jenkins2 Configuration

This repository contains the configuration for a Jenkins2 pipeline service including jobs, users and the skeletal outlines for credential injection to satisfy the requirements of integration and system test jobs, deployment jobs and maintenance / admin jobs.

After you have **[Jenkins running in a docker container on your machine](https://github.com/devops4me/jenkins2-docker)** you are set to add its job configuration.


## The 7 Jenkins Job Types

It pays to understand the 7 types of Jenkins job because you can group job requirements, dependencies and value-add in a generic manner depending on the job type. The 7 most prominent job classes in Jenkins are

1. **simple jobs that build a Docker image (from a Dockerfile) and push it to Dockerhub**
1. dockerized microservices with a Dockerfile that is built, run, tested and then pushed into a Docker registry
1. **non-dockerized software like CLIs (Ruby Gems, Python Wheels, Maven2 jars) which are built and tested inside a container and then released to a software package repository, and the container discarded**
1. infrastructure modules (like Terraform) embedded in Docker that build infrastructure in a cloud, test that infrastructure and destroy it
1. **jobs that build infrastructure eco-systems like a Kubernetes cluster or a big data warehousing setup and complex blue-green deployments sometimes storing state like with Terraform**
1. jobs that perform sys-admin tasks like backups, monitoring and report production
1. **jobs that do local work and run scripts in and around a laptop or desktop possibly reading credentials and config from stdin**

Now lets clone a project that includes two job types, (1) a simple build from a Dockerfile and push to Dockerhub and jobs (4) that perform integration tests on Terraform modules by building infrastructure in the AWS cloud, validating that infrastructure and then destroying it.


## How to Build and Run the Jenkins Configuration Docker Volume

When docker builds the jenkins volume ([see Dockerfile](Dockerfile)) it creates the home directory and copies in both the **global configuration** and **all the job configurations**.

### Chicken and Egg

There is a Jenkins job that builds the Jenkins job configuration docker image and posts it to DockerHub.

However to bring up Jenkins itself for the very first time these commands are executed by a devops task runner.


### Building and Pushing the Jenkins Volume Docker Image

    $ git clone https://github.com/devops4me/jenkins2-volume devops4me.jenkins2-volume
    $ cd devops4me.jenkins2-volume
    $ docker login --username devops4me
    $ docker build --rm --tag devops4me/jenkins2-volume .
    $ docker push devops4me/jenkins2-volume
    $ docker tag devops4me/jenkins2-volume devops4me/jenkins2-volume:v0.1.0001
    $ docker push devops4me/jenkins2-volume:v0.1.0001

That's it. Check in docker hub to ensure that the image has been pushed with both a **latest tag** and a **versioned tag**.


### Running Jenkins 2

**To run Jenkins 2 locally you issue two docker run commands and use curl to inject the necessary credentials.**

    $ docker ps -a
    $ docker rm -vf $(docker ps -aq)
    $ docker rmi $(docker images -aq) --force
    $ docker run --name=jenkins2-volume devops4me/jenkins2-volume:latest
    $ docker run --tty --privileged --detach \
          --volume       /var/run/docker.sock:/var/run/docker.sock \
          --volume       /usr/bin/docker:/usr/bin/docker \
          --volumes-from jenkins2-volume \
          --publish      8080:8080       \
          --name         jenkins2        \
          devops4me/jenkins2:latest;


**[The full details of running Jenkins2 can be found here.](https://www.devopswiki.co.uk)**


## Installing Jenkins Jobs

Use **git** to pull down the **[Jenkins2 configuration files](https://github.com/devops4me/jenkins2-config)** and then **docker copy** to place them into the Jenkins docker volume.

    $ git clone https://github.com/devops4me/jenkins2-config
    $ cd jenkins2-config
    $ tree
    $ docker cp jobs jenkins2:/var/jenkins_home
    $ docker exec -i jenkins2 bash -c "ls -lah /var/jenkins_home/jobs"
    $ docker cp config.xml jenkins2:/var/jenkins_home/
    $ curl -X POST http://localhost:8080/reload

It includes jobs that use Terraform to create AWS cloud infrastructure and then they destroy it. These are your typical infrastructure module integration testing Jenkins job type.

### Tree of Jenkins Job Configurations

├── rabbitmq-docker-image<br/>
│   ├── config.xml<br/>
│   └── nextBuildNumber<br/>
├── terraform-coreos-ami-id<br/>
│   ├── config.xml<br/>
│   └── nextBuildNumber<br/>
├── terraform-security-groups<br/>
│   ├── config.xml<br/>
│   └── nextBuildNumber<br/>
└── terraform-vpc-network<br/>
    ├── config.xml<br/>
    └── nextBuildNumber<br/>

## Diff of Jenkins Job config.xml

Note that the config.xml in the Terraform (VPC subnets, security groups and fetch CoreOS AMI ID) modules **only differ in three ways** namely

- their directory names (which become the Jenkins job ID)
- their human readable name (within config.xml)
- their Git repository URL

A Jenkinsfile and Dockerfile must exist at the source of their Git repositories. Note that these jobs are configured to

- run at 7am, 11am, 3pm, 7pm and 11pm
- poll the Git SCM repository every 2 minutes and trigger the build if the master branch changes


## Injecting Credentials into Jenkins

The **jobs have all promptly failed** is the prognosis when you visit http://localhost:8080 after the above curl relooad command. The RabbitMQ job needs DockerHub credentials and the **Terraform infrastructure integration tests need AWS cloud credentials**.


## Inject DockerHub Username and Password

The RabbitMQ job is configured to expect credentials with an ID of **safe.docker.login.id**. The DockerHub account username is **devops4me** and lets pretend the password is **password12345** - this would be the curl command you issue.

```bash
curl -X POST 'http://localhost:8080/credentials/store/system/domain/_/createCredentials' \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "safe.docker.login.id",
    "username": "devops4me",
    "password": "password12345",
    "description": "docker login credentials to push built images to Docker registry",
    "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
  }
}'
```

**If your Jenkins server is not at localhost:8080 do not forget to make the change in the first line above.**

## Inject AWS Cloud Credentials

The AWS Credentials spawn from **StringCredentialsImpl** which is a class apart from the DockerHub credentials that hail from **UsernamePasswordCredentialsImpl**.

These are the credential identities that the Terraform jobs expect.

| Credential ID       | Environment Variable  | Description                     |
|:-------------------:|:--------------------- |:------------------------------- |
| safe.aws.access.key | AWS_ACCESS_KEY_ID     | The AWS access key credential.  |
| safe.aws.secret.key | AWS_SECRET_ACCESS_KEY | The AWS secret key credential.  |
| safe.aws.region.key | AWS_REGION            | The AWS region key credential.  |


Look inside their Jenkinsfile and you will see the **environment declaration** which will make the injected credentials available to the environments in each stage and subseequently will be placed into the docker containers via the docker run --env switch.

    environment
    {
        AWS_ACCESS_KEY_ID     = credentials( 'safe.aws.access.key' )
        AWS_SECRET_ACCESS_KEY = credentials( 'safe.aws.secret.key' )
        AWS_REGION            = credentials( 'safe.aws.region.key' )
    }

You must issue the curl command 3 times to inject each of the 3 credentials IDs and their corresponding values. Click on the Credentials item in the Jenkins main menu for some assurance.

## Inject AWS Region Key | safe.aws.region.key

```bash
curl -X POST 'http://localhost:8080/credentials/store/system/domain/_/createCredentials' \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "safe.aws.region.key",
    "secret": "<<region-key-text>>",
    "description": "The AWS region key for example eu-west-1 for Dublin in Ireland.",
    "$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
  }
}'
```

## Inject AWS Access Key | safe.aws.access.key

```bash
curl -X POST 'http://localhost:8080/credentials/store/system/domain/_/createCredentials' \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "safe.aws.access.key",
    "secret": "<<access-key-text>>",
    "description": "The user key of the AWS IAM (programmatic) user credentials.",
    "$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
  }
}'
```

## Inject AWS Secret Key | safe.aws.secret.key

```bash
curl -X POST 'http://localhost:8080/credentials/store/system/domain/_/createCredentials' \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "safe.aws.secret.key",
    "secret": "<<secret-key-text>>",
    "description": "The secret key of the AWS IAM (programmatic) user credentials.",
    "$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
  }
}'
```

**Again - if your Jenkins server is not at localhost:8080 do not forget to make the change in the first line above.**


## Copy Jenkins Configuration and Jobs into Container

The **container** is running and we've **injected** both the Dockerhub credentials and the AWS IAM user credentials into it.

Now all we need do is to **clone and then copy** the **[git repository job configurations](https://github.com/devops4me/jenkins2-volume)** into the Jenkins container at the ubiquitous **`/var/jenkins_home`** location.

```
├── config.xml
├── Dockerfile
├── Jenkinsfile
├── jobs
│   ├── jenkins2-docker-image
│   │   └── config.xml
│   ├── jenkins2-docker-volume
│   │   └── config.xml
│   ├── rabbitmq-3.7-docker-image
│   │   └── config.xml
│   ├── rabbitmq-docker-image
│   │   ├── config.xml
│   │   └── nextBuildNumber
│   ├── terraform-coreos-ami-id
│   │   ├── config.xml
│   │   └── nextBuildNumber
│   ├── terraform-etcd3-cluster
│   │   └── config.xml
│   ├── terraform-load-balancer
│   │   └── config.xml
│   ├── terraform-security-groups
│   │   ├── config.xml
│   │   └── nextBuildNumber
│   └── terraform-vpc-network
│       ├── config.xml
│       └── nextBuildNumber
├── LICENSE
└── README.md
```

Notice in the directory tree above the root config.xml takes of the overall Jenkins configuration whilst the folders and their corresponding config.xml files in the jobs folder is concerned with each job's configuration.

The integer state of **nextBuildNumber** is commonly maintained but it is optional and removing it will simple kick things off from square one.

    $ git clone https://github.com/devops4me/jenkins2-volume
    $ cd jenkins2-volume
    $ docker cp config.xml jenkins2-volume:/var/jenkins_home/config.xml
    $ docker cp jobs jenkins2-volume:/var/jenkins_home
    $ docker exec -i jenkins2 bash -c "ls -lah /var/jenkins_home/jobs"


## Reload Jenkins Configuration

Now that the credentials are in we reload the configuration and click Build Now on the Jobs. They should work!

```bash
curl -X POST http://localhost:8080/reload
```

## Jenkins Design Considerations

These design tips are extremely important in allowing your Jenkins jobs to scale in both volume and complexity whilst maintaining an underlying simplicity in the overall continuous integration architecture.

- look at the 7 types of Jenkins job and maintain them in separate folders
- avoid **dependencies between jobs** to maintain separation of concerns that prevents brittleness in the future


## Reverse Engineer Jenkins Job | Terraform AWS Security Groups

In the Jenkins UI you have changed the configuration of a job called **terraform-security-groups** and now you want to update your Jenkins config in Git.

This snippet pulls down the **updated job's configuration** from Jenkins and does a diff.

    $ git clone https://github.com/devops4me/jenkins2-volume
    $ cd jenkins2-volume/jobs/terraform-security-groups
    $ docker cp jenkins2-volume:/var/jenkins_home/jobs/terraform-security-groups/config.xml config-updated.xml
    $ diff config.xml config-updated.xml


The diff below is shows us that we have decided to keep a maximum of 10 builds for 7 days. We've also changed the Cron timings to run 3 times a day instead of 5. And finally we want light checkouts.

```
7a16,23
>     <jenkins.model.BuildDiscarderProperty>
>       <strategy class="hudson.tasks.LogRotator">
>         <daysToKeep>7</daysToKeep>
>         <numToKeep>10</numToKeep>
>         <artifactDaysToKeep>-1</artifactDaysToKeep>
>         <artifactNumToKeep>-1</artifactNumToKeep>
>       </strategy>
>     </jenkins.model.BuildDiscarderProperty>
12c28
<           <spec>H 7,11,15,19,23 * * *</spec>
---
>           <spec>H 8,14,20 * * *</spec>
41c55
<     <lightweight>false</lightweight>
---
>     <lightweight>true</lightweight>
```

We are happy with what we see so we decide to accept the updated configuration and commit it back into our Jenkins job configuration repository.

    $ rm config.xml
    $ mv config-updated.xml config.xml
    $ git status
    $ git commit -am "Updated configuration of Jenkins terraform-security-groups job."
    $ git push origin master

Note that we do not need any of the other build logs and directories in the jobs folder. All we need to squirrel away when reverse engineering is the config.xml file and maybe the job's build number.

Also re the **job build number** - you can arrange the configuration to respect the job buildnumber in case it is used as part of the tagging/versioning - mitigating the reset resulting in duplicates.

### As rsync not used - we do manual deletions for each job

``` bash
rm ./jobs/<<job-name>>/lastStable
rm ./jobs/<<job-name>>/lastSuccessful
rm ./jobs/<<job-name>>/scm-polling.log
rm -r ./jobs/<<job-name>>/builds
tree
```

The **`tree`** command should show only a config.xml and nextBuildNumber within each job directory.


## Refresh (Forward Engineer) Jenkins Jobs

If we have **created a new job/s** or **updated one or more jobs** - we want to update (refresh) Jenkins so that the new Job configurations take effect. We do this by copying the **[git repository jobs folder](https://github.com/devops4me/jenkins2-volume)** into Jenkins home.

Travel to just below the jobs folder then execute this docker copy command and reload the Jenkins configuration.

    $ docker cp jobs jenkins2-volume:/var/jenkins_home
    $ docker exec -i jenkins2 bash -c "ls -lah /var/jenkins_home/jobs"
    $ curl -X POST http://localhost:8080/reload

### Docker Copy Syncs

**Docker copy syncs instead of brut force copying**. It doesn't remove the jobs folder and replace it with our local copy.

Above when we copy the jobs it simply updates the files that have changed keeping the build history and logs.








