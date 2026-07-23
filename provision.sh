#!/usr/bin/env bash
#
# provision.sh — Gold Master Image per laboratorio TSN (eBPF/XDP + LXD).
# Idempotente: rieseguirlo (vagrant provision) non rompe uno stato esistente.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> [1/10] Aggiornamento indici e sistema"
apt-get update -y
apt-get upgrade -y

echo "==> [2/10] Installazione kernel HWE (Hardware Enablement, 6.14+)"
# Metodo standard Ubuntu LTS per ottenere il kernel 6.x più recente.
apt-get install -y \
  linux-generic-hwe-24.04 \
  linux-headers-generic-hwe-24.04 \
  linux-image-generic-hwe-24.04

echo "==> [3/10] Installazione toolchain eBPF/XDP e utility"
apt-get install -y \
  clang \
  llvm \
  libelf-dev \
  libbpf-dev \
  iproute2 \
  net-tools \
  git \
  build-essential \
  pkg-config \
  linux-tools-generic-hwe-24.04

echo "==> [4/10] Installazione LXD"
# Su Ubuntu 24.04 il pacchetto apt 'lxd' è transitorio verso lo snap.
# Proviamo apt e ripieghiamo sullo snap in modo idempotente.
if ! command -v lxc >/dev/null 2>&1; then
  apt-get install -y lxd || {
    apt-get install -y snapd
    systemctl enable --now snapd.socket || true
    snap install lxd --channel=latest/stable || true
  }
fi

echo "==> [5/10] Inizializzazione non interattiva di LXD"
# --auto è idempotente: non fallisce se LXD è già inizializzato.
if command -v lxc >/dev/null 2>&1; then
  lxd init --auto || true
  # L'utente 'vagrant' gestisce i container senza sudo.
  getent group lxd >/dev/null 2>&1 && usermod -aG lxd vagrant || true
fi

echo "==> [6/10] Installazione Ansible"
# Ansible gira DENTRO questa VM (ansible.cfg del progetto usa
# ansible_connection: local per l'host CUC e community.general.lxd,
# via 'lxc exec', per i container) - va installato qui, non sull'host.
apt-get install -y ansible
if [ -f /opt/tsn_lab/ansible/requirements.yml ]; then
  ansible-galaxy collection install -r /opt/tsn_lab/ansible/requirements.yml
fi

echo "==> [7/10] Modulo mac80211_hwsim persistente (radios=4)"
# 4 radio, una per nodo del prototipo: talker, listener, bridge-repl,
# bridge-elim (ARCHITECTURE.md §1.1). /etc/modules carica il modulo al
# boot ma NON accetta parametri: vanno dichiarati in /etc/modprobe.d,
# altrimenti al riavvio (incluso il 'vagrant reload' subito dopo il
# cambio kernel) il modulo riparte con radios=2 di default, qualunque
# valore sia stato passato al modprobe one-shot qui sotto.
touch /etc/modules
grep -qxF "mac80211_hwsim" /etc/modules || echo "mac80211_hwsim" >> /etc/modules
cat > /etc/modprobe.d/mac80211_hwsim.conf <<'EOF'
options mac80211_hwsim radios=4
EOF
# Se il modulo e' gia' caricato con un numero di radio diverso, ricaricalo
# per applicare subito il parametro persistito sopra.
if lsmod | grep -q '^mac80211_hwsim'; then
  modprobe -r mac80211_hwsim 2>/dev/null || true
fi
modprobe mac80211_hwsim radios=4 2>/dev/null || true

