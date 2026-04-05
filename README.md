# Scalable 3-Tier Java Application on AWS (Terraform + CI/CD)

## Overview

This project demonstrates the design and deployment of a **highly available**, **scalable**, and **secure** 3-tier Java web application on AWS. It combines a **Spring Boot** login/registration app shipped as the **`dptweb` WAR** with **Terraform** that **provisions** the AWS environment around it.

**End users** reach the app through an **internet-facing Network Load Balancer** while **Tomcat**, **RDS**, and the **Maven build host** stay in **private subnets**. Only the front tier (Nginx + public NLB) sits in the public path; the database is never exposed to the internet.

---

## Modern DevOps principles (how this stack is built)

| Principle | How it shows up here |
|-----------|---------------------|
| **Immutable infrastructure** | **Golden AMIs** (base → Nginx, Tomcat, Maven) bake OS and middleware once; new capacity launches from known images instead of hand-patched servers. |
| **Auto Scaling** | **Nginx** and **Tomcat** run in **Auto Scaling Groups** behind **Network Load Balancers** so the web and app tiers can scale horizontally across **Availability Zones**. |
| **CI/CD-style release path** | **Git** → **Maven build EC2** (`mvn deploy`) → **JFrog Artifactory** (`dptweb-1.0.war`) → each **new Tomcat** instance **user-data** pulls the WAR and deploys **`ROOT.war`**. |
| **Private networking & least exposure** | **RDS** and app/build subnets are **private**; **outbound** traffic uses a **NAT Gateway**. Operators can use a **separate VPC**, **Transit Gateway**, and **bastion** for access without opening the app tier to the world. |
| **Secrets, not static credentials** | **AWS Secrets Manager** stores **JFrog** credentials (for Maven + WAR download) and the **RDS master password** (injected for Spring at boot, e.g. via Tomcat/`tomcat.conf`). |

### Runtime path (who talks to whom)

Users hit an **internet-facing NLB** → **Nginx** (reverse proxy) → **internal NLB** → **Tomcat** (serves `ROOT.war`) → **Amazon RDS for MySQL** (`UserDB`). **Nginx does not** connect to the database; **Tomcat** does, using the JDBC URL from the WAR and **`SPRING_DATASOURCE_PASSWORD`** from **Secrets Manager** (applied at instance boot).

### Build & deploy path

Source lives in **Git**. A **Maven build EC2** (from a **Maven golden AMI**) runs **`mvn deploy`** and publishes **`dptweb-1.0.war`** to **JFrog Artifactory**. Each **new Tomcat** instance (from a **Tomcat golden AMI**) runs **user-data** that reads **JFrog** and **RDS** secrets, **downloads** the WAR, installs it as **`ROOT.war`**, and **restarts Tomcat**.

### Reference architecture diagrams

These diagrams are **design references**. This repo’s Terraform may differ in details (for example this stack uses **Network Load Balancers** and **GitHub**, and RDS is **single-AZ** unless you extend the module).

#### Target pipeline & platform (reference)

![Reference architecture: VPN, TGW, CI/CD, JFrog, NLB, multi-tier](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/02-architecture-target-devops-pipeline.png)

*Illustrative target: Bitbucket/Maven/Sonar/JFrog, Transit Gateway, public NLB, internal balancing to app tier, RDS. Align mentally with this project’s GitHub → Maven EC2 → JFrog → Tomcat path.*

#### Classic 3-tier VPC across two AZs (reference)

![Reference: public / private app / private DB subnets across AZs](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/03-architecture-3tier-vpc-az.png)

*Illustrative 3-tier layout. This project uses **NLBs** (not ALB) for load balancing; subnet and routing ideas are the same.*

---

## Request & release flow (text)

### End-user HTTP request flow

`Internet user` → **`Public NLB`** `:80` → **`Nginx`** (ASG, reverse proxy) → **`Internal NLB`** `:8080` → **`Tomcat`** (ASG, `ROOT.war`) → **`RDS MySQL`** `:3306` (`UserDB`)

### Build & artifact flow (to runtime)

