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
                sh 'docker network create consul_consul || true'
                sh 'docker compose config'
                sh 'docker compose build'
            }
        }

        stage('Squash & Merge PR') {
            when {
                changeRequest()
            }
            steps {
                echo "Build succeeded. Squashing and merging PR #${env.CHANGE_ID} into ${env.CHANGE_TARGET}..."
                withCredentials([string(credentialsId: 'github-token', variable: 'GH_TOKEN')]) {
                    sh "gh pr merge ${env.CHANGE_ID} --squash --delete-branch"
                }
            }
        }

        stage('Deploy & Update Container') {
            when {
                branch 'master'
            }
            steps {
                echo "Deploying update on master branch..."
                sh 'docker network create consul_consul || true'
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
