# Kyverno Further Reading 
This is a document that explores more in-depth on the architecture and concepts of Kyverno.
>⚠️ *Warning: Please view [kyverno-101.md](/docs/knowledge/kyverno-101.md) before reading this document as this document contains more abstract information only for those that are more interested in Kyverno.*

# Kyverno Architecture Components
The table below lists the core components of the Kyverno policy engine and their respective responsibilities:

| Component | Responsibility |
| :--- | :--- |
| **Webhook** | The server that receives incoming AdmissionReview requests from the Kubernetes API server and hands them to the Engine |
| **Engine** | Evaluates the request against installed policies and decides allow/deny/mutate |
| **Webhook Controller** | Watches installed policies and dynamically updates the webhook so only relevant resources are sent to Kyverno (e.g. only Pods, if that's all you have policies for) |
| **Cert Renewer** | Manages and renews the TLS certificates the webhook needs to talk securely to the API server |
| **Background Controller** | Handles `generate` and mutate-existing policies on resources that already exist in the cluster, not just new ones |
| **Report Controllers** | Build and reconcile Policy Reports so you can see what Kyverno has been doing |

# Two Webhooks
A webhook is a method in which a system can automatically notify another system the instant something happens. In this case, the momment someone runs "kubectl apply", the Kubernetes API will immediately call out to Kyverno's webhook and waits until Kyverno responds.  
Kyverno has two kinds of webhooks that it uses: 
## MutatingAdmissionWebhook
[Modify](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#mutating-admission-webhook) the resource to as what it is wanted (Inject defaults etc)  
Runs first and is what supports the MutatingPolicy.
## ValidatingAdmissionWebhook
[Validates](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#validating-admission-webhook) rules as specified to determine if the resource is allowed or deny  
Runs second and is what supports the ValidatingPolicy.

# Four Pods
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
## Background Controller [Optional]
The controller that handles resources that already exist in the cluster.
```
New ClusterPolicy applied → background controller wakes up → scans all existing resources → generates PolicyReports
```
>⚠️*Warning:*  
>
> Won't block or modify existing resources, only reports on them  
## Reports Controller [Optional]
The controller that handles PolicyReport and ClusterPolicyReport objects. 
```
Admission Controller → raw result → Reports Controller → builds/updates PolicyReport CRDs → visible via kubectl
```
## Cleanup Controller [Optional]
The controller that handles the deletion of resources based on certain conditions set.
```
CleanupPolicy defined → cleanup controller watches for matches → deletes resources when conditions are met
```
# Five Policy Types
As mentioned in [kyverno-101](kyverno-101.md), there are five policy types available in Kyverno.  
This document will explore further in detail for the five policy types, especially **Generating Policy**, **Deleting Policy**, and **Image Validation Policy**. 
## Mutating Policy 
## Validating Policy
## Image Validation Policy
Cryptographically verifies resource footprints and metadata before allowing them to run.  
Ensures integrity of the resources by checking if they are signed.  
A failure to verify will reject the resource or flag it in audits
### Use Cases:
**Signature Verification:** Checks if an resource has been signed by a trusted Authority for enhanced security.  
**Registry Enforcement:** Ensures that container images are only pulled from approved, secure registries rather than public, untrusted sources  
**Integrity Chceking:** Checks if the resource has been tampered with or modified
### General Approach 
#### 1.

## Generating Policy 
Automatically creates or clones new resources in response to another resource being created.
Expands on the original requests.
### Use Cases:
**Multi-Tenancy Automation:** Automatically provide a default set of resources such as "Role Bindings" when a new Namespace is created.  
**Credential-Syncing:** Clones a TLS certificate from a secure admin namespace into the new Namespace.
### General Approach 
#### 1.
## Deleting Policy
Cleans up resources on a schedule or condition.  
Operates entirely in the background on a cron-like schedule.
### Use Cases:
**Resource TTL Management:** Automatically cleans up test environments after a specified TTL duration has passed.  
**Stale Resources Removal:** Scans for and removes unutilised resources that no longer have a purpose within the cluster.
### General Approach 
#### 1.

# Monitoring Capabilities
# Tracing Capabilities
# Availabiity Capabilities
# Pod Security Standards   