echo "==> [8/10] Installazione kernel mainline 7.1.4"
# Build ufficiale del kernel team Ubuntu (non presente in HWE/apt).
# Non firmato: va bene qui perche' la VM non usa secure boot.
MAINLINE_VER="7.1.4-070104"
MAINLINE_ABI="7.1.4-070104.202607181533"
MAINLINE_BASE="https://kernel.ubuntu.com/mainline/v7.1.4/amd64"
if ! dpkg -l "linux-image-unsigned-${MAINLINE_VER}-generic" 2>/dev/null | grep -q ^ii; then
  tmpdir="$(mktemp -d)"
  for pkg in \
    "linux-headers-${MAINLINE_VER}_${MAINLINE_ABI}_all.deb" \
    "linux-headers-${MAINLINE_VER}-generic_${MAINLINE_ABI}_amd64.deb" \
    "linux-image-unsigned-${MAINLINE_VER}-generic_${MAINLINE_ABI}_amd64.deb" \
    "linux-modules-${MAINLINE_VER}-generic_${MAINLINE_ABI}_amd64.deb"; do
    wget -q -P "$tmpdir" "${MAINLINE_BASE}/${pkg}"
  done

  # Workaround: i maintainer script del kernel mainline invocano run-parts
  # con due directory come argomenti posizionali, sintassi non supportata
  # da debianutils 5.17 (Ubuntu 24.04) -> "run-parts: missing operand".
  # Si disabilitano temporaneamente gli hook e si rifanno a mano i passi
  # (initramfs, grub) che quegli hook avrebbero eseguito.
  for d in preinst.d postinst.d; do
    [ -d "/etc/kernel/$d" ] && mv "/etc/kernel/$d" "/etc/kernel/$d.disabled-mainline-install"
  done

  dpkg -i "$tmpdir"/*.deb

  for d in preinst.d postinst.d; do
    [ -d "/etc/kernel/$d.disabled-mainline-install" ] && mv "/etc/kernel/$d.disabled-mainline-install" "/etc/kernel/$d"
  done

  rm -rf "$tmpdir"

  update-initramfs -c -k "${MAINLINE_VER}-generic"
  update-grub
else
  echo "Kernel mainline ${MAINLINE_VER} gia' installato."
fi

echo "==> [9/10] Compilazione bpftool per il kernel mainline"
# linux-tools-generic-hwe-24.04 fornisce bpftool solo per il kernel HWE:
# per il kernel mainline (non pacchettizzato da apt) si compila lo
# standalone bpftool (upstream, libbpf incluso come submodule).
if ! /usr/local/sbin/bpftool version >/dev/null 2>&1; then
  apt-get install -y libssl-dev
  bpftool_src="$(mktemp -d)"
  git clone --recurse-submodules --depth 1 https://github.com/libbpf/bpftool.git "$bpftool_src"
  make -C "$bpftool_src/src" -j"$(nproc)"
  install -m 0755 "$bpftool_src/src/bpftool" /usr/local/sbin/bpftool
  rm -rf "$bpftool_src"
else
  echo "bpftool standalone gia' presente in /usr/local/sbin."
fi

echo "==> [10/10] Workspace e alias di build eBPF"
# Cartella sincronizzata col workspace host (creata da Vagrant via rsync).
mkdir -p /opt/tsn_lab
chown vagrant:vagrant /opt/tsn_lab || true

# Alias di sistema per compilare programmi eBPF con un comando.
cat > /etc/profile.d/tsn_lab.sh <<'EOF'
# Ambiente laboratorio TSN
export TSN_LAB=/opt/tsn_lab

# Compila un sorgente .bpf.c in oggetto eBPF:  ebpf-build prog.bpf.c prog.o
ebpf-build() {
  if [ "$#" -lt 1 ]; then
    echo "uso: ebpf-build <src.bpf.c> [out.o]"; return 1
  fi
  local src="$1"
  local out="${2:-${src%.bpf.c}.bpf.o}"
  clang -O2 -g -Wall -target bpf \
    -D__TARGET_ARCH_x86 \
    -I/usr/include/"$(uname -m)"-linux-gnu \
    -c "$src" -o "$out" && echo "OK -> $out"
}
alias ebpf='ebpf-build'
EOF
chmod 0644 /etc/profile.d/tsn_lab.sh

echo ""
echo "--- Riepilogo ---"
echo "Kernel attuale : $(uname -r)  (dopo 'vagrant reload' sarà il kernel mainline ${MAINLINE_VER})"
echo "clang          : $(clang --version | head -n1)"
echo "bpftool        : $(/usr/local/sbin/bpftool version 2>/dev/null | head -n1 || echo 'non ancora compilato')"
command -v lxc >/dev/null 2>&1 && echo "LXD            : $(lxc version 2>/dev/null | head -n1)"
command -v ansible >/dev/null 2>&1 && echo "Ansible        : $(ansible --version | head -n1)"
echo "hwsim in /etc/modules: $(grep -c mac80211_hwsim /etc/modules) riga"
echo "Provisioning completato."
