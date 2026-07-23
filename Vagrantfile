# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Gold Master Image per laboratorio di sviluppo TSN (eBPF/XDP + LXD).
# Provider: libvirt (KVM) — più performante di VirtualBox su Linux nativo.

Vagrant.configure("2") do |config|
  # Box leggera e stabile. Il kernel HWE viene forzato dallo script di provision.
  config.vm.box              = "bento/ubuntu-24.04"
  config.vm.box_architecture = "amd64"
  config.vm.hostname         = "tsn-gold-master"

  config.vm.provider :libvirt do |lv|
    lv.memory               = 4096
    lv.cpus                 = 2
    lv.nested               = true   # necessario per LXD/nested virt
    lv.machine_virtual_size = 40      # GB disco
    lv.cpu_mode             = "host-passthrough"
  end

  # Workspace host <-> VM. La cartella /opt/tsn_lab ospiterà lo Spike e i tool.
  # rsync evita dipendenze NFS/9p e mantiene la VM autonoma.
  config.vm.synced_folder ".", "/opt/tsn_lab",
    type: "rsync",
    rsync__exclude: [".vagrant/", ".git/"]

  # Provisioning "Gold Master" (idempotente).
  config.vm.provision "shell", path: "provision.sh"

  config.vm.provision "shell", inline: <<-SHELL
    echo ""
    echo "=================================================="
    echo " Gold Master pronta."
    echo " Kernel installato: mainline 7.1.4. Esegui 'vagrant reload'"
    echo " una sola volta per avviare col nuovo kernel, poi 'uname -r'."
    echo "=================================================="
  SHELL
end
