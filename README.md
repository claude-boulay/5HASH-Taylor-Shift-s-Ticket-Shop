# Taylor Shift's Ticket Shop

Infrastructure et configuration pour la boutique de billetterie de Taylor
Shift : provisionnement avec Terraform, configuration et déploiement avec
Ansible, hébergée sur [Floci](https://floci.io) (émulateur AWS local) pour
le développement et les tests.

## Stack

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

```
Internet
   │
   ▼
[ ALB — port 80 ]
   │  répartit vers les cibles saines du groupe de cibles
   ├──► [ app1 ]  EC2 + Docker : conteneur PrestaShop
   └──► [ app2 ]  EC2 + Docker : conteneur PrestaShop
                     │
                     ▼
            [ RDS MySQL 8.0 ]
            sous-réseaux privés, aucune entrée hors du
            security group des instances applicatives

Secrets Manager : identifiants DB (générés par Terraform)
Ansible Vault   : identifiants admin PrestaShop (local, jamais versionné)
```

**Placement des composants et pourquoi :**
- **PrestaShop sur EC2**, en conteneur Docker installé par Ansible
  (rôle `geerlingguy.docker` + rôle `prestashop`) : c'est la partie
  applicative, sans état, qui doit pouvoir se répéter à l'identique sur
  plusieurs instances.
- **La base sur RDS**, un service managé, plutôt que sur EC2 : sauvegardes
  automatiques, option Multi-AZ, et ça illustre le partage EC2/managé
  demandé par le sujet.
- **Réseau** : 2 sous-réseaux publics (ALB + instances, un par zone), 2
  sous-réseaux privés (RDS uniquement, aucune route vers Internet). Le
  security group de la base n'autorise que le security group applicatif.

## Comment le trafic atteint l'application, et sa montée en charge

Un visiteur atteint l'ALB (`app_url`, sortie Terraform), qui répartit les
requêtes entre les instances **saines** de son groupe de cibles — un
health check HTTP (`GET /`, toutes les 15s) retire automatiquement une
instance en panne, sans intervention manuelle. **`var.instance_count`**
(2 en dev/staging, 3 en prod) fixe combien d'instances Terraform
provisionne.

**Limites assumées :**
- **Pas d'élasticité automatique.** Le nombre d'instances est fixé par une
  variable, pas ajusté par la charge — un vrai Auto Scaling Group
  demanderait que chaque machine se configure elle-même à l'arrivée
  (`ansible-pull` ou image déjà prête), puisqu'ici Terraform doit connaître
  chaque instance à l'avance pour nourrir l'inventaire Ansible.
- **HTTP seul**, pas de TLS. Extension possible : `aws_acm_certificate` +
  listener 443.
- **Si une instance tombe** : l'ALB cesse de lui envoyer du trafic dès
  l'échec du health check (jusqu'à ~45s, 3 échecs à 15s d'intervalle) ;
  les visiteurs continuent d'être servis par l'autre instance. La panne
  n'est pas réparée automatiquement — il faut relancer `ansible-playbook`
  (ou `terraform apply` si l'instance elle-même a disparu).
- **Limite de l'émulateur Floci** : son ALB relaie chaque requête vers la
  cible en remplaçant le `Host` par `ip:port` de cette cible, au lieu de
  préserver le nom de domaine du client comme le fait un vrai ALB AWS. Le
  rôle `prestashop` compense en forçant ce `Host` côté Apache
  (`mod_headers` + `RequestHeader set Host`, incident 22 de
  `cmdlist.md`) — sans ce correctif, PrestaShop redirige indéfiniment
  vers son propre domaine à chaque requête passée par l'ALB.
- **Autre limite de Floci** : le conteneur `floci` doit être sur le même
  réseau Docker que le VPC qu'il émule pour pouvoir router vers les IP
  privées (`10.x.x.x`) des instances, mais ne rejoint pas ce réseau tout
  seul — sans intervention, son ALB reste en `503` permanent même si
  PrestaShop répond correctement. L'étape 6 du démarrage
  (`docker network connect`) corrige ça une fois pour toutes ; voir
  « Floci reste en 503 : il n'est pas sur le réseau du VPC » si vous
  l'avez zappée ou après une recréation complète de `floci`.

## Prérequis

| Outil | Version |
|---|---|
| Terraform | ≥ 1.11 |
| Ansible (`ansible-core`) | 2.20.x |
| AWS CLI | v2 |
| Docker + Docker Compose | — |

Le CLI AWS n'est pas qu'un outil d'exploitation manuelle : le rôle
`prestashop` (Part 7) l'appelle lui-même pour récupérer le mot de passe
de la base dans Secrets Manager

## Démarrage, depuis un clone tout neuf

```bash
git clone git@github.com:claude-boulay/5HASH-Taylor-Shift-s-Ticket-Shop.git
cd 5HASH-Taylor-Shift-s-Ticket-Shop
```

### 1. Lancer Floci

```bash
docker compose up -d
```

### 2. Mettre en place le backend Terraform

Le bucket S3 qui reçoit le state n'existe pas encore — Terraform ne peut
pas créer le bucket dont il a lui-même besoin pour démarrer. On le crée
une fois, à la main :

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url http://localhost.floci.io:4566 s3api create-bucket \
  --bucket taylor-shift-tfstate
```

### 3. Générer la clé SSH du projet

```bash
mkdir -p .keys
ssh-keygen -t ed25519 -f .keys/taylor-shift -N ""
```

### 4. Le secret applicatif (Ansible Vault)

`ansible/group_vars/all/vault.yml` n'est **ni versionné, ni partagé**
(`.gitignore`) : chaque personne qui clone crée son propre coffre, avec
son propre mot de passe. Ça évite qu'un seul mot de passe de coffre (et
un seul fichier chiffré à tenir à jour) protège tout le monde.

```bash
mkdir -p ansible/group_vars/all
ansible-vault create ansible/group_vars/all/vault.yml
```
Contenu à saisir :
```yaml
---
vault_admin_email: admin@taylor-shift.example
vault_admin_password: <votre mot de passe>
```

**Notez le mot de passe du coffre quelque part** — il est redemandé à
chaque commande Ansible (`--ask-vault-pass`), et lui non plus ne part
jamais dans le dépôt (`.vault-pass`, `.gitignore`) : personne ne peut le
retrouver à votre place.

### 5. Déployer l'infrastructure

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply
```

### 6. Rattacher Floci au réseau du VPC qu'il vient de créer

`terraform apply` fait créer par Floci le réseau Docker qui émule le VPC
(`floci-vpc-...`) et y attache les instances EC2 — mais Floci n'y attache
pas son propre conteneur. Sans cette étape, son ALB ne peut pas router
vers les IP privées (`10.x.x.x`) des cibles : health checks en échec,
`503` permanent (voir « Limites assumées » ci-dessus). À faire une seule
fois, juste après le premier `apply` qui crée le VPC :

```bash
docker network connect $(docker network ls --filter name=floci-vpc --format '{{.Name}}') \
  $(docker compose ps -q floci)
```
Fait à ce stade (avant que l'ALB commence ses health checks), **aucun
redémarrage de Floci n'est nécessaire** — donc les instances EC2 ne
risquent pas d'être tuées au passage. Voir « Floci reste en 503 » plus
bas si vous l'avez zappée ou si vous recréez `floci` entièrement.

### 7. Installer les dépendances Ansible

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-galaxy role install -r ansible/requirements.yml
```

### 8. Configurer et déployer l'application

```bash
ansible-inventory -i ansible/inventory.yml --graph   # vérification
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
```
Relancez la même commande une seconde fois : elle doit annoncer
`changed=0` partout (idempotence).

### 9. Vérifier

```bash
terraform -chdir=terraform output app_url
curl -I $(terraform -chdir=terraform output -raw app_url)
```
**Résultat attendu :** `200` ou `302`.

## Environnements

Trois environnements partagent le même code, séparés par variable
(`var.environment`) et par **state Terraform** (jamais par un simple
`-var`, sinon Terraform remplacerait un environnement par l'autre) :

| Environnement | Instances | RDS Multi-AZ | Fichier |
|---|---|---|---|
| `dev` (par défaut) | 2 | non | `environments/dev.tfvars` |
| `staging` | 2 | non | `environments/staging.tfvars` |
| `prod` | 3 | oui, `db.t3.small` | `environments/prod.tfvars` |

Déployer un environnement autre que `dev` :
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

## Détruire l'infrastructure

```bash
terraform -chdir=terraform destroy
aws --endpoint-url http://localhost.floci.io:4566 s3 rm s3://taylor-shift-tfstate --recursive
aws --endpoint-url http://localhost.floci.io:4566 s3api delete-bucket --bucket taylor-shift-tfstate
docker compose down
```

Pour la reconstruire ensuite, repartez de l'étape 2 (le bucket a été
supprimé) — les étapes 3 et 4 (clé SSH, coffre Vault) n'ont besoin d'être
refaites que si vous avez aussi supprimé `.keys/` et le coffre.

## Floci reste en 503 : il n'est pas sur le réseau du VPC

**Symptôme :** `curl -I $(terraform -chdir=terraform output -raw app_url)`
renvoie `503 Service Unavailable` en boucle (ou un timeout pur et simple
si ça traîne depuis un moment), alors que PrestaShop répond bien en
direct sur chaque instance :
```bash
aws --endpoint-url http://localhost.floci.io:4566 elbv2 describe-target-health \
  --target-group-arn <arn du groupe de cibles>
```
montre les cibles `unhealthy` (`Target.Timeout` ou
`Target.FailedHealthChecks`).

### Connaître l'arn du groupe de cibles 
```bash
aws --endpoint-url http://localhost.floci.io:4566 \
  elbv2 describe-target-groups \
  --names taylor-shift-dev-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text
```

**Cause :** `floci` crée lui-même le réseau Docker qui émule le VPC
(`floci-vpc-...`) et y attache les instances EC2, mais ne s'y attache pas
toujours lui-même à la création de la stack. Sans cette interface, son
ALB ne peut structurellement pas router vers les IP privées (`10.x.x.x`)
des cibles enregistrées — le health check échoue indéfiniment, quel que
soit l'état réel de PrestaShop.

**Vérifier :**
```bash
docker inspect $(docker compose ps -q floci) \
  --format '{{range $net, $_ := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}'
```
S'il n'affiche que le réseau du projet (`..._default`) et aucun réseau
`floci-vpc-...`, c'est ça.

**Corriger :**
```bash
docker network connect $(docker network ls --filter name=floci-vpc --format '{{.Name}}') \
  $(docker compose ps -q floci)
docker compose restart floci
```
Le redémarrage de `floci` est nécessaire pour relever son ALB : le
listener finit par planter à force de health checks vers des cibles
injoignables. **Attention**, ce redémarrage arrête aussi les conteneurs
qui simulent les instances EC2 sans les reprovisionner (sshd et le
Docker imbriqué ne repartent pas tout seuls) — enchaînez directement
avec la procédure « Redémarrer les instances après un arrêt de Floci »
ci-dessous, jusqu'à la recréation via `terraform apply -replace` si
`service ssh start` / `service docker start` ne suffisent pas. Pensez
aussi à retirer du groupe de cibles les anciennes IP devenues fantômes
(`elbv2 deregister-targets`) si vous recréez les instances au lieu de
les redémarrer.

Cette connexion réseau **n'est pas persistée** : elle ne tient que tant
que le conteneur `floci` existe. Si vous le recréez entièrement
(`docker compose down` puis `up`, pas un simple `restart`), il faudra la
refaire.

## Redémarrer les instances après un arrêt de Floci

Floci tourne dans Docker : un redémarrage de Docker Desktop/WSL (pas une
suppression Terraform) arrête ses conteneurs, y compris ceux qui simulent
les instances EC2 — mais **ne relance ni leurs services ni leur SSH**
automatiquement (`docker start` ne fait que relancer le process principal
du conteneur, pas le bootstrap que Floci exécute à la création).

```bash
docker compose up -d   # relance Floci lui-même

# pour chaque instance arrêtée :
docker start floci-ec2-<instance-id>
docker exec floci-ec2-<instance-id> service ssh start
docker exec floci-ec2-<instance-id> service docker start
```
Les identifiants d'instance (`i-...`) sont dans la sortie `instance_ids`
de `terraform output`. Le Docker imbriqué (celui qui fait tourner
PrestaShop *dans* l'instance) ne redémarre pas non plus tout seul — sans
`service docker start`, `ansible-playbook` échouera en essayant de
joindre son SDK Python Docker. Une fois SSH et Docker de retour, un
simple `ansible-playbook ... --ask-vault-pass` remet le reste en ordre :
grâce à `restart_policy: unless-stopped`, le dockerd qui redémarre relance
lui-même le conteneur PrestaShop, Ansible le retrouve déjà démarré et ne
change rien.

Si malgré ça les instances ne redeviennent pas joignables en SSH (ça
arrive, notamment après le redémarrage forcé de `floci` décrit
ci-dessus), le plus simple est de les recréer plutôt que de s'acharner :
```bash
terraform -chdir=terraform apply \
  -replace='module.compute.aws_instance.app["app1"]' \
  -replace='module.compute.aws_instance.app["app2"]'
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-vault-pass
```

## Pour aller plus loin

Le détail complet de la construction de ce projet — chaque fichier, dans
l'ordre, avec le contenu à y mettre — vit dans
[`cmdlist.md`](cmdlist.md), ainsi qu'un journal des incidents
rencontrés pendant la construction (diagnostic et correction de chacun),
utile en cas de nouvelle panne du même genre.
