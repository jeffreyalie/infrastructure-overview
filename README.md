
* **Servers used**
  - LXD
  - Gitea
  - Gitea runner
  - Openbao (Vault)
  - Seaweed (S3)
  - Developer laptop - Kubuntu
* **OS**
  - Kubuntu - **The Great**
  ---
* **Infradtructure Architecture**
  - Infrastructure Archtecture VM Deployment - GHA workflows - terraform modules - ansible roles / galaxy
    - Infrastructure Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3)
    - Infrastructure Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3) - openbao (vault)
  
  - Infrastructure Archtecture Go app deployment - Gitea - Gitea runner - kubernetes - openbao (vault)
  - Infrastructure Archtecture Go app deployment - Gitea - Developer - kubernetes - openbao (vault)
  
  - Infrastructure Architecture Kube-promethius-stack Goap and other devices Deployment

* **Infrastrucure Secrets Architecture**
  - Infrastructure Secrets Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3) - openbao (vault) - **Vault level secreats**
  - Infrastructure Secrets Archtecture VM Deployment - Gitea - Gitea runner - terraform - ansible - LXD - seaweed (S3) - **Org/Repo level secrets**
  
  - Infrastructure Secrets Archtecture Go app deployment - Microk8s - openbao (vault)
  - Infrastructure Secrets Archtecture Go app deployment - GHA runner - Microk8s - openbao (vault)

* **Systems Architecture**
  - System Architecture Kubernetes
  - System Architecture Kube-promethius-stack
---