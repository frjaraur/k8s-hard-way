# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')
# Require YAML module
require 'yaml'

config = YAML.load_file(File.join(File.dirname(__FILE__), 'config.yml'))

base_box=config['environment']['base_box']

master_ip=config['environment']['masterip']

domain=config['environment']['domain']

engine_version=config['environment']['engine_version']

k8s_release_url=config['environment']['k8s_release_url']

boxes = config['boxes']

boxes_hostsfile_entries=""

 boxes.each do |box|
   boxes_hostsfile_entries=boxes_hostsfile_entries+box['mgmt_ip'] + ' ' +  box['name'] + ' ' + box['name']+'.'+domain+'\n'
 end

#puts boxes_hostsfile_entries

disable_swap = <<SCRIPT
    sudo swapoff -a 
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
SCRIPT

update_hosts = <<SCRIPT
    echo "127.0.0.1 localhost" >/etc/hosts
    echo -e "#{boxes_hostsfile_entries}" |tee -a /etc/hosts
SCRIPT

enable_ssh_with_password_for_maintenance_jobs = <<SCRIPT
  sed -i "s/PasswordAuthentication .*$/PasswordAuthentication yes/" /etc/ssh/sshd_config
  systemctl restart ssh
SCRIPT

install_certificate_tools = <<SCRIPT
  curl -o /usr/local/bin/cfssl -sSL https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 
  curl -o /usr/local/bin/cfssljson -sSL https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
  chmod +x /usr/local/bin/cfssl* 
SCRIPT


$install_docker_engine = <<SCRIPT
  #curl -sSk $1 | sh
  DEBIAN_FRONTEND=noninteractive apt-get remove -qq docker docker-engine docker.io
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  bridge-utils
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | DEBIAN_FRONTEND=noninteractive apt-key add -
  add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
  DEBIAN_FRONTEND=noninteractive apt-get -qq update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce=$1
  usermod -aG docker vagrant >/dev/null
  iptables -t nat -F
  systemctl stop docker
  ip link set docker0 down
  ip link delete docker0
  brctl addbr cbr0
  ip addr add 172.16.0.0/16 dev cbr0
  ip link set dev cbr0 up
  printf '{\n
  	"iptables": false, \n
	"ip-masq": false, \n
	"bridge": "cbr0" \n
	}\n
  ' >/etc/docker/daemon.json
 
  systemctl start docker
SCRIPT


install_kubernetes_master_binaries = <<SCRIPT
  echo "K8s Master Binaries URL #{k8s_release_url}"
  curl -o /usr/local/bin/kube-apiserver -sSL #{k8s_release_url}/kube-apiserver
  curl -o /usr/local/bin/kube-controller-manager -sSL #{k8s_release_url}/kube-controller-manager
  curl -o /usr/local/bin/kube-scheduler -sSL #{k8s_release_url}/kube-scheduler
  curl -o /usr/local/bin/kubectl -sSL #{k8s_release_url}/kubectl

  chmod +x /usr/local/bin/kube*
  mkdir -p /var/lib/kubernetes/

SCRIPT

install_kubernetes_worker_binaries = <<SCRIPT
apt-get -qq install socat
echo "K8s Workers Binaries URL  #{k8s_release_url}"
curl -o /usr/local/bin/kube-proxy -sSL #{k8s_release_url}/kube-proxy
curl -o /usr/local/bin/kubelet -sSL #{k8s_release_url}/kubelet
curl -o /usr/local/bin/kubectl -sSL #{k8s_release_url}/kubectl

chmod +x /usr/local/bin/kube*
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

  curl -o /tmp/cni-plugins-amd64-v0.6.0.tgz -sSL https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
  curl -o /tmp/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz -sSL https://github.com/containerd/cri-containerd/releases/download/v1.0.0-beta.1/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz

  sudo tar -xvf /tmp/cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
  sudo tar -xvf /tmp/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz -C /

SCRIPT


Vagrant.configure(2) do |config|
   VAGRANT_COMMAND = ARGV[0]
