# W9 — Tin nhắn cho HV Cloud/DevOps

> Gửi cuối T6 W8 (05/06/2026) hoặc sáng T2 W9 (08/06).

Chào cả nhà,

W9 bắt đầu **T2 ngày 08/06**, theme **Deliver Smartly** — sau khi W8 đã có K8s cluster (minikube) chạy 3 component, tuần này lên đời: GitOps + Observability + Canary auto-abort.

**🎙️ Live mentor tuần này:** anh Minh T4 15h-17h (online) — Monitoring / Observability. Mentor onsite (T5–T6 Đà Nẵng): _coming soon_.

---

## W9 — Deliver Smartly: GitOps + Observability + Canary

| Ngày | Hoạt động |
|---|---|
| **T2 08/06** | Self-study **D1 GitOps & CI/CD** — GitHub Actions plan-on-PR + apply-on-merge, ArgoCD vs Flux, app-of-apps, sync waves, rollback (`git revert` vs `kubectl rollout undo`) |
| **T3 09/06** | Self-study **D2 Observability — SLO/SLI/OTel** — OTel SDK + Collector, Prometheus + Grafana + Loki, SLO methodology (availability + latency), multi-window burn rate alert (fast 1h × 5min, slow 6h × 30min) |
| **T4 10/06** | Sáng: Self-study **D3 Progressive Delivery (Canary)** — Argo Rollouts, Rollout CRD, AnalysisTemplate với Prometheus query, abort criteria, integration với burn rate<br>**🎙️ 15h–17h: LIVE Monitoring/Observability với mentor Minh (online)**<br>**📝 17h–18h: Online Test 1** (60p, scope D1 + D2) |
| **T5 11/06** | **Onsite Đà Nẵng với mentor _(coming soon)_** — bắt đầu **Lab "GitOps-ify W8 platform + bolt-on observability + canary"** full day |
| **T6 12/06** | Onsite — hoàn thiện Lab → show-and-tell pod 5 người 13h30–15h → **📝 15h–16h: Online Test 2** (60p, scope D3 + Lab) |

**Mục tiêu cuối W9:** Cluster W8 đã có giờ GitOps-managed (ArgoCD sync), có observability stack đo SLO + burn rate alert, deploy nào ra cũng canary auto-abort khi metric tệ. Không apply manifest tay nữa.

---

## Tài liệu tham khảo

### GitOps & CI/CD

Tài liệu chính thống:
- **ArgoCD Docs** — https://argo-cd.readthedocs.io (start: "Getting Started" → "App of Apps")
- **GitHub Actions Docs** — https://docs.github.com/en/actions
- **Flux Docs** (alternative to ArgoCD) — https://fluxcd.io/flux
- **GitOps Principles** (OpenGitOps) — https://opengitops.dev

### Observability — SLO/SLI/OTel

Tài liệu chính thống:
- **OpenTelemetry Docs** — https://opentelemetry.io/docs (start: Concepts → Instrumentation)
- **Prometheus Docs** — https://prometheus.io/docs
- **Grafana Docs** — https://grafana.com/docs/grafana/latest
- **Loki Docs** — https://grafana.com/docs/loki/latest
- **Google SRE Book — SLO chapter** — https://sre.google/sre-book/service-level-objectives (free online)
- **The Site Reliability Workbook — Implementing SLOs** — https://sre.google/workbook/implementing-slos
- **Multi-window burn rate alert** (Google) — https://sre.google/workbook/alerting-on-slos

### Progressive Delivery — Canary

Tài liệu chính thống:
- **Argo Rollouts Docs** — https://argoproj.github.io/argo-rollouts (start: "Concepts" → "Analysis")
- **Flagger Docs** (alternative) — https://flagger.app
- **Progressive Delivery patterns** (CNCF) — https://www.cncf.io/blog/2024/01/26/progressive-delivery/

### Load Testing (cho lab)

- **k6 Docs** — https://k6.io/docs (recommended cho load test trong CI)
- **Vegeta** — https://github.com/tsenart/vegeta (CLI alternative)

---

## Repo cá nhân (W9)

```
cloud/
  w9/
    day-a/      # GitOps & CI/CD — .github/workflows/ + argocd/
    day-b/      # Observability — otel/ + dashboards/ + alert-rules/
    day-c/      # Canary — rollout/ + analysis-template/
    lab/        # GitOps-ify + bolt-on
    reflection.md
```

Commit message: `[W9-D1] <topic ngắn>`. Push hằng ngày T2–T4.

---

## Cần hỗ trợ

- Câu hỏi material → `#phase2-cloud-daily`
- Vướng technical → `#phase2-cloud-help` (kèm screenshot + log)
- Urgent → DM anh Minh

— Mentor team
