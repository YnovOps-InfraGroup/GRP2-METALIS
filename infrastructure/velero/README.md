# 🚀 Velero Backup Infrastructure - Azure Bicep

Infrastructure-as-Code (IaC) pour déployer les ressources Azure nécessaires à **Velero** (solution de backup/restore pour k3s).

## 📋 Vue d'ensemble

Ce Bicep crée:

- ✅ **Resource Group** (`RG-BACKUP-METALIS`)
- ✅ **Storage Account** (Blob storage pour les backups)
- ✅ **Container** (`velero-backups`) pour les fichiers de backup
- ✅ **Service Principal** avec permissions RBAC appropriées

```
Velero (k3s Cluster)
       ↓
   Backups → Azure Blob Storage (velero-backups container)
       ↑
  Service Principal + Storage Key
```

---

## 🔧 Configuration

### Paramètres

| Paramètre           | Valeur                    | Notes                       |
| ------------------- | ------------------------- | --------------------------- |
| **Tenant ID**       | `<votre-tenant-id>`       | Tenant Azure                |
| **Subscription ID** | `<votre-subscription-id>` | Subscription cible          |
| **Resource Group**  | `RG-BACKUP-VELERO`        | Créé ou existant            |
| **Location**        | `swedencentral`           | Modifiable dans `deploy.sh` |
| **Environment**     | `prod`                    | Tag pour organisation       |

---

## 📦 Fichiers

```
velero/
├── main.bicep              # Template Bicep principal (ressources Azure)
├── parameters.biceparam    # Paramètres de déploiement
├── deploy.sh               # Script automatisé de déploiement
└── README.md               # Cette documentation
```

---

## 🚀 Déploiement

# Prérequis

```bash
# Azure CLI installé
az --version

# Vérifier l'authentification
az account show

# Basculer sur votre subscription
az account set --subscription "<votre-subscription-id>"
```

### Option 1: Script automatisé (RECOMMANDÉ)

```bash
cd infrastructure/velero

# Rendre le script exécutable
chmod +x deploy.sh

# Lancer le déploiement
./deploy.sh

# Output: credentials-velero (à donner à Thibaut)
```

### Option 2: Déploiement manuel

```bash
# 1. Créer le Resource Group
az group create \
  --name RG-BACKUP-METALIS \
  --location eastus

# 2. Déployer le Bicep
az deployment group create \
  --name velero-backup-$(date +%Y%m%d-%H%M%S) \
  --resource-group RG-BACKUP-METALIS \
  --template-file main.bicep \
  --parameters parameters.biceparam

# 3. Récupérer les outputs
az deployment group show \
  --name <deployment-name> \
  --resource-group RG-BACKUP-METALIS \
  --query properties.outputs
```

---

## 🔑 Service Principal pour Velero

### Étape 1: Créer le Service Principal

```bash
# Créer le SP avec Contributor role
az ad sp create-for-rbac \
  --name sp-velero-k3s \
  --role Contributor \
  --scopes /subscriptions/<votre-subscription-id>

# Output (SAUVEGARDER):
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "displayName": "sp-velero-metalis",
#   "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "tenant": "3c4107f0-14b9-4991-84e8-0f60a9add6d8"
# }
```

### Étape 2: Compléter `credentials-velero`

Après déploiement, le script génère un fichier `credentials-velero` template:

```bash
cat credentials-velero
```

Remplir avec les valeurs du SP:

```bash
export AZURE_CLIENT_ID="<appId-du-sp>"
export AZURE_CLIENT_SECRET="<password-du-sp>"
```

---

## 📊 Structure des ressources Azure

```
Subscription (<votre-subscription-id>)
  └─ Resource Group (RG-BACKUP-VELERO)
     ├─ Storage Account (<storage-account-name>)
     │  └─ Container (velero-backups)
     │     └─ Blob files (backup snapshots)
     │
     └─ Service Principal (sp-velero-k3s)
        └─ Role Assignment (Storage Blob Data Contributor + Storage Account Contributor)
```

---

## 🔐 Permissions RBAC

Le Service Principal reçoit:

1. **Contributor** sur la subscription (accès général)
2. **Storage Blob Data Contributor** sur le Storage Account (accès backups)

