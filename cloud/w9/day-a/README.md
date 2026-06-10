# W9-D1: Hands-on GitOps & CI/CD with ArgoCD

Chào mừng bạn đến với bài Lab **Day 1: GitOps & CI/CD**. Bài lab này được thiết kế để giúp bạn tiếp cận thực tế với mô hình GitOps kéo (Pull-based) sử dụng **ArgoCD**, thiết lập thứ tự triển khai tài nguyên bằng **Sync Waves**, cấu hình CI/CD Pipeline đơn giản với **GitHub Actions**, và thực hành quy trình **Rollback** an toàn.

---

## 🎯 Mục tiêu bài Lab
1. **Cài đặt & Thiết lập ArgoCD** trên cụm Kubernetes cục bộ (Minikube/Kind).
2. **Triển khai ứng dụng qua ArgoCD** sử dụng cấu trúc thư mục Manifests GitOps.
3. **Ứng dụng Sync Waves** để đảm bảo ConfigMap được áp dụng thành công trước khi Deployment khởi chạy.
4. **Mô phỏng CI/CD Workflow**: Thiết kế GitHub Actions để validate manifests khi tạo PR và tự động trigger/sync khi merge.
5. **Thực hành Rollback**: So sánh và thực hành `git revert` (chuẩn GitOps) và `kubectl rollout undo`.

---

## 🏗️ Cấu trúc thư mục Lab (`cloud/w9/day-a/`)
Bạn sẽ làm việc với cấu trúc thư mục sau:
```text
cloud/w9/day-a/
├── README.md               # Hướng dẫn bài lab (file này)
├── manifests/              # Các tài nguyên Kubernetes của ứng dụng
│   ├── 01-configmap.yaml   # Sync Wave: 1
│   ├── 02-deployment.yaml  # Sync Wave: 2
│   └── 03-service.yaml     # Sync Wave: 3
├── argocd/
│   └── application.yaml    # Định nghĩa ArgoCD Application
└── github-actions/
    └── gitops-ci.yml       # File cấu hình GitHub Actions Workflow mẫu
```

---

## 🛠️ Bước 1: Khởi động Cluster & Cài đặt ArgoCD

### 1. Khởi động Minikube (hoặc Docker Desktop/Kind)
```bash
minikube start --driver=docker
```

### 2. Cài đặt ArgoCD
Tạo namespace và cài đặt ArgoCD:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3. Kiểm tra trạng thái các Pod của ArgoCD
Chờ cho đến khi tất cả các Pod chuyển sang trạng thái `Running`:
```bash
kubectl get pods -n argocd -w
```

### 4. Truy cập ArgoCD UI
Để truy cập vào giao diện web trên máy local, sử dụng lệnh port-forward:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
*Giao diện ArgoCD sẽ khả dụng tại: `https://localhost:8080` (Bỏ qua cảnh báo bảo mật SSL).*

**Lấy mật khẩu Admin đăng nhập:**
User mặc định là `admin`. Mật khẩu được sinh ngẫu nhiên và lưu trong Kubernetes Secret, bạn lấy bằng lệnh:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($input))"
# Nếu trên Linux/macOS:
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
```

---

## 📦 Bước 2: Thiết lập Manifests & Sync Waves

Để tránh tình trạng Pod chạy lên bị lỗi do cấu hình ConfigMap chưa kịp tạo, chúng ta sử dụng **ArgoCD Sync Waves** để sắp xếp thứ tự apply.

Chúng ta định nghĩa thứ tự: `ConfigMap (Wave 1) -> Deployment (Wave 2) -> Service (Wave 3)`.

Hãy xem các file manifest trong thư mục [manifests/](file:///d:/uni/xbrain/phase_2/Dung-aws-accelerator-p2/cloud/w9/day-a/manifests/):

### 🔑 1. ConfigMap (`manifests/01-configmap.yaml`)
*Được gắn annotation `"argocd.argoproj.io/sync-wave": "1"`*
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
  annotations:
    argocd.argoproj.io/sync-wave: "1"
data:
  APP_COLOR: "deepskyblue"
  APP_MESSAGE: "Xin chào từ GitOps & ArgoCD Sync Waves!"
```

### 🚀 2. Deployment (`manifests/02-deployment.yaml`)
*Được gắn annotation `"argocd.argoproj.io/sync-wave": "2"`*
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-server
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: app-config
```

### 🔌 3. Service (`manifests/03-service.yaml`)
*Được gắn annotation `"argocd.argoproj.io/sync-wave": "3"`*
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: default
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: web-app
```

---

## ⚙️ Bước 3: Tạo ArgoCD Application

Chúng ta sẽ tạo một ArgoCD Application để đồng bộ thư mục `cloud/w9/day-a/manifests` trên Git Repository của bạn với Kubernetes cluster.

