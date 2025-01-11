node {
    properties([
        pipelineTriggers([
            pollSCM('H/2 * * * *')
        ])
    ])
    
    docker.image('node:16-buster-slim').inside('-p 3000:3000') {
        
        stage('Checkout') {
            echo 'Checking out the code...'
            checkout scm
        }
        
        stage('Build') {
            echo 'Building the project...'
            sh 'npm install'
        }
        
        stage('Test') {
            echo 'Running tests...'
            sh './jenkins/scripts/test.sh'
        }
    }
}