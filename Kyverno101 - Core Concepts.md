# Kyverno101 - Core Concepts
This is a document that describes the architecture, core concepts, and examples in Kyverno.
# Overview
```text
┌───────────┐             ┌────────────┐             ┌─────────┐
│  User/CI  │             │ Kubernetes │             │ Kyverno │
└─────┬─────┘             └─────┬──────┘             └────┬────┘
      │                         │                         │
      │─── 1. kubectl apply ───>│                         │
      │    (Deploy Pod)         │                         │
      │                         │─── 2. Webhook Request ─>│
      │                         │    "Is this allowed?"   │
      │                         │                         │──┐ 3. Check
      │                         │                         │  │ Cluster
      │                         │                         │<─┘ Policies
      │                         │<── 4. Allow / Deny ─────│
      │                         │                         │
      │<── 5. Final Response ───│                         │
```
Adopted from: Claude AI
> 🛡️ **Architecture Note: Policy Enforcement with Kyverno**
> 
> 1. **Submission:** The developer or CI pipeline pushes a manifest via `kubectl`.
> 2. **Intercept:** The Kubernetes API server catches the request and passes it to Kyverno using an *Admission Webhook*.
> 3. **Validation:** Kyverno checks if the incoming configuration violates any structural or security rules (e.g., checking if the pod runs as root).
> 4. **Verdict:** If approved, the resource is created in the cluster; otherwise, the request is instantly blocked.

# Two Webhooks
## MutatingAdmissionWebhook
Able to modify the resource to as what it is wanted (Inject defaults etc)  
Runs first 
## ValidatingAdmissionWebhook
Validates rules as specified to determine if the resource is allowed or deny  
Runs second

# Four Pods
## Admission Controller
The controller that handles real-time requests; running validation and mutation rules to allow or deny pods.
```text 
Pod created → webhook fires → admission controller → runs validate/mutate rules → allow or deny instantly
```
## Background Controller
The controller that handles resources that already exist in the cluster.
```text
New ClusterPolicy applied → background controller wakes up → scans all existing resources → generates PolicyReports
```
>⚠️*Warning:*  
>
> Won't block or modify existing resources, only reports on them  
## Reports Controller
The controller that handles PolicyReport and ClusterPolicyReport objects. 
```text
Admission Controller → raw result → Reports Controller → builds/updates PolicyReport CRDs → visible via kubectl
```
## Cleanup Controller
The controller that handles the deletion of resources based on certain conditions set.
```text
CleanupPolicy defined → cleanup controller watches for matches → deletes resources when conditions are met
```

# Four Rule Types
## Validate
Inspecting a resource to determine if it should be allowed or denied 
### Pattern Matching
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
> 🔧 **Properties:**
> 
> **Aproach:** Describe what should be accepted (whitelist)  
> **Logic:** Implicit - Anything not matched is denied
### Deny with Conditions
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
        deny:
          conditions:
            all:
            - key: "{{ request.object.spec.ports[0].port }}"
              operator: NotEquals
              value: 443
