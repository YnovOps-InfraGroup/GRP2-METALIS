#!/bin/bash
# ================================================================
# PRA METALIS — Post-Restore : Re-IP + Restauration Volumes
#
# Ce script corrige automatiquement toutes les références IP/URL
# après une restauration Velero sur le cluster PRA Azure.
#
# Il résout le problème systémique : le node-agent Velero monte
# /var/lib/kubelet/pods mais k3s local-path crée les PV dans
# /var/lib/rancher/k3s/storage/ → les volumes Kopia ne sont
# jamais restaurés automatiquement.
#
# Usage:
#   # Depuis la VM PRA (après activate-pra.sh) :
#   sudo ./post-restore.sh
#
#   # Ou à distance via SSH :
#   ssh azureuser@<IP> 'sudo /home/azureuser/post-restore.sh'
#
#   # Avec une IP spécifique (si pas d'auto-détection) :
#   sudo ./post-restore.sh --ip 20.203.187.132
#
#   # Avec l'ancienne IP on-prem (par défaut 10.1.248.100) :
#   sudo ./post-restore.sh --old-ip 10.1.248.100
#
# Prérequis:
#   - k3s cluster avec pods wordpress/odoo restaurés par Velero
#   - kopia installé (/usr/local/bin/kopia)
#   - Azure CLI ou STORAGE_KEY en variable d'environnement
#   - Exécuter en root (sudo)
# ================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
export KUBECONFIG

K3S_STORAGE="/var/lib/rancher/k3s/storage"

# Velero / Kopia
STORAGE_ACCOUNT="${VELERO_STORAGE_ACCOUNT:-stobkpmetalis974}"
BLOB_CONTAINER="${VELERO_CONTAINER:-contmetalisbkp974}"
STORAGE_RG="${VELERO_RESOURCE_GROUP:-rg-metalis}"
AZURE_SUB="${AZURE_SUBSCRIPTION_ID:-***REDACTED_SUB_ID***}"
KOPIA_PASSWORD="${KOPIA_PASSWORD:-changeme}"
export KOPIA_PASSWORD

# IPs
OLD_IP="${OLD_IP:-10.1.248.100}"
NEW_IP=""

# Credentials applicatifs (utilisés pour vérification uniquement)
WP_DB_ROOT_PASS="${WP_DB_ROOT_PASS:-changeme}"
WP_DB_NAME="${WP_DB_NAME:-wordpress}"
ODOO_DB_USER="${ODOO_DB_USER:-odoo}"
ODOO_DB_NAME="${ODOO_DB_NAME:-odoo}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Compteurs
ERRORS=0
WARNINGS=0

# ─── Fonctions utilitaires ───────────────────────────────────
log_step()  { echo -e "\n${YELLOW}[$1] $2${NC}"; }
log_ok()    { echo -e "  ${GREEN}✅ $1${NC}"; }
log_warn()  { echo -e "  ${YELLOW}⚠️  $1${NC}"; ((WARNINGS++)) || true; }
log_error() { echo -e "  ${RED}❌ $1${NC}"; ((ERRORS++)) || true; }
log_info()  { echo -e "  ${CYAN}ℹ  $1${NC}"; }

wait_for_pod() {
  local ns="$1" label="$2" timeout="${3:-120}"
  kubectl wait --for=condition=ready pod -l "$label" -n "$ns" --timeout="${timeout}s" 2>/dev/null
}

get_pod_name() {
  local ns="$1" label="$2"
  kubectl get pods -n "$ns" -l "$label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# ─── Parse arguments ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --ip)       NEW_IP="$2"; shift 2 ;;
    --old-ip)   OLD_IP="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --skip-kopia) SKIP_KOPIA=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--ip <NEW_IP>] [--old-ip <OLD_IP>] [--skip-kopia] [--dry-run]"
      exit 0 ;;
    *) echo "Option inconnue: $1"; exit 1 ;;
  esac
done

DRY_RUN="${DRY_RUN:-false}"
SKIP_KOPIA="${SKIP_KOPIA:-false}"

