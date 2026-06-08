# W8 Day B — Docker & Kubernetes Fundamentals

## Mục tiêu học

Day B tập trung vào Container (Docker) và Container Orchestration (Kubernetes) — nền tảng cho microservices và modern cloud infrastructure.

Sau Day B, bạn cần nắm chắc:

1. **Container** là gì, tại sao lại cần Container.
2. **Docker**: image, container, Dockerfile, registry.
3. **Docker workflow**: build → run → push → pull.
4. **Container best practices** và docker-compose cơ bản.
5. **Kubernetes (K8s)** là gì, tại sao lại cần orchestration.
6. **K8s core concepts**: Pod, Service, Deployment, ConfigMap, Secret.
7. **K8s probes**: liveness, readiness, startup probes.
8. **minikube** để chạy K8s local.
9. **kubectl** cơ bản: commands, YAML manifests.
10. Kết nối Docker + K8s để deploy containerized apps.

---

## 1. Container & Docker

### Tài liệu chính thống

- **Docker Docs** — https://docs.docker.com
- **Docker Curriculum** — https://docker-curriculum.com (tutorial từ scratch)
- *Docker Deep Dive* — Nigel Poulton
- **OCI Image Spec** — https://github.com/opencontainers/image-spec (chuẩn image)

### Series học từ mentor

- **Docker from Basics to Swarm** — https://kkloudtarus.net/en/blog/series/docker-from-basics-to-swarm

### Khái niệm cơ bản

**Container** là một lightweight, portable, self-contained execution environment chứa:
- Application code
- Runtime (Python, Node, Java, etc.)
- Dependencies (libraries, packages)
- System tools

```
Virtual Machine (Heavy)          Container (Light)
├─ Hypervisor                    ├─ Docker Engine
├─ Guest OS (GB)                 ├─ Shared Host OS (MB)
├─ Runtime                       ├─ Runtime
├─ App + Dependencies            └─ App + Dependencies
└─ (minutes to boot)                (seconds to boot)
```

**Docker Image** = Blueprint (like a class)
**Docker Container** = Running instance (like an object)

### Dockerfile Example

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "app.py"]
```

### Workflow: Build → Run → Push

```bash
# Build image
docker build -t myapp:1.0 .

# Run container
docker run -p 8000:8000 myapp:1.0

# Push to registry (Docker Hub)
docker login
docker tag myapp:1.0 username/myapp:1.0
docker push username/myapp:1.0

# Pull and run from registry
docker pull username/myapp:1.0
docker run -p 8000:8000 username/myapp:1.0
```

---

## 2. Kubernetes (K8s)

### Tài liệu chính thống

- **Kubernetes Docs** — https://kubernetes.io/docs (start: Concepts → Tutorials)
- **Kubernetes Basics (interactive)** — https://kubernetes.io/docs/tutorials/kubernetes-basics
- **minikube** — https://minikube.sigs.k8s.io/docs/start (K8s local trên laptop)
- **CNCF Curriculum** — https://github.com/cncf/curriculum (CKA/CKAD reference)
- *Kubernetes in Action* — Marko Lukša (sách classic)
- *Kubernetes Patterns* — Bilgin Ibryam (design patterns)
- **kubectl Cheat Sheet** — https://kubernetes.io/docs/reference/kubectl/cheatsheet (bookmark!)

### Khái niệm cơ bản

**Kubernetes (K8s)** là container orchestration platform — tự động deploy, scale, manage containerized apps.

```
1 Container = app chạy trong 1 machine ✓
100+ Containers = ? (scale, load balance, health check, rolling update)
→ Kubernetes giải quyết bài toán này
```

### K8s Architecture

```
Master Node (Control Plane)
├─ API Server (quản lý state)
├─ etcd (database lưu state)
├─ Scheduler (lên lịch Pod)
└─ Controller Manager (quản lý Deployment, Service, etc.)

Worker Nodes
├─ Node 1: [Pod1] [Pod2] ...
├─ Node 2: [Pod3] [Pod4] ...
└─ Node 3: [Pod5] [Pod6] ...
```

### Core K8s Objects

| Object | Purpose |
|--------|---------|
| **Pod** | Smallest unit, chứa 1+ containers (thường 1) |
| **Service** | Network endpoint, load balance traffic đến Pods |
| **Deployment** | Quản lý Pod replicas, rolling updates |
| **ConfigMap** | Lưu configuration (non-secret) |
| **Secret** | Lưu sensitive data (password, token, API key) |
| **Namespace** | Virtual cluster, isolation |

### Pod Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8000
    env:
    - name: ENV
      value: "production"
```

### Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8000
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### kubectl Cơ bản

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# Pod, Deployment
kubectl get pods
kubectl get deployments
kubectl create deployment my-app --image=myapp:1.0
kubectl scale deployment my-app --replicas=5
kubectl logs my-app-xyz
kubectl exec -it my-app-xyz -- bash

# Apply YAML
kubectl apply -f deployment.yaml
kubectl delete -f deployment.yaml

# Service
kubectl expose deployment my-app --port=80 --target-port=8000
kubectl get services
```

---

## 3. Setup Local Environment

### Cần cài đặt

- **Docker Desktop** (includes Docker + Kubernetes single-node)
  - https://www.docker.com/products/docker-desktop
- **minikube** (K8s cluster local)
  - https://minikube.sigs.k8s.io/docs/start
- **kubectl** (K8s CLI)
  - https://kubernetes.io/docs/tasks/tools/

### Quick Start

```bash
# Docker: build & run
docker build -t myapp:1.0 .
docker run -p 8000:8000 myapp:1.0

# Kubernetes local with minikube
minikube start
minikube status

# Deploy
kubectl apply -f deployment.yaml
kubectl get pods
kubectl port-forward svc/my-app 8000:80

# Cleanup
kubectl delete -f deployment.yaml
minikube stop
```

---

## 4. Learning Path (Self-study)

**Week 1-2: Docker Fundamentals**
1. Container vs VM concept
2. Build Dockerfile
3. docker build, run, push, pull
4. Docker Hub registry

**Week 2-3: Kubernetes Basics**
1. Pod, Deployment, Service concepts
2. kubectl commands
3. YAML manifest writing
4. Deploy app on minikube

**Week 3-4: Advanced**
1. ConfigMap, Secret, Volume
2. Health probes (liveness, readiness)
3. Networking, Service types (ClusterIP, NodePort, LoadBalancer)
4. StatefulSet, DaemonSet

**Week 4+: Integration**
1. CI/CD with Docker images
2. GitOps (ArgoCD)
3. Helm package manager
4. Service mesh (optional: Istio, Linkerd)

---

## 5. References

- **Docker Docs**: https://docs.docker.com
- **Kubernetes Docs**: https://kubernetes.io/docs
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet
- **minikube Docs**: https://minikube.sigs.k8s.io/docs
- **Docker Curriculum**: https://docker-curriculum.com
- **Play with Docker**: https://www.docker.com/play-with-docker
- **Play with Kubernetes**: https://www.playwithdocker.com/orchestration
