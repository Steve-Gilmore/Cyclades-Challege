#!/bin/bash

kubectl delete configmap logstash-pipelines -n elastic-system
kubectl -n elastic-system delete -f logstash-deploy.yaml
