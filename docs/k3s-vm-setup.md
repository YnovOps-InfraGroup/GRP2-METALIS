# Setup VM + k3s — Procédure de reproduction

**Hyperviseur** : OpenNebula `nebula.cloud.enov.local:2616`
**OS** : Ubuntu 24.04.4 LTS
**Date mise à jour** : 24 juin 2026
**Architecture** : 3 nœuds (1 Control-Plane + 2 Workers)

---

## Architecture du Cluster

| Rôle          | Hostname          | IP            | vCPU | RAM   | Disque Data |
| ------------- | ----------------- | ------------- | ---- | ----- | ----------- |
| Control-Plane | `metalis-cp`      | `10.1.248.15` | 4    | 8 GB  | 40 GB       |
| Worker 1      | `metalis-worker1` | `10.1.248.13` | 6    | 16 GB | 80 GB       |
| Worker 2      | `metalis-worker2` | `10.1.248.6`  | 6    | 16 GB | 80 GB       |

**VIP (Keepalived)** : `10.1.248.100` — flottante entre les 2 workers

> Les workloads applicatifs tournent exclusivement sur les workers.
> Le control-plane a un taint `CriticalAddonsOnly` (pas de pods applicatifs).

---

## 1. Prérequis OpenNebula

### Spécifications VM (par nœud worker)

| Ressource         | Valeur                          |
| ----------------- | ------------------------------- |
| vCPU              | 6                               |
| RAM               | 16 GB                           |
| Disque OS (vda)   | 4 GB (Ubuntu cloud image)       |
| Disque Data (sda) | **80 GB** (ajouté manuellement) |
| Réseau            | `eth0` — 10.1.248.0/24          |

> Ajouter la clé SSH publique au profil OpenNebula avant de créer la VM.
> Procédure : https://github.com/Enov-Salle-Serveur/Documentation_Public/blob/main/Procédure/Nebula_Add_SSH_Key.md

### Connexion

```bash
ssh root@10.1.248.15  # Control-Plane
ssh root@10.1.248.13  # Worker 1
ssh root@10.1.248.6   # Worker 2
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

### Control-Plane (metalis-cp — 10.1.248.15)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable=traefik \
  --write-kubeconfig-mode=644 \
  --tls-san=10.1.248.15 \
  --tls-san=10.1.248.100 \
  --node-taint CriticalAddonsOnly=true:NoSchedule \
  --data-dir=/var/lib/rancher" sh -

# Récupérer le token pour les workers
cat /var/lib/rancher/server/node-token
```

### Workers (metalis-worker1, metalis-worker2)

```bash
# Sur chaque worker (remplacer <TOKEN> par le token du CP)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" \
  K3S_URL="https://10.1.248.15:6443" \
  K3S_TOKEN="<TOKEN>" sh -
```

### Vérification (depuis le CP)

```bash
kubectl get nodes -o wide
# metalis-cp       Ready   control-plane,master
# metalis-worker1  Ready   <none>
# metalis-worker2  Ready   <none>
kubectl get pods -A
```

> - `--disable=traefik` : on utilisera ingress-nginx à la place
> - `--node-taint` : empêche les pods applicatifs sur le CP
> - `--tls-san=10.1.248.100` : la VIP Keepalived est ajoutée au certificat

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
kubectl get nodes      # 3 nœuds Ready (metalis-cp, metalis-worker1, metalis-worker2)
df -h /var/lib/rancher # ~74GB libre (sur chaque nœud)
```

---

## 7. Keepalived (VIP haute disponibilité)

> Installe sur les 2 workers une VIP flottante `10.1.248.100` pour l'accès aux applications.
> Voir `PCA/PROCEDURES.md` pour la configuration détaillée.

```bash
apt-get install -y keepalived

# Configuration : /etc/keepalived/keepalived.conf
# Worker1 = MASTER (priority 110)
# Worker2 = BACKUP (priority 90)
systemctl enable --now keepalived
```

---

## 8. Longhorn (stockage distribué)

```bash
# Depuis le CP
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml

# Vérification
kubectl get pods -n longhorn-system --watch
```

> Longhorn réplique les volumes sur les 2 workers (2 replicas par défaut).
> Configuration multipath requise — voir `PCA/PROCEDURES.md`.
