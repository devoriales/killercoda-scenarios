#!/bin/bash
set -e

if ! kubectl get sealedsecret db-password -n sealed-demo >/dev/null 2>&1; then
  echo "No SealedSecret named db-password in the sealed-demo namespace."
  echo "Seal the manifest and apply it:"
  echo "  kubeseal --controller-namespace kube-system --format yaml < /root/manifests/04-security/plain-secret.yaml > /root/sealed-secret.yaml"
  echo "  kubectl apply -f /root/sealed-secret.yaml"
  exit 1
fi

# The ciphertext must actually be ciphertext, not the plaintext pasted in.
CIPHER=$(kubectl get sealedsecret db-password -n sealed-demo -o jsonpath='{.spec.encryptedData.password}' 2>/dev/null)
if [ -z "$CIPHER" ]; then
  echo "The SealedSecret has no encryptedData.password field, so it was not produced by kubeseal."
  exit 1
fi
if echo "$CIPHER" | grep -q 'hunter2'; then
  echo "The SealedSecret contains the plaintext password, so it was not encrypted."
  exit 1
fi

# The controller must have decrypted it into a real Secret.
if ! kubectl get secret db-password -n sealed-demo >/dev/null 2>&1; then
  echo "The SealedSecret exists but no Secret was created from it."
  echo "The controller decrypts within a few seconds. Check it is running and read its log:"
  echo "  kubectl logs deploy/sealed-secrets-controller -n kube-system --tail=20"
  exit 1
fi

# And the decrypted value must be right, which is the whole point of a round trip.
PLAIN=$(kubectl get secret db-password -n sealed-demo -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
if [ "$PLAIN" != "hunter2-the-real-password" ]; then
  echo "The Secret exists but its value is '${PLAIN}', not the sealed password."
  exit 1
fi

# Owned by the SealedSecret, which is what makes it self-healing.
OWNER=$(kubectl get secret db-password -n sealed-demo -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
if [ "$OWNER" != "SealedSecret" ]; then
  echo "The Secret is not owned by a SealedSecret (owner: '${OWNER:-none}')."
  echo "It looks like the plaintext Secret was re-applied rather than the sealed one."
  exit 1
fi

echo "Round trip complete: ciphertext committed safely, controller decrypted it, and the Secret is owned by the SealedSecret."
exit 0