#   if VAGRANT_COMMAND == "ssh"
#    config.ssh.username = 'ubuntu'
#    config.ssh.password = 'ubuntu'
#   end
  config.vm.box = base_box
  config.vm.synced_folder "tmp_deploying_stage/", "/tmp_deploying_stage",create:true
  config.vm.synced_folder "src/", "/src",create:true
  boxes.each do |node|
    config.vm.define node['name'] do |config|
      config.vm.hostname = node['name']
      config.vm.provider "virtualbox" do |v|
        config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"       
      	v.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
        v.name = node['name']
        v.customize ["modifyvm", :id, "--memory", node['mem']]
        v.customize ["modifyvm", :id, "--cpus", node['cpu']]

        v.customize ["modifyvm", :id, "--nictype1", "Am79C973"]
        v.customize ["modifyvm", :id, "--nictype2", "Am79C973"]
        v.customize ["modifyvm", :id, "--nictype3", "Am79C973"]
        v.customize ["modifyvm", :id, "--nictype4", "Am79C973"]
        v.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc4", "allow-all"]
        v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]

        if node['role'] == "client"
          v.gui = true
          v.customize ["modifyvm", :id, "--vram", "64"]
        end


      end

      config.vm.network "private_network",
      ip: node['mgmt_ip'],
      virtualbox__intnet: "LABS"

      #config.vm.network "private_network", :type => 'dhcp', :name => 'vboxnet0', :adapter => 2
      config.vm.network "private_network", ip: node['hostonly_ip']

      config.vm.network "public_network",
      bridge: ["enp4s0","wlp3s0","enp3s0f1","wlp2s0","enp3s0"],
      auto_config: true

      if node['role'] == "manager"
        config.vm.network "forwarded_port", guest: 8001, host: 8001, auto_correct: true
        config.vm.network "forwarded_port", guest: 6443, host: 6443, auto_correct: true
      end

      config.vm.provision "shell", inline: <<-SHELL
        sudo apt-get update -qq && apt-get install -qq ntpdate ntp && timedatectl set-timezone Europe/Madrid
      SHELL

      # Delete default router for host-only-adapter
      #  config.vm.provision "shell",
      #  run: "always",
      #  inline: "route del default gw 192.168.56.1"

      config.vm.provision :shell, :inline => update_hosts
      config.vm.provision :shell, :inline => disable_swap
      config.vm.provision :shell, :inline => enable_ssh_with_password_for_maintenance_jobs

      config.vm.provision "shell", inline: <<-SHELL
        sudo cp -R /src ~vagrant
        sudo chown -R vagrant:vagrant ~vagrant/src
      SHELL
 
        #config.vm.provision "shell", inline: "sudo sed -i 's/allowed_users=.*$/allowed_users=anybody/' /etc/X11/Xwrapper.config"
        #            DEBIAN_FRONTEND=noninteractive apt-get install -qq curl lightdm lubuntu-core lxde-common lubuntu-desktop xinit firefox unzip zip gpm mlocate console-common chromium-browser

      if node['role'] == "client"
        config.vm.provision "shell", inline: <<-SHELL
            echo "vagrant:vagrant"|sudo chpasswd
            DEBIAN_FRONTEND=noninteractive apt-get install -qq xserver-xorg-legacy \
            xfce4-session xfce4-terminal xfce4-xkb-plugin xterm curl xinit firefox unzip zip gpm mlocate console-common chromium-browser
            service gpm start
            update-rc.d gpm enable
            localectl set-x11-keymap es
            localectl set-keymap es
            setxkbmap -layout es
            echo -e "XKBLAYOUT=\"es\"\nXKBMODEL=\"pc105\"\nXKBVARIANT=\"\"\nXKBOPTIONS=\"lv3:ralt_switch,terminate:ctrl_alt_bksp\"" >/etc/default/keyboard
            echo '@setxkbmap -layout "es"'|tee -a /etc/xdg/xfce4/xinitrc
        SHELL

        config.vm.provision "shell", inline: "sudo sed -i 's/allowed_users=.*$/allowed_users=anybody/' /etc/X11/Xwrapper.config"
            #echo '@setxkbmap -option lv3:ralt_switch,terminate:ctrl_alt_bksp "es"' | sudo tee -a /etc/xdg/lxsession/LXDE/autostart
            #echo '@setxkbmap -layout "es"'|tee -a /etc/xdg/lxsession/LXDE/autostart
              next
      end

      ## INSTALLDOCKER --> on script because we can reprovision
      # config.vm.provision "shell" do |s|
     	# 	s.name       = "Install Docker Engine version "+engine_version
      #   s.inline     = $install_docker_engine
      #   s.args       = engine_version
      # end
      

      if node['role'] == "manager"
        config.vm.provision :shell, :inline => install_certificate_tools
        config.vm.provision :shell, :inline => install_kubernetes_master_binaries
      end
      if node['role'] == "worker"
        config.vm.provision :shell, :inline => install_kubernetes_worker_binaries
      end


      ## INSTALLKUBERNETES --> on script because we can reprovision
      # config.vm.provision "shell", inline: <<-SHELL
      #   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
      #   echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list 
      #   apt-get update -qq
      #   apt-get install -y --allow-unauthenticated kubelet kubeadm kubectl kubernetes-cni
      # SHELL


      # config.vm.provision "file", source: "create_cluster.sh", destination: "/tmp/create_cluster.sh"
      # config.vm.provision :shell, :path => 'create_cluster.sh' , :args => [ node['mgmt_ip'], master_ip, calico_url ]

    end
  end

end
