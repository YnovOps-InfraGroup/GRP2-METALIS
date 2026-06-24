# PRA METALIS — Plan de Reprise d'Activité sur Azure

## Vue d'ensemble

Infrastructure PRA (Plan de Reprise d'Activité) pour METALIS.
En cas de sinistre majeur sur le site on-prem, une VM Azure dormante est activée
pour restaurer les services critiques depuis les sauvegardes Velero.

| Paramètre        | Valeur                                   |
| ---------------- | ---------------------------------------- |
| **RTO**          | 4h (bascule manuelle automatisée)        |
| **RPO**          | 24h (sauvegarde Velero quotidienne 2h00) |
| **VM Azure**     | B2s (2 vCPU, 4GB) — éteinte par défaut   |
| **Région**       | Switzerland North                        |
| **Coût dormant** | ~7€/mois (disque + IP)                   |
| **Coût actif**   | ~40€/mois (compute + disque + IP)        |

## Architecture

```
ON-PREM (PCA)                           AZURE (PRA)
┌──────────────┐                        ┌──────────────────────┐
│ k3s cluster  │   Velero (2h AM)       │ rg-metalis-pra       │
│ 10.1.248.6   │ ──────────────────►    │                      │
│ ├─ WordPress │                        │ vm-metalis-pra (OFF) │
│ ├─ Odoo      │                        │ ├─ k3s pré-installé  │
│ ├─ Monitoring│                        │ ├─ Velero CLI         │
│ └─ Velero    │                        │ └─ 64GB Standard HDD │
└──────────────┘                        └──────────────────────┘
       │                                         ▲
       │         ┌─────────────────┐             │
       └────────►│ stobkpmetalis974│─────────────┘
                 │ contmetalisbkp974│  Velero restore
                 └─────────────────┘
```

## Structure des fichiers

```
PRA/
├── terraform/
│   ├── providers.tf            # Config Terraform + provider Azure
│   ├── variables.tf            # Variables (VM, réseau, Velero)
│   ├── network.tf              # VNet + Subnet + NSG
│   ├── vm.tf                   # VM + NIC + IP publique
│   ├── outputs.tf              # Outputs utiles
│   ├── cloud-init.yaml         # Bootstrap k3s + outils
│   └── terraform.tfvars.example # Exemple de configuration
├── scripts/
│   ├── activate-pra.sh         # Démarrer VM + restaurer Velero
│   └── deactivate-pra.sh       # Désallouer VM (0€ compute)
├── RUNBOOK.md                  # Procédure opérateur complète
└── README.md                   # Ce fichier
```

## Quick Start

### 1. Prérequis

```bash
# Azure CLI
az login --tenant ***REDACTED_TENANT_ID***
az account set --subscription ***REDACTED_SUB_ID***

# Terraform
terraform --version  # >= 1.5.0

# Clé SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/pra_metalis -N ""
```

### 2. Déployer l'infrastructure PRA

```bash
cd PRA/terraform

# Configurer les variables
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars : remplacer ssh_public_key par le contenu de ~/.ssh/pra_metalis.pub

# Déployer
terraform init
terraform plan
terraform apply

# Attendre cloud-init (~3-5 min)
PUBLIC_IP=$(terraform output -raw public_ip_address)
ssh -i ~/.ssh/pra_metalis azureuser@$PUBLIC_IP "sudo cloud-init status --wait"

# Vérifier k3s
ssh -i ~/.ssh/pra_metalis azureuser@$PUBLIC_IP "sudo kubectl get nodes"

# Désallouer la VM (mode dormant — 0€ compute)
az vm deallocate --resource-group rg-metalis-pra --name vm-metalis-pra
```

### 3. Activer le PRA (en cas de sinistre)

```bash
cd PRA/scripts

export VELERO_SP_CLIENT_ID="***REDACTED_SP_ID***"
export VELERO_SP_CLIENT_SECRET="votre-secret"
export PRA_SSH_KEY="$HOME/.ssh/pra_metalis"

chmod +x activate-pra.sh
./activate-pra.sh
```

### 4. Désactiver le PRA (retour on-prem)

```bash
chmod +x deactivate-pra.sh
./deactivate-pra.sh
```

## Estimation des coûts (Switzerland North)

| État        | Ressource                   | Coût/mois |
| ----------- | --------------------------- | --------- |
| **Dormant** | Disque OS 64GB Standard HDD | ~3€       |
| **Dormant** | IP Publique Standard        | ~4€       |
| **Dormant** | **Total**                   | **~7€**   |
| **Actif**   | VM B2s (2 vCPU, 4GB)        | ~30€      |
| **Actif**   | Disque + IP                 | ~7€       |
| **Actif**   | **Total**                   | **~37€**  |

> Pour réduire à ~3€/mois dormant : mettre `create_public_ip = false` dans terraform.tfvars.
> L'IP sera créée automatiquement à l'activation et supprimée à la désactivation.

## GitHub Actions

Un workflow GitHub Actions est disponible dans `.github/workflows/pra-deploy.yml`
pour activer/désactiver le PRA depuis l'interface GitHub.

**Secrets à configurer dans GitHub :**

- `AZURE_CREDENTIALS` — JSON du Service Principal
- `VELERO_SP_CLIENT_ID` — Client ID du SP Velero
- `VELERO_SP_CLIENT_SECRET` — Secret du SP Velero
- `SSH_PRIVATE_KEY` — Clé SSH privée pour la VM PRA

## Voir aussi

- [RUNBOOK.md](RUNBOOK.md) — Procédure opérateur détaillée
- [../k8s/velero/installation.md](../k8s/velero/installation.md) — Installation Velero on-prem
- [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — Architecture globale
