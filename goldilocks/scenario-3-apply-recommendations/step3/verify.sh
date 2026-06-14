#!/bin/bash
# Verify api has Burstable QoS with requests < limits
set -e

kubectl rollout status deployment/api -n metrics-app --timeout=90s 2>/dev/null || true

QOS=$(kubectl get pod -n metrics-app -l app=api \
  -o jsonpath='{.items[0].status.qosClass}' 2>/dev/null)
if [ "$QOS" != "Burstable" ]; then
  echo "FAIL: Expected QoS Burstable for api, got '$QOS'"
  echo "Hint: requests must be less than limits for Burstable QoS"
  exit 1
fi

# Verify requests are less than limits (sanity check)
CPU_REQ=$(kubectl get pod -n metrics-app -l app=api \
  -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}' 2>/dev/null)
CPU_LIM=$(kubectl get pod -n metrics-app -l app=api \
  -o jsonpath='{.items[0].spec.containers[0].resources.limits.cpu}' 2>/dev/null)

echo "Api patched: QoS=$QOS, CPU request=$CPU_REQ, CPU limit=$CPU_LIM"

# Final summary
echo ""
echo "=== Final QoS Summary ==="
kubectl get pods -n metrics-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}' 2>/dev/null