```
> 🔧 **Properties:**
> 
> **Approach:** Describe what should be rejected (blacklist)  
> **Logic:** Explicit - Conditions needs to be specified to trigger denial

## Mutate
Modifying a resource before it is saved 
### Merge
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-pod-defaults
spec:
  rules:
    - name: add-defaults
      match:
        any:
        - resources:
            kinds: [Pod]
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(team): "unassigned"         # ADD team label only if it doesn't exist
                                            # if team label already exists, leave it alone
          spec:
            containers:
              - (name): "*"                 # MATCH every container by name (anchor)
                                            # without this, Kyverno won't know which
                                            # container in the array to target
                resources:
                  +(limits):               # ADD resource limits only if limits block
                    memory: "256Mi"        # doesn't exist yet
                    cpu: "500m"
                =(securityContext):                 # ONLY apply the below IF securityContext
                  allowPrivilegeEscalation: false   # already exists on the container
                                                    # if securityContext is absent,
                                                    # skip this entirely
```
> 🔧 **Properties:**
> 
> **+():** Adds only if field does not exist prior  
> **():** Match to anchor  
> **=():** Adds only if field exists prior  
### Patches
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-pod-patch
spec:
  rules:
    - name: add-defaults-patch
      match:
        any:
        - resources:
            kinds: [Pod]
      mutate:
        patches: 
          - path: "/metadata/labels/env"
            op: add
            value: "production"
            # Result: adds label env=production
            # Note: if the field already exists, add OVERWRITES it (unlike +() in merge patch)
          - path: "/metadata/labels/debug"
            op: remove
            # Result: removes the debug label entirely
            # Note: fails if the field doesn't exist
          - path: "/spec/containers/0/image"
            op: replace
            value: "nginx:1.25"
            # Result: changes the image tag
            # Note: fails if the field doesn't exist (use add if unsure)
          - path: "/metadata/labels/app"
            op: move
            from: "/metadata/labels/application"
            # Result: renames label 'application' to 'app'
          - path: "/metadata/labels/app"
            op: copy
            from: "/metadata/name"
            # Result: copies the pod name into a label called 'app'
          - path: "/metadata/labels/env"
            op: test
            value: "production"
            # If env != production, the entire patch fails
            # Useful as a guard before making changes
```
> 🔧 **Properties:**
> 
> **add:** Overwrites and creates a new field  
> **remove:** Deletes a field  
> **replace:** Replaces the original value with a new value  
> **move:** Relocating a field  
> **copy:** Duplicate a field  
> **test:** Checks for certain conditions  
## Generate
Generate rules watch for a trigger resource and automatically create new resources in response. The created resources can optionally be synchronized — meaning if the policy changes, all generated resources update automatically.
```
generate:
  kind: NetworkPolicy
  name: default-deny
  namespace: "{{request.object.metadata.name}}"
  data:
    spec:
      podSelector: {}
      policyTypes:
      - Ingress
      - Egress
---
generate:
  kind: ConfigMap
  name: app-config
  namespace: "{{ request.object.metadata.name }}"
  synchronize: true
  clone:
    namespace: templates      # copy from this namespace
    name: app-config-template # copy this resource
---
generate:
  kind: ConfigMap
  namespace: "{{ request.object.metadata.name }}"
  synchronize: true
  cloneList:
    namespace: templates
    kinds:
      - ConfigMap
      - Secret
    selector:
      matchLabels:
        template: "true"      # only clone resources with this label
```
> 🔧 **Properties:**
> 
> **data:** Write the resource directly in the policy  
> **clone:** Copy from an existing resource  
> **cloneList:** Copy multiple resources at once  

>⚠️*Warning:*  
>
>By default, generate only works on new resources, to apply to existing ones need to use: <span style="color: yellow;"><i>generateExisting:true</i></span>  
>An intermediate object, "GenerateRequest" that tracks generation: <span style="color: yellow;"><i>kubectl get generaterequests -n kyverno</i></span>

## Verify
Ensures that the container images are trusted and legitimate  
Signing image with Cosign:
```
# Generate a key pair
cosign generate-key-pair

# Sign the image
cosign sign --key cosign.key ghcr.io/myorg/myapp:v1.0

# Create the secret from your cosign.pub file
kubectl create secret generic cosign-public-key \
  --from-file=cosign.pub=cosign.pub \
  -n kyverno
```
Verify with Kyverno:
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-signature
      match:
        any:
        - resources:
            kinds: [Pod]
      verifyImages:
        - imageReferences:
          - "ghcr.io/myorg/*"         # apply to all images from this org
          mutateDigest: true           # replace tag with immutable digest
          verifyDigest: true           # ensure digest hasn't changed
          required: true               # image MUST be signed — no exceptions
          attestors:
          - entries:
            - keys:
                secret:
                   name: cosign-public-key      # name of the secret
                   namespace: kyverno           # where the secret lives
```
> 🔧 **Properties:**
> 
> **Static Key Signing:** Key is generated manually  
> **Github:** Utilises GitHub Actions OIDC token as identity   

