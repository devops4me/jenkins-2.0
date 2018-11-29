
pipeline
{
    agent any

    stages
    {
        stage( 'Unit Test Software' )
        {
            agent { dockerfile true }
            steps
            {
                sh 'ls -lah'
                sh 'echo releaseSoftwareToRepo'
            }
        }

        stage( 'Build and Push Image' )
        {
            steps
            {
                script
                {
                    docker.withRegistry('', 'safe.docker.login.id')
                    {
                        def customImage = docker.build("devops4me/jenkins-2.0:${env.BUILD_ID}")
                        customImage.push("${env.BUILD_NUMBER}")
                        customImage.push("latest")
                    }
                }
            }
        }
    }
}
