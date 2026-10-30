# AWS - Vcenter (On-premises) - Github (Saas)
```
On-Prem (vCenter / VMs)
      10.20.0.0/16
            │
            │
            │
 Firewall (Palo Alto / Silver Peak)
            │
            |
    VPN / SD-WAN
            │
            │
            │
AWS VPC (10.10.0.0/16)
            ├── EC2
                ├── EKS (Kubernetes)
                └── Runners
```
---
```
                On-Prem vCenter 
                (10.20.0.0/16)
                        │
                Palo Alto VPN
                        │
      ┌─────────────────────────────────┐
      │     AWS VPC (10.10.0.0/16)      │
      │                                 │
      │     Public:  10.10.1.0/24       │
      │	    App:  10.10.10.0/24 (EKS)   │
      │     DB:      10.10.20.0/24      │
      │	    Mgmt:    10.10.30.0/24      │
      └─────────────────────────────────┘
```
---
```

            GitHub Cloud (SaaS)
                    │
        ┌───────────┼───────────┐
        │                       │
 On-Prem Runner             AWS Runner
 (vCenter side)             (EKS / EC2)
        │                       │
vCenter / VMs            Kubernetes / AWS

```