## Policy Kind
### ClusterPolicy
Applies within cluster, ie accross all namespaces  
Usually used for Organisational-wide rules such as Security Baselines
### Policy
Applies to one namespace only  
Used for more specific rules

## Match vs Exclude
### match.any
Similar to OR logic, where it is matched if any of the condtions specified are true
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: match-any-example
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-team-label
      match:
        any:
        - resources:
            kinds: [Pod]              # match if it's a Pod
        - resources:
            kinds: [Deployment]       # OR a Deployment
        - resources:
            kinds: [Service]          # OR a Service
      validate:
        message: "Resource must have a team label."
        pattern:
          metadata:
            labels:
              team: "?*"
```
### match.all
Similar to AND logic, where it is matched only if all of the conditions specified are true
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: match-all-example
spec:
  validationFailureAction: Enforce
  rules:
    - name: production-pods-need-limits
      match:
        all:
        - resources:
            kinds: [Pod]              # must be a Pod
        - resources:
            namespaces: [production]  # AND must be in production namespace
        - subjects:
          - kind: User
            name: developer           # AND must be created by developer user
      validate:
        message: "Production pods must have resource limits."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```
### exclude.any
Optional to include, and is used to exclude certain fields that should not be checked against
```
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: exclude-any-example
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-team-label
      match:
        any:
        - resources:
            kinds: [Pod]
      exclude:
        any:
        - resources:
            namespaces:
              - kube-system          # never touch system namespace
              - kyverno              # never touch kyverno itself
        - subjects:
          - kind: ServiceAccount
            name: ci-agent           # exclude CI service account
            namespace: default
        - resources:
            names:
              - "debug-*"            # exclude any pod named debug-*
      validate:
        message: "Pod must have a team label."
        pattern:
          metadata:
            labels:
              team: "?*"
```

## Audit vs Enforce
### Audit
Despite not matching, Audit will allow the resource to pass through. It will log a violation that can be seen in PolicyReport instead
### Enforce
When not matched, Enforce will block the resouce and returns an error to the user. It does not require a PolicyReport

> ⚙️ **Recommended Rollout For Existing Clusters**:
>
> 1. Deploy policy in Audit mode
> 2. Check PolicyReports for violations
> 3. Fix violating resources
> 4. Switch to Enforce once violations = 0

> 💡 **Why?**   
>
> Auditing first allows for a greater visibility of all resources currently running in the cluster.  
> Immediate enforcement could break things or block things with no warning.  
> Audting also helps identify if the policy is too strict or have any unintended side-effects which might conflict with the existing pods.

## PolicyReports
Reports automatically generated by Kyverno 
Viewing Reports:
```
# See all reports
kubectl get policyreport -A

# Detailed view of a specific report
kubectl describe policyreport -n default
```
Report Entry Example:
```
Results:
  Message:  Every pod must have a 'team' label
  Policy:   require-team-label
  Resource:
    Kind:       Pod
    Name:       bad-pod
    Namespace:  default
  Result:     fail
  Rule:       check-team-label
  Scored:     true
  Severity:   medium
```

## JMESPath Engine
Kyverno uses JMESPath to navigate and evaluate resource fields in conditions and deny rules
```
# Access a field
"{{ request.object.metadata.name }}"

# Check array contents
"{{ request.object.spec.containers[].image }}"

# Use built-in functions
"{{ request.object.metadata.name | length(@) }}"
```
> 🔧 **Properties:**
> 
> **request.object:** Resouce being created/updated  
> **request.userInfo:** Who is making the request   
> **request.operation:** CREATE, UPDATE, DELETE  

> 📦 **Common Built-in Functions**
> 
> **Length():** Check for size of array.  
> **contains():** Check if a value exists in a string/array.  
> **starts_with():** Check if a prefix is at the beginning of a string.  
> **to_lower():** Forces every character to be lowercase.  
> **not_null():** Checks for values in fields. 