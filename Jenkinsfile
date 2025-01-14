pipeline {
    agent {
        docker {
            image 'node:16-buster-slim'
            args '-p 3000:3000'
        }
    }
    triggers {
        pollSCM('H/2 * * * *')
    }
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out the code...'
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
        stage('Manual Approval') {
            steps {
                script {
                    def userInput = input(
                        id: 'ProceedToDeploy', 
                        message: 'Lanjutkan ke tahap Deploy?', 
                        parameters: [
                            choice(name: 'Decision', choices: ['Proceed', 'Abort'], description: 'Pilih salah satu')
                        ]
                    )
                    if (userInput == 'Abort') {
                        error 'Pipeline dihentikan oleh pengguna.'
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
                sh './jenkins/scripts/deliver.sh'
                sh 'sleep 60'
                sh './jenkins/scripts/kill.sh'
            }
        }
    }
    post {
        always {
            echo 'Pipeline selesai.'
        }
    }
}
