# GitOps rollback: Argo CD vs Flux

Working files for the post [GitOps Rollback: Argo CD vs Flux](https://sumguy.com/gitops-rollback-argocd-vs-flux/).

A throwaway kind cluster with Argo CD and Flux installed, a small Git server on the `kind` Docker network, and a demo repo you break on purpose. You practice the rollback paths from the post without touching a real cluster.

## Tested versions

| Component | Version |
| --- | --- |
| Argo CD | v3.5.3 |
| Flux | v2.9.5 (`helm.toolkit.fluxcd.io/v2`, `kustomize.toolkit.fluxcd.io/v1`, `source.toolkit.fluxcd.io/v1`) |
| kind | v0.33.0 (Kubernetes v1.37.0) |
| kubectl | v1.37.1 |

Test-host note: the author's host kernel lacked the netfilter modules that kind's default kube-proxy and kindnet need, so the run used kind with `disableDefaultCNI`, `kubeProxyMode: none` and Cilium in native routing mode, and the controller health probes were stripped. On a normal host, `kind-config.yaml` as shipped is enough.

## Files

- `kind-config.yaml`: single-node kind cluster.
- `git-server/`: Dockerfile and nginx config for a smart-HTTP Git server (`git-http-backend`) with an empty bare repo at `/homelab.git`.
- `demo-repo/`: the content you push to that repo. `apps/argo-demo` (plain Deployment for Argo CD), `apps/flux-demo` (Kustomize app for Flux), `apps/flux-helm` + `charts/demo` (HelmRelease with remediation).
- `argocd/application.yaml`: Application with commented auto-sync and `retry` with backoff.
- `flux/gitrepository.yaml`, `flux/kustomizations.yaml`: Flux source and two Kustomizations (`wait: true`, `timeout: 60s`).

## Run it

1. Create the cluster and the Git server.

   ```bash
   kind create cluster --name gitops-rb --config kind-config.yaml
   docker build -t gitops-rb-git git-server/
   docker run -d --name gitops-rb-git --network kind gitops-rb-git
   GIT_IP=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' gitops-rb-git)
   ```

2. Install Argo CD and Flux.

   ```bash
   kubectl create ns argocd
   kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
   flux install
   ```

3. Push the demo repo.

   ```bash
   cp -r demo-repo /tmp/homelab && cd /tmp/homelab
   git init -b main && git add -A && git commit -m "initial: good state"
   git remote add origin http://$GIT_IP/homelab.git && git push origin main
   cd -
   ```

4. Point both tools at it. The manifests use a placeholder URL; the sed swaps in the container IP.

   ```bash
   U=http://$GIT_IP/homelab.git
   sed "s#http://git.example.com/you/homelab.git#$U#" argocd/application.yaml | kubectl apply -f -
   sed "s#http://git.example.com/you/homelab.git#$U#" flux/gitrepository.yaml | kubectl apply -f -
   kubectl apply -f flux/kustomizations.yaml
   kubectl config set-context --current --namespace=argocd
   argocd --core app sync web
   ```

5. Break things and recover.

   Argo CD:
   - Change the image in `apps/argo-demo/deployment.yaml` to `nginx:1.29-alpine-broken`, commit, push, `argocd --core app sync web`.
   - Manual rollback (auto-sync off): `argocd --core app history web`, then `argocd --core app rollback web <ID>`.
   - Turn on auto-sync (`argocd --core app set web --sync-policy automated`) and run the rollback again to see the refusal.
   - Git recovery: `git revert --no-edit HEAD && git push`, then `argocd --core app get web --refresh`.
   - Stuck operation: set `replicas: two`, push, watch `.status.operationState` retry, then `argocd --core app terminate-op web`.

   Flux:
   - Bad tag in `apps/flux-demo/deployment.yaml`, push, `flux reconcile kustomization demo --with-source`. Health check fails after 60s.
   - Recovery: `flux suspend kustomization demo`, `git revert`, push, `flux resume kustomization demo`, `flux reconcile kustomization demo --with-source`.
   - HelmRelease: set `values.image.tag` in `apps/flux-helm/helmrelease.yaml` to `1.29-alpine-broken`, push, and watch `flux get helmrelease demo` and `helm -n flux-helm history demo`.

6. Clean up.

   ```bash
   kind delete cluster --name gitops-rb
   docker rm -f gitops-rb-git && docker rmi gitops-rb-git
   ```
