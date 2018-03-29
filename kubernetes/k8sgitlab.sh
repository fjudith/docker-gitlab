#!/bin/bash

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        v="${1/--/}"
        declare $v="$2"
   fi

  shift
done

# Create
if [ -z create ] || [ -v create ] || [ "$create" == "conduit" ] || [ "$create" == "istio" ]; then
  kubectl create namespace gitlab

  tr --delete '\n' <gitlab.postgres.password.txt >.strippedpassword.txt && mv .strippedpassword.txt gitlab.postgres.password.txt
  tr --delete '\n' <gitlab.imap.password.txt >.imap.strippedpassword.txt && mv .imap.strippedpassword.txt gitlab.imap.password.txt
  tr --delete '\n' <gitlab.smtp.password.txt >.smtp.strippedpassword.txt && mv .smtp.strippedpassword.txt gitlab.smtp.password.txt
  tr --delete '\n' <gitlab.ldap.password.txt >.ldap.strippedpassword.txt && mv .ldap.strippedpassword.txt gitlab.ldap.password.txt
  tr --delete '\n' <gitlab.saml.password.txt >.saml.strippedpassword.txt && mv .saml.strippedpassword.txt gitlab.saml.password.txt
  kubectl create secret -n gitlab generic gitlab-postgres-pass --from-file=gitlab.postgres.password.txt
  kubectl create secret -n gitlab generic gitlab-imap-pass --from-file=gitlab.imap.password.txt
  kubectl create secret -n gitlab generic gitlab-smtp-pass --from-file=gitlab.smtp.password.txt
  kubectl create secret -n gitlab generic gitlab-ldap-pass --from-file=gitlab.ldap.password.txt
  kubectl create secret -n gitlab generic gitlab-saml-pass --from-file=gitlab.saml.password.txt

  kubectl apply -f ./local-volumes.yaml
fi

if [ -z create ] ; then
  kubectl apply -n gitlab -f ./gitlab-deployment.yaml

  kubectl get svc gitlab -n gitlab
elif [ -v create ] && [ "$create" == "conduit" ]; then
  cat ./gitlab-deployment.yaml | conduit inject --skip-outbound-ports=5432,11211 --skip-inbound-ports=5432,11211 - | kubectl apply -n gitlab -f -

  kubectl get svc gitlab -n gitlab -o jsonpath="{.status.loadBalancer.ingress[0].*}"

  kubectl get svc gitlab -n gitlab
elif [ -v create ] && [ "$create" == "istio" ]; then
  kubectl label namespace gitlab istio-injection=enabled

  kubectl apply -n gitlab -f ./gitlab-deployment.yaml
  kubectl apply -n gitlab -f ./gitlab-ingress.yaml

  export GATEWAY_URL=$(kubectl get po -l istio=ingress -n istio-system -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc istio-ingress -n istio-system -o 'jsonpath={.spec.ports[0].nodePort}')

  printf "Istio Gateway: $GATEWAY_URL"
fi


# Delete
if [ -z delete ] || [ "$delete" == "conduit" ]; then
  kubectl delete -f ./local-volumes.yaml
  kubectl delete secret -n gitlab gitlab-postgres-pass
  kubectl delete secret -n gitlab gitlab-imap-pass
  kubectl delete secret -n gitlab gitlab-smtp-pass
  kubectl delete -n gitlab -f ./gitlab-deployment.yaml

  kubectl delete namespace gitlab
fi

if [ -v delete ] && [ "$delete" == "istio" ]; then
  kubectl delete -f ./local-volumes.yaml
  kubectl delete secret -n gitlab gitlab-postgres-pass
  kubectl delete secret -n gitlab gitlab-imap-pass
  kubectl delete secret -n gitlab gitlab-smtp-pass
  kubectl delete -n gitlab -f ./gitlab-deployment.yaml
  kubectl delete -n gitlab -f ./gitlab-ingress.yaml

  kubectl delete namespace gitlab
fi