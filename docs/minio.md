# Documentation d'Installation : Configuration Initiale MinIO sous Windows Server 2022

Ce guide détaille l'installation et la configuration de base de MinIO sur Windows Server 2022, incluant la préparation des répertoires, le paramétrage des variables d'environnement, le lancement initial et l'automatisation sous forme de service Windows.

---

## Prérequis

Avant de commencer, assurez-vous de disposer de :

* Un serveur exécutant Windows Server 2022 connecté au réseau.
* Un accès avec les privilèges Administrateur sur la machine.
* Un espace de stockage dédié pour accueillir les données de sauvegarde (par exemple, un second disque dur ou une partition distincte).
* Une connexion Internet sur le serveur pour le téléchargement initial du binaire.

---

## Étape 1 : Préparation des Répertoires et Téléchargement (PowerShell)

Pour garantir une structure propre, il est nécessaire de séparer l'exécutable de l'application de l'emplacement de stockage des données réelles.

Ouvrez une console PowerShell en mode Administrateur et exécutez les commandes suivantes :

```powershell
# 1. Création du répertoire pour l'application MinIO
mkdir C:\MinIO

# 2. Création du répertoire dédié au stockage des objets S3
# Note : Si vous disposez d'un disque de stockage séparé (ex: D:), créez ce dossier dessus.
mkdir C:\MinIO-Data

```

Téléchargez ensuite l'exécutable officiel stable pour l'architecture Windows :

```powershell
# 3. Téléchargement du fichier binaire minio.exe
Invoke-WebRequest -Uri "https://dl.min.io/server/minio/release/windows-amd64/minio.exe" -OutFile "C:\MinIO\minio.exe"

```

## Étape 2 : Configuration des Variables d'Environnement

Par défaut, MinIO utilise les identifiants génériques "minioadmin" pour l'accès. Il est impératif de configurer des variables d'environnement pour définir vos propres accès sécurisés.

```powershell
# 1. Déclaration des variables pour la session PowerShell actuelle (Prise en compte immédiate)
$env:MINIO_ROOT_USER="votre_nom_utilisateur"
$env:MINIO_ROOT_PASSWORD="UnMotDePasseTresRobuste123!"

# 2. Enregistrement définitif des variables dans le système Windows
setx MINIO_ROOT_USER "votre_nom_utilisateur" /M
setx MINIO_ROOT_PASSWORD "UnMotDePasseTresRobuste123!" /M

```

## Étape 3 : Premier Lancement et Comportement de la CLI

Exécutez la commande suivante pour démarrer manuellement le serveur MinIO et valider sa configuration :

```powershell
C:\MinIO\minio.exe server C:\MinIO-Data --console-address ":9001"

```

Attention : Lors de l'exécution dans PowerShell, vous constaterez l'apparition de lignes de texte rouge contenant la mention "NativeCommandError". Ce comportement est normal et ne traduit pas un plantage du programme. MinIO redirige ses lignes de logs d'initialisation vers le flux d'erreur standard (stderr), que PowerShell interprète à tort comme une anomalie critique. Le serveur reste parfaitement actif et à l'écoute.

## Étape 4 : Accès à l'Interface Graphique (GUI)

Une fois le serveur démarré, l'administration s'effectue via un navigateur web.

1. Ouvrez un navigateur et accédez à l'adresse de la console : `http://localhost:9001` (ou l'adresse IP locale du serveur sur le port 9001).
2. Connectez-vous avec les identifiants définis à l'Étape 2.
3. Utilisez l'interface pour créer vos espaces de stockage (Buckets) et générer les clés d'accès (Access Key et Secret Key) requises par votre logiciel de sauvegarde.

## Étape 5 : Automatisation en tant que Service Windows

Pour éviter de maintenir une session utilisateur et une fenêtre PowerShell ouvertes en permanence, vous devez configurer MinIO pour qu'il s'exécute en arrière-plan comme un service Windows natif à l'aide de l'utilitaire WinSW.

1. Téléchargez l'utilitaire WinSW depuis son dépôt officiel GitHub (binaire exécutable pour Windows x64).
2. Placez l'exécutable dans le dossier `C:\MinIO` et renommez-le précisément en `winsw.exe`.
3. Créez un fichier texte nommé `winsw.xml` dans ce même dossier `C:\MinIO` contenant la configuration suivante :

```xml
<service>
  <id>minio</id>
  <name>MinIO Object Storage</name>
  <description>Serveur de stockage objet compatible S3 (Alternative Cloud)</description>
  <executable>C:\MinIO\minio.exe</executable>
  <arguments>server C:\MinIO-Data --console-address ":9001"</arguments>
  <env name="MINIO_ROOT_USER" value="votre_nom_utilisateur"/>
  <env name="MINIO_ROOT_PASSWORD" value="UnMotDePasseTresRobuste123!"/>
  <log mode="roll"></log>
</service>

```

4. Ouvrez une invite de commandes ou un terminal PowerShell en mode Administrateur, puis exécutez l'installation et le démarrage du service :

```powershell
cd C:\MinIO
.\winsw.exe install
.\winsw.exe start

```

## Commandes Utiles (Aide-Mémoire)

Démarrer manuellement le service Windows :

```powershell
net start minio

```

Arrêter le service Windows :

```powershell
net stop minio

```

Désinstaller le service Windows (nécessite l'arrêt préalable) :

```powershell
cd C:\MinIO
.\winsw.exe uninstall

```
