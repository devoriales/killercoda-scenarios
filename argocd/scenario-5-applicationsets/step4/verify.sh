#!/bin/bash
set -e

# 1. The feature must actually be enabled, which is the point of the step.
FLAG=$(kubectl get cm argocd-cmd-params-cm -n argocd \
  -o jsonpath='{.data.applicationsetcontroller\.enable\.progressive\.syncs}' 2>/dev/null)
if [ "$FLAG" != "true" ]; then
  echo "Progressive syncs are still disabled (key reads: '${FLAG:-absent}')."
  echo "Enable it with:"
  echo "  kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '{\"data\":{\"applicationsetcontroller.enable.progressive.syncs\":\"true\"}}'"
  exit 1
fi

# 2. And the controller must have been restarted to pick it up.
SEEN=$(kubectl exec -n argocd deploy/argocd-applicationset-controller \
  -c argocd-applicationset-controller \
  -- sh -c 'echo $ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_PROGRESSIVE_SYNCS' 2>/dev/null | tr -d '\r\n ')
if [ "$SEEN" != "true" ]; then
  echo "The ConfigMap is set but the controller has not picked it up (it reads: '${SEEN:-empty}')."
  echo "Restart it with: kubectl rollout restart deploy argocd-applicationset-controller -n argocd"
  exit 1
fi

if ! kubectl get applicationset rolling-demo -n argocd >/dev/null 2>&1; then
  echo "The 'rolling-demo' ApplicationSet does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/04-rolling/appset-rolling.yaml"
  exit 1
fi

# 3. The strategy must have assigned every Application to a step. That only appears
#    in status once the feature is live, so it proves the whole chain worked.
STEPS=$(kubectl get applicationset rolling-demo -n argocd -o json 2>/dev/null | python3 -c "
import json,sys
try:
    st=json.load(sys.stdin).get('status',{}).get('applicationStatus',[])
    print(len([a for a in st if a.get('step')]))
except Exception:
    print(0)
" 2>/dev/null || echo 0)

if [ "${STEPS:-0}" -lt 3 ]; then
  echo "Only ${STEPS:-0} of 3 Applications have been assigned a RollingSync step."
  echo "Give the controller a few seconds after the restart, then check:"
  echo "  kubectl get applicationset rolling-demo -n argocd -o jsonpath='{.status.applicationStatus}'"
  exit 1
fi

echo "Progressive syncs enabled, the controller sees the flag, and all 3 Applications are assigned to RollingSync steps."
exit 0
