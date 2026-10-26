# VM deployment architecture - terraform - ansible - GHA runner - seaweed (S3) - openbao (vault) - Vault level secrets
---
```
 Developer / GitHub Actions Runner
 ----main commands----
 terraform plan / apply
 ansible-playbook
 ---------------------


 Gitea / Developer
 ┌─────────────────────────────────────────┐
 │  Terraform, ansible                     │ ----------------------------(Org level secrets for openbao only)
 |  GHA workflows, roles                   │                      (VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID)
 └─────────────────┬───────────────────────┘
                   │
                   |
                   |
                   ▼
 ┌───────────────────────────────────────────┐
 │        Runner / Developer                 │  ----------------------- (Runner picks secrets from Openbao )
 |                                           |                                  homelab/data/lxd
 |       (Docker-based, LXD VM)              |                                  homelab/data/seaweed	
 |                                           |                                  homelab/data/ansible
 |                                           |                             
 |                                           |                            (Developer picks from env variables)
 |                                           |
 └───────┬───────────────────────────┬───────┘
         │                           │
         |                           |
         |                           |
Terraform│ plan / apply              │Ansible-playbook
         |                           |
         |                           |       
         ▼                           |
 ┌─────────────────┐                 |               
 │      MinIO      │                 |
 │    backend s3   │                 |
 │    (TF state)   │                 |
 └─────────────────┘                 |
         │                           |      
         │                           |
         │                           |
 ┌─────────────────┐                 |               
 │   LXD / KVM     │                 |
 │  (localhost:    │                 |       
 │    8443)        │                 |      
 └─────────────────┘                 |
         |                           |
         |                           |
         |                           |
 ┌─────────────────┐                 |       
 │  Target VM      │                 |      
 │  Ubuntu 26.04   │ +---------------+                   
 │With ansible user|
 └─────────────────┘

```
---

# VM deployment architecture - terraform - ansible - GHA runner - seaweed (S3) - Org level secrets

---
```
 Developer / GitHub Actions Runner
 ----main commands----
 terraform plan / apply
 ansible-playbook
 ---------------------


 Gitea / Developer
 ┌─────────────────────────────────────────┐
 │  Terraform, ansible                     │ ----------------------------(Org level secrets for rubber)
 |  GHA workflows, roles                   │                                    ANSIBLE_SSH_PRIVATE_KEY 
 |                                         |                                    ANSIBLE_SSH_PUBLIC_KEY
 |                                         |                                    LXD_ADDRESS
 |                                         |                                    LXD_CLIENT_CERT
 |                                         |                                    LXD_CLIENT_KEY
 |                                         |                                    S3_ACCESS_KEY
 |                                         |                                    S3_BUCKET
 |                                         |                                    S3_ENDPOINT
 |                                         |                                    S3_SECRET_KEY 
 |                                         |     
 └─────────────────┬───────────────────────┘
                   │
                   |
                   |
                   ▼
 ┌───────────────────────────────────────────┐
 │        Runner / Developer                 │  ----------------------- (Runner picks secrets from Openbao )
 |                                           |                          (Developer picks from env variables)
 |       (Docker-based, LXD VM)              |  
 |                                           |                             
 |                                           |                           
 |                                           |
 └───────┬───────────────────────────┬───────┘
         │                           │
         |                           |
         |                           |
Terraform│ plan / apply              │Ansible-playbook
         |                           |
         |                           |       
         ▼                           |
 ┌─────────────────┐                 |               
 │      MinIO      │                 |
 │    backend s3   │                 |
 │    (TF state)   │                 |
 └─────────────────┘                 |
         │                           |      
         │                           |
         │                           |
 ┌─────────────────┐                 |               
 │   LXD / KVM     │                 |
 │  (localhost:    │                 |       
 │    8443)        │                 |      
 └─────────────────┘                 |
         |                           |
         |                           |
         |                           |
 ┌─────────────────┐                 |       
 │  Target VM      │                 |      
 │  Ubuntu 26.04   │ +---------------+                   
 │With ansible user|
 └─────────────────┘

```
---