```bicep
# Assigned by main.bicep automatically
roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'  # Storage Blob Data Contributor
```

---

## 📝 Exemple: Fichier `credentials-velero` complet

```bash
cat <<EOF > credentials-velero
# ================================================================
# VELERO CREDENTIALS - AZURE STORAGE
# Generated: 2026-06-17T12:00:00Z
# ================================================================

# Azure Subscription & Tenant
export AZURE_SUBSCRIPTION_ID="709a488b-bab7-45cb-9305-33c64d3d4257"
export AZURE_TENANT_ID="3c4107f0-14b9-4991-84e8-0f60a9add6d8"

# Service Principal Credentials
export AZURE_CLIENT_ID="12345678-1234-1234-1234-123456789012"
export AZURE_CLIENT_SECRET="your-secret-here-very-long-string"

# Azure Configuration
export AZURE_RESOURCE_GROUP="RG-BACKUP-METALIS"
export AZURE_CLOUD_NAME="AzurePublicCloud"

# Storage Configuration
export AZURE_STORAGE_ACCOUNT_ID="metalisvelero1a2b3c4d"
export AZURE_STORAGE_ACCOUNT_KEY="DefaultEndpointsProtocol=https;..."

# Velero Configuration
export VELERO_CONTAINER_NAME="velero-backups"
export VELERO_BUCKET_NAME="velero-backups"

echo "✅ Credentials loaded for Velero"
EOF

chmod 600 credentials-velero
```

---

## 🚚 Donner à Thibaut

Une fois le déploiement réussi:

```bash
# 1. Vérifier que tout fonctionne
az storage container list \
  --account-name metalisvelero... \
  --account-key <storage-key>

# 2. Transmettre à Thibaut:
# - Fichier credentials-velero (SÉCURISÉ)
# - Documentation Velero install (voir docs/k8s-apps-deploy.md)

# 3. Thibaut source le fichier puis installe Velero:
source credentials-velero
helm install velero velero/velero \
  --namespace velero --create-namespace \
  --set configuration.backupStorageLocation.bucket=$VELERO_BUCKET_NAME \
  --set configuration.backupStorageLocation.provider=azure \
  --set configuration.backupStorageLocation.config.resourceGroup=$AZURE_RESOURCE_GROUP \
  --set configuration.backupStorageLocation.config.storageAccount=$AZURE_STORAGE_ACCOUNT_ID \
  ... (voir doc Velero Azure)
```

---

## 🔍 Vérification post-déploiement

```bash
# 1. Vérifier le RG
az group show --name RG-BACKUP-METALIS

# 2. Lister les ressources
az resource list --resource-group RG-BACKUP-METALIS -o table

# 3. Tester la connexion Storage
az storage container list \
  --account-name metalisvelero... \
  --account-key <storage-key>

# 4. Vérifier le SP
az ad sp show --id <client-id>

# 5. Vérifier les role assignments
az role assignment list \
  --scope /subscriptions/709a488b-bab7-45cb-9305-33c64d3d4257 \
  --query "[?principalName=='sp-velero-metalis']"
```

---

## ⚠️ Sécurité

- ✅ Ne JAMAIS committer `credentials-velero` au git
- ✅ Stocker dans gestionnaire de secrets (Bitwarden, 1Password, etc)
- ✅ Rotation des credentials tous les 90 jours recommandée
- ✅ Utiliser Managed Identity si possible (évite les secrets)

---

## 🔄 Alternative: Managed Identity (Plus sécurisé)

Pour éviter les secrets, on peut utiliser une **Azure Managed Identity** attachée à:

- VM OpenNebula (si on redeploie Velero directement)
- AKS managed identity (si passage futur à AKS)

Modifier `main.bicep` pour ajouter Managed Identity au lieu du SP.

---

## 📚 Ressources utiles

- [Velero Azure Plugin](https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Storage REST API](https://learn.microsoft.com/en-us/rest/api/storageservices/)
- [Service Principal Security](https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)

---

## 🤝 Questions / Support

- **Pour Bicep**: Voir `main.bicep` (bien commenté)
- **Pour Velero**: Attendre Thibaut
- **Pour Azure**: Voir docs Microsoft Learn
