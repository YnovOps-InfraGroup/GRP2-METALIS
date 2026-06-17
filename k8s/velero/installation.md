# Documentation d'Installation : Velero sur K3s avec Azure Blob Storage

Ce guide détaille l'installation et la configuration de Velero sur un cluster K3s pour sauvegarder les ressources Kubernetes et les volumes persistants (via Node Agent) vers Azure Blob Storage.

---

## 📋 Prérequis

Avant de commencer, assurez-vous de disposer de :
* Un cluster **K3s** fonctionnel avec `kubectl` configuré et des droits d'administration.
* L'outil **Azure CLI** (`az`) installé sur votre machine d'administration.
* L'outil **jq** installé (`sudo apt install jq`).
* Les droits de création de ressources et de Service Principal sur votre souscription Azure.

---

## 🛠 Étape 1 : Préparation de l'infrastructure Azure

Velero a besoin d'un compte de stockage Azure pour héberger les sauvegardes, ainsi que d'un Service Principal (une identité d'application) pour s'y authentifier de manière sécurisée.

Connectez-vous à votre compte Azure :
```bash
az login
```
Exécutez le script suivant pour provisionner automatiquement les ressources nécessaires. Pensez à modifier les variables selon vos conventions de nommage et votre région.

```Bash
# 1. Définition des variables
AZ_RESOURCE_GROUP="rg-velero-backups"
AZ_STORAGE_ACCOUNT="stvelerok3s$(date +%s)" # Doit être unique au monde
AZ_CONTAINER="velero-blob"
AZ_LOCATION="francecentral" # ex: francecentral, westeurope
AZ_SP_NAME="sp-velero-k3s"

# 2. Création du Resource Group
az group create --name $AZ_RESOURCE_GROUP --location $AZ_LOCATION -o none

# 3. Création du Storage Account
az storage account create \
  --name $AZ_STORAGE_ACCOUNT \
  --resource-group $AZ_RESOURCE_GROUP \
  --location $AZ_LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --access-tier Hot -o none

# 4. Création du Conteneur Blob
az storage container create \
  --name $AZ_CONTAINER \
  --public-access off \
  --account-name $AZ_STORAGE_ACCOUNT -o none

# 5. Récupération des IDs pour les droits
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
STORAGE_ACCOUNT_ID=$(az storage account show --name $AZ_STORAGE_ACCOUNT --resource-group $AZ_RESOURCE_GROUP --query id -o tsv)

# 6. Création du Service Principal avec les droits d'écriture sur les blobs
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name $AZ_SP_NAME \
  --role "Storage Blob Data Contributor" \
  --scopes $STORAGE_ACCOUNT_ID \
  --query "{clientId: appId, clientSecret: password}" -o json)

CLIENT_ID=$(echo $SP_OUTPUT | jq -r .clientId)
CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r .clientSecret)

# 7. Affichage des identifiants (à conserver pour l'Étape 2)
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_CLIENT_ID=$CLIENT_ID"
echo "AZURE_CLIENT_SECRET=$CLIENT_SECRET"
echo "AZURE_RESOURCE_GROUP=$AZ_RESOURCE_GROUP"
echo "AZURE_STORAGE_ACCOUNT=$AZ_STORAGE_ACCOUNT"
echo "AZURE_CONTAINER=$AZ_CONTAINER"
```
## 🔐 Étape 2 : Création du fichier de credentials
Sur votre nœud K3s, créez un fichier credentials-velero contenant les identifiants générés à l'étape précédente
```Bash
cat <<EOF > credentials-velero
AZURE_SUBSCRIPTION_ID="<Votre_Subscription_ID>"
AZURE_TENANT_ID="<Votre_Tenant_ID>"
AZURE_CLIENT_ID="<Votre_Client_ID>"
AZURE_CLIENT_SECRET="<Votre_Client_Secret>"
AZURE_RESOURCE_GROUP="<Votre_Resource_Group>"
AZURE_CLOUD_NAME="AzurePublicCloud"
EOF
```

## 💻 Étape 3 : Installation de la CLI Velero
Téléchargez et installez l'outil en ligne de commande Velero sur le nœud maître de votre cluster K3s. (Remplacez la version par la dernière stable si nécessaire).
```Bash
wget [https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-amd64.tar.gz](https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-amd64.tar.gz)
tar -xvf velero-v1.14.0-linux-amd64.tar.gz
sudo mv velero-v1.14.0-linux-amd64/velero /usr/local/bin/
```
Vérifiez l'installation :
```Bash
velero version --client-only
```
## 🚀 Étape 4 : Déploiement de Velero sur le cluster K3s
Exécutez la commande d'installation. Cette commande déploie les pods Velero, configure le plugin Azure et active le Node Agent (requis pour sauvegarder le contenu des volumes montés via HostPath ou Local Path sur K3s).

Remplacez <Votre_Container_Blob>, <Votre_Resource_Group> et <Votre_Storage_Account> par les valeurs obtenues à l'Étape 1.
```Bash
velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.10.0 \
  --bucket <Votre_Container_Blob> \
  --secret-file ./credentials-velero \
  --backup-location-config resourceGroup=<Votre_Resource_Group>,storageAccount=<Votre_Storage_Account> \
  --use-node-agent
```
## 🔍 Étape 5 : Vérification et Premier Test
Vérifiez que tous les composants Velero sont bien démarrés (cela peut prendre une minute) :

```Bash
kubectl get pods -n velero
```
Vous devriez voir un pod velero et un ou plusieurs pods node-agent avec le statut Running.

Lancer une sauvegarde de test
Pour tester que tout fonctionne, créez une sauvegarde incluant tous les namespaces :

```Bash
velero backup create test-backup-01
```
Vérifiez le statut de la sauvegarde :

```Bash
velero backup describe test-backup-01
# ou
velero backup get
```
Si le statut affiche Completed, l'installation est un succès ! Les données sont désormais stockées de manière sécurisée sur Azure.

## 🗑 Commandes Utiles (Aide-Mémoire)
Restaurer une sauvegarde :

```Bash
velero restore create --from-backup test-backup-01
```
Voir les journaux d'une sauvegarde :

```Bash
velero backup logs test-backup-01
```
Désinstaller complètement Velero du cluster :

```Bash
kubectl delete namespace/velero clusterrolebinding/velero
kubectl delete crds -l component=velero
```