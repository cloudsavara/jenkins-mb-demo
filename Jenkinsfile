pipeline {
    parameters {
        choice(name: 'action', choices: 'create\ndestroy', description: 'Action to create AWS EKS cluster')
        string(name: 'cluster_name', defaultValue: 'demo', description: 'EKS cluster name')
        string(name: 'terraform_version', defaultValue: '0.14.6', description: 'Terraform version')
    }

    agent any
    environment {
        AWS_ACCESS_KEY_ID     = credentials('jenkins-aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins-aws-secret-access-key')
    }

    stages {
        stage('clone repo') {
            steps {
                git url:'https://github.com/Niranjankolli/EKS-Jenkins-Terraform.git', branch:'main'
            }
        }
        stage('Prepare the setup') {
            steps {
                script {
                    currentBuild.displayName = "#" + env.BUILD_ID + " " + params.action + " eks-" + params.cluster_name
                    plan = params.cluster_name + '.plan'
                    TF_VERSION = params.terraform_version
                }
            }
        }
        stage('Check terraform PATH'){
            steps {
                script{
                    if (fileExists('/usr/bin/terraform')) {
                        echo 'Terraform installed.'
                    }
                    else {
                        echo 'Installing Terraform'
                        sh "wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
                        sh "unzip terraform_${TF_VERSION}_linux_amd64.zip"
                        sh 'sudo mv terraform /usr/bin'
                        echo 'Installing AWS OAM Authenticator'
                        sh "curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/aws-iam-authenticator"
                        sh "curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/kubectl"
                        sh 'chmod +x ./kubectl'
                        sh 'sudo mv kubectl /usr/bin'
                        sh 'sudo chmod +x ./aws-iam-authenticator'
                        sh 'sudo mv aws-iam-authenticator /usr/bin'
                        sh "rm -rf terraform_${TF_VERSION}_linux_amd64.zip"
                    } 
                }
                sh 'terraform version'
                sh 'aws-iam-authenticator help'
                sh 'kubectl version --short --client'

            }
        }
        stage ('Run Terraform Plan') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    sh 'terraform init'
                    sh "terraform plan -var cluster-name=${params.cluster_name} -out ${plan}"                    
                }
            }
        }
        stage ('Deploy Terraform Plan ==> apply') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    if (fileExists('$HOME/.kube')) {
                        echo '.kube Directory Exists'
                     } else {
                        sh 'mkdir -p $HOME/.kube'
                     }
                    echo 'Running Terraform apply'
                    sh 'terraform apply -auto-approve ${plan}'
                    sh 'terraform output -raw kubeconfig > $HOME/.kube/config'
                    sh 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
                    sleep 30
                    sh 'kubectl get nodes'
                    }
                }   
            }   
        }
        stage ('Run Terraform destroy'){
            when { expression { params.action == 'destroy' } }
            steps {
                script {
                    sh 'terraform destroy -auto-approve $plan'
                }
            }
        }
    }
    stage ('Deploy Monitoring') {
        steps {
            script {
                echo 'Deploying promethus and grafana using Ansible playbooks and Helm chars'
                sh 'sudo yum update -y'
                sh "wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
                sh 'sudo yum install epel-release-latest-7.noarch.rpm -y'
                sh 'sudo yum update -y'
                sh 'sudo yum install ansible -y'
                sh 'ansible-galaxy collection install -r requirements.yml'
                sh 'ansible-playbook helm.yml --user jenkins'
                sh 'sleep 20'
                sh 'kubectl get all -n monitoring'
                sh 'export ELB=$(kubectl get svc -n monitoring grafana-test -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")'
                echo 'http://"$ELB"'
            }
         }
      }
   }
}
