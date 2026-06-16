# Kyverno101 - Validate Use Case Guide
This document will serve as a guide for constructing validation policies with Kyverno. It will show the steps expected to be taken when dealing with future policies. In this specific example, it features a simple example of allowing only 443 port to be open.
# Problem
## Scenario
Assuming we have web-application pods that transmit sensitive information such as usernames and passwords from the pod to the database. Thus, it is of upmost importance to ensure that the pods are communicating through HTTPS only to ensure that the information being transferred are encrypted and secure to prevent information from leaking. 
## Task
To ensure that the pods are talking in HTTPS and that no other unnecssary ports are open.

# Audit Policy Configured 
only-allow-port-443.yaml:
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: only-allow-port-443
spec:
  validationFailureAction: Audit
  rules:
    - name: check-port
      match:
        any:
        - resources:
            kinds: [Service]
      validate:
        message: "Only port 443 is allowed."
        pattern:
          spec:
            ports:
              - port: 443
```
> 💡 **To Note:**   
>
> Audit is used first so as to see the violations before blocking anything.  
> Can be skipped to <span style="color: yellow"><i>Enforce Policy Configured</i></span> if it is a new Cluster.

# Applying Audit Policy
```
[root@DESKTOP-1JL50UD edwar]# kubectl apply -f <path_to_yaml_file>/only-allow-port-443.yaml
clusterpolicy.kyverno.io/only-allow-port-443 created
[root@DESKTOP-1JL50UD edwar]# kubectl get clusterpolicy
NAME                  ADMISSION   BACKGROUND   READY   AGE   MESSAGE
only-allow-port-443   true        true         True    23s   Ready

```
# Testing Audit Policy
## Service expected to Fail
```
[root@DESKTOP-1JL50UD edwar]# kubectl create service clusterip bad-service --tcp=80:80
service/bad-service created
```
## Service expected to Pass
```
[root@DESKTOP-1JL50UD edwar]# kubectl create service clusterip good-service --tcp=443:443
service/good-service created
```
## Checking Audits
### PolicyReport
```
[root@DESKTOP-1JL50UD edwar]# kubectl get policyreport -A
NAMESPACE     NAME                                   KIND      NAME                                    PASS   FAIL   WARN   ERROR   SKIP   AGE
default       1cc9f726-474b-434a-8326-cea55e6bca56   Service   kubernetes                              1      0      0      0       0      6m23s
default       6dd7628d-bbee-4f90-a8cb-43cb424fcdd7   Service   good-service                            1      0      0      0       0      6s
default       e6dc305b-5571-48e2-954f-62d23e02a1b2   Service   bad-service                             0      1      0      0       0      63s
```
### Describe PolicyReport
```diff
[root@DESKTOP-1JL50UD edwar]# kubectl describe policyreport -n default
Name:         6dd7628d-bbee-4f90-a8cb-43cb424fcdd7
Namespace:    default
Labels:       app.kubernetes.io/managed-by=kyverno
Annotations:  <none>
API Version:  wgpolicyk8s.io/v1alpha2
Kind:         PolicyReport
Metadata:
  Creation Timestamp:  2026-06-16T05:42:10Z
  Generation:          2
  Owner References:
    API Version:     v1
    Kind:            Service
+   Name:            good-service
    UID:             6dd7628d-bbee-4f90-a8cb-43cb424fcdd7
  Resource Version:  44968
  UID:               20c645bb-8c55-44a1-bca1-7d9ba4bbd5a9
Results:
+  Message:  validation rule 'check-port' passed.
  Policy:   only-allow-port-443
  Properties:
    Process:  background scan
+  Result:     pass
  Rule:       check-port
  Scored:     true
  Source:     kyverno
  Timestamp:
    Nanos:    0
    Seconds:  1781588540
Scope:
  API Version:  v1
  Kind:         Service
  Name:         good-service
  Namespace:    default
  UID:          6dd7628d-bbee-4f90-a8cb-43cb424fcdd7
Summary:
  Error:  0
  Fail:   0
+  Pass:   1
  Skip:   0
  Warn:   0
Events:   <none>

Name:         e6dc305b-5571-48e2-954f-62d23e02a1b2
Namespace:    default
Labels:       app.kubernetes.io/managed-by=kyverno
Annotations:  <none>
API Version:  wgpolicyk8s.io/v1alpha2
Kind:         PolicyReport
Metadata:
  Creation Timestamp:  2026-06-16T05:41:13Z
  Generation:          2
  Owner References:
    API Version:     v1
    Kind:            Service
-    Name:            bad-service
    UID:             e6dc305b-5571-48e2-954f-62d23e02a1b2
  Resource Version:  44793
  UID:               17634992-ff78-4d06-a2fb-0c1cc3446707
Results:
-  Message:  validation error: Only port 443 is allowed. rule check-port failed at path /spec/ports/0/port/
  Policy:   only-allow-port-443
  Properties:
    Process:  background scan
-  Result:     fail
  Rule:       check-port
  Scored:     true
  Source:     kyverno
  Timestamp:
    Nanos:    0
    Seconds:  1781588483
Scope:
  API Version:  v1
  Kind:         Service
 Name:         bad-service
  Namespace:    default
  UID:          e6dc305b-5571-48e2-954f-62d23e02a1b2
Summary:
  Error:  0
-  Fail:   1
  Pass:   0
  Skip:   0
  Warn:   0
Events:   <none>
```
## Clean Up 
```
[root@DESKTOP-1JL50UD edwar]# kubectl delete service bad-service
service "bad-service" deleted from default namespace
[root@DESKTOP-1JL50UD edwar]# kubectl delete service good-service
service "good-service" deleted from default namespace
```
# Enforce Policy Configured
only-allow-port-443.yaml:
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: only-allow-port-443
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-port
      match:
        any:
        - resources:
            kinds: [Service]
      validate:
        message: "Only port 443 is allowed."
        pattern:
          spec:
            ports:
              - port: 443
```
# Applying Enforce Policy
```
[root@DESKTOP-1JL50UD edwar]# kubectl apply -f <path_to_yaml_file>/only-allow-port-443.yaml
clusterpolicy.kyverno.io/only-allow-port-443 created
[root@DESKTOP-1JL50UD edwar]# kubectl get clusterpolicy
NAME                  ADMISSION   BACKGROUND   READY   AGE   MESSAGE
only-allow-port-443   true        true         True    23s   Ready

```
# Testing Enforce Policy
## Service expected to Fail
```
[root@DESKTOP-1JL50UD edwar]# kubectl create service clusterip bad-service --tcp=80:80
error: failed to create ClusterIP service: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Service/default/bad-service was blocked due to the following policies

only-allow-port-443:
  check-port: 'validation error: Only port 443 is allowed. rule check-port failed
    at path /spec/ports/0/port/'
```
## Service expected to Pass
```
[root@DESKTOP-1JL50UD edwar]# kubectl create service clusterip good-service --tcp=443:443
service/good-service created
```
## Cleanup
```
[root@DESKTOP-1JL50UD edwar]# kubectl delete service good-service
service "good-service" deleted from default namespace
[root@DESKTOP-1JL50UD edwar]# kubectl delete clusterpolicy only-allow-port-443
clusterpolicy.kyverno.io "only-allow-port-443" deleted
```