
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
                sh 'echo replace_me_with_a_docker_run'
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
                        def customImage = docker.build( "devops4me/jenkins-2.0" )
                        customImage.push( "v1.0.0" )
                        customImage.push( "latest" )
                    }
                }
            }
        }
    }
}
