#!/bin/bash

kubectl create configmap logstash-pipelines --from-file=./pipelines -n elastic-system
kubectl -n elastic-system apply -f logstash-deploy.yaml
