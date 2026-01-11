pipeline {
    agent any

    // 1. ประกาศตัวแปร Global ไว้ตรงนี้ แก้ที่เดียวจบ
    environment {
        // Project Info
        IMAGE_NAME      = "express-testing"
        SONAR_PROJECT   = "express-app-testing"
        
        // Nexus Config
        NEXUS_URL       = "nexus:8082"
        NEXUS_REPO      = "nexus:8082/express-testing"
        
        // Credentials IDs
        NEXUS_CREDS     = "nexus-docker-creds"
        SONAR_TOKEN_ID  = "sonar-token"
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs() // ล้างก่อนเริ่มงาน เพื่อความชัวร์
            }
        }

        stage('Clone') {
            steps {
                git credentialsId: 'github-token-cred',
                    url: 'https://github.com/dragonfore4/express-app-testing-demo.git',
                    branch: "master"
            }
        }

        // ⚠️ ต้องเปิดใช้นะครับ ไม่งั้นไม่มี coverage/lcov.info ส่งให้ Sonar
        stage('Build & Test') {
            steps {
                script {
                    sh """
                        docker run --rm \
                        -v ${WORKSPACE}:/app \
                        -w /app \
                        node:lts-alpine \
                        sh -c "npm install && npm test -- --coverage"
                    """
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    withCredentials([string(credentialsId: SONAR_TOKEN_ID, variable: 'SONAR_TOKEN')]) {
                        withSonarQubeEnv("sonarqube-server") {
                            // ล้างโฟลเดอร์ temp ของ scanner
                            sh "rm -rf .scannerwork"
                            
                            sh """
                                docker run --rm \
                                --network host \
                                -u 0:0 \
                                -e SONAR_TOKEN=${SONAR_TOKEN} \
                                -v ${WORKSPACE}:/app \
                                -w /app \
                                sonarsource/sonar-scanner-cli \
                                -Dsonar.projectKey=${SONAR_PROJECT} \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=http://sonarqube:9000 \
                                -Dsonar.working.directory=/app/.scannerwork \
                                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                            """
                        }
                        timeout(time: 5, unit: 'MINUTES') {
                            waitForQualityGate abortPipeline: true
                        }
                    }
                }
            }
        }

        stage("Build & Push to Nexus") {
            steps {
                script {
                    // ใช้ Build Number หรือ Git Commit Hash แทน latest อย่างเดียว เพื่อให้ Track ย้อนหลังได้
                    def imageTag = "${NEXUS_REPO}:${BUILD_NUMBER}" 
                    def latestTag = "${NEXUS_REPO}:latest"

                    sh "docker build -t ${imageTag} ."
                    sh "docker tag ${imageTag} ${latestTag}"

                    // Login แบบปลอดภัย (Pipe password เข้า stdin)
                    withCredentials([usernamePassword(credentialsId: NEXUS_CREDS, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                        sh "echo $PASS | docker login -u $USER --password-stdin ${NEXUS_URL}"
                        sh "docker push ${imageTag}"
                        sh "docker push ${latestTag}"
                        sh "docker logout ${NEXUS_URL}"
                    }
                }
            }
        }
    }

    // 2. Post Actions: จัดการหลังจบงาน (ไม่ว่าจะผ่านหรือพัง)
    post {
        always {
            // ล้าง Workspace เมื่อจบงาน ประหยัดพื้นที่ Disk
            cleanWs()
            // ลบ Docker image ที่สร้างค้างไว้ในเครื่อง Jenkins
            sh "docker rmi ${NEXUS_REPO}:${BUILD_NUMBER} || true"
            sh "docker rmi ${NEXUS_REPO}:latest || true"
        }
        success {
            echo "✅ Pipeline Success! Image pushed to Nexus."
            // ใส่แจ้งเตือน Line/Discord/Slack ตรงนี้ได้
        }
        failure {
            echo "❌ Pipeline Failed!"
        }
    }
}