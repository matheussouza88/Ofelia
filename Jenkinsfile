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

        stage('Build & Auto-Merge PR') {
            when {
                changeRequest()
            }
            steps {
                echo "Building and validating PR #${env.CHANGE_ID} from branch ${env.CHANGE_BRANCH}..."
                sh 'docker compose config'
                sh 'docker compose build'
            }
            post {
                success {
                    echo "Build passed for PR #${env.CHANGE_ID}. Automatically squashing and merging PR into ${env.CHANGE_TARGET}..."
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
