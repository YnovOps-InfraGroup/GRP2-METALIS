#!/bin/bash
# ================================================================
# PRA METALIS — Script d'Activation
# Démarre la VM PRA, installe Velero, restaure les backups
#
# Usage:
#   export VELERO_SP_CLIENT_ID="d03caba9-..."
#   export VELERO_SP_CLIENT_SECRET="Fq38Q~..."
#   ./activate-pra.sh
#
# Prérequis:
#   - Azure CLI authentifié (az login)
#   - Clé SSH pour la VM PRA (~/.ssh/id_rsa)
#   - Variables VELERO_SP_CLIENT_ID et VELERO_SP_CLIENT_SECRET
# ================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
RESOURCE_GROUP="${PRA_RESOURCE_GROUP:-rg-metalis-pra}"
VM_NAME="${PRA_VM_NAME:-vm-metalis-pra}"
ADMIN_USER="${PRA_ADMIN_USER:-azureuser}"
SSH_KEY="${PRA_SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Velero — même config que l'on-prem
VELERO_STORAGE_ACCOUNT="${VELERO_STORAGE_ACCOUNT:-stobkpmetalis974}"
VELERO_CONTAINER="${VELERO_CONTAINER:-contmetalisbkp974}"
VELERO_RESOURCE_GROUP="${VELERO_RESOURCE_GROUP:-rg-metalis}"
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-***REDACTED_SUB_ID***}"
AZURE_TENANT_ID="${AZURE_TENANT_ID:-***REDACTED_TENANT_ID***}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Vérifications ────────────────────────────────────────────
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚨 ACTIVATION PRA METALIS — Azure                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"

if [[ -z "${VELERO_SP_CLIENT_ID:-}" ]] || [[ -z "${VELERO_SP_CLIENT_SECRET:-}" ]]; then
  echo -e "${RED}❌ Variables requises manquantes :${NC}"
  echo "   export VELERO_SP_CLIENT_ID=\"***REDACTED_SP_ID***\""
  echo "   export VELERO_SP_CLIENT_SECRET=\"votre-secret\""
  exit 1
fi

if ! az account show &>/dev/null; then
  echo -e "${RED}❌ Azure CLI non authentifié. Exécuter :${NC}"
  echo "   az login --tenant $AZURE_TENANT_ID --subscription $AZURE_SUBSCRIPTION_ID"
  exit 1
fi

echo -e "${YELLOW}Configuration :${NC}"
echo "  Resource Group : $RESOURCE_GROUP"
echo "  VM             : $VM_NAME"
echo "  Velero Storage : $VELERO_STORAGE_ACCOUNT / $VELERO_CONTAINER"
echo ""

# ─── Étape 1 : Démarrage VM ──────────────────────────────────
echo -e "${YELLOW}[1/8] Démarrage de la VM PRA...${NC}"
az vm start --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --no-wait
echo "  Attente du démarrage..."
az vm wait --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --created 2>/dev/null || true
sleep 10
echo -e "${GREEN}✅ VM démarrée${NC}"

# ─── Étape 2 : Récupération IP ───────────────────────────────
echo -e "\n${YELLOW}[2/8] Récupération de l'IP publique...${NC}"
PUBLIC_IP=$(az vm show -d \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --query publicIps -o tsv)

if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
  echo "  Pas d'IP publique — création temporaire..."
  az network public-ip create \
    --name pip-metalis-pra-temp \
    --resource-group "$RESOURCE_GROUP" \
    --sku Standard \
    --allocation-method Static \
    --output none
  NIC_NAME=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
  az network nic ip-config update \
    --name internal \
    --nic-name "$NIC_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --public-ip-address pip-metalis-pra-temp \
    --output none
  PUBLIC_IP=$(az network public-ip show \
    --name pip-metalis-pra-temp \
    --resource-group "$RESOURCE_GROUP" \
    --query ipAddress -o tsv)
fi
echo -e "${GREEN}✅ IP publique : $PUBLIC_IP${NC}"

# ─── Étape 3 : Attente SSH ───────────────────────────────────
echo -e "\n${YELLOW}[3/8] Attente de la disponibilité SSH...${NC}"
SSH_READY=false
for i in $(seq 1 30); do
  if ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "echo ok" &>/dev/null; then
    SSH_READY=true
    echo -e "${GREEN}✅ SSH disponible${NC}"
    break
  fi
  echo "  Tentative $i/30..."
  sleep 10
