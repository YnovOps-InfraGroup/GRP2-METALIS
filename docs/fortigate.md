# Documentation d'Installation : Configuration Initiale FortiGate 7.6

Ce guide détaille l'installation et la configuration de base d'un pare-feu FortiGate sous FortiOS 7.6 (en licence d'évaluation), incluant le paramétrage des interfaces WAN/LAN, la création d'un VLAN serveur, la mise en place des règles de sécurité initiales et l'intégration de l'annuaire Active Directory.

---

## 📋 Prérequis

Avant de commencer, assurez-vous de disposer de :
* Un boîtier **FortiGate** (ou une VM) fraîchement installé en version 7.6.
* Un ordinateur d'administration connecté sur le **Port 2 (LAN)**.
* Une **licence d'évaluation** active (Attention : elle limite le chiffrement et bloque à 3 routes statiques maximum).
* Votre serveur **Windows Server 2022 (AD/DNS)** prêt à être intégré sur le réseau.

---

## 🛠 Étape 1 : Configuration des Interfaces (CLI)

Par défaut, l'accès graphique (GUI) peut être bloqué ou restreint. La configuration initiale des adresses IP se fait via l'interface en ligne de commande (CLI). 

Connectez-vous en console (ou via l'accès d'usine du port 2) :

```bash
# 1. Configuration du Port 1 (WAN - Accès Internet)
# L'accès d'administration est désactivé sur ce port pour des raisons de sécurité.
config system interface
    edit "port1"
        set mode static
        set ip 10.1.248.4 255.255.255.0
    next

# 2. Configuration du Port 2 (LAN - Réseau Local)
# L'accès HTTPS et SSH est activé uniquement de ce côté.
    edit "port2"
        set mode static
        set ip 192.168.20.1 255.255.255.0
        set allowaccess ping https ssh
    next

# 3. Création du VLAN 100 (SRV - Serveurs AD/DNS)
# Ce VLAN est encapsulé sur l'interface physique port2.
    edit "VLAN100_SRV"
        set ip 192.168.100.1 255.255.255.0
        set allowaccess https
        set interface "port2"
        set vlanid 100
    next
end
```

## 🌍 Étape 2 : Configuration du Routage et du DNS

Pour que le pare-feu et les équipements internes puissent accéder à Internet, il faut définir la route par défaut et indiquer le serveur DNS (votre contrôleur de domaine interne).

Remplacez `10.1.248.x` par l'adresse IP de votre passerelle FAI/Routeur.

```bash
# 1. Ajout de la route par défaut (Passerelle Internet)
config router static
    edit 1
        set gateway 10.1.248.1
        set device "port1"
    next
end

# 2. Configuration du DNS Système (Pointé vers l'AD du VLAN 100)
config system dns
    set primary 8.8.8.8
    set secondary 8.8.4.4
end
```

## 🔐 Étape 3 : Création des Règles de Pare-feu (Policies)

Par défaut, le FortiGate bloque tout le trafic. Il faut créer des politiques explicites pour autoriser la navigation vers Internet et l'accès entre le LAN et le VLAN Serveurs.

```bash
config firewall policy
# 1. Règle : LAN vers WAN (Internet)
    edit 1
        set name "LAN_to_WAN"
        set srcintf "port2"
        set dstintf "port1"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
    next

# 2. Règle : VLAN Serveurs vers WAN (Mises à jour Windows, etc.)
    edit 2
        set name "SRV_to_WAN"
        set srcintf "VLAN100_SRV"
        set dstintf "port1"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
    next

# 3. Règle : LAN vers VLAN Serveurs (Pour joindre le domaine, requêtes DNS)
    edit 3
        set name "LAN_to_SRV"
        set srcintf "port2"
        set dstintf "VLAN100_SRV"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
    next
end
```

## 🔍 Étape 4 : Vérification et Accès Web (GUI)

Vérifiez que vous pouvez accéder à l'interface d'administration depuis votre réseau LAN.

1. Configurez votre ordinateur avec une IP fixe dans le LAN (ex: `192.168.20.50`, passerelle `192.168.20.1`).
2. Ouvrez un navigateur web et accédez à : `https://192.168.20.1`
3. Connectez-vous avec les identifiants par défaut (`admin` / mot de passe).
4. Le système vous obligera immédiatement à définir un mot de passe sécurisé.

## 👥 Étape 5 : Intégration de l'annuaire Active Directory (LDAP)

Une fois connecté à l'interface graphique (GUI) du FortiGate, vous pouvez lier votre annuaire Active Directory pour gérer les authentifications (VPN, Portail, etc.).

1. Dans le menu de gauche, accédez à **User & Authentication** > **LDAP Servers**.
2. Cliquez sur le bouton **Create New**.
3. Remplissez le formulaire de la façon suivante :
   * **Name :** `LDAP_Serveur_AD`
   * **Server IP/Name :** `192.168.100.2` *(Adresse IP du serveur)*
   * **Port :** `389`
   * **Common Name Identifier :** `sAMAccountName`
   * **Distinguished Name :** `dc=metalis,dc=local` *(Racine de l'annuaire)*
   * **Bind Type :** `Regular`
   * **Username :** `svc_fortigate_ldap@metalis.local` *(Votre compte de service)*
   * **Password :** *Saisissez le mot de passe du compte de service*
4. **Secure Connection :** Assurez-vous que cette option est **décochée** (configuration en LDAP standard non chiffré).
5. Cliquez sur **Test Connectivity** en bas de la page. Si le message `Successful` apparaît en vert, la communication est opérationnelle.
6. Cliquez sur **OK** pour sauvegarder.

## 🗑 Commandes Utiles (Aide-Mémoire)

Afficher la table de routage active :
```bash
get router info routing-table all
```

Tester la connectivité vers Internet depuis le FortiGate :
```bash
execute ping 8.8.8.8
```

Afficher le résumé des adresses IP des interfaces :
```bash
get system interface physical
```

Réinitialiser complètement le FortiGate aux paramètres d'usine (Factory Reset) :
```bash
execute factoryreset
```
