# Déploiement des applications — k3s METALIS

**Cluster** : `metalis-k3s` (10.1.248.6)
**Accès apps** : via `*.10.1.248.6.nip.io` (résolution DNS automatique)

> nip.io résout automatiquement `*.10.1.248.6.nip.io` → `10.1.248.6`, sans DNS local.

---

## 0. Namespaces

```bash
kubectl apply -f k8s/namespaces.yaml

# Vérification
kubectl get namespaces | grep -E 'wordpress|nextcloud|odoo|monitoring'
```

---

## 1. Ingress NGINX

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f k8s/ingress-nginx/values.yaml

# Attendre l'IP externe (ServiceLB k3s → 10.1.248.6)
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch
```

---

## 2. WordPress

```bash
helm install wordpress bitnami/wordpress \
  --namespace wordpress \
  -f k8s/wordpress/values.yaml

# Suivi déploiement
kubectl rollout status deployment/wordpress -n wordpress
kubectl get pods -n wordpress
kubectl get ingress -n wordpress
```

**Accès** : http://wordpress.10.1.248.6.nip.io/wp-admin
**Credentials** : voir `docs/CREDENTIALS.md`

---

## 3. Nextcloud

> Chart officiel `nextcloud/nextcloud` — bitnami/nextcloud retiré du catalogue gratuit (août 2025)

```bash
# Ajouter le repo officiel Nextcloud
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

helm install nextcloud nextcloud/nextcloud \
  --namespace nextcloud \
  -f k8s/nextcloud/values.yaml

# Suivi (Nextcloud est long au premier démarrage ~3-5 min)
kubectl rollout status deployment/nextcloud -n nextcloud
kubectl get pods -n nextcloud
kubectl get ingress -n nextcloud
```

**Accès** : http://nextcloud.10.1.248.6.nip.io
**Credentials** : voir `docs/CREDENTIALS.md`

---

## 4. Odoo

> bitnami/odoo retiré du catalogue gratuit (août 2025) → déploiement via images officielles `odoo:18` + `postgres:16`

```bash
# Appliquer le manifest officiel
kubectl apply -f k8s/odoo/odoo-official.yaml

# (Ancienne commande Helm bitnami — non fonctionnelle)
# helm install odoo bitnami/odoo \
  --namespace odoo \
  -f k8s/odoo/values.yaml

# Suivi (Odoo + PostgreSQL ~3-5 min)
kubectl rollout status deployment/odoo -n odoo
kubectl get pods -n odoo
kubectl get ingress -n odoo
```

**Accès** : http://odoo.10.1.248.6.nip.io
**Credentials** : voir `docs/CREDENTIALS.md`

> Au premier accès Odoo, configurer la base de données depuis l'interface web.

---

## 5. Monitoring (Prometheus + Grafana)

```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f k8s/monitoring/values.yaml

# Suivi (~5 min, plusieurs composants)
kubectl get pods -n monitoring --watch
kubectl get ingress -n monitoring
```

**Grafana** : http://grafana.10.1.248.6.nip.io
**Prometheus** : http://prometheus.10.1.248.6.nip.io
**AlertManager** : http://alertmanager.10.1.248.6.nip.io
**Credentials** : voir `docs/CREDENTIALS.md`

---

## Vérification globale

```bash
# Tous les pods
kubectl get pods -A

# Tous les ingress
kubectl get ingress -A

# Tous les PVC (stockage)
kubectl get pvc -A

# Consommation disque
df -h /var/lib/rancher
```

---

## Commandes utiles

```bash
# Logs d'un pod
kubectl logs -n <namespace> <pod-name> --tail=50

# Redémarrer un déploiement
kubectl rollout restart deployment/<name> -n <namespace>

# Mise à jour via Helm
helm upgrade wordpress bitnami/wordpress \
  --namespace wordpress \
  -f k8s/wordpress/values.yaml

# Supprimer une release
helm uninstall <release-name> -n <namespace>

# Liste des releases Helm
helm list -A
```

---

## Accès rapide — Récapitulatif URLs

| App | URL | Namespace |
|---|---|---|
| WordPress | http://wordpress.10.1.248.6.nip.io | wordpress |
| Nextcloud | http://nextcloud.10.1.248.6.nip.io | nextcloud |
| Odoo ERP | http://odoo.10.1.248.6.nip.io | odoo |
| Grafana | http://grafana.10.1.248.6.nip.io | monitoring |
| Prometheus | http://prometheus.10.1.248.6.nip.io | monitoring |
| AlertManager | http://alertmanager.10.1.248.6.nip.io | monitoring |
