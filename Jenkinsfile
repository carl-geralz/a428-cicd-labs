node {
    properties([
        pipelineTriggers([
            pollSCM('H/2 * * * *')
        ])
    ])
    agent {
        docker {
            image 'node:16-buster-slim' 
            args '-p 3000:3000' 
        }
    }
    stage('Checkout') {
        steps {
            checkout scm
        }
    }
    stage('Build') {
        steps {
            echo 'Building the project...'
            sh 'npm install'
        }
    }
    stage('Test') {
        steps {
            echo 'Running tests...'
            sh './jenkins/scripts/test.sh'
        }
    }
}
