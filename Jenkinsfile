pipeline {
    agent any

    environment {
        APP_NAME = 'app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build PR') {
            when {
                changeRequest()
            }
            steps {
                echo "Building and validating PR #${env.CHANGE_ID} from branch ${env.CHANGE_BRANCH}..."
                sh 'docker compose config'
                sh 'docker compose build'
            }
        }

        stage('Deploy & Update Container') {
            when {
                branch 'master'
            }
            steps {
                echo "Deploying update on master branch..."
                sh 'docker compose build'
                sh 'docker compose up -d --remove-orphans'
            }
        }
    }

    post {
        always {
            echo "Pipeline execution completed for branch ${env.BRANCH_NAME}."
        }
    }
}