# ─── En-tête ─────────────────────────────────────────────────
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   POST-RESTORE PRA METALIS — Re-IP + Volumes        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"

# ─── Vérifications préalables ────────────────────────────────
log_step "0/9" "Vérifications préalables"

if [[ $EUID -ne 0 ]]; then
  log_error "Ce script doit être exécuté en root (sudo)"
  exit 1
fi

if ! kubectl get nodes &>/dev/null; then
  log_error "k3s non accessible (KUBECONFIG=$KUBECONFIG)"
  exit 1
fi
log_ok "k3s accessible"

# Auto-détecter l'IP publique Azure
if [[ -z "$NEW_IP" ]]; then
  NEW_IP=$(curl -s -4 --max-time 5 http://ifconfig.me 2>/dev/null || \
           curl -s -4 --max-time 5 http://checkip.amazonaws.com 2>/dev/null || \
           curl -s -4 --max-time 5 http://icanhazip.com 2>/dev/null || \
           echo "")
  NEW_IP=$(echo "$NEW_IP" | tr -d '[:space:]')
fi

if [[ -z "$NEW_IP" ]]; then
  log_error "Impossible de détecter l'IP publique. Utiliser: $0 --ip <IP>"
  exit 1
fi
log_ok "IP publique détectée : $NEW_IP"

# Détecter l'ancienne IP depuis les ingress existants
DETECTED_OLD_IP=$(kubectl get ingress -A -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null \
  | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "")
if [[ -n "$DETECTED_OLD_IP" && "$DETECTED_OLD_IP" != "$NEW_IP" ]]; then
  OLD_IP="$DETECTED_OLD_IP"
  log_info "Ancienne IP détectée depuis l'ingress : $OLD_IP"
elif [[ -n "$DETECTED_OLD_IP" && "$DETECTED_OLD_IP" == "$NEW_IP" ]]; then
  log_info "Les ingress utilisent déjà la bonne IP"
fi

echo ""
echo -e "  ${CYAN}Ancienne IP (on-prem) : $OLD_IP${NC}"
echo -e "  ${CYAN}Nouvelle IP (PRA)     : $NEW_IP${NC}"
echo -e "  ${CYAN}Skip Kopia            : $SKIP_KOPIA${NC}"
echo -e "  ${CYAN}Dry-run               : $DRY_RUN${NC}"

if [[ "$OLD_IP" == "$NEW_IP" ]]; then
  log_warn "Ancienne IP = Nouvelle IP — les ingress sont déjà configurés"
fi

# ═════════════════════════════════════════════════════════════
# ÉTAPE 1 : Débloquer les pods stuck en Init
# ═════════════════════════════════════════════════════════════
log_step "1/9" "Déblocage des pods stuck en Init"

STUCK_PODS=$(kubectl get pods -A --no-headers 2>/dev/null \
  | grep -E 'Init:|PodInitializing|Pending' \
  | awk '{print $1"/"$2}' || true)

if [[ -n "$STUCK_PODS" ]]; then
  while IFS= read -r pod; do
    ns=$(echo "$pod" | cut -d/ -f1)
    name=$(echo "$pod" | cut -d/ -f2)
    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl delete pod -n "$ns" "$name" --force --grace-period=0 2>/dev/null || true
      log_info "Pod supprimé : $pod"
    else
      log_info "[DRY-RUN] Supprimerait : $pod"
    fi
  done <<< "$STUCK_PODS"
  log_ok "Pods stuck nettoyés"
  sleep 10
else
  log_ok "Aucun pod bloqué"
fi

# Supprimer le webhook nginx qui peut bloquer les ingress
kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null && \
  log_info "Webhook nginx supprimé" || true

# ═════════════════════════════════════════════════════════════
# ÉTAPE 2 : Restauration volumes Kopia (contourne le bug k3s)
# ═════════════════════════════════════════════════════════════
log_step "2/9" "Restauration des volumes depuis Kopia"

if [[ "$SKIP_KOPIA" == "true" ]]; then
  log_info "Restauration Kopia ignorée (--skip-kopia)"
