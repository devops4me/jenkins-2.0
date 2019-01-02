
# Installing Jenkins 2.0 | Docker Pipeline Manager

This repository contains the docker container that supports a fully configured Jenkins 2.0 service with continuous jobs running under the auspices of docker pipelines declaratively defined by a Jenkinsfile.

Let's walk through the 3 steps required to bring up a fully operational Jenkins service from nought.


---


## Usage

**We only need *3 steps* to get Jenkins 2.0 up and running.**

1. **run the jenkins 2.0 docker container**
1. *inject the Dockerhub and AWS IAM user credentials*
1. ask Jenkins to **reload its configuration**

The job set includes one where Jenkins builds its own container image and pushes it to Dockerhub.


### Step 1 - Run the Jenkins 2.0 Docker Container

``` bash
docker run --tty --privileged --detach \
          --volume       /var/run/docker.sock:/var/run/docker.sock \
          --volume       /usr/bin/docker:/usr/bin/docker \
          --publish      8080:8080       \
          --name         jenkins-2.0     \
          devops4me/jenkins-2.0;
```

---

### Step 2 - Inject the DockerHub and AWS Credentials

We must inject the credentials before copying in the batch of Jenkins jobs otherwise the jobs will promptly fail as they discover they can't talk to the AWS cloud or login to Dockerhub.


``` bash
safe open <<chapter>> <<verse>>
safe jenkins post docker http://localhost:8080
safe open <<chapter>> <<verse>>
safe jenkins post aws http://localhost:8080
```


**This printout shows safe in action injecting the AWS IAM user access key credential.**

```
 - Jenkins Host Url : http://localhost:8080/credentials/store/system/domain/_/createCredentials
 -   Credentials ID : safe.aws.access.key
 - So what is this? : The access key of the AWS IAM (programmatic) user credentials.

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   369    0     0  100   369      0  14760 --:--:-- --:--:-- --:--:-- 14760
```

---


### Step 3 - Reload Jenkins' Configuration

``` bash
curl -X POST http://localhost:8080/reload
```


---


## Jenkins is now running | http://localhost:8080

Well done - **[visit Jenkins in any browser](http://localhost:8080)** and marvel at how it takes on its workload like the faithful butler it is.

The next hurdle is to get a **Jenkins cluster up and running** or connect the Jenkins head to a Kubernetes backend for managing huge docker oriented workloads.


## Prerequisites | Back to Square One

**Why are we going back to square one?**

### Build the first volume and Jenkins 2.0 Service Images

Did you know that Jenkins can start building its own container image ( **[look at job jenkins-2.0-docker-image](jobs/jenkins-2.0-docker-image/config.xml)** ) once it is up and running.

However we must get back to square one to demonstrate how to make **the very first Jenkins chicken (or egg)**!


    $ git clone https://github.com/devops4me/jenkins-2.0 docker.jenkins-2.0
    $ cd docker.jenkins-2.0
    $ docker build --rm --tag devops4me/jenkins-2.0 .
    $ safe open dockerhub devops4me     # if the safe credentials manager is installed
    $ safe docker login                 # if the safe credentials manager is installed
    $ docker push devops4me/jenkins-2.0
    $ docker tag devops4me/jenkins-2.0 devops4me/jenkins-2.0:v0.1.0001
    $ docker push devops4me/jenkins-2.0:v0.1.0001
    $ safe docker logout                 # if the safe credentials manager is installed



## Docker | How to start from scratch!

**This is how to start from scratch and remove all docker containers and images.**

```bash
docker rm -vf $(docker ps -aq)
docker rmi $(docker images -aq) --force
```

How about checking whether everything really has gone.

```bash
docker ps -a
docker images -a
```


---


When docker builds the jenkins volume ([see Dockerfile](Dockerfile)) it creates the home directory and copies in both the **global configuration** and **all the job configurations**.



## Installing Jenkins Jobs

Use **git** to pull down the **[Jenkins2 configuration files](https://github.com/devops4me/jenkins2-config)** and then **docker copy** to place them into the Jenkins docker volume.

    $ git clone https://github.com/devops4me/jenkins2-config
    $ cd jenkins2-config
    $ tree
    $ docker cp jobs jenkins2:/var/jenkins_home
    $ docker exec --interactive --tty j2volume bash -c "ls -lah /var/jenkins_home"
    $ docker cp config.xml jenkins2:/var/jenkins_home/
    $ curl -X POST http://localhost:8080/reload

It includes jobs that use Terraform to create AWS cloud infrastructure and then they destroy it. These are your typical infrastructure module integration testing Jenkins job type.

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


## The 7 Jenkins Job Types

It pays to understand the 7 types of Jenkins job because you can group job requirements, dependencies and value-add in a generic manner depending on the job type. The 7 most prominent job classes in Jenkins are

1. **simple jobs that build a Docker image (from a Dockerfile) and push it to Dockerhub**
1. dockerized microservices with a Dockerfile that is built, run, tested and then pushed into a Docker registry
1. **non-dockerized software like CLIs (Ruby Gems, Python Wheels, Maven2 jars) which are built and tested inside a container and then released to a software package repository, and the container discarded**
1. infrastructure modules (like Terraform) embedded in Docker that build infrastructure in a cloud, test that infrastructure and destroy it
1. **jobs that build infrastructure eco-systems like a Kubernetes cluster or a big data warehousing setup and complex blue-green deployments sometimes storing state like with Terraform**
1. jobs that perform sys-admin tasks like backups, monitoring and report production
1. **jobs that do local work and run scripts in and around a laptop or desktop possibly reading credentials and config from stdin**


