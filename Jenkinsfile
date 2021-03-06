pipeline {
    parameters {
        choice(name: 'action', choices: 'create\ndestroy', description: 'Action to create AWS EKS cluster')        
        string(name: 'cluster_name', defaultValue: 'demo', description: 'EKS cluster name')
        string(name: 'terraform_version', defaultValue: '0.14.6', description: 'Terraform version')
    }

    agent any
    environment {
        VAULT_TOKEN = credentials('vault_token')
        eksEnvs = "dev,qa,prod"
    }

    stages {
        stage('Retrieve AWS creds from vault'){
            when { expression { params.action == 'create' } }
            steps {
                script {
                    def host=sh(script: 'curl http://169.254.169.254/latest/meta-data/public-ipv4', returnStdout: true)
                    echo "$host"
                    sh "export VAULT_ADDR=http://${host}:8200"
                    sh 'export VAULT_SKIP_VERIFY=true'
                    sh "curl --header 'X-Vault-Token: ${VAULT_TOKEN}' --request GET http://${host}:8200/v1/MY_CREDS/data/secret > mycreds.json"
                    sh 'cat mycreds.json | jq -r .data.data.aws_access_key_id > awskeyid.txt'
                    sh 'cat mycreds.json | jq -r .data.data.aws_secret_access_key > awssecret.txt'
                    AWS_ACCESS_KEY_ID = readFile('awskeyid.txt').trim()
                    AWS_SECRET_ACCESS_KEY = readFile('awssecret.txt').trim()
                }
            }
        }
        stage('clone repo') {
            steps {
                git url:"https://github.com/kodekolli/jenkins-mb-demo.git", branch:'master'
            }
        }
        stage('Prepare the setup') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    currentBuild.displayName = "#" + env.BUILD_ID + " " + params.action + "-eks-" + params.cluster_name
                    plan = params.cluster_name + '.plan'
                    TF_VERSION = params.terraform_version
                }
            }
        }
        stage('Check terraform PATH'){
            when { expression { params.action == 'create' } }
            steps {
                script{
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
                    echo "Copying AWS cred to ${HOME} directory"
                    sh "mkdir -p $HOME/.aws"
                    sh """
                    set +x
                    cat <<-EOF | tee $HOME/.aws/credentials
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}"""
                    
                }
                sh 'terraform version'
                sh 'aws-iam-authenticator help'
                sh 'kubectl version --short --client'

            }
        }
        stage ('Deploy Clusters to EKS using Terraform') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    def env = eksEnvs.split(',')
                    for (type in env){
                        sh 'terraform init'
                        sh "terraform workspace new ${type}"
                        plan = "${type}_"+ params.cluster_name + '.plan'
                        sh "terraform plan -out=${plan} -var env=${type}"
                        sh "terraform apply ${plan}"
                    }
                }
            }
        }
        stage ('Deploy Monitoring') {
            when { expression { params.action == 'create' } }
            steps {
                script {
                    def env = eksEnvs.split(',')
                    sh 'mkdir -p $HOME/.kube'
                    sh 'sudo mkdir -p /root/.kube'
                    sh 'sudo mkdir -p /root/.aws'
                    sh 'sudo cp $HOME/.aws/credentials /root/.aws'
                    for (type in env){
                        sh "terraform workspace select ${type}"                        
                        sh "terraform output -raw kubeconfig > $HOME/.kube/${type}config"
                        sh "sudo cp $HOME/.kube/${type}config /root/.kube"                        
                        echo "Deploying promethus and grafana using Ansible playbooks and Helm chars on ${type} environment"
                        sh 'ansible-galaxy collection install -r requirements.yml'
                        sh "export KUBECONFIG=$HOME/.kube/${type}config"
                        sh "ansible-playbook helm.yml --user jenkins -e config=$HOME/.kube/${type}config"
                        sh 'sleep 20'
                        sh "kubectl get all -n grafana --kubeconfig=$HOME/.kube/${type}config"
                        sh "kubectl get all -n prometheus --kubeconfig=$HOME/.kube/${type}config"
                        sh 'export ELB=$(kubectl get svc --kubeconfig=$KUBECONFIG -n grafana grafana -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")'
                    }
                }
            }
        }
        stage ('Run Terraform destroy'){
            when { expression { params.action == 'destroy' } }
            steps {
                script {
                    def env = eksEnvs.split(',')
                    for (type in env){
                        sh "kubectl delete ns grafana --kubeconfig=$HOME/.kube/${type}config || true"
                        sh "kubectl delete ns prometheus --kubeconfig=$HOME/.kube/${type}config || true"
                        sh "terraform workspace select ${type}"
                        sh "terraform destroy --auto-approve"
                        sh "terraform workspace select default"
                        sh "terraform workspace delete ${type}"
                    }                    
                }                
            }
        }
    }
}
