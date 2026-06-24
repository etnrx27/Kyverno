# Kyverno Further Reading 
This is a document that explores more in-depth on the architecture and concepts of Kyverno.
>⚠️ *Warning: Please view [kyverno-101.md](/docs/knowledge/kyverno-101.md) before reading this document as this document contains more abstract information only for those that are more interested in Kyverno.*

<br>

# Table-of-Contents 
- [Admission Controller](#admission-controller)
- [Kyverno Architecture](#kyverno-architecture-components)
- [Webhooks](#two-webhooks)
- [Controllers](#four-controllers)  
- [Policy Types](#five-policy-types)
- [Additional Configurations](#additional-configurations)

<br>

# [Admission Controller](https://kyverno.io/docs/guides/admission-controllers/#about-admission-controllers)
In k8s, admission controllers are components responsible for either validating or modifying requests as part of the admission process. They are often used to control the outcome when new resources are being created. The flow of the admission controller phases can be seen below:
```

  API Request
       │
       ▼
┌─────────────┐     ┌────────────────┐     ┌────────────────┐     ┌──────────────┐     ┌────────────────┐     ┌──────────────┐
│  API HTTP   │────>│ Authentication │────>│    Mutating    │────>│Object Schema │────>│   Validating   │────>│  Persisted   │
│   Handler   │     │  & Authoriz.   │     │   Admission    │     │  Validation  │     │   Admission    │     │   to etcd    │
└─────────────┘     └────────────────┘     └────┬──────┬────┘     └──────────────┘     └────┬───┬───┬───┘     └──────────────┘
                                                │ ▲    │ ▲                                  │ ▲ │ ▲ │ ▲
                                                ▼ │    ▼ │                                  ▼ │ ▼ │ ▼ │
                                             ┌──┴─┴────┴─┴──┐                            ┌──┴─┴─┴─┴─┴─┴─┐
                                             │   Webhook    │                            │   Webhook    │─┐
                                             └──────────────┘                            │   Webhook    │ │─┐
                                             ┌──────────────┐                            │   Webhook    │ │ │
                                             │   Webhook    │                            └─┬────────────┘ │ │
                                             └──────────────┘                              └─┬────────────┘ │
                                                                                             └──────────────┘
```
> 💡**Phase Explanations:**
>
> **API HTTP Handler:** Filters and accepts the incoming API request.  
> **Authentication & Authorization:** Verifies who is making the request and whether they have the permission to do so.  
> **Mutating Admission:** Intercepts requests to modify resources before they are stored (e.g., injecting sidecar containers, adding default values). This queries registered Mutating Webhooks.  
> **Object Schema Validation:** Ensures the submitted resource matches the official Kubernetes schema formatting.  
> **Validating Admission:** Evaluates the final resource spec to allow or deny the request (e.g., enforcing security policies like Kyverno or OPA Gatekeeper). This queries registered Validating Webhooks.  
> **Persisted to etcd:** If all phases pass successfully, the resource configuration is written to Kubernetes' highly-available key-value store.

There are two types of admission controller: Kubernetes built-in admission controllers and Dynamic Admission Controllers (Kyverno)  
> 🧱 **Built-in Admission Controller:**  
> Highly specific, purpose-built controllers that only does one task and cannot be modified  
> Example: ResourceQuota -> examine new Deployments to ensure that the resources being requested does not exceed a threshold established

> 🔌 **Dynamic Admission Controller:**    
> More flexible, and can be used to implement custom decisions  
> Example: Kyverno -> examine new Deployments to ensure that the resources does not exceed a threshold and has high availability at the same time.

<br>

# [Kyverno Architecture Components](https://kyverno.io/docs/introduction/how-kyverno-works/)
The table below lists the core components of the Kyverno policy engine and their respective responsibilities:

| Component | Responsibility |
| :--- | :--- |
| **Webhook** | The server that receives incoming AdmissionReview requests from the Kubernetes API server and hands them to the Engine |
| **Engine** | Evaluates the request against installed policies and decides allow/deny/mutate |
| **Webhook Controller** | Watches installed policies and dynamically updates the webhook so only relevant resources are sent to Kyverno (e.g. only Pods, if that's all you have policies for) |
| **Cert Renewer** | Manages and renews the TLS certificates the webhook needs to talk securely to the API server |
| **Background Controller** | Handles `generate` and mutate-existing policies on resources that already exist in the cluster, not just new ones |
| **Report Controllers** | Build and reconcile Policy Reports so you can see what Kyverno has been doing |

<br>

# Two Webhooks
A webhook is a method in which a system can automatically notify another system the instant something happens. In this case, the momment someone runs "kubectl apply", the Kubernetes API will immediately call out to Kyverno's webhook and waits until Kyverno responds. It is an instruction for the Kubernetes API server. 
Kyverno has two kinds of webhooks that it uses: 
## MutatingAdmissionWebhook
[Modify](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#mutating-admission-webhook) the resource to as what it is wanted (Inject defaults etc).  
Runs first and is what supports the MutatingPolicy.
## ValidatingAdmissionWebhook
[Validates](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#validating-admission-webhook) rules as specified to determine if the resource is allowed or deny.   
Runs second and is what supports the ValidatingPolicy.

<br>

# [Four Controllers](https://kyverno.io/docs/introduction/how-kyverno-works/#:~:text=The-,Webhook,-is%20the%20server)
The controller listens for requests sent by the API server and uses a policy to determine a decision for the resources it receive. Controllers receiving requests from the Kubernetes API server do so over HTTP/REST. They work together with webhooks to bring about custom decisions. A policy is an instruction for the controller.   
There are four main pods that is running for Kyverno.  
```
                         ┌──────────────────────────┐
   Pod created  ───────▶| ADMISSION CONTROLLER      │ ───────▶  Allow / Deny
  (webhook fires)        |  runs validate/mutate    │           (instant)
                         └──────────────────────────┘
                                       │
                                       │ raw result
                                       ▼
                         ┌──────────────────────────┐
                         │    REPORTS CONTROLLER    │ ───────▶  kubectl get
                         │  builds PolicyReport CRDs│           policyreport
                         └──────────────────────────┘
                                       ▲
                                       │ findings
                                       │
  New ClusterPolicy ───▶ ┌──────────────────────────┐
  applied                 │  BACKGROUND CONTROLLER   │
                          │  scans existing resources│
                          └──────────────────────────┘

  CleanupPolicy ───▶ ┌─────────────────┐ ───▶ ┌──────────────────┐ ───▶ Resource
  defined             │ CLEANUP         │      │ deletes matching │      deleted
                      │ CONTROLLER      │      │ resources        │
                      │ watches for     │      └──────────────────┘
                      │ matches         │
                      └─────────────────┘
```
## Admission Controller
The controller that handles real-time requests; running validation and mutation rules to allow or deny pods.
```
Pod created → webhook fires → admission controller → runs validate/mutate rules → allow or deny instantly
```
## Background Controller
The controller that handles resources that already exist in the cluster.
```
New ClusterPolicy applied → background controller wakes up → scans all existing resources → generates PolicyReports
```
>⚠️*Warning:*  
>
> Won't block or modify existing resources, only reports on them.   
## Reports Controller 
The controller that handles PolicyReport and ClusterPolicyReport objects. 
```
Admission Controller → raw result → Reports Controller → builds/updates PolicyReport CRDs → visible via kubectl
```
## Cleanup Controller 
The controller that handles the deletion of resources based on certain conditions set.  
```
CleanupPolicy defined → cleanup controller watches for matches → deletes resources when conditions are met
```

<br>

# [Five Policy Types](https://kyverno.io/docs/policy-types/overview/)
As mentioned in [kyverno-101](kyverno-101.md#five-main-policy-types), there are five policy types available in Kyverno.  
This document will explore further in detail for the five policy types, especially **Generating Policy**, **Deleting Policy**, and **Image Validation Policy**. 
## Mutating Policy 
**Evaluation:** Defines how the policy is applied and how the payload is processed.
```
spec:
  evaluation:
    admission: # admission requests(CREATE, UPDATE operations)
      enabled: true
    mutateExisting: # Applied to existing resources in the cluster through background
      enabled: false
  # ...
```
**Webhook Configuration:** Defines properties to manag ethe Kyverno admission controller webhook settings
```
spec:
  webhookConfiguration:
    timeoutSeconds: 15 # Defines how long the admission request waits for policy evaluation. 
  # ...
```
**Autogen:** Defines policy auto-generation behaviours to automatically generate policies for pod controllers 
```
spec:
  autogen: 
    mutatingAdmissionPolicy: # Leverage From Native K8s  
      enabled: true
    podControllers:
      controllers: # Default 4 controllers
        - deployments
        - jobs
        - cronjobs
        - statefulsets
# mutatingAdmissionPolicy will translate CEL rules to native for Kubernetes
# mutatingAdmissionPolicy provides the benefits of faster and more resillient execution
# Only need to write the rule once as it will apply to all resources specified
```
## Validating Policy
**Evaluation:** Defines how the policy is applied and how the payload is processed.
```
spec:
  evaluation:
    admission: # actively enforced (intercept resoures when created and updated)
      enabled: false
    background: # background (resources already running in the cluster)
      enabled: true
    mode: Kubernetes # Set to JSON for non-kubernetes payload
  # ...
```
**Webhook Configuration:** Defines properties to manag ethe Kyverno admission controller webhook settings.
```
spec:
  webhookConfiguration:
    timeoutSeconds: 15 # Defines how long the admission request waits for policy evaluation
  # ...
```
**Autogen:** Defines policy auto-generation behaviours to automatically generate policies for pod controllers. 
```
spec:
  autogen: 
    validatingAdmissionPolicy: # Leverage From Native K8s  
      enabled: true
    podControllers:
      controllers: # Default 4 controllers
        - deployments
        - jobs
        - cronjobs
        - statefulsets
# ValidatingAdmissionPolicy will translate CEL rules to native for Kubernetes
# ValidatingAdmissionPolicy provides the benefits of faster and more resillient execution
# Only need to write the rule once as it will apply to all resources specified
```
## [Image Validation Policy](https://kyverno.io/docs/policy-types/image-validating-policy/)
Cryptographically verifies resource footprints and metadata before allowing them to run.  
Ensures integrity of the resources by checking if they are signed.  
A failure to verify will reject the resource or flag it in audits.
### Use Cases:
**Signature Verification:** Checks if an resource has been signed by a trusted Authority for enhanced security.  
**Registry Enforcement:** Ensures that container images are only pulled from approved, secure registries rather than public, untrusted sources.  
**Integrity Chceking:** Checks if the resource has been tampered with or modified.
### General Approach 
#### 1. Decide On Policy Scope
This defines the range the policy covers.
```
kind: ImageValidatingPolicy # Cluster-scoped, where the policies applies to matching resources across all namespaces. OR
kind: NamespacedImageValidatingPolicy # Namespaced-scope, where the policies applies to matching resources within a specific namespace.
```
#### 2. Identify which Images to Check
This defines the CEL expressions to extract image references.
```
images: # Typically used for Custom Resources or JSON payload 
- name: imagerefs
      expression: '[object.imageReference]'
  # ...
```
Narrow down further the images the policy apply to.
```
matchImageReferences: # At least one sub-field is required
    - glob: 'ghcr.io/kyverno/*' # Match images using glob pattern
    - expression: "image.registry == 'ghcr.io'" # Match using CEL expression
  # ...
```
#### 3. Define what is Trusted (Attestors)
This declares the signing authorities (keys, certs etc) used to verify image signatures.   
```
attestors:
    - name: cosign # A unique name to identify this attestor
      cosign:
        key: # Public key-based verification and At least one sub-field is required
          expression: variables.cm.data.pubKey # CEL expression that resolves to the public key
          kms: 'gcpkms://...' # KMS URI for key verification (e.g., GCP KMS, AWS KMS)
          hashAlgorithm: 'sha256' # Optional hash algorithm used with the key
          data:
            | # Direct inline public key data (optional if secretRef or kms is used)
            -----BEGIN PUBLIC KEY-----
            ...
            -----END PUBLIC KEY-----
      certificate: # Certificate-based verification and At least one sub-field is required
          cert:
            value: | # Inline signing certificate
              -----BEGIN CERTIFICATE-----
              ...
              -----END CERTIFICATE-----
            expression: variables.cm.data.cert # CEL expression resolving to certificate
          certChain: # At least one sub-field is required
            value: | # Certificate chain associated with the signer o
              -----BEGIN CERTIFICATE-----
              ...
              -----END CERTIFICATE-----
            expression: variables.cm.data.certChain # CEL expression resolving to certificate
```
> **Attestors:**
>
> There are multiple attestors. More can be found [here.](https://kyverno.io/docs/policy-types/image-validating-policy/#attestors)
#### 4. Define what Evidence is Required (Attestations) [Optional]
This specifies additional metadata that must accompany the image.
```
attestations:
    - name: sbom # Logical name for this attestation
      referrer: # Uses OCI artifact type for verification
        type: sbom/cyclone-dx
```
#### 5. Define the Validation Logic 
This defines the CEL expressions that Kyverno evaluates against the matched images, attestors, and attestations.
```
validations:
  - expression: >-
    images.containers.map(image, verifyImageSignatures(image, [attestors.cosign])).all(e, e > 0)
    message: 
      'Failed image signature verification'
```
#### 6. Define Validation Configurations [Optional]
This defines settings for enforcing image validation requirements across policies.
```
validationConfigurations:
    mutateDigest: true # Mutates image tags to digests (recommended to avoid mutable tags).
    required: true # Enforces that images must be validated according to policies.
    verifyDigest: true # Ensures that images are verified with a digest instead of tags.
```
#### 7. Define Credentials [Optional]
This specify the authentication information required to securely access and interact for images in a private/autehnticated registry.
```
  credentials:
    allowInsecureRegistry: false # Deny insecure access to registries
    providers: # specifies whose authentication providers are provided
      - 'default'
      - 'google'
      - 'azure'
      - 'amazon'
      - 'github'
```
## [Generating Policy](https://kyverno.io/docs/policy-types/generating-policy/)
Automatically creates or clones new resources in response to another resource being created.
Expands on the original requests.
### Use Cases:
**Multi-Tenancy Automation:** Automatically provide a default set of resources such as "Role Bindings" when a new Namespace is created.  
**Credential-Syncing:** Clones a TLS certificate from a secure admin namespace into the new Namespace.
### General Approach 
#### 1. Decide On Policy Scope
This defines the range the policy covers.
```
kind: GeneratingPolicy # Cluster-scoped, where the policies applies to matching resources across all namespaces. OR
kind: NamespacedGeneratingPolicy # Namespaced-scope, where the policies applies to matching resources within a specific namespace.
```
#### 2. Define Match Constraints 
This defines the resources whose creation will trigger generation. 
```
matchConstraints:
    resourceRules:
      - apiGroups: ['']
        apiVersions: ['v1']
        operations: ['CREATE']
        resources: ['pods']
```
Optionally, could be narrow down further with CEL-based conditions.
```
matchConditions:
  name: 'only-prod'
  expression: "object.metadata.labels['env'] == 'prod'"
```
#### 3. Choose a Generation Mode
This defines where the content of the generated resource comes from.
```
# Data Source - Define resource directly with CEL
variables:
    - name: nsName
      expression: 'object.metadata.name'
    - name: downstream
      expression: >-
        [
          {
            "kind": dyn("ConfigMap"),
            "apiVersion": dyn("v1"),
            "metadata": dyn({
              "name": "zk-kafka-address",
              "namespace": string(variables.nsName),
            }),
            "data": dyn({
              "KAFKA_ADDRESS": "192.168.10.13:9092,192.168.10.14:9092,192.168.10.15:9092",
              "ZK_ADDRESS": "192.168.10.10:2181,192.168.10.11:2181,192.168.10.12:2181"
            })
          }
        ]
```
**<i>OR</i>**
```
# Clone Source - Copies an Existing Resource
variables:
    - name: nsName
      expression: 'object.metadata.name'
    - name: sources
      expression: resource.List("v1", "secrets", "default") # Fetch a list of resource 
      expression: resource.Get("v1", "secrets", "default", "regcred") # Fetch the specific resource
```
#### 4. Define the generation logic
This executes the generation of the generated resources in the targetted namespace.
```
generate:
    - expression: generator.Apply(variables.nsName, [variables.sources]) # OR
    - expression: >
        variables.nsList.all(ns, generator.Apply(ns, variables.downstream)) # Generate multiple resource through looping
```
#### 5. Configuring Synchronisation [Optional]
This determines whether downstream resources stay in sync with the policy/source, or are independent after creation.
```
synchronize:
enabled: true # Downstream is kept in sync with policy/source changes. OR
enabled: false # Downstream is created once and left alone (Default)
```
## [Deleting Policy](https://kyverno.io/docs/policy-types/deleting-policy/)
Cleans up resources on a schedule or condition.  
Operates entirely in the background on a cron-like schedule.
### Use Cases:
**Resource TTL Management:** Automatically cleans up test environments after a specified TTL duration has passed.  
**Stale Resources Removal:** Scans for and removes unutilised resources that no longer have a purpose within the cluster.
### General Approach 
#### 1. Decide On Policy Scope
This defines the range the policy covers.
```
kind: DeletingPolicy # Cluster-scoped, where the policies applies to matching resources across all namespaces. OR
kind: NamespacedDeletingPolicy # Namespaced-scope, where the policies applies to matching resources within a specific namespace.
```
#### 2. Define the Schedule
This defines when Kyverno evaluates existing cluster resources for deletion.
```
schedule: '0 0 * * *' #everyday at midnight -> Follow Cron format and minimum is 1 minute
```
#### 3. Define Match Constraints
This defines the exact resources to be targeted for evaluation.
```
matchConstraints:
    resourceRules:
      - apiGroups: ['']
        apiVersions: ['v1']
        operations: ['*']
        resources: ['pods']
        scope: 'Namespaced' # Can be further narrowed down using namespaceSelector
```
#### 4. Choose A Match Policy 
This defines how strictly the resource rules are matched against API group.
```
matchPolicy: 'Equivalent' # Matches across equivalent group/versions
matchPolicy: 'Exact' # Matches stricly on group/version
```
#### 5. Define Conditions to Delete
This defines the CEL expressions that decide which of the matched resources gets deleted.
```
conditions:
    - name: isOld
      expression: "has(object.metadata.labels.old) && object.metadata.labels.old == 'true'"
```
#### 6. Choose a Deletion Propagation Policy
This defines how dependent resources are handled when the primary resource is deleted. 
```
deletionPropagationPolicy: 'Orphan'     # Dependents are left untouched (not deleted). OR
deletionPropagationPolicy: 'Background' # Primary deleted first; dependents garbage-collected in the background. OR
deletionPropagationPolicy: 'Foreground' # Primary resource persists until all dependents are deleted (cascading).
```
### Tracking Deletion Events
Every time a <i>DeletingPolicy</i> deletes a resource, Kyverno emits a event that can be traced to identify which policy deleted which resource for auditing and troubleshooting. 
```
kubectl get events --field-selector reason=PolicyApplied -A # List Policy-Applied Events
kubectl get events -n <namespace> \
  -o custom-columns=NAME:.metadata.name,REASON:.reason,MESSAGE:.message # Get Event Name and Message
kubectl get event <event-name> -n <namespace> -o yaml # Get full event details
```
### Event Logged Example
```
action: Resource cleaned-up
reason: PolicyApplied
message: human-readable success message
involvedObject: the DeletingPolicy that triggered the action
related: the resource that was deleted
reportingComponent: kyverno-cleanup
```
> **To Note:**
>
> **No Validation Action:** Actively deletes resources that already exists on a schedule. There is no request to Deny any deletion.  
> **RBAC Required:** Cleanup controller needs explicit get/list/watch/delete RBAC for each targeted resource -> [get, list, watch, delete].

<br>

# Additional Configurations
## [Monitoring](https://kyverno.io/docs/guides/monitoring/) + [Tracing](https://kyverno.io/docs/guides/tracing/) Capabilities
Kyverno has monitoring capbilities that gives visibility into policy activitiy through three layers:  
**Metrics:** Covers area such as how many policies are often, how often rules pass/fail, deletion counts etc.  
**Tracing:** Covers deeper request-level debugging.  
**Native:** Covers native Kubernetes Events and Reports. 
```
                         ┌──────────────────────────┐
                         │   Kyverno Controllers    │
                         │ (Admission / Background  │
                         │  / Cleanup / Reports)    │
                         └────────────┬─────────────┘
                                      │
            ┌─────────────────┬───────┴───────┬──────────────────┐
            │                 │               │                  │
            ▼                 ▼               ▼                  ▼
     ┌─────────────┐   ┌─────────────┐  ┌──────────┐    ┌───────────────┐
     │   Metrics   │   │   Tracing   │  │  Events  │    │ Policy Reports│
     │ (port 8000) │   │(OTel→Jaeger)│  │(knative) │    │     (CRDs)    │
     └──────┬──────┘   └──────┬──────┘  └─────┬────┘    └───────┬───────┘
            │                 │               │                 │
            ▼                 ▼               ▼                 ▼
     ┌─────────────┐   ┌─────────────┐  ┌──────────┐    ┌───────────────┐
     │ Prometheus  │   │   Jaeger    │  │ kubectl  │    │  kubectl get  │
     │             │   │     UI      │  │get events│    │  policyreport |
     └──────┬──────┘   └─────────────┘  └──────────┘    └───────────────┘
            │
            ▼
     ┌─────────────┐
     │   Grafana   │
     │ (dashboards │
     │ & alerting) │
     └─────────────┘
```
> **Flow:**
> 
> Metrics -> Prometheus -> Grafana for Trends/Alerting.  
> Tracing -> Open Telemetry -> Jagear for per-request debugging.   
> Events + Policy Report -> kubectl without extra infrastructure. 

## [Availabiity](https://kyverno.io/docs/guides/high-availability/) Capabilities
Multiple replicas can be configured in the helm chart for the controllers for both availability and scaling.

## [Pod Security Standards](https://kyverno.io/docs/guides/pod-security/)
Kyverno Pod Security Standard policies is an optional chart containing the full set of Kyverno policies which implement the Kubernetes Pod Security Standards.  
It provides guidelines and best practices to ensure that pods are deployed securely and follow principle of least priviledged.  
There are three standards, [Priviledged, Baseline, Restricted].
```
helm install kyverno-policies kyverno/kyverno-policies -n kyverno
```
---
 🗓️ *Last Updated: 24/06/2026*  
 ⚠️ *Based on: kyverno v1.18.1.*
