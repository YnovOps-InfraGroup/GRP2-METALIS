# Setup VM + k3s — Procédure de reproduction

**VM** : OpenNebula `nebula.cloud.enov.local:2616`
**IP** : `10.1.248.6`
**OS** : Ubuntu 24.04.4 LTS
**Date** : 29 mai 2026

---

## 1. Prérequis OpenNebula

### Spécifications VM

| Ressource | Valeur |
|---|---|
| vCPU | 6 |
| RAM | 16 GB |
| Disque OS (vda) | 4 GB (Ubuntu cloud image) |
| Disque Data (sda) | **80 GB** (ajouté manuellement) |
| Réseau | `eth0` — 10.1.248.0/24 |

> Ajouter la clé SSH publique au profil OpenNebula avant de créer la VM.
> Procédure : https://github.com/Enov-Salle-Serveur/Documentation_Public/blob/main/Procédure/Nebula_Add_SSH_Key.md

### Connexion

```bash
ssh root@10.1.248.6
```

---

## 2. Prérequis système

```bash
# Hostname
hostnamectl set-hostname metalis-k3s
echo "127.0.1.1 metalis-k3s" >> /etc/hosts

# Locale
localectl set-locale LANG=en_US.UTF-8
echo 'LC_ALL=en_US.UTF-8' >> /etc/environment

# Kernel modules requis par k3s/containerd
cat > /etc/modules-load.d/k3s.conf << EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl réseau Kubernetes
cat > /etc/sysctl.d/99-k3s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.rp_filter         = 0
vm.swappiness                       = 0
fs.inotify.max_user_instances       = 8192
fs.inotify.max_user_watches         = 524288
EOF
sysctl --system

# Swap désactivé (k3s l'exige)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Firewall désactivé (k3s gère iptables)
ufw disable

# DNS (si résolution absente)
mkdir -p /etc/systemd/resolved.conf.d/
printf '[Resolve]\nDNS=8.8.8.8 1.1.1.1\nFallbackDNS=8.8.4.4\n' \
  > /etc/systemd/resolved.conf.d/dns.conf
systemctl restart systemd-resolved
```

---

## 3. Disque de données (sda → /var/lib/rancher)

> k3s stocke images containers + PVC dans `/var/lib/rancher`.
> On monte le disque 80 GB dessus pour ne pas saturer le disque OS.

```bash
# Partition + format
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary ext4 0% 100%
sleep 1
mkfs.ext4 -F /dev/sda1

# Montage permanent
mkdir -p /var/lib/rancher
mount /dev/sda1 /var/lib/rancher
UUID=$(blkid -s UUID -o value /dev/sda1)
echo "UUID=$UUID /var/lib/rancher ext4 defaults,nofail 0 2" >> /etc/fstab
```

---

## 4. Paquets système

```bash
apt-get update
apt-get install -y curl wget git ca-certificates \
  open-iscsi nfs-common socat conntrack ipset apparmor
```

---

## 5. Installation k3s

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable=traefik \
  --write-kubeconfig-mode=644 \
  --data-dir=/var/lib/rancher" sh -

# Vérification
kubectl get nodes -o wide
kubectl get pods -A
```

> - `--disable=traefik` : on utilisera ingress-nginx à la place
> - `--data-dir=/var/lib/rancher` : pointe vers le disque 80 GB
> - `--write-kubeconfig-mode=644` : kubeconfig lisible sans sudo

---

## 6. Installation Helm 3

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version --short

# Repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# KUBECONFIG
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /root/.bashrc
```

---

## Vérification finale

```bash
k3s --version          # k3s version v1.35.5+k3s1
helm version --short   # v3.21.0
kubectl get nodes      # metalis-k3s   Ready
df -h /var/lib/rancher # ~74GB libre
```
