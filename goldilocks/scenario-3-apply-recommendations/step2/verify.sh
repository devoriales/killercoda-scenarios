#!/bin/bash
# Verify frontend has been patched to 15m/100Mi Guaranteed
set -e

# Wait for rollout
kubectl rollout status deployment/frontend -n metrics-app --timeout=90s 2>/dev/null || true

# Check QoS
QOS=$(kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].status.qosClass}' 2>/dev/null)
if [ "$QOS" != "Guaranteed" ]; then
  echo "FAIL: Expected QoS Guaranteed, got '$QOS'"
  exit 1
fi

# Check CPU request is 15m
CPU_REQ=$(kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}' 2>/dev/null)
if [ "$CPU_REQ" != "15m" ]; then
  echo "FAIL: Expected CPU request 15m, got '$CPU_REQ'. Did you apply the patch?"
  exit 1
fi

# Check memory request is 100Mi
MEM_REQ=$(kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].spec.containers[0].resources.requests.memory}' 2>/dev/null)
if [ "$MEM_REQ" != "100Mi" ]; then
  echo "FAIL: Expected memory request 100Mi, got '$MEM_REQ'"
  exit 1
fi

echo "Frontend patched correctly: QoS=$QOS, CPU=$CPU_REQ, Memory=$MEM_REQ"