`Git` (e.g. GitHub) → **`Maven build EC2`** (golden AMI) → **`mvn deploy`** → **`JFrog Artifactory`** (`dptweb-1.0.war`) → **Tomcat user-data** (Secrets Manager + `curl`) → **`ROOT.war`** on new instances

---

Use this document together with:

- `database/README.md` — schema and how to run SQL against RDS  
- `Terraform/` — all infrastructure code (`terraform.tfvars` / variables for your environment)  
- `docs/images/` — screenshots referenced in [Screenshots & diagrams](#screenshots--diagrams)

---

## Table of contents

1. [What this project does](#what-this-project-does)  
2. [High-level architecture](#high-level-architecture)  
3. [Repository layout](#repository-layout)  
4. [Infrastructure components (implemented)](#infrastructure-components-implemented)  
5. [CI pipeline (build phase)](#ci-pipeline-build-phase)  
6. [CD pipeline (deployment phase)](#cd-pipeline-deployment-phase)  
7. [Secrets and configuration](#secrets-and-configuration)  
8. [Application configuration](#application-configuration)  
9. [Typical deployment flow](#typical-deployment-flow)  
10. [Pre-deployment (golden AMIs)](#pre-deployment-golden-amis)  
11. [VPC and connectivity](#vpc-and-connectivity)  
12. [Post-deployment & operations](#post-deployment--operations)  
13. [Validation checklist](#validation-checklist)  
14. [Screenshots & diagrams](#screenshots--diagrams)  
15. [Application deployment](#application-deployment)  
16. [Observability](#observability)  
17. [Final outcome](#final-outcome)  
18. [Author notes](#author-notes)  

---

## What this project does

- **Web UI:** JSP views under `Java-Login-App/Java-Login-App` (login, registration).  
- **Backend:** Spring Boot **2.2.x**, packaged as a **WAR** (`com.devopsrealtime:dptweb:1.0`), deployed to **Apache Tomcat 8.5** as **`ROOT.war`** (served at `/`).  
- **Data:** MySQL database **`UserDB`** with an **`Employee`** table (see `database/schema.sql`).  
- **AWS:** Automated build path: **Git → Maven build EC2 → JFrog → Tomcat ASG (user-data)**; **RDS** stores data; **Nginx** exposes HTTP to the internet via a **public Network Load Balancer**.

---

## High-level architecture

Traffic flow:

1. **Internet** → **public NLB** (port 80) → **Nginx Auto Scaling Group** (instances in the **application VPC public subnets**).  
2. **Nginx** reverse-proxies to the **private NLB** DNS name on **port 8080** (configured in Nginx user-data).  
3. **Private NLB** → **Tomcat Auto Scaling Group** (private app subnets).  
4. **Tomcat** serves the WAR and connects to **RDS MySQL** in **private DB subnets** (port 3306, security group–restricted).

**Operator access:** A separate **bastion VPC** hosts a **bastion** instance; **Transit Gateway** connects bastion VPC to the application VPC so you can reach private resources (and RDS is reachable from bastion paths as allowed by security groups). The bastion can run **initial DB schema** setup using the RDS endpoint and master secret (see `database/README.md` and bastion user-data).

---

## Repository layout

| Path | Purpose |
|------|--------|
| `Java-Login-App/Java-Login-App/` | Maven module: Spring Boot app, `pom.xml`, `src/` |
| `Terraform/` | Root module: VPC, NLBs, ASGs, RDS, bastion, golden AMI builders, Maven build host |
| `Terraform/modules/` | Reusable modules (`vpc`, `tomcat-asg`, `nginx-asg`, `rds`, etc.) |
| `Terraform/scripts/` | Optional helper scripts (e.g. Tomcat/systemd troubleshooting) |
| `database/` | `schema.sql` and database documentation |
| `docs/images/` | README figures (architecture, AWS console, JFrog, cloud-init logs) |

---

## Infrastructure components (implemented)

### Global / golden AMIs (Terraform)

- **Base (“global”) AMI builder** (`modules/ami`): Amazon Linux 2–based image with tooling used by downstream builders; **IAM instance profile** grants SSM, CloudWatch, S3 (where configured), and **Secrets Manager** read access to **JFrog** and **RDS master** secrets (ARNs passed from root module).  
- **Nginx golden AMI** (`modules/nginx-golden-ami`): Nginx installed on top of the base AMI.  
- **Tomcat golden AMI** (`modules/tomcat-golden-ami`): **JDK 11**, **Tomcat 8.5**, MySQL client; Tomcat enabled via **systemd**.  
- **Maven golden AMI** (`modules/maven-golden-ami`): **Maven**, **Git**, **JDK** for build workloads.

### Application VPC (3-tier pattern)

- **CIDR** is configurable (e.g. `172.32.0.0/16` in tfvars — see `Terraform/variables.tf`).  
- **Public subnets** (two AZs): NAT Gateway, internet-facing resources.  
- **Private app subnets** (two AZs): Tomcat ASG, private NLB attachments.  
- **Private DB subnets** (two AZs): RDS subnet group.  
- **Security groups**: e.g. MySQL **3306** from Tomcat (and bastion path as defined in `modules/vpc`).

### Load balancers

- **Private NLB** (`modules/nlb`): fronting **Tomcat** target group (TCP **8080**).  
- **Public NLB** (`modules/public-nlb`): internet-facing, fronting **Nginx** target group (TCP **80**).

### Compute

- **Tomcat ASG** (`modules/tomcat-asg`): **launch template** + **user-data** (see below) + optional **rolling instance refresh** when the launch template changes.  
- **Nginx ASG** (`modules/nginx-asg`): launch template + user-data sets **`proxy_pass`** to the **private NLB** hostname.  
- **Maven build instance** (`modules/maven-build-instance`): long-lived EC2 in a **private app subnet**; clones Git, reads **JFrog** credentials from Secrets Manager, writes **`~/.m2/settings.xml`**, runs **`mvn clean deploy`** (or you can run `package` / `deploy` manually).

### Database

- **RDS MySQL** (`modules/rds`): database name **`UserDB`**, master user **`admin`**, **managed master password** in **AWS Secrets Manager** (`manage_master_user_password = true`).  
- Default deployment is **single-AZ** (one AZ picked for the instance); subnets span multiple AZs for subnet group layout. Not Multi-AZ standby unless you change the module.

### Bastion & TGW

- **Bastion VPC** (separate CIDR, e.g. `192.168.0.0/16` in your design).  
- **Bastion host** (`modules/bastion-host`): can pull **`schema.sql`** from **S3** and apply to RDS using credentials from the **RDS secret** (see module user-data).  
- **Transit Gateway** (`modules/transit-gateway`): private routing between bastion VPC and application VPC.

---

## CI pipeline (build phase)

This is the **continuous integration** side: turn **Git** sources into a **versioned binary** in **JFrog**, without placing secrets in the repo.

### Where it runs

- **Maven build EC2** (`modules/maven-build-instance`): one (or more) instances in a **private app subnet**, outbound via **NAT**, reachable by operators through **SSM** (and optionally SSH if you attach a key pair).  
- The instance is built from the **Maven golden AMI** (Git, JDK, Maven preinstalled).

### Flow (ordered steps)

1. **Terraform** creates the instance and passes **`maven_build_git_repo_url`** (e.g. GitHub HTTPS clone URL) into **user-data**.  
2. **First boot (user-data):** install tooling if needed (**AWS CLI**, **Python**), call **Secrets Manager** for the app secret (`jfrogusername` / `jfrogpassword`), and write **`/home/ec2-user/.m2/settings.xml`** so Maven can authenticate to **JFrog**.  
3. **Clone:** `git clone` the repo into **`/home/ec2-user/Java-Login-App`** (layout includes nested **`Java-Login-App/Java-Login-App/`** where **`pom.xml`** lives).  
4. **Build & publish:** from the module directory, run **`mvn clean deploy`** (often with **`-s /home/ec2-user/.m2/settings.xml`**). **`package`** produces **`target/dptweb-1.0.war`**; **`deploy`** uploads the **WAR** and **POM** to **`distributionManagement`** in **`pom.xml`** (JFrog **`libs-release-local`** layout: `com/devopsrealtime/dptweb/1.0/`).  
5. **Artifact:** **`dptweb-1.0.war`** is the **immutable build output** the CD stage consumes. Update **`tomcat_jfrog_war_url`** in Terraform if you change repo path, version, or Artifactory repository.

### What “good” looks like

- JFrog UI shows **`dptweb-1.0.war`** under the expected Maven path.  
- A fresh **`mvn deploy`** after fixing **`application.properties`** is required for Tomcat to serve an updated JDBC URL inside the WAR.

---

## CD pipeline (deployment phase)

This is the **continuous delivery** side: **new or replaced Tomcat capacity** pulls the **released WAR** and **configuration/secrets** at boot. **Nginx** does not deploy artifacts; it only forwards traffic.

### Tomcat layer (application / backend)

**Role:** Run the **Spring Boot WAR** as **`ROOT.war`**, talk to **RDS**, stay off the public internet.

**Provisioning (launch template user-data), in order:**

1. Resolve **Tomcat `webapps`** path and install **AWS CLI** / **jq** / **curl** if needed.  
2. **Secrets Manager — JFrog:** read **`jfrogusername`** / **`jfrogpassword`** for authenticated download.  
3. **Secrets Manager — RDS:** read master JSON, extract **`password`**, append **`SPRING_DATASOURCE_PASSWORD=...`** to **`/etc/tomcat/tomcat.conf`** (loaded by **`tomcat.service`** via systemd) so the JVM sees the DB password at runtime.  
4. **`systemctl daemon-reload`** after updating **`tomcat.conf`**.  
5. **Download:** **`curl`** **`tomcat_jfrog_war_url`** → **`/tmp/app.war`**.  
6. **Install:** replace **`ROOT.war`** (and exploded **`ROOT`**) under **`webapps`**, **`chown tomcat`**.  
7. **Run:** **`systemctl restart tomcat`**, wait until **HTTP 8080** responds locally.

**Runtime behavior:**

- **HTTP:** Tomcat listens on **8080**; only the **internal NLB** and private network paths should reach it.  
- **App:** Spring loads **`application.properties`** from the WAR (JDBC URL, DB user). **`SPRING_DATASOURCE_PASSWORD`** comes from the **environment** (via **`tomcat.conf`**), not from Git.  
- **Scale-out:** each **new** ASG instance repeats user-data → same JFrog URL → same pattern; use **instance refresh** or new launches after you change the launch template or need a fresh pull.

### Nginx layer (frontend / edge)

**Role:** **TLS termination is not shown here** (plain **HTTP** on **80**); accept internet-facing traffic and **reverse-proxy** to Tomcat **without** exposing Tomcat’s **8080** directly to the world.

**Provisioning (launch template user-data):**

1. Write **`/etc/nginx/nginx.conf`** with an **`upstream`** pointing at the **private NLB DNS name** on **port 8080** (value injected from Terraform: **`private_nlb_dns_name`**).  
2. **`proxy_pass`** to that upstream for the default server on **port 80**.  
3. **Reload / enable** Nginx so changes apply.

**Runtime behavior:**

- **Public NLB** (TCP **80**) → registers **Nginx** instances in the **Nginx target group**.  
- Nginx forwards requests to the **internal NLB**, which load-balances **Tomcat** targets.  
- Nginx **does not** open JDBC connections; it is **stateless HTTP forwarding** only.

---

## Secrets and configuration

### Secrets Manager — JFrog (build + Tomcat download)

- Secret name default: **`dev-app-secrets`** (`maven_build_app_secret_name`).  
- **JSON keys:** `jfrogusername`, `jfrogpassword`.  
- Used by: **Maven build instance** user-data (deploy to JFrog) and **Tomcat** user-data (**curl** authenticated download of the WAR).

### Secrets Manager — RDS master password

- Created/managed by RDS (**master user secret**).  
- Used by: **Tomcat user-data** (injects **`SPRING_DATASOURCE_PASSWORD`** into **`/etc/tomcat/tomcat.conf`** so systemd’s `tomcat.service` passes it into the JVM), **bastion** user-data (schema load), and any manual **`mysql`** / **`aws secretsmanager`** workflows.

### Terraform variables (examples)

- **`tomcat_jfrog_war_url`**: HTTPS URL to **`dptweb-1.0.war`** in JFrog (default path pattern under `libs-release-local/.../dptweb-1.0.war`).  
- **`maven_build_git_repo_url`**: public Git URL for the app repo.  
- **`aws_region`**, **`environment`**, **`project_name`**, VPC CIDRs, **`admin_ip_cidr`**, **`ssh_allowed_cidr`**, instance types — see `Terraform/variables.tf` and your `terraform.tfvars`.

### State file

- Run Terraform from **`Terraform/`** and use a **remote backend** (S3 + DynamoDB lock) for teams; avoid committing **`terraform.tfstate`** if it contains sensitive metadata.

---

## Application configuration

- **`Java-Login-App/Java-Login-App/src/main/resources/application.properties`**  
  - **`spring.datasource.url`**: JDBC URL for **your** RDS endpoint (update per environment).  
  - **`spring.datasource.username`**: typically **`admin`** (must match RDS master user).  
  - **No DB password in Git** — password is supplied at runtime as **`SPRING_DATASOURCE_PASSWORD`** (from Tomcat’s environment via **`tomcat.conf`**).  
- Java controllers use **`@Value("${spring.datasource.password:}")`** so optional password works in tests while production relies on the environment variable.

**Important:** After changing `application.properties`, **rebuild the WAR** (`mvn clean package` or `deploy`) and ensure Tomcat instances **pull the new artifact** (new ASG instances / refresh, or new deploy to the same JFrog URL Tomcat uses).

---

## Typical deployment flow

1. **Prerequisites:** AWS account, Terraform **≥ 1.5**, AWS provider **~> 5.x**, Secrets Manager secrets created (JFrog JSON, RDS created by apply).  
2. **`terraform init`** / **`terraform plan`** / **`terraform apply`** from **`Terraform/`** with valid **`terraform.tfvars`**.  
3. **Golden AMI builds** run as part of apply (builders create AMIs used by Tomcat/Nginx/Maven).  
4. **Bastion user-data** (if successful) seeds schema from S3; otherwise apply **`database/schema.sql`** per `database/README.md`.  
5. **Maven build host:** `git pull` under the clone path, then from the module that contains **`pom.xml`** (`.../Java-Login-App/Java-Login-App/`):  
   `mvn clean deploy -s ~/.m2/settings.xml`  
6. **Tomcat ASG:** new instances (or instance refresh) run user-data: fetch secrets, configure Tomcat env, download WAR, deploy **`ROOT.war`**, restart Tomcat.  
7. **Test:** browser → **public NLB DNS** on port **80** → login/register flows.

---

## Pre-deployment (golden AMIs)

Summary of what each layer installs (details in module `user_data.sh` / `main.tf`):

### Create global (base) AMI

- Amazon Linux 2 baseline used by golden AMI builders.  
- **SSM**, **CloudWatch** agent (as configured in modules), and IAM for instance operations.

### Golden AMI — Nginx

- **Nginx** installed and ready for reverse proxy configuration at instance launch.

### Golden AMI — Tomcat

- **Apache Tomcat 8.5**, **JDK 11**, **MySQL client**; Tomcat service enabled for **systemd**.

### Golden AMI — Maven

- **Apache Maven**, **Git**, **JDK 11**; PATH / environment suitable for headless builds.

---

## VPC and connectivity

- **Application VPC:** hosts 3-tier resources, NAT, IGW, private + public subnets across AZs, NLBs, ASGs, RDS.  
- **Bastion VPC:** dedicated admin network; bastion in a public subnet with controlled ingress (**`admin_ip_cidr`**).  
- **Transit Gateway:** connects bastion VPC to application VPC for private administration traffic.  
- **NAT Gateway:** outbound internet from private subnets (e.g. Maven build, Tomcat pulling JFrog/Secrets Manager).

---

## Post-deployment & operations

The following items appear in older runbooks as **recommended** follow-ups; they are **not** all implemented as Terraform in this repo unless you add them separately:

- **Log shipping:** cron → S3 for Tomcat logs, rotation on instance.  
- **Monitoring:** CloudWatch alarms (e.g. DB connections).  
- **Security:** rotate any credentials exposed during troubleshooting; prefer SSM Session Manager over wide SSH where possible.

**Useful logs on instances**

- Tomcat user-data: **`/var/log/tomcat-userdata.log`**  
- Nginx user-data: **`/var/log/nginx-asg-userdata.log`**  
- **`journalctl -u tomcat`** for service logs  

**Tomcat / DB password issues**

- Confirm **`SPRING_DATASOURCE_PASSWORD`** is present in the Tomcat process environment (see `Terraform/scripts/tomcat-systemd-spring-datasource.sh` for a manual alignment helper if needed — must be run **on the Linux instance**, not on your Mac).

---

## Validation checklist

- **Admin:** SSM Session Manager (and/or SSH via bastion) to Maven build host, Tomcat, Nginx, bastion — as allowed by your security groups and IAM.  
- **End user:** HTTP to **public NLB** → login page loads without JDBC errors; registration/login hits **`UserDB`** (see [App working over public NLB](#app-working-over-public-nlb)).  
- **Artifacts:** `unzip -p /var/lib/tomcat/webapps/ROOT.war WEB-INF/classes/application.properties` shows the **correct RDS hostname** and **no** hard-coded DB password.  
- **Secrets:** JFrog secret allows **`mvn deploy`**; RDS secret allows app DB auth.

---

## Screenshots & diagrams

Figures live under **`docs/images/`** in this repository. Captions describe the **staging** deployment shown in the captures; your account IDs, ARNs, and DNS names will differ.

**Rendering on GitHub:** Each figure uses an absolute **`https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/...`** URL so the file is loaded as an image (not only as a repo file link). That requires the PNGs to be **committed and pushed** on branch **`main`**. If you fork this repo or rename the default branch, search-replace that base URL in this file (or switch back to relative paths like `docs/images/…`).

### Reference & conceptual architecture

The **Target pipeline & platform** and **Classic 3-tier VPC across two AZs** reference diagrams appear [earlier in this document](#reference-architecture-diagrams), immediately after **Build & deploy path** (under **Overview**).

---

### Application VPC (staging console)

#### VPC resource map

![VPC resource map: IGW, NAT, public and private subnets, route tables](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/04-vpc-resource-map.png)

*`Stag-java-login-app-vpc`: subnets in **us-east-1a** / **us-east-1b**, Internet Gateway, NAT Gateway, route tables.*

---

### Load balancing

#### Public and internal NLBs

![Two network load balancers: internet-facing and internal](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/07-network-load-balancers.png)

*Internet-facing NLB for user traffic; **internal** NLB in front of Tomcat (Nginx proxies to this DNS name on port 8080).*

#### Public NLB details

![Public NLB DNS name and AZ mappings](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/06-public-nlb-details.png)

*Use the **DNS name** (port 80) as the URL users hit. Staging uses **HTTP**; browsers may show “Not secure” until you add TLS (e.g. ACM + listener or a layer-7 LB).*

#### Nginx target group (TCP 80)

![Nginx target group healthy targets in two AZs](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/08-target-group-nginx.png)

*`Stag-java-login-app-nginx-tg`: two healthy instances behind the **public** NLB.*

#### Tomcat target group (TCP 8080)

![Tomcat target group healthy targets in two AZs](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/09-target-group-tomcat.png)

*`Stag-java-login-app-tomcat-tg`: two healthy Tomcat instances behind the **internal** NLB.*

---

### Compute & images

#### EC2 instances (overview)

![EC2 instances: Tomcat, Nginx, bastion, Maven build, etc.](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/05-ec2-instances.png)

*Mix of **public** (Nginx, bastion) and **private** (Tomcat, Maven) IPs; naming prefix **`Stag-java-login-app-`**.*

#### Launch templates

![Launch templates for Tomcat and Nginx ASGs](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/10-launch-templates.png)

*Separate templates per tier; **latest version** advances when Terraform updates AMI or user-data.*

#### Golden AMIs

![Private AMIs: global base, Tomcat, Maven, Nginx golden](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/11-golden-amis.png)

*Immutable images produced by Terraform **golden AMI** builders; ASGs launch from these AMIs.*

---

### Data & artifacts

#### RDS MySQL + Secrets Manager

![RDS instance summary and master credentials in Secrets Manager](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/13-rds-mysql-secrets-manager.png)

*`stag-java-login-app-mysql-db`: MySQL in a **private** subnet; master password in **Secrets Manager** (used by Tomcat user-data and bastion/schema flows).*

#### JFrog Artifactory (`dptweb-1.0.war`)

![JFrog libs-release-local Maven path to dptweb-1.0.war](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/12-jfrog-dptweb-war.png)

*`libs-release-local` / `com/devopsrealtime/dptweb/1.0/` — WAR Tomcat user-data downloads with JFrog credentials from Secrets Manager.*

---

### Automation & proof of life

#### Tomcat user-data / cloud-init log

![Cloud-init log: JFrog + RDS secrets, WAR download, Tomcat restart, health check](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/14-tomcat-user-data-cloud-init.png)

*Typical success path: fetch **JFrog** and **RDS** secrets, **curl** WAR from Artifactory, deploy **`ROOT.war`**, restart Tomcat, verify **HTTP 8080**.*

### App working over public NLB

![Browser: welcome page after login via public NLB URL](https://raw.githubusercontent.com/0byiaks/Java-Login-App/main/docs/images/01-app-welcome-public-nlb.png)

*End-to-end check: user reaches the app through **`Stag-java-login-app-public-nlb-...elb.us-east-1.amazonaws.com`** (HTTP).*

---

## Application deployment

- The **WAR** is built by **Maven** and stored in **JFrog Artifactory** (`dptweb-1.0.war`).  
- **Tomcat** instances **pull that WAR at startup** (launch template **user-data**), so each new or replaced instance gets the same deployment pattern.

**This enables:**

- **Stateless deployments** — app servers do not depend on a hand-copied artifact on disk long-term; they re-fetch from JFrog on boot.  
- **Rapid scaling** — ASG adds instances; user-data repeats the pull-and-deploy steps automatically.  
- **Decoupled CI/CD** — **build** (Maven → JFrog) and **runtime** (Tomcat user-data) are separate phases with a clear handoff: the published artifact URL.

---

## Observability

- **CloudWatch Agent** is installed on instances through the **global / golden AMI** build path (see `modules/ami` and related golden AMI `user_data` scripts).  
- **Custom memory metrics** can be pushed to **CloudWatch** from that agent configuration (as defined in the AMI build recipes).  
- **User-data logs** are written on the instance (e.g. **`/var/log/tomcat-userdata.log`**, **`/var/log/nginx-asg-userdata.log`**, Maven build logs) for **local debugging** when SSM or SSH access is available.

---

## Final outcome

This project delivers a **production-style AWS architecture** that demonstrates:

- **End-to-end CI/CD pipeline** — Git → Maven → JFrog → Tomcat bootstrap.  
- **Secure multi-tier networking** — public edge (Nginx + public NLB), private app and data tiers, NAT for outbound, optional bastion + Transit Gateway for operations.  
- **High availability across AZs** — Nginx and Tomcat **Auto Scaling Groups** and NLBs span multiple **Availability Zones**.  
- **Scalable application deployment** — horizontal scaling of the web and app tiers behind load balancers.

---

## Author notes

This implementation prioritizes:

- **Simplicity for learning** — readable Terraform modules and explicit user-data steps.  
- **Real-world architecture patterns** — golden AMIs, secrets in **Secrets Manager**, NLBs, ASGs, and a clear build vs runtime split.  
- **Clear separation between build and runtime phases** — **CI** produces an immutable artifact in JFrog; **CD** applies it when Tomcat instances start.

---

## Contact

austinbale667@gmail.com
