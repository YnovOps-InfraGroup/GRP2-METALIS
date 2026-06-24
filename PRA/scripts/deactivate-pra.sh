#!/bin/bash
# ================================================================
# PRA METALIS — Script de Désactivation
# Désalloue la VM PRA (0€ compute) et nettoie l'IP temporaire
#
# Usage: ./deactivate-pra.sh
#
# Prérequis: Azure CLI authentifié
# ================================================================

set -euo pipefail

RESOURCE_GROUP="${PRA_RESOURCE_GROUP:-rg-metalis-pra}"
VM_NAME="${PRA_VM_NAME:-vm-metalis-pra}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🔌 DÉSACTIVATION PRA METALIS                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"

if ! az account show &>/dev/null; then
  echo -e "${RED}❌ Azure CLI non authentifié${NC}"
  exit 1
fi

# Vérifier l'état de la VM
VM_STATE=$(az vm get-instance-view \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
  -o tsv 2>/dev/null || echo "Unknown")

echo -e "${YELLOW}État actuel : $VM_STATE${NC}"

if [[ "$VM_STATE" == *"deallocated"* ]]; then
  echo -e "${GREEN}✅ VM déjà désallouée${NC}"
  exit 0
fi

# Désallouer la VM
echo -e "\n${YELLOW}[1/2] Désallocation de la VM...${NC}"
az vm deallocate \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME"
echo -e "${GREEN}✅ VM désallouée (0€ compute)${NC}"

# Supprimer l'IP publique temporaire si elle existe
echo -e "\n${YELLOW}[2/2] Nettoyage IP temporaire...${NC}"
if az network public-ip show --name pip-metalis-pra-temp --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  NIC_NAME=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
  az network nic ip-config update \
    --name internal \
    --nic-name "$NIC_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --remove publicIpAddress \
    --output none 2>/dev/null || true
  az network public-ip delete \
    --name pip-metalis-pra-temp \
    --resource-group "$RESOURCE_GROUP" \
    --output none
  echo -e "${GREEN}✅ IP temporaire supprimée${NC}"
else
  echo "  Pas d'IP temporaire à supprimer"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  PRA désactivé — Coûts mensuels : ~3-7€ (disques)   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
