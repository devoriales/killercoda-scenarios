#!/bin/bash
# Verify VPA recommendations are available for both deployments
set -e

for i in $(seq 1 36); do
  FRONTEND_REC=$(kubectl get vpa goldilocks-frontend -n metrics-app \
    -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}' 2>/dev/null || echo "")
  API_REC=$(kubectl get vpa goldilocks-api -n metrics-app \
    -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}' 2>/dev/null || echo "")

  if [ -n "$FRONTEND_REC" ] && [ -n "$API_REC" ]; then
    echo "Recommendations available: frontend target CPU=$FRONTEND_REC, api target CPU=$API_REC"
    exit 0
  fi
  sleep 5
done

echo "FAIL: VPA recommendations not yet available. This can take a few minutes after the background setup finishes. Wait for Step 1's readiness check to print 'Recommendations ready!', then try again."
exit 1
