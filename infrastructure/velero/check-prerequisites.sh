#!/bin/bash

# ================================================================
# Velero Deployment - Prerequisites Check
# Verify everything is ready before deployment
# ================================================================

set -e

# ⚠️  Renseigner via variables d'environnement
TENANT_ID="${AZURE_TENANT_ID:-<votre-tenant-id>}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-<votre-subscription-id>}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     VELERO DEPLOYMENT - PREREQUISITES CHECK              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

FAILED=0

# Check 1: Azure CLI
echo ""
echo -e "${YELLOW}Check 1️⃣ : Azure CLI...${NC}"
if command -v az &> /dev/null; then
  VERSION=$(az --version | head -1)
  echo -e "${GREEN}✅ $VERSION${NC}"
else
  echo -e "${RED}❌ Azure CLI not installed${NC}"
  echo "   Install: https://learn.microsoft.com/cli/azure/install-azure-cli"
  FAILED=$((FAILED + 1))
fi

# Check 2: jq
echo ""
echo -e "${YELLOW}Check 2️⃣ : jq (JSON parser)...${NC}"
if command -v jq &> /dev/null; then
  VERSION=$(jq --version)
  echo -e "${GREEN}✅ $VERSION${NC}"
else
  echo -e "${RED}❌ jq not installed${NC}"
  echo "   Install: brew install jq (macOS) or apt install jq (Linux)"
  FAILED=$((FAILED + 1))
fi

# Check 3: Azure Authentication
echo ""
echo -e "${YELLOW}Check 3️⃣ : Azure Authentication...${NC}"
if az account show > /dev/null 2>&1; then
  CURRENT_ACCOUNT=$(az account show --query "user.name" -o tsv)
  echo -e "${GREEN}✅ Authenticated as: $CURRENT_ACCOUNT${NC}"
else
  echo -e "${RED}❌ Not authenticated to Azure${NC}"
  echo "   Run: az login --tenant $TENANT_ID"
  FAILED=$((FAILED + 1))
fi

# Check 4: Correct Tenant
echo ""
echo -e "${YELLOW}Check 4️⃣ : Tenant...${NC}"
CURRENT_TENANT=$(az account show --query "tenantId" -o tsv)
if [ "$CURRENT_TENANT" = "$TENANT_ID" ]; then
  echo -e "${GREEN}✅ Correct tenant: $TENANT_ID${NC}"
else
  echo -e "${YELLOW}⚠️  Different tenant: $CURRENT_TENANT${NC}"
  echo "   Expected: $TENANT_ID (runmyskills)"
  echo "   Run: az login --tenant $TENANT_ID"
fi

# Check 5: Correct Subscription
echo ""
echo -e "${YELLOW}Check 5️⃣ : Subscription (SUB-YNOV)...${NC}"
az account set --subscription "$SUBSCRIPTION_ID" 2>/dev/null || {
  echo -e "${RED}❌ Cannot access subscription: $SUBSCRIPTION_ID${NC}"
  echo "   Verify you're subscription owner"
  FAILED=$((FAILED + 1))
}

CURRENT_SUB=$(az account show --query "id" -o tsv)
if [ "$CURRENT_SUB" = "$SUBSCRIPTION_ID" ]; then
  echo -e "${GREEN}✅ Correct subscription: $SUBSCRIPTION_ID${NC}"
else
  echo -e "${RED}❌ Wrong subscription: $CURRENT_SUB${NC}"
  FAILED=$((FAILED + 1))
fi

# Check 6: Resource Group
echo ""
echo -e "${YELLOW}Check 6️⃣ : Resource Group (RG-BACKUP-METALIS)...${NC}"
if az group exists --name "RG-BACKUP-METALIS" | grep -q true; then
  echo -e "${GREEN}✅ RG already exists (will be used)${NC}"
else
  echo -e "${BLUE}ℹ️  RG does not exist (will be created by deploy.sh)${NC}"
fi

# Check 7: Bicep files
echo ""
echo -e "${YELLOW}Check 7️⃣ : Bicep template files...${NC}"
if [ -f "main.bicep" ]; then
  echo -e "${GREEN}✅ main.bicep found${NC}"
else
  echo -e "${RED}❌ main.bicep not found${NC}"
  FAILED=$((FAILED + 1))
fi

if [ -f "parameters.biceparam" ]; then
  echo -e "${GREEN}✅ parameters.biceparam found${NC}"
else
  echo -e "${RED}❌ parameters.biceparam not found${NC}"
  FAILED=$((FAILED + 1))
fi

# Check 8: Scripts permissions
echo ""
echo -e "${YELLOW}Check 8️⃣ : Script permissions...${NC}"
if [ -f "deploy.sh" ]; then
  if [ -x "deploy.sh" ]; then
    echo -e "${GREEN}✅ deploy.sh is executable${NC}"
  else
    echo -e "${YELLOW}⚠️  deploy.sh needs chmod +x${NC}"
  fi
else
  echo -e "${RED}❌ deploy.sh not found${NC}"
  FAILED=$((FAILED + 1))
fi

if [ -f "create-sp.sh" ]; then
  if [ -x "create-sp.sh" ]; then
    echo -e "${GREEN}✅ create-sp.sh is executable${NC}"
  else
    echo -e "${YELLOW}⚠️  create-sp.sh needs chmod +x${NC}"
  fi
else
  echo -e "${RED}❌ create-sp.sh not found${NC}"
  FAILED=$((FAILED + 1))
fi

# Summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"

if [ $FAILED -eq 0 ]; then
  echo -e "${BLUE}║                  ALL CHECKS PASSED ✅                   ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}Ready to deploy! Run:${NC}"
  echo "  ./deploy.sh"
  exit 0
else
  echo -e "${BLUE}║              SOME CHECKS FAILED ❌ ($FAILED)              ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${RED}Fix the issues above before running deployment${NC}"
  exit 1
fi
