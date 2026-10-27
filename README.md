# Portfolio: Platform / DevOps Engineering

Proyectos de referencia sobre cómo diseño y opero plataformas cloud-native: GitOps multi-región,
infraestructura como código, identidad y pipelines de entrega. Todo el código está escrito para este
portfolio, se puede ejecutar y no contiene datos de ninguna empresa.

| Proyecto | Qué muestra |
|---|---|
| [cloud](cloud/) | Terraform para celdas en GCP: red privada, GKE con Workload Identity y Connect Gateway, Cloud SQL con auth IAM, Secret Manager con residencia regional, Pub/Sub con DLQ, módulo de "workload" por servicio, tests con provider simulado y CI sin llaves (OIDC). |
| [gitops-multicell](gitops-multicell/) | ArgoCD ApplicationSets dirigidos por carpetas, celdas por región y ambiente, Helm en capas, Argo Rollouts canary con análisis de Prometheus, External Secrets, Workload Identity y CI que valida y muestra el diff de cada celda. Despliega sobre las celdas de `cloud`. |

## Stack

Kubernetes (GKE) · ArgoCD · Argo Rollouts · Helm · Terraform · Google Cloud · External Secrets ·
Keycloak / OIDC · GitHub Actions · PostgreSQL · Debezium / CDC · Prometheus