done

if [[ "$SSH_READY" != "true" ]]; then
  echo -e "${RED}❌ SSH non disponible après 5 min. Vérifier le NSG et la VM.${NC}"
  exit 1
fi

# ─── Étape 4 : Vérification k3s ──────────────────────────────
echo -e "\n${YELLOW}[4/8] Vérification k3s...${NC}"
ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" \
  "sudo kubectl get nodes -o wide"

# Vérifier que cloud-init a terminé
ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" \
  "test -f /opt/pra-ready && echo 'Cloud-init: OK' || echo 'Cloud-init: en cours...'"
echo -e "${GREEN}✅ k3s opérationnel${NC}"

# ─── Étape 5 : Credentials Velero ────────────────────────────
echo -e "\n${YELLOW}[5/8] Configuration des credentials Velero...${NC}"
cat <<CRED | ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "cat > /tmp/credentials-velero"
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${VELERO_SP_CLIENT_ID}
AZURE_CLIENT_SECRET=${VELERO_SP_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${VELERO_RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
CRED
echo -e "${GREEN}✅ Credentials configurées${NC}"

# ─── Étape 6 : Installation Velero sur le cluster ────────────
echo -e "\n${YELLOW}[6/8] Installation de Velero sur le cluster PRA...${NC}"
ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  # Vérifier si Velero est déjà installé
  if sudo kubectl get namespace velero &>/dev/null; then
    echo 'Velero déjà installé — skip'
  else
    sudo velero install \
      --provider azure \
      --plugins velero/velero-plugin-for-microsoft-azure:v1.10.0 \
      --bucket $VELERO_CONTAINER \
      --secret-file /tmp/credentials-velero \
      --backup-location-config resourceGroup=$VELERO_RESOURCE_GROUP,storageAccount=$VELERO_STORAGE_ACCOUNT \
      --use-node-agent \
      --kubeconfig /etc/rancher/k3s/k3s.yaml
  fi
"

echo "  Attente des pods Velero..."
ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" \
  "sudo kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero -n velero --timeout=180s --kubeconfig /etc/rancher/k3s/k3s.yaml"
echo -e "${GREEN}✅ Velero installé et prêt${NC}"

# ─── Étape 7 : Restauration Velero ───────────────────────────
echo -e "\n${YELLOW}[7/8] Restauration depuis le dernier backup...${NC}"

# Attendre que le BSL soit disponible
echo "  Synchronisation des backups..."
sleep 15

LATEST_BACKUP=$(ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "
  sudo velero backup get --kubeconfig /etc/rancher/k3s/k3s.yaml -o json 2>/dev/null \
    | jq -r '[.items[] | select(.status.phase==\"Completed\")] | sort_by(.metadata.creationTimestamp) | last | .metadata.name'
")

if [[ -z "$LATEST_BACKUP" || "$LATEST_BACKUP" == "null" ]]; then
  echo -e "${RED}❌ Aucun backup trouvé. Vérifier la connexion Velero → Azure Blob.${NC}"
  echo "  Debug : ssh $ADMIN_USER@$PUBLIC_IP 'sudo velero backup-location get --kubeconfig /etc/rancher/k3s/k3s.yaml'"
  exit 1
fi

echo -e "  Dernier backup : ${GREEN}$LATEST_BACKUP${NC}"
RESTORE_NAME="pra-restore-$(date +%Y%m%d-%H%M%S)"

ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "
  sudo velero restore create $RESTORE_NAME \
    --from-backup $LATEST_BACKUP \
    --exclude-namespaces velero \
    --kubeconfig /etc/rancher/k3s/k3s.yaml
"

echo "  Restauration en cours (5-15 min)..."
for i in $(seq 1 30); do
  STATUS=$(ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" \
    "sudo velero restore get $RESTORE_NAME --kubeconfig /etc/rancher/k3s/k3s.yaml -o json 2>/dev/null \
     | jq -r '.status.phase'" 2>/dev/null || echo "InProgress")

  if [[ "$STATUS" == "Completed" ]]; then
    echo -e "${GREEN}✅ Restauration terminée${NC}"
    break
  elif [[ "$STATUS" == "Failed" || "$STATUS" == "PartiallyFailed" ]]; then
    echo -e "${YELLOW}⚠️  Restauration: $STATUS (vérifier les logs)${NC}"
    break
  fi
  echo "  Status: $STATUS ($i/30)..."
  sleep 20
done

# ─── Étape 8 : Patch Ingress & Vérification ──────────────────
echo -e "\n${YELLOW}[8/8] Mise à jour des ingress + vérification...${NC}"

# Attendre que les pods démarrent
sleep 30

ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  PRA_IP=$PUBLIC_IP

  # Patch des ingress avec la nouvelle IP
  for NS_INGRESS in \$(sudo kubectl get ingress --all-namespaces -o json | jq -r '.items[] | \"\(.metadata.namespace)/\(.metadata.name)\"'); do
    NS=\$(echo \$NS_INGRESS | cut -d/ -f1)
    ING=\$(echo \$NS_INGRESS | cut -d/ -f2)

    CURRENT_HOST=\$(sudo kubectl get ingress \$ING -n \$NS -o jsonpath='{.spec.rules[0].host}')
    APP_PREFIX=\$(echo \$CURRENT_HOST | cut -d. -f1)
    NEW_HOST=\"\${APP_PREFIX}.\${PRA_IP}.nip.io\"

    sudo kubectl patch ingress \$ING -n \$NS --type=json \
      -p=\"[{\\\"op\\\": \\\"replace\\\", \\\"path\\\": \\\"/spec/rules/0/host\\\", \\\"value\\\": \\\"\$NEW_HOST\\\"}]\" 2>/dev/null || true
    echo \"  Ingress \$NS/\$ING → \$NEW_HOST\"
  done

  echo ''
  echo '=== PODS ==='
  sudo kubectl get pods --all-namespaces -o wide
  echo ''
  echo '=== INGRESS ==='
  sudo kubectl get ingress --all-namespaces
"

# ─── Étape 9 : Post-restore (re-IP + volumes Kopia) ─────────
echo -e "\n${YELLOW}[9/9] Post-restore : re-IP + restauration volumes Kopia...${NC}"

# Copier et exécuter post-restore.sh sur la VM
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/post-restore.sh" ]]; then
  scp $SSH_OPTS -i "$SSH_KEY" "$SCRIPT_DIR/post-restore.sh" "$ADMIN_USER@$PUBLIC_IP:/tmp/post-restore.sh"
  ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" \
    "chmod +x /tmp/post-restore.sh && sudo /tmp/post-restore.sh --ip $PUBLIC_IP"
  echo -e "${GREEN}✅ Post-restore terminé${NC}"
else
  echo -e "${YELLOW}⚠️  post-restore.sh introuvable — exécuter manuellement sur la VM${NC}"
  echo "  sudo ./post-restore.sh --ip $PUBLIC_IP"
fi

# ─── Résumé ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🚨 PRA METALIS — ACTIVÉ AVEC SUCCÈS            ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                         ║${NC}"
echo -e "${GREEN}║  VM IP      : $PUBLIC_IP${NC}"
echo -e "${GREEN}║  SSH        : ssh -i $SSH_KEY $ADMIN_USER@$PUBLIC_IP${NC}"
echo -e "${GREEN}║                                                         ║${NC}"
echo -e "${GREEN}║  WordPress  : http://wordpress.$PUBLIC_IP.nip.io        ║${NC}"
echo -e "${GREEN}║  Odoo       : http://odoo.$PUBLIC_IP.nip.io             ║${NC}"
echo -e "${GREEN}║  Grafana    : http://grafana.$PUBLIC_IP.nip.io          ║${NC}"
echo -e "${GREEN}║                                                         ║${NC}"
echo -e "${GREEN}║  Backup     : $LATEST_BACKUP${NC}"
echo -e "${GREEN}║  Restore    : $RESTORE_NAME${NC}"
echo -e "${GREEN}║                                                         ║${NC}"
echo -e "${GREEN}║  ⚠️  COMMUNIQUER LES NOUVELLES URLs AUX UTILISATEURS    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"

# Nettoyer les credentials
ssh $SSH_OPTS -i "$SSH_KEY" "$ADMIN_USER@$PUBLIC_IP" "rm -f /tmp/credentials-velero"