else
  # Récupérer la clé de stockage
  if [[ -z "${STORAGE_KEY:-}" ]]; then
    STORAGE_KEY=$(az storage account keys list \
      --account-name "$STORAGE_ACCOUNT" \
      --resource-group "$STORAGE_RG" \
      --subscription "$AZURE_SUB" \
      --query '[0].value' -o tsv 2>/dev/null || echo "")
  fi

  if [[ -z "$STORAGE_KEY" ]]; then
    log_error "Impossible de récupérer la clé de stockage Azure"
    log_info "Exporter STORAGE_KEY=<clé> avant d'exécuter le script"
    SKIP_KOPIA=true
  fi

  if [[ "$SKIP_KOPIA" != "true" ]]; then
    # --- WordPress volumes ---
    log_info "Connexion au repo Kopia WordPress..."
    kopia repository connect azure \
      --container "$BLOB_CONTAINER" \
      --prefix 'kopia/wordpress/' \
      --storage-account "$STORAGE_ACCOUNT" \
      --storage-key "$STORAGE_KEY" \
      --no-persist-credentials 2>/dev/null

    # Trouver le PVC WordPress (wordpress/wordpress)
    WP_PVC_DIR=$(find "$K3S_STORAGE" -maxdepth 1 -name '*_wordpress_wordpress' -type d | head -1)
    WP_MARIA_PVC_DIR=$(find "$K3S_STORAGE" -maxdepth 1 -name '*_wordpress_data-wordpress-mariadb*' -type d | head -1)

    if [[ -n "$WP_PVC_DIR" ]]; then
      # Trouver le snapshot le plus récent du PVC Longhorn (pas CSI)
      # Les snapshots Longhorn sont > 100MB, les CSI < 20MB
      WP_SNAP=$(kopia snapshot list --all 2>&1 \
        | grep -oP 'k[0-9a-f]{31,}' \
        | while read sid; do
            SIZE=$(kopia show "$sid" 2>/dev/null | grep -oP '"size":\K\d+' | head -1 || echo 0)
            echo "$SIZE $sid"
          done \
        | sort -rn \
        | head -1 \
        | awk '{print $2}' 2>/dev/null || echo "")

      if [[ -n "$WP_SNAP" ]]; then
        log_info "Restauration WordPress data depuis snapshot $WP_SNAP..."
        rm -rf /tmp/wp-kopia-restore
        if kopia snapshot restore "$WP_SNAP" /tmp/wp-kopia-restore \
          --overwrite-directories --overwrite-files 2>/dev/null; then

          # Copier wp-content (uploads, themes, plugins, languages)
          if [[ -d /tmp/wp-kopia-restore/wordpress/wp-content ]]; then
            for dir in uploads themes plugins languages; do
              if [[ -d "/tmp/wp-kopia-restore/wordpress/wp-content/$dir" ]]; then
                rm -rf "$WP_PVC_DIR/wordpress/wp-content/$dir"
                cp -r "/tmp/wp-kopia-restore/wordpress/wp-content/$dir" \
                       "$WP_PVC_DIR/wordpress/wp-content/$dir"
              fi
            done
            chown -R 1001:1001 "$WP_PVC_DIR/wordpress/wp-content/"
            UPLOAD_COUNT=$(find "$WP_PVC_DIR/wordpress/wp-content/uploads" -type f 2>/dev/null | wc -l)
            log_ok "WordPress wp-content restauré ($UPLOAD_COUNT fichiers uploads)"
          fi
        else
          log_warn "Échec restauration snapshot WordPress"
        fi
        rm -rf /tmp/wp-kopia-restore
      else
        log_warn "Aucun snapshot WordPress trouvé dans Kopia"
      fi
    else
      log_warn "PVC WordPress introuvable dans $K3S_STORAGE"
    fi

    # Restauration MariaDB si le répertoire est vide
    if [[ -n "$WP_MARIA_PVC_DIR" ]]; then
      MARIA_SIZE=$(du -s "$WP_MARIA_PVC_DIR" 2>/dev/null | awk '{print $1}')
      if [[ "${MARIA_SIZE:-0}" -lt 1000 ]]; then
        MARIA_SNAP=$(kopia snapshot list --all 2>&1 \
          | grep -oP 'k[0-9a-f]{31,}' \
          | while read sid; do
              META=$(kopia show "$sid" 2>/dev/null || echo "")
              if echo "$META" | grep -q '"name":"data"'; then
                SIZE=$(echo "$META" | grep -oP '"size":\K\d+' | head -1 || echo 0)
                echo "$SIZE $sid"
              fi
            done \
          | sort -rn | head -1 | awk '{print $2}' 2>/dev/null || echo "")

        if [[ -n "$MARIA_SNAP" ]]; then
          log_info "Restauration MariaDB depuis snapshot $MARIA_SNAP..."
          rm -rf /tmp/maria-kopia-restore
          kopia snapshot restore "$MARIA_SNAP" /tmp/maria-kopia-restore \
            --overwrite-directories --overwrite-files 2>/dev/null
          if [[ -d /tmp/maria-kopia-restore/data ]]; then
            cp -r /tmp/maria-kopia-restore/data/* "$WP_MARIA_PVC_DIR/data/" 2>/dev/null
            chown -R 1001:1001 "$WP_MARIA_PVC_DIR/"
            log_ok "MariaDB data restauré"
          fi
          rm -rf /tmp/maria-kopia-restore
        fi
      else
        log_ok "MariaDB data déjà présent (${MARIA_SIZE}K)"
      fi
    fi

    kopia repository disconnect 2>/dev/null || true

    # --- Odoo volumes ---
    log_info "Connexion au repo Kopia Odoo..."
    kopia repository connect azure \
      --container "$BLOB_CONTAINER" \
      --prefix 'kopia/odoo/' \
      --storage-account "$STORAGE_ACCOUNT" \
      --storage-key "$STORAGE_KEY" \
      --no-persist-credentials 2>/dev/null

    ODOO_DATA_PVC=$(find "$K3S_STORAGE" -maxdepth 1 -name '*_odoo_odoo-data' -type d | head -1)
    ODOO_PG_PVC=$(find "$K3S_STORAGE" -maxdepth 1 -name '*_odoo_pgdata*' -type d | head -1)

    if [[ -n "$ODOO_DATA_PVC" ]]; then
      # Trouver le snapshot odoo-data (petit, ~10MB, contient addons/filestore)
      ODOO_DATA_SNAP=$(kopia snapshot list --all 2>&1 \
        | grep -oP 'k[0-9a-f]{31,}' \
        | while read sid; do
            META=$(kopia show "$sid" 2>/dev/null || echo "")
            if echo "$META" | grep -q '"name":"addons"'; then
              SIZE=$(echo "$META" | grep -oP '"size":\K\d+' | head -1 || echo 0)
              echo "$SIZE $sid"
            fi
          done \
        | sort -rn | head -1 | awk '{print $2}' 2>/dev/null || echo "")

      if [[ -n "$ODOO_DATA_SNAP" ]]; then
        log_info "Restauration Odoo filestore depuis $ODOO_DATA_SNAP..."
        rm -rf /tmp/odoo-kopia-restore
        kopia snapshot restore "$ODOO_DATA_SNAP" /tmp/odoo-kopia-restore \
          --overwrite-directories --overwrite-files 2>/dev/null
        for dir in addons filestore sessions; do
          if [[ -d "/tmp/odoo-kopia-restore/$dir" ]]; then
            cp -r "/tmp/odoo-kopia-restore/$dir/"* "$ODOO_DATA_PVC/$dir/" 2>/dev/null || true
          fi
        done
        chown -R 1001:1001 "$ODOO_DATA_PVC/"
        FILESTORE_COUNT=$(find "$ODOO_DATA_PVC/filestore" -type f 2>/dev/null | wc -l)
        log_ok "Odoo filestore restauré ($FILESTORE_COUNT fichiers)"
        rm -rf /tmp/odoo-kopia-restore
      else
        log_warn "Aucun snapshot odoo-data trouvé"
      fi
    fi

    # Restauration PostgreSQL si vide
    if [[ -n "$ODOO_PG_PVC" ]]; then
      PG_SIZE=$(du -s "$ODOO_PG_PVC" 2>/dev/null | awk '{print $1}')
      if [[ "${PG_SIZE:-0}" -lt 1000 ]]; then
        PG_SNAP=$(kopia snapshot list --all 2>&1 \
          | grep -oP 'k[0-9a-f]{31,}' \
          | while read sid; do
              META=$(kopia show "$sid" 2>/dev/null || echo "")
              if echo "$META" | grep -q '"name":"pgdata"'; then
                SIZE=$(echo "$META" | grep -oP '"size":\K\d+' | head -1 || echo 0)
                echo "$SIZE $sid"
              fi
            done \
          | sort -rn | head -1 | awk '{print $2}' 2>/dev/null || echo "")

        if [[ -n "$PG_SNAP" ]]; then
          log_info "Restauration PostgreSQL depuis $PG_SNAP..."
          rm -rf /tmp/pg-kopia-restore
          kopia snapshot restore "$PG_SNAP" /tmp/pg-kopia-restore \
            --overwrite-directories --overwrite-files 2>/dev/null
          if [[ -d /tmp/pg-kopia-restore/pgdata ]]; then
            cp -r /tmp/pg-kopia-restore/pgdata/* "$ODOO_PG_PVC/pgdata/" 2>/dev/null
            chown -R 1001:1001 "$ODOO_PG_PVC/"
            log_ok "PostgreSQL data restauré"
          fi
          rm -rf /tmp/pg-kopia-restore
        fi
      else
        log_ok "PostgreSQL data déjà présent (${PG_SIZE}K)"
      fi
    fi

    kopia repository disconnect 2>/dev/null || true
  fi
fi

# ═════════════════════════════════════════════════════════════
# ÉTAPE 3 : Redémarrage des pods pour charger les volumes
# ═════════════════════════════════════════════════════════════
log_step "3/9" "Redémarrage des pods applicatifs"

for ns in wordpress odoo; do
  PODS=$(kubectl get pods -n "$ns" --no-headers -o custom-columns=':metadata.name' 2>/dev/null)
  while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl delete pod -n "$ns" "$pod" --force --grace-period=0 2>/dev/null || true
    fi
  done <<< "$PODS"
  log_info "Pods redémarrés dans $ns"
done

# Attente que les pods soient prêts
log_info "Attente des pods (timeout 3min)..."
sleep 15
wait_for_pod "wordpress" "app.kubernetes.io/name=wordpress" 180 2>/dev/null && \
  log_ok "WordPress pod ready" || log_warn "WordPress pod timeout"
wait_for_pod "wordpress" "app.kubernetes.io/name=mariadb" 120 2>/dev/null && \
  log_ok "MariaDB pod ready" || log_warn "MariaDB pod timeout"
wait_for_pod "odoo" "app=odoo" 120 2>/dev/null && \
  log_ok "Odoo pod ready" || log_warn "Odoo pod timeout"
wait_for_pod "odoo" "app=odoo-db" 120 2>/dev/null && \
  log_ok "PostgreSQL pod ready" || log_warn "PostgreSQL pod timeout"

# ═════════════════════════════════════════════════════════════
# ÉTAPE 4 : Patch Ingress
# ═════════════════════════════════════════════════════════════
log_step "4/9" "Mise à jour des Ingress (re-IP)"

for NS_INGRESS in $(kubectl get ingress --all-namespaces --no-headers 2>/dev/null \
  | awk '{print $1"/"$2}'); do
  NS=$(echo "$NS_INGRESS" | cut -d/ -f1)
  ING=$(echo "$NS_INGRESS" | cut -d/ -f2)

  CURRENT_HOST=$(kubectl get ingress "$ING" -n "$NS" -o jsonpath='{.spec.rules[0].host}')
  APP_PREFIX=$(echo "$CURRENT_HOST" | cut -d. -f1)
  NEW_HOST="${APP_PREFIX}.${NEW_IP}.nip.io"

  if [[ "$CURRENT_HOST" == "$NEW_HOST" ]]; then
    log_ok "Ingress $NS/$ING déjà correct ($NEW_HOST)"
    continue
  fi

  if [[ "$DRY_RUN" == "false" ]]; then
    kubectl patch ingress "$ING" -n "$NS" --type=json \
      -p="[{\"op\": \"replace\", \"path\": \"/spec/rules/0/host\", \"value\": \"$NEW_HOST\"}]" 2>/dev/null
  fi
  log_ok "Ingress $NS/$ING : $CURRENT_HOST → $NEW_HOST"
done

# ═════════════════════════════════════════════════════════════
# ÉTAPE 5 : WordPress wp-config.php
# ═════════════════════════════════════════════════════════════
log_step "5/9" "WordPress — wp-config.php"

WP_PVC_DIR=$(find "$K3S_STORAGE" -maxdepth 1 -name '*_wordpress_wordpress' -type d | head -1)

if [[ -n "$WP_PVC_DIR" ]]; then
  WP_CONFIG="$WP_PVC_DIR/wordpress/wp-config.php"
  if [[ -f "$WP_CONFIG" ]]; then
    # Supprimer les anciennes définitions WP_HOME/WP_SITEURL
    sed -i "/define.*WP_HOME/d" "$WP_CONFIG"
    sed -i "/define.*WP_SITEURL/d" "$WP_CONFIG"

    # Ajouter les nouvelles après la ligne "<?php"
    sed -i "1a\\
define( 'WP_HOME', 'http://wordpress.${NEW_IP}.nip.io/' );\\
define( 'WP_SITEURL', 'http://wordpress.${NEW_IP}.nip.io/' );" "$WP_CONFIG"

    # Remplacer toute ancienne IP résiduelle dans le fichier
    sed -i "s|${OLD_IP}|${NEW_IP}|g" "$WP_CONFIG"
    # Remplacer aussi 127.0.0.1 si présent
    sed -i "s|127\.0\.0\.1|wordpress.${NEW_IP}.nip.io|g" "$WP_CONFIG"

    log_ok "wp-config.php mis à jour"
    grep -E "WP_HOME|WP_SITEURL" "$WP_CONFIG" | while read -r line; do
      log_info "  $line"
    done
  else
    log_warn "wp-config.php introuvable dans $WP_PVC_DIR"
  fi
else
  log_warn "PVC WordPress introuvable"
fi

# ═════════════════════════════════════════════════════════════
# ÉTAPE 6 : WordPress — Variable d'environnement
# ═════════════════════════════════════════════════════════════
log_step "6/9" "WordPress — WORDPRESS_HOSTNAME env var"

WP_DEPLOY=$(kubectl get deploy -n wordpress -o name 2>/dev/null | head -1)
if [[ -n "$WP_DEPLOY" ]]; then
  DEPLOY_NAME=$(echo "$WP_DEPLOY" | cut -d/ -f2)
  if [[ "$DRY_RUN" == "false" ]]; then
    kubectl set env "deployment/$DEPLOY_NAME" -n wordpress \
      WORDPRESS_HOSTNAME="wordpress.${NEW_IP}.nip.io" 2>/dev/null
  fi
  log_ok "WORDPRESS_HOSTNAME → wordpress.${NEW_IP}.nip.io"
else
  log_warn "Deployment WordPress introuvable"
fi

# ═════════════════════════════════════════════════════════════
# ÉTAPE 7 : WordPress — URLs dans la base de données
# ═════════════════════════════════════════════════════════════
log_step "7/9" "WordPress — Remplacement URLs en base de données"

# Attendre que MariaDB soit prêt
MARIA_POD=$(get_pod_name "wordpress" "app.kubernetes.io/name=mariadb")
if [[ -n "$MARIA_POD" ]]; then
  # Construire la liste de patterns à remplacer
  # On remplace TOUTES les variantes possibles
  REPLACE_PATTERNS=(
    "http://${OLD_IP}|http://wordpress.${NEW_IP}.nip.io"
    "https://${OLD_IP}|https://wordpress.${NEW_IP}.nip.io"
    "http://${OLD_IP}:80|http://wordpress.${NEW_IP}.nip.io"
    "http://127.0.0.1|http://wordpress.${NEW_IP}.nip.io"
    "https://127.0.0.1|https://wordpress.${NEW_IP}.nip.io"
  )

  # Aussi remplacer si une ancienne URL nip.io existe
  if [[ "$OLD_IP" != "$NEW_IP" ]]; then
    REPLACE_PATTERNS+=("http://wordpress.${OLD_IP}.nip.io|http://wordpress.${NEW_IP}.nip.io")
  fi

  SQL_COMMANDS=""
  for pattern in "${REPLACE_PATTERNS[@]}"; do
    FROM=$(echo "$pattern" | cut -d'|' -f1)
    TO=$(echo "$pattern" | cut -d'|' -f2)
    SQL_COMMANDS+="UPDATE wp_options SET option_value=REPLACE(option_value,'$FROM','$TO') WHERE option_value LIKE '%$(echo "$FROM" | sed "s|http[s]*://||")%';
"
    SQL_COMMANDS+="UPDATE wp_posts SET guid=REPLACE(guid,'$FROM','$TO') WHERE guid LIKE '%$(echo "$FROM" | sed "s|http[s]*://||")%';
"
    SQL_COMMANDS+="UPDATE wp_posts SET post_content=REPLACE(post_content,'$FROM','$TO') WHERE post_content LIKE '%$(echo "$FROM" | sed "s|http[s]*://||")%';
"
    SQL_COMMANDS+="UPDATE wp_postmeta SET meta_value=REPLACE(meta_value,'$FROM','$TO') WHERE meta_value LIKE '%$(echo "$FROM" | sed "s|http[s]*://||")%';
"
  done

  # Options critiques : siteurl et home
  SQL_COMMANDS+="UPDATE wp_options SET option_value='http://wordpress.${NEW_IP}.nip.io' WHERE option_name IN ('siteurl','home');
"

  if [[ "$DRY_RUN" == "false" ]]; then
    kubectl exec -n wordpress "$MARIA_POD" -- \
      mysql -u root "-p${WP_DB_ROOT_PASS}" "$WP_DB_NAME" \
      -e "$SQL_COMMANDS" 2>/dev/null
    log_ok "URLs WordPress mises à jour en DB"

    # Vérification
    SAMPLE=$(kubectl exec -n wordpress "$MARIA_POD" -- \
      mysql -u root "-p${WP_DB_ROOT_PASS}" "$WP_DB_NAME" -N \
      -e "SELECT option_value FROM wp_options WHERE option_name='siteurl'" 2>/dev/null | grep -v mysql:)
    log_info "siteurl = $SAMPLE"
  else
    log_info "[DRY-RUN] ${#REPLACE_PATTERNS[@]} patterns de remplacement préparés"
  fi
else
  log_warn "MariaDB pod introuvable — skip DB update"
fi

# ═════════════════════════════════════════════════════════════
# ÉTAPE 8 : Odoo — web.base.url + reset password admin
# ═════════════════════════════════════════════════════════════
log_step "8/9" "Odoo — web.base.url + password admin"

PG_POD=$(get_pod_name "odoo" "app=odoo-db")
if [[ -n "$PG_POD" ]]; then
  if [[ "$DRY_RUN" == "false" ]]; then
    # Mettre à jour web.base.url
    kubectl exec -n odoo "$PG_POD" -- \
      psql -U "$ODOO_DB_USER" -d "$ODOO_DB_NAME" -c \
      "UPDATE ir_config_parameter SET value='http://odoo.${NEW_IP}.nip.io' WHERE key='web.base.url';" 2>/dev/null && \
      log_ok "web.base.url → http://odoo.${NEW_IP}.nip.io" || \
      log_warn "Échec update web.base.url (table peut ne pas exister)"

    # Reset password admin via passlib dans le pod Odoo
    ODOO_POD=$(get_pod_name "odoo" "app=odoo")
    if [[ -n "$ODOO_POD" ]]; then
      NEW_HASH=$(kubectl exec -n odoo "$ODOO_POD" -- python3 -c "
from passlib.context import CryptContext
ctx = CryptContext(schemes=['pbkdf2_sha512'], default='pbkdf2_sha512', pbkdf2_sha512__rounds=600000)
print(ctx.hash(os.environ.get('ODOO_ADMIN_PASS','admin')))" 2>/dev/null || echo "")

      if [[ -n "$NEW_HASH" && "$NEW_HASH" == *'pbkdf2'* ]]; then
        kubectl exec -n odoo "$PG_POD" -- \
          psql -U "$ODOO_DB_USER" -d "$ODOO_DB_NAME" -c \
          "UPDATE res_users SET password='$NEW_HASH' WHERE login='admin';" 2>/dev/null
        log_ok "Password admin Odoo réinitialisé (admin / à définir via ODOO_ADMIN_PASS)"
      else
        log_warn "Impossible de générer le hash Odoo — reset password ignoré"
      fi
    fi
  fi
else
  log_warn "PostgreSQL pod introuvable — skip Odoo DB update"
fi

# ═════════════════════════════════════════════════════════════
# ÉTAPE 9 : Vérification finale
# ═════════════════════════════════════════════════════════════
log_step "9/9" "Vérification finale"

# Redémarrer le pod WordPress pour prendre en compte wp-config + env var
WP_POD=$(get_pod_name "wordpress" "app.kubernetes.io/name=wordpress")
if [[ -n "$WP_POD" ]]; then
  kubectl delete pod -n wordpress "$WP_POD" --force --grace-period=0 2>/dev/null || true
  log_info "Pod WordPress redémarré pour appliquer les changements"
  sleep 20
fi

# Tests HTTP
echo ""
WP_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://wordpress.${NEW_IP}.nip.io/" 2>/dev/null || echo "000")
ODOO_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://odoo.${NEW_IP}.nip.io/web/login" 2>/dev/null || echo "000")
WP_IMG=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://wordpress.${NEW_IP}.nip.io/wp-content/uploads/2024/08/footer-cta.jpg" 2>/dev/null || echo "000")

[[ "$WP_HTTP" == "200" ]] && log_ok "WordPress homepage : HTTP $WP_HTTP" || log_error "WordPress homepage : HTTP $WP_HTTP"
[[ "$WP_IMG" == "200" ]] && log_ok "WordPress images   : HTTP $WP_IMG" || log_warn "WordPress images   : HTTP $WP_IMG"
[[ "$ODOO_HTTP" == "200" ]] && log_ok "Odoo login page    : HTTP $ODOO_HTTP" || log_error "Odoo login page    : HTTP $ODOO_HTTP"

# Résumé pods
echo ""
kubectl get pods -A --no-headers 2>/dev/null | grep -E 'wordpress|odoo' | while read -r line; do
  log_info "$line"
done

# ─── Résumé final ────────────────────────────────────────────
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}║   POST-RESTORE TERMINÉ — $WARNINGS warning(s), $ERRORS erreur(s)          ║${NC}"
else
  echo -e "${RED}║   POST-RESTORE TERMINÉ — $WARNINGS warning(s), $ERRORS erreur(s)          ║${NC}"
fi
echo -e "${BLUE}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}║  ${NC}WordPress : http://wordpress.${NEW_IP}.nip.io${BLUE}${NC}"
echo -e "${BLUE}║  ${NC}Odoo      : http://odoo.${NEW_IP}.nip.io${BLUE}${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}║  ${NC}WP Admin  : admin / (voir CREDENTIALS.md)${BLUE}${NC}"
echo -e "${BLUE}║  ${NC}Odoo      : admin / (voir CREDENTIALS.md)${BLUE}${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
