# K8s requests vs limits on k3s: home lab kit

Companion files for [K8s Requests vs Limits in a Home Lab](https://sumguy.com/k8s-requests-vs-limits-home-lab/).

## What it does

- `qos-demo.yaml`: three pods (no resources, requests only, requests equal limits) that land in BestEffort, Burstable and Guaranteed.
- `oom-demo.yaml`: allocates 200 MiB under a 64 MiB memory limit. Ends `OOMKilled`, exit code 137.
- `cpu-throttle-demo.yaml`: a busy loop under a 100m CPU limit. `nr_throttled` climbs in `/sys/fs/cgroup/cpu.stat`.
- `resourcequota.yaml`, `no-resources-pod.yaml`, `limitrange.yaml`: a quota on `requests.memory` rejects a pod with no resources until a LimitRange supplies defaults.
- `config.yaml`: a k3s `config.yaml` snippet with `kube-reserved`, `system-reserved` and a memory eviction threshold.

## Prerequisites and tested versions

- Docker 29.9.2 on a cgroup v2 host (kubectl is not needed on the host; the commands run inside the k3s container)
- k3s v1.37.1+k3s1 (Kubernetes v1.37.1), as of November 2026

## How to run

```bash
docker run -d --name k8srl-test --privileged --cgroupns=host -p 16443:6443 \
  rancher/k3s:v1.37.1-k3s1 server --disable=traefik --disable=metrics-server
docker cp . k8srl-test:/kit
alias k='docker exec k8srl-test kubectl'

k apply -f /kit/qos-demo.yaml -f /kit/oom-demo.yaml -f /kit/cpu-throttle-demo.yaml
k get pod -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,PHASE:.status.phase
k get pod oom-demo -o jsonpath='{.status.containerStatuses[0].state.terminated.reason} {.status.containerStatuses[0].state.terminated.exitCode}{"\n"}'
k exec cpu-throttle-demo -- cat /sys/fs/cgroup/cpu.stat

k apply -f /kit/resourcequota.yaml
k apply -f /kit/no-resources-pod.yaml     # rejected
k apply -f /kit/limitrange.yaml
k apply -f /kit/no-resources-pod.yaml     # accepted

docker rm -f k8srl-test
```

For the reservations, start a second container with the snippet mounted and compare Capacity to Allocatable in `kubectl describe node`:

```bash
docker run -d --name k8srl-test2 --privileged --cgroupns=host -p 16444:6443 \
  -v "$PWD/config.yaml:/etc/rancher/k3s/config.yaml:ro" \
  rancher/k3s:v1.37.1-k3s1 server --disable=traefik --disable=metrics-server
```

## Expected results (from the tested run)

- QoS: `qos-besteffort` BestEffort, `qos-burstable` Burstable, `qos-guaranteed` Guaranteed. `oom-demo` and `cpu-throttle-demo` are Burstable because each sets only one resource type.
- `oom_score_adj` inside the pods: 1000, 998, -997 (BestEffort, Burstable with a 64Mi request on a 27.2 GiB host, Guaranteed).
- `oom-demo`: `OOMKilled 137`.
- `cpu-throttle-demo`: `cpu.max` is `10000 100000`; `nr_periods 492 / nr_throttled 492` then `545 / 545` five seconds later.
- Quota without defaults: `pods "bare" is forbidden: failed quota: caps: must specify limits.memory for: app; requests.cpu for: app; requests.memory for: app`. After the LimitRange the pod is accepted with requests `50m`/`64Mi` and a `128Mi` memory limit.
- Reservations: Capacity memory 28506216Ki and cpu 16. Allocatable memory 27195496Ki and cpu 15600m (1 GiB reserved plus the 256Mi eviction threshold; 400m CPU reserved). Without the snippet, Allocatable equals Capacity.
- k3s v1.37.1 default `evictionHard` is `nodefs.available: 5%` and `imagefs.available: 5%` only, with no `kubeReserved` or `systemReserved`.

The Docker-in-Docker numbers (16 CPUs, about 27 GiB) come from the host running the test, not from a mini PC.