### 📝 Định nghĩa Application (`argocd/application.yaml`)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: w9-day-a-gitops
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>.git'
    targetRevision: HEAD
    path: cloud/w9/day-a/manifests
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

> **Lưu ý:** Thay thế `<YOUR_GITHUB_USERNAME>` và `<YOUR_REPO_NAME>` bằng thông tin repo thực tế của bạn trước khi apply.

**Apply file application lên cụm:**
```bash
kubectl apply -f cloud/w9/day-a/argocd/application.yaml
```

Kiểm tra trạng thái trên ArgoCD dashboard. Bạn sẽ thấy quá trình đồng bộ diễn ra theo từng đợt sóng (Sync Waves) rất rõ ràng.

---

## 🤖 Bước 4: CI/CD Pipeline với GitHub Actions

Mô hình GitOps chuẩn yêu cầu kiểm tra kỹ lưỡng trước khi thay đổi được ghi nhận (apply). Chúng ta cấu hình workflow thực hiện:
- **Plan-on-PR**: Khi tạo Pull Request, chạy các công cụ Lint/Validate để phát hiện lỗi cú pháp YAML hoặc cấu hình sai.
- **Apply-on-Merge**: Khi PR được merge vào nhánh chính (`main`/`master`), ArgoCD tự động nhận diện thay đổi qua cơ chế webhook hoặc polling và tiến hành đồng bộ.

### File cấu hình mẫu: `.github/workflows/gitops-ci.yml`
```yaml
name: GitOps CI/CD

on:
  pull_request:
    paths:
      - 'cloud/w9/day-a/manifests/**'
  push:
    branches:
      - main
    paths:
      - 'cloud/w9/day-a/manifests/**'

jobs:
  validate-manifests:
    name: Validate Manifests (Plan-on-PR)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Setup Kubeconform
        run: |
          wget https://github.com/yannh/kubeconform/releases/download/v0.6.1/kubeconform-linux-amd64.tar.gz
          tar -xf kubeconform-linux-amd64.tar.gz
          sudo mv kubeconform /usr/local/bin/

      - name: Validate YAML Syntax & Kubernetes Schemas
        run: |
          kubeconform -summary -strict cloud/w9/day-a/manifests/

  deploy-gitops:
    name: Sync ArgoCD (Apply-on-Merge)
    needs: validate-manifests
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Notify ArgoCD to Sync
        run: |
          echo "Changes merged to main. ArgoCD will automatically sync the resources in the cluster."
          # Option: có thể tích hợp CLI để ép ArgoCD sync ngay lập tức:
          # argocd app sync w9-day-a-gitops --auth-token ${{ secrets.ARGOCD_TOKEN }} --server <ARGOCD_SERVER>
```

---

## 🔄 Bước 5: Thực hành Rollback (Git Revert vs Kubectl Undo)

Điều gì xảy ra khi bản cập nhật mới làm sập ứng dụng? Có 2 cách rollback:

### Cách 1: `kubectl rollout undo` (Anti-pattern trong GitOps ❌)
* Cách này dùng lệnh can thiệp trực tiếp vào cluster:
  ```bash
  kubectl rollout undo deployment/web-app
  ```
* **Vấn đề:** Trạng thái trong Git (Single Source of Truth) và trạng thái thực tế trong Cluster bị lệch nhau (Configuration Drift). ArgoCD có tính năng `Self-Heal` bật sẵn sẽ ngay lập tức ghi đè (overwrite) và kéo trạng thái lỗi từ Git về lại cụm, khiến lệnh undo mất tác dụng.

### Cách 2: `git revert` (Quy trình chuẩn GitOps ✅)
* Để rollback một cách an toàn và giữ tính nhất quán, ta rollback trên Git:
  ```bash
  # Tìm commit hash bị lỗi hoặc commit trước đó
  git log --oneline
  
  # Revert commit bị lỗi
  git revert <COMMIT_HASH_LOI>
  
  # Push lên remote repository
  git push origin main
  ```
* **Kết quả:** Git cập nhật lại code/manifest cũ, ArgoCD nhận diện sự thay đổi và tự động đồng bộ cluster về trạng thái hoạt động tốt. Lịch sử thay đổi được lưu vết rõ ràng trên Git.

---

## 📝 Báo cáo kết quả (Reflection)
Sau khi hoàn thành bài lab, hãy ghi lại nhận xét của bạn vào file `cloud/w9/reflection.md`:
1. Tại sao Sync Waves lại quan trọng khi cấu hình các Stateful/Database application trước Stateless application?
2. Ưu và nhược điểm của mô hình GitOps kéo (Pull-based ArgoCD) so với mô hình đẩy (Push-based GitHub Actions run `kubectl apply`) là gì?
3. Bạn đã xử lý lỗi cấu hình trôi lệch (Configuration Drift) như thế nào trong bài lab?
