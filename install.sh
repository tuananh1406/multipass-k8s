#!/bin/bash
for instance in controller node1 node2;
do
        echo -e "\e[1m\e[100mTạo ${instance}\e[0m"
        multipass launch --name k3s-${instance} --cpus 2 --mem 1024M --disk 10G

        echo -e "\e[1m\e[100mCài và chạy docker trên controller\e[0m"
        multipass exec k3s-${instance} -- bash -c 'sudo apt update && sudo apt install -y docker.io'
        multipass exec k3s-${instance} -- bash -c 'sudo systemctl start docker && sudo systemctl enable docker'
        echo -e "\e[1m\e[100mThêm user hiện tại vào docker\e[0m"
        multipass exec k3s-${instance} -- bash -c 'sudo usermod -aG docker $USER'
        multipass exec k3s-${instance} -- bash -c 'newgrp docker<<EONG
        exit
        EONG'

        echo -e "\e[1m\e[100mCài đặt k8s\e[0m"
        echo -e "\e[1m\e[100mAdd repo và cài đặt k8s\e[0m"
        multipass exec k3s-${instance} -- bash -c 'curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add && sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"'
        multipass exec k3s-${instance} -- bash -c 'sudo apt update && sudo apt install -y kubeadm kubelet kubectl'
done

for instance in controller node1 node2;
do
        echo -e "\e[1m\e[100mLấy IPV4 của các controller và nodes\e[0m"
        for instance in controller node1 node2;
        do
                IP=$(multipass info k3s-${instance} |grep IPv4|awk '{print $2}')
                echo "$IP"
                multipass exec k3s-${instance} -- sudo bash -c "echo ${IP} ${instance} >> /etc/hosts"
        done

        echo -e "\e[1m\e[100mTắt swap\e[0m"
        multipass exec k3s-${instance} -- bash -c "sudo swapoff -a"
done

for instance in controller node1 node2;
do
        if [ $instance = 'controller' ]; then
                echo -e "\e[1m\e[100mDeploy k8s trên ${instance}\e[0m"
                IP=$(multipass info k3s-controller |grep IPv4|awk '{print $2}')
                multipass exec k3s-${instance} -- bash -c "sudo kubeadm init --pod-network-cidr=${IP}/16 --ignore-preflight-errors=Mem" > ./init.txt
                TOKEN=$(tail -n 2 init.txt | sed -z 's/\n//g;s/\\//')
                echo -e "\e[1m\e[100m ${TOKEN} \e[0m"
                multipass exec k3s-${instance} -- sudo bash -c 'mkdir -p $HOME/.kube'
                multipass exec k3s-${instance} -- sudo bash -c 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
                multipass exec k3s-${instance} -- sudo bash -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
                multipass exec k3s-${instance} -- sudo bash -c 'sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'
        else
                echo -e "\e[1m\e[100mThêm node ${instance} vào k8s controller \e[0m"
                TOKEN=$(tail -n 2 init.txt | sed -z 's/\n//g;s/\\//')
                multipass exec k3s-${instance} -- sudo bash -c "$TOKEN"
        fi
done
