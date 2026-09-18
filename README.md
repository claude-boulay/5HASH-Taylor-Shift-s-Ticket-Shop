# Taylor Shift's Ticket Shop

Infrastructure et configuration pour la boutique de billetterie de Taylor Shift : provisionnement avec Terraform, configuration et déploiement avec Ansible, hébergée sur [Floci](https://floci.io) (émulateur AWS local) pour le développement et les tests.

## Prérequis

### Outils nécessaires

| Outil | Version requise | Rôle |
|-------|----------------|------|
| **Terraform** | ≥ 1.11 | Provisionnement de l'infrastructure AWS (EC2, VPC, ALB, RDS, etc.) |
| **Ansible Core** | 2.20.x (>=2.20, <2.21) | Configuration des serveurs et déploiement de l'application |
| **AWS CLI** | v2 | Interaction avec les services AWS (utilisé aussi par les rôles Ansible) |
| **Docker** | Latest | Conteneurisation de l'application PrestaShop |
| **Docker Compose** | Latest | Orchestration du conteneur Floci (émulateur AWS local) |
| **Python** | 3.8+ | Nécessaire pour Ansible et ses dépendances |
| **Git** | Latest | Gestion de version du code |

### À propos de Chocolatey (Windows uniquement)

**Qu'est-ce que Chocolatey ?**

Chocolatey est un gestionnaire de paquets pour Windows, similaire à `apt` sur Linux ou `brew` sur macOS. Il permet d'installer, mettre à jour et désinstaller des logiciels en ligne de commande, simplifiant grandement la gestion des outils de développement.

**Vérifier si Chocolatey est installé :**

```powershell
choco --version
```

**Installer Chocolatey (si non installé) :**

Ouvrez PowerShell **en tant qu'administrateur** et exécutez :

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Fermez et rouvrez PowerShell (toujours en administrateur) pour finaliser l'installation.

**Lien officiel :** [https://chocolatey.org/install](https://chocolatey.org/install)

> 💡 **Note** : Toutes les installations via Chocolatey mentionnées ci-dessous sont **optionnelles**. Une méthode d'installation manuelle est systématiquement proposée en alternative.

### Installation des outils

#### Terraform

**Windows (PowerShell) :**
```powershell
# Option A : Via Chocolatey (gestionnaire de paquets Windows)
# Nécessite Chocolatey installé (voir section ci-dessus)
# Ouvrir PowerShell en administrateur puis :
choco install terraform

# Option B : Téléchargement manuel (recommandé si Chocolatey n'est pas installé)
# 1. Télécharger depuis : https://www.terraform.io/downloads
# 2. Extraire le .zip et ajouter terraform.exe au PATH Windows
```

**Linux (Debian/Ubuntu) :**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Lien officiel :** [https://www.terraform.io/downloads](https://www.terraform.io/downloads)

#### Ansible Core

**Important :** Ansible Core **doit être en version 2.20.x** (pas 2.21+) à cause d'une incompatibilité avec la collection `cloud.terraform` utilisée pour l'inventaire dynamique.

**Windows & Linux (via pip - recommandé) :**
```bash
python3 -m venv .venv
source .venv/bin/activate  # Linux/macOS
# Ou : .venv\Scripts\activate  # Windows PowerShell

pip install -r requirements.txt  # Inclut ansible-core>=2.20,<2.21
```

**Lien officiel :** [https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

#### AWS CLI

**Windows (PowerShell) :**
```powershell
# Option A : Via installeur MSI (recommandé)
# Télécharger et exécuter : https://awscli.amazonaws.com/AWSCLIV2.msi

# Option B : Via Chocolatey (si déjà installé)
# Ouvrir PowerShell en administrateur puis :
choco install awscli
```

**Linux (Debian/Ubuntu) :**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Lien officiel :** [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/)

#### Docker & Docker Compose

**Windows :**
- Docker Desktop : [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)

**Linux (Debian/Ubuntu) :**
```bash
# Installation de Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER  # Ajouter l'utilisateur au groupe docker

# Docker Compose est inclus dans les versions récentes de Docker
```

**Lien officiel :** [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)

#### Git

**Windows :**
- [https://git-scm.com/download/win](https://git-scm.com/download/win)

**Linux :**
```bash
sudo apt install git  # Debian/Ubuntu
```

**Lien officiel :** [https://git-scm.com/downloads](https://git-scm.com/downloads)

## Stack technique

| Domaine | Outils |
|---|---|
| Infrastructure | Terraform (`hashicorp/aws` ~> 6.0), modules réutilisables |
| Configuration | Ansible, inventaire dynamique (`cloud.terraform.terraform_provider`) |
| Secrets | AWS Secrets Manager (infra), Ansible Vault (local, par personne) |
| Application | [PrestaShop](https://hub.docker.com/r/prestashop/prestashop) (image officielle), Docker |
| Base de données | RDS MySQL 8.0 |
| Répartition de charge | Application Load Balancer |
| Émulation locale | Floci |

## Architecture

### Vue d'ensemble

```
Internet
   │
   ▼
[ ALB — port 80 ]  ← Load Balancer avec health checks
   │  Répartit vers les cibles saines du groupe de cibles
   ├──► [ app1 ]  EC2 + Docker : conteneur PrestaShop
   └──► [ app2 ]  EC2 + Docker : conteneur PrestaShop
                     │
                     ▼
            [ RDS MySQL 8.0 ]  ← Base de données managée
            Sous-réseaux privés, aucune entrée hors du
            security group des instances applicatives

Secrets Manager : identifiants DB (générés par Terraform)
Ansible Vault   : identifiants admin PrestaShop (local, jamais versionné)
```

### Composants et justifications

**PrestaShop sur EC2 :**
- Déployé en conteneur Docker via Ansible (rôle `geerlingguy.docker` + rôle custom `prestashop`)
- Application stateless pouvant être répliquée sur plusieurs instances
- Configuration uniforme grâce à Ansible

**Base de données sur RDS :**
- Service managé AWS pour la base MySQL 8.0
- Sauvegardes automatiques et option Multi-AZ (en production)
- Illustre la répartition EC2/services managés demandée par le projet

**Réseau :**
- 2 sous-réseaux publics (ALB + instances EC2, un par zone de disponibilité)
- 2 sous-réseaux privés (RDS uniquement, aucune route Internet)
- Security groups : la base n'autorise que le trafic depuis les instances applicatives

### Gestion du trafic et montée en charge

**Flux de trafic :**
1. Le visiteur accède à l'URL de l'ALB (`app_url` dans les outputs Terraform)
2. L'ALB répartit les requêtes entre les instances **saines** via des health checks HTTP
3. Health check : `GET /` toutes les 15 secondes
4. Une instance défaillante est automatiquement retirée du pool sans intervention manuelle

**Scalabilité :**
- Le nombre d'instances est contrôlé par `var.instance_count` : 2 en dev/staging, 3 en production
- Scalabilité manuelle : modification de la variable puis `terraform apply`

**Limites et contraintes :**

1. **Pas d'auto-scaling** : Le nombre d'instances est fixe, pas ajusté automatiquement selon la charge. Un véritable Auto Scaling Group nécessiterait que chaque instance se configure elle-même au démarrage (`ansible-pull` ou AMI préconfigurée).

2. **HTTP uniquement** : Pas de TLS/HTTPS. Extension possible avec `aws_acm_certificate` + listener 443.

3. **Haute disponibilité en cas de panne** :
   - Si une instance tombe, l'ALB détecte l'échec en ~45 secondes (3 échecs × 15s)
   - Le trafic est automatiquement redirigé vers les instances restantes
   - La réparation nécessite une intervention manuelle : `ansible-playbook` ou `terraform apply`

4. **Limites de l'émulateur Floci** :
   - L'ALB de Floci remplace le header `Host` par `ip:port` au lieu de préserver le nom de domaine
   - Le rôle Ansible `prestashop` compense avec `mod_headers` + `RequestHeader set Host`
   - Floci doit être manuellement connecté au réseau Docker du VPC (voir étape 6 de l'installation)

## Environnements

Trois environnements séparés par variable `var.environment` et par state Terraform distinct :

| Environnement | Instances | RDS Multi-AZ | Fichier de configuration |
|---------------|-----------|--------------|--------------------------|
| `dev` (défaut) | 2 | Non | `environments/dev.tfvars` |
| `staging` | 2 | Non | `environments/staging.tfvars` |
| `prod` | 3 | Oui, `db.t3.small` | `environments/prod.tfvars` |

**Changer d'environnement :**

Pour déployer `staging` :
```bash
terraform -chdir=terraform init -reconfigure \
  -backend-config="key=staging/terraform.tfstate"
terraform -chdir=terraform apply -var-file=environments/staging.tfvars
```

Pour revenir à `dev` :
```bash
terraform -chdir=terraform init -reconfigure \
  -backend-config="key=dev/terraform.tfstate"
```

## Installation et déploiement

### Étape 1 : Cloner le projet

```bash
git clone git@github.com:claude-boulay/5HASH-Taylor-Shift-s-Ticket-Shop.git
cd 5HASH-Taylor-Shift-s-Ticket-Shop
```

### Étape 2 : Configurer l'environnement Python pour Ansible

```bash
# Créer un environnement virtuel
python3 -m venv .venv

# Activer l'environnement
source .venv/bin/activate  # Linux/macOS
# Ou : .venv\Scripts\activate  # Windows PowerShell

# Installer les dépendances (inclut ansible-core>=2.20,<2.21)
pip install -r requirements.txt
```

**Vérification :**
```bash
ansible --version
# Doit afficher : ansible [core 2.20.x]
```

> ⚠️ **Important** : Si vous avez ansible-core 2.21+, l'inventaire dynamique échouera avec l'erreur `get_bin_path() got an unexpected keyword argument 'required'`. Utilisez impérativement un environnement virtuel avec la version 2.20.x.

### Étape 3 : Lancer Floci (émulateur AWS local)

```bash
docker compose up -d
```

**Vérification :**
```bash
docker compose ps
# Le conteneur 'floci' doit être en état 'running'
```

> 💡 **Note** : Si votre utilisateur n'est pas dans le groupe `docker`, préfixez les commandes Docker avec `sudo`.

### Étape 4 : Créer le bucket S3 pour le state Terraform

Le bucket S3 qui stocke le state Terraform doit être créé manuellement (bootstrap) :

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url http://localhost.floci.io:4566 s3api create-bucket \
  --bucket taylor-shift-tfstate
```

**Vérification :**
```bash
aws --endpoint-url http://localhost.floci.io:4566 s3 ls
# Doit afficher : taylor-shift-tfstate
```

### Étape 5 : Générer la clé SSH du projet

Cette clé SSH sera utilisée par Ansible pour se connecter aux instances EC2 :

```bash
mkdir -p .keys
ssh-keygen -t ed25519 -f .keys/taylor-shift -N ""
```

**Vérification :**
```bash
ls -l .keys/
# Doit afficher : taylor-shift et taylor-shift.pub
```

### Étape 6 : Créer le coffre Ansible Vault pour les secrets applicatifs

Le fichier `ansible/group_vars/all/vault.yml` contient les identifiants admin PrestaShop. Il est **chiffré** et **non versionné** (chaque développeur a le sien).

```bash
mkdir -p ansible/group_vars/all
ansible-vault create ansible/group_vars/all/vault.yml
```

Lorsque l'éditeur s'ouvre, saisissez :
```yaml
---
vault_admin_email: admin@taylor-shift.example
vault_admin_password: VotreMotDePasseSecurise123!
```

Sauvegardez et quittez. **Notez le mot de passe du coffre** : il sera redemandé à chaque commande Ansible.

**Vérification :**
```bash
ansible-vault view ansible/group_vars/all/vault.yml
# Entrez le mot de passe du coffre : doit afficher le contenu déchiffré
```

### Étape 7 : Initialiser et déployer l'infrastructure avec Terraform

```bash
# Initialiser Terraform
terraform -chdir=terraform init

# Déployer l'infrastructure
terraform -chdir=terraform apply
# Tapez 'yes' quand demandé
```

**Vérification :**
```bash
terraform -chdir=terraform output
# Doit afficher les outputs : app_url, instance_ids, db_endpoint, etc.
```

### Étape 8 : Connecter Floci au réseau Docker du VPC

Cette étape critique permet à l'ALB de Floci de router vers les IP privées des instances EC2.

```bash
docker network connect $(docker network ls --filter name=floci-vpc --format '{{.Name}}') \
  $(docker compose ps -q floci)
```

**Vérification :**
```bash
docker inspect $(docker compose ps -q floci) \
  --format '{{range $net, $_ := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}'
# Doit afficher : le réseau du projet ET un réseau floci-vpc-...
```

> ⚠️ **Important** : Sans cette étape, l'ALB restera en erreur 503 permanent.

### Étape 9 : Installer les dépendances Ansible (rôles et collections)

```bash
# Collections (dont cloud.terraform pour l'inventaire dynamique)
ansible-galaxy collection install -r ansible/requirements.yml

# Rôles (dont geerlingguy.docker)
ansible-galaxy role install -r ansible/requirements.yml
```

**Vérification de l'inventaire dynamique :**
```bash
ansible-inventory -i ansible/inventory.yml --graph
# Doit afficher la structure : @all > @ungrouped, @application > app1, app2
```

### Étape 10 : Configurer et déployer l'application avec Ansible

```bash
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
# Entrez le mot de passe du coffre Ansible Vault
```

**Test d'idempotence :** Relancez la même commande une seconde fois :
```bash
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
# Résultat attendu : changed=0 partout (aucun changement appliqué)
```

### Étape 11 : Vérifier l'accès à l'application

```bash
# Récupérer l'URL de l'application
terraform -chdir=terraform output app_url

# Tester l'accès HTTP
curl -I $(terraform -chdir=terraform output -raw app_url)
```

**Résultat attendu :**
- Code HTTP `200 OK` ou `302 Found` (redirection PrestaShop normale)
- L'URL doit être accessible dans un navigateur web

**Accès à l'interface d'administration :**
- URL : `http://<app_url>/admin-dev`
- Email : celui configuré dans `vault.yml`
- Mot de passe : celui configuré dans `vault.yml`

## Problèmes courants et résolutions

### 1. Erreur `get_bin_path() got an unexpected keyword argument 'required'`

**Symptôme :**
```
ERROR! couldn't resolve module/action 'cloud.terraform.terraform_provider'
...
get_bin_path() got an unexpected keyword argument 'required'
```

**Cause :** Ansible Core version 2.21 ou supérieure installée. La collection `cloud.terraform` est incompatible avec cette version.

**Solution :**
```bash
# Créer un environnement virtuel avec la bonne version
python3 -m venv .venv
source .venv/bin/activate  # Linux/macOS
# Ou : .venv\Scripts\activate  # Windows

pip install 'ansible-core>=2.20,<2.21'
pip install -r requirements.txt
```

### 2. ALB en erreur 503 permanent (Service Unavailable)

**Symptôme :**
```bash
curl -I $(terraform -chdir=terraform output -raw app_url)
# Retourne : HTTP/1.1 503 Service Unavailable
```

**Diagnostic :**
```bash
# Vérifier l'état des cibles dans le groupe de cibles
aws --endpoint-url http://localhost.floci.io:4566 elbv2 describe-target-health \
  --target-group-arn <arn_du_target_group>
# Affiche : "State": "unhealthy", "Reason": "Target.FailedHealthChecks"
```

**Cause :** Le conteneur Floci n'est pas connecté au réseau Docker du VPC. L'ALB ne peut pas router vers les IP privées des instances.

**Solution :**
```bash
# Connecter Floci au réseau du VPC
docker network connect $(docker network ls --filter name=floci-vpc --format '{{.Name}}') \
  $(docker compose ps -q floci)

# Redémarrer Floci pour relancer l'ALB
docker compose restart floci

# Attendre 30-60 secondes que les health checks passent
curl -I $(terraform -chdir=terraform output -raw app_url)
```

**Si le problème persiste après redémarrage de Floci :**
Les instances EC2 doivent être redémarrées manuellement (voir section 3).

### 3. Instances EC2 inaccessibles après redémarrage de Floci/Docker

**Symptôme :**
```bash
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
# Erreur : "Failed to connect to the host via ssh"
```

**Cause :** Le redémarrage de Docker Desktop/WSL ou du conteneur Floci arrête les conteneurs qui simulent les EC2, mais ne relance pas leurs services (SSH, Docker interne).

**Solution 1 - Redémarrage manuel des services :**
```bash
# Relancer Floci
docker compose up -d

# Pour chaque instance (remplacer i-xxxxx par l'ID réel)
docker start floci-ec2-i-xxxxx
docker exec floci-ec2-i-xxxxx service ssh start
docker exec floci-ec2-i-xxxxx service docker start

# Vérifier que PrestaShop est redémarré
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
```

**Solution 2 - Recréation des instances (plus rapide) :**
```bash
# Recréer toutes les instances
terraform -chdir=terraform apply \
  -replace='module.compute.aws_instance.app["app1"]' \
  -replace='module.compute.aws_instance.app["app2"]'

# Redéployer l'application
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
```

### 4. Permission denied sur les commandes Docker

**Symptôme :**
```bash
docker compose up -d
# Erreur : "permission denied while trying to connect to the Docker daemon socket"
```

**Cause :** L'utilisateur actuel n'est pas dans le groupe `docker`.

**Solution (Linux) :**
```bash
# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Se déconnecter/reconnecter ou :
newgrp docker

# Vérifier
docker ps
```

**Solution (Windows/WSL) :**
Vérifier que Docker Desktop est lancé et configuré pour WSL 2.

### 5. Erreur "bucket does not exist" lors du terraform init

**Symptôme :**
```bash
terraform -chdir=terraform init
# Erreur : "Failed to get existing workspaces: S3 bucket does not exist"
```

**Cause :** Le bucket S3 de backend n'a pas été créé (étape 4 manquante).

**Solution :**
```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url http://localhost.floci.io:4566 s3api create-bucket \
  --bucket taylor-shift-tfstate

# Réessayer
terraform -chdir=terraform init
```

### 6. Ansible Vault : "Decryption failed"

**Symptôme :**
```bash
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
# Erreur : "Decryption failed (no vault secrets were found that could decrypt)"
```

**Cause :** Mot de passe du coffre Ansible Vault incorrect.

**Solution :**
- Vérifier le mot de passe noté lors de l'étape 6
- Si perdu, recréer le coffre :
```bash
rm ansible/group_vars/all/vault.yml
ansible-vault create ansible/group_vars/all/vault.yml
# Saisir à nouveau : vault_admin_email et vault_admin_password
```

### 7. PrestaShop affiche une erreur de connexion à la base de données

**Symptôme :** Page blanche ou erreur "Database connection error" lors de l'accès à l'application.

**Diagnostic :**
```bash
# Vérifier que RDS est accessible
terraform -chdir=terraform output db_endpoint

# Tester depuis une instance
ansible app -i ansible/inventory.yml -m shell \
  -a "mysql -h <db_endpoint> -u admin -p<password> -e 'SHOW DATABASES;'" \
  --ask-vault-pass
```

**Solutions possibles :**
- Vérifier que les security groups autorisent le trafic 3306 entre instances et RDS
- Vérifier que le mot de passe de base de données dans Secrets Manager est correct
- Redéployer avec Ansible : `ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass`

### 8. "No hosts matched" lors de ansible-playbook

**Symptôme :**
```bash
ansible-inventory -i ansible/inventory.yml --graph
# Affiche uniquement : @all | @ungrouped
```

**Cause :** L'inventaire dynamique ne trouve pas les instances Terraform.

**Diagnostic :**
```bash
# Vérifier que l'infrastructure existe
terraform -chdir=terraform output instance_ids

# Vérifier le state Terraform
ls -la terraform/terraform.tfstate
```

**Solution :**
- Si pas d'infrastructure : `terraform -chdir=terraform apply`
- Si l'inventaire ne se rafraîchit pas : vérifier `ansible/inventory.yml` et que `cloud.terraform` est installé

## Détruire l'infrastructure

Pour supprimer complètement l'infrastructure et repartir de zéro :

```bash
# Détruire les ressources AWS
terraform -chdir=terraform destroy
# Confirmer avec 'yes'

# Supprimer le bucket S3 de state
aws --endpoint-url http://localhost.floci.io:4566 s3 rm \
  s3://taylor-shift-tfstate --recursive
aws --endpoint-url http://localhost.floci.io:4566 s3api delete-bucket \
  --bucket taylor-shift-tfstate

# Arrêter et supprimer Floci
docker compose down

# (Optionnel) Supprimer les réseaux Docker orphelins
docker network prune -f
```

**Pour redéployer après destruction :**
1. Reprendre à partir de l'étape 3 (Lancer Floci)
2. Les étapes 2 (Python venv), 5 (clé SSH) et 6 (Ansible Vault) ne sont à refaire que si vous avez aussi supprimé `.venv/`, `.keys/` et le fichier vault
