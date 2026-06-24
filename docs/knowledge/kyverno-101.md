# Kyverno-101 
This is a document that explores the basic fundamentals of Kyverno.

<br>

# Table-of-Contents 
- [Policy-As-Code](#policy-as-code-pac)
- [Kyverno](#kyverno)
- [Capabilities](#capabilities)  
      - [Mutating Policy](#mutating-policy)  
      - [Validating Policy](#validating-policy)  
      - [Policy Exceptions](#policy-exceptions)  
      - [Policy Report](#policy-reports)  
      - [CLI Testing](#cli-for-local-testing)  

<br> 

# Policy-As-Code (PAC) 
## What is A Policy?
A Policy is any type of rule, condition, or instruction that governs IT operations or processes.  
Traditionally, policies have been written as documents and enforcement depends heavily on people, where someone is responsible in remembering the policies and manually checking that these policies are being followed.

## Why is Policy Management Necessary?
Modern cloud native systems such as Kubernetes are built on declarative configuration. This makes them extremely flexible and able to support a huge range of use cases. However, this flexibility comes at a cost. Multiple roles, such as developers, operations, and platform, will read and write to the same configurations, and the surface area for mistakes grows as more people access it. With policy management, policies give the right level of abstraction to separate these concerns, where every team does not need to know every rule as enforcement can happen automatically instead of relying on someone remembering to check. 

## What is PAC?
[PAC](https://www.paloaltonetworks.com/cyberpedia/what-is-policy-as-code) takes the same kind of rules and conditions but is expressed in code (Python, YAML, or REGO) instead of words written in documents. Once defined, a PAC enforcement engine checks every relevant action against the policies defined in the code automatically. 

PAC covers a wide range of operational concerns including Security and Compliance. It also allows for greater flexibility, as custom policy checks can be written to answer the specific needs of an organisation. Because the policy is code, it can also be version-controlled and be treated just like any other part of the codebase. 

Analagy:
The difference between PAC and traditional Policy enforcement is similar to how asking someone to poofread one's essay for grammatical or spelling mistakes versus having grammarly enabled to immediately catch mistakes and to fix it. 

<br>

# Kyverno
## What is Kyverno?
[Kyverno](https://kyverno.io/docs/introduction/) is a cloud native policy engine that is built as an extension of K8s' native Admission Webhook system. It is a dynamic admission controller, suggesting that it could be used to implement custom decisions. Through PAC, it allows platform engineers to automate security, compliance, and best practices validation.   
Kyverno watches every request in the cluster. It can automatically fix small issues such as missing fields, and will check the request against the rules specified, and decide to block it if it violates any of the rules. 
A diagram illustrating this can be seen below:  
```
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
> 🛡️ **Architecture Note: Policy Enforcement with Kyverno**
> 
> 1. **Submission:** The developer or CI pipeline pushes a manifest via `kubectl`.
> 2. **Intercept:** The Kubernetes API server catches the request and passes it to Kyverno using a *[Webhook](kyverno-further-reading.md#two-webhooks)*.
> 3. **Validation:** Kyverno checks if the incoming configuration violates any structural or security rules (e.g., checking if the pod runs as root).
> 4. **Verdict:** If approved, the resource is created in the cluster; otherwise, the request is instantly blocked.

## Why Should We Use It?
| Improvement | Explanation |
| :--- | :--- |
| **Efficiency** | Currently, manual enforcement is done to ensure that pods follow conventions. This leads to wastage of time and is also subjected to human errors. With Kyverno, checks will be automated and validated automatically. |
| **Convenience** | Uses YAML language and Common Expression Language (CEL), thus there is no new language that is required to learn. |
| **Portable** | Works the same across any Kubernetes distribution and is not tied to a specific distribution. |
| **Simplicity** | No need to manage underlying infrastructure (ie. certificates, registration and server uptime) as Kyverno handles it. Instead, time can be focused on solely configuring policies. |
| **Visibility** | Kyverno provides information on what is happening in the cluster by reporting on what resources was checked, what passed, what failed throughout the cluster. |
| **Compliance** | Kyverno allows for mandating a reasonable, uniform, and unavoidable security baseline across to increase security. |

<br>

# Capabilities
## Five Main Policy Types 
Once a request reaches Kyverno, it can be handled by five different kinds of policy. All of these policies can be either scoped to resources accross all namespaces or to resources within the same namespace. An image of the Kyverno policy evaluation flow can be seen below:  
```
                ┌──────────────────────────┐    
                │      New resource        │                # A request *does not need* to always pass through these five policies.  
                │  e.g. a Pod, Namespace   │                # They are five independent capabilities that fire under different conditions.  
                └────────────┬─────────────┘                # A given resource could trigger, *one, several or none.*
                             │
                             ▼
   ┌──────────────────── Kyverno engine ─────────────────────┐
   │                                                         │
   │   ┌──────────────────────────────────────────────────┐  │
   │   │ MutatingPolicy                                   │  │
   │   │ Modify the resource before it's checked          │  │
   │   │ (ie. auto-fixing a form before it's filed)       │  │
   │   └──────────────────────────────────────────────────┘  │
   │                         │                               │
   │                         ▼                               │
   │   ┌──────────────────────────────────────────────────┐  │
   │   │ ValidatingPolicy                                 │  │
   │   │ Allow or deny the (possibly mutated) resource    │  │
   │   │ (ie. checking if all fields are filled)          │  │
   │   └──────────────────────────────────────────────────┘  │
   │                         │                               │
   │                         ▼                               │
   │   ┌──────────────────────────────────────────────────┐  │
   │   │ ImageValidatingPolicy                            │  │
   │   │ Check container image signatures                 │  │
   │   │ (ie. checking if the form has been tampered)     │  │
   │   └──────────────────────────────────────────────────┘  │
   │                         │                               │
   │                         ▼                               │
   │   ┌──────────────────────────────────────────────────┐  │
   │   │ GeneratingPolicy                                 │  │
   │   │ Create or clone other resources                  │  │
   │   │ (ie. submitting of form triggers another form)   │  │
   │   └──────────────────────────────────────────────────┘  │
   │                         │                               │
   │                         ▼                               │
   │   ┌──────────────────────────────────────────────────┐  │
   │   │ DeletingPolicy                                   │  │
   │   │ Clean up resources on a schedule                 │  │
   │   │ (ie. expired forms are deleted automatically)    │  │
   │   └──────────────────────────────────────────────────┘  │
   │                                                         │
   └─────────────────────────────────────────────────────────┘
```

### Mutating Policy 
Automatically modifies a resource before it is checked.  
Does not have the ability to reject resources and can only change what the resource is before validation.
#### Use Cases:
**Consistency:** Auto-labels resources with metadata that might be forgotten to ensure every resource stays uniformly tagged.  
**Auto-remediation:** Silently fixes a resource that would otherwise fail a validation rule so that the pod becomes compliant without further action required from developer.
#### General Approach
#### 1. Decide On Policy Scope
This defines the range the policy covers.
```
kind: MutatingPolicy # Cluster-scoped, where the policies applies to matching resources across all namespaces.
kind: NamespacedMutatingPolicy # Namespaced-scope, where the policies applies to matching resources within a specific namespace.
```
#### 2. Define Match Constraints
This defines the exact resources to be targeted for mutation. 
```
matchConstraints:
  resourceRules: # Specifies the resources that are being targetted
      - apiGroups: ['apps']
        apiVersions: ['v1']
        operations: [CREATE, UPDATE] # List of Actions that trigger the policy
        resources: ['deployments'] # Kubernetes resource that can be viewed from "kubectl api-resources"
```
>⚠️ **Notice:**
>
> For core resources such as pods, namespaces, services and configmaps, the API group is blank.  
> An empty string must be passed -> apiGroups: [""].

> ⚙️ **[Different Operations](https://kyverno.io/docs/guides/admission-controllers/#:~:text=parlance.%20There%20are-,four%20operations,-which%20the%20API)**:
> 
> **Create:** Triggers when a new resource is made.  
> **Update:** Triggers when an existing resource is being modified.  
> **Delete:** Triggers when a "kubectl delete" command is used to remove a resource.  
> **Connect:** Triggers when a "kubectl exec" command is used against a pod.

#### 3. Choose A Patch Type
This defines what kind of patches to use for mutation. 
```
mutations: - patchType: ApplyConfiguration # Merge-style approach and less error prone than JSONPatch OR
mutations: - patchType: JSONPatch # Fine-grained control over mutations and more useful when requiring more precise control
```

#### 4. Define Mutation Expression with CEL 
This defines the mutation expressions that Kyverno will be implementing.
```
applyConfiguration:
      expression: |
          has(object.metadata.labels) && has(object.metadata.labels.environment) ? # True
          Object{ 
            metadata: Object.metadata{
              labels: {"managed": "true"}
            }
          } : # False
          Object{
            metadata: Object.metadata{
              labels: {"environment": "dev", "managed": "true"}
            }
          }
```
**<i>OR</i>**
```
jsonPatch:
        expression: |
          has(object.metadata.labels) ? # True
          [
              JSONPatch{
                  op: "add",
                  path: "/metadata/labels/managed",
                  value: "true"
              }
          ] : # False
          [
              JSONPatch{
                  op: "add",
                  path: "/metadata/labels",
                  value: {"managed": "true"}
              }
          ]
```

### Validating Policy 
Inspects a resource and allows or denies it based on a CEL expression.  
Only Produces a true/false boolean.  
A False result will lead to either immediate rejection or recording of logs. 

#### Use Cases:
**Least Priviledge Enforcement:** Denying containers to run as root or denying previlege escalation.   
**Governance and Compliance:** Enforces naming conventions and ensures crucial labels are not missed out.    
**Operational Safety:** Ensuring resource requests/limits are configured on every container to prevent resource hogging.   
**Logical Segmentation:** Prevents pods from mouting Secrets that belong to another namespace.   
**Security Hardening:** Limiting the ports open on the pods. 

#### General Approach
#### 1. Decide On Policy Scope
This defines the range the policy covers.
```
kind: ValidatingPolicy # Cluster-scoped, where the policies applies to matching resources across all namespaces. OR
kind: NamespacedValidatingPolicy # Namespaced-scope, where the policies applies to matching resources within a specific namespace.
```
#### 2. Choose A Validation Action
This defines what the policy does when a resource fails the policy.
```
validationActions: - Deny # Rejects the API request immediately. OR
validationActions: - Audit # Allows the resource to be created but logs the violations in a PolicyReport.
```
#### 3. Define Match Constraints
This defines the exact resources to be targeted for checks. 
```
matchConstraints:
  resourceRules: # Specifies the resources that are being targetted
      - apiGroups: ['apps']
        apiVersions: ['v1']
        operations: [CREATE, UPDATE] # List of Actions that trigger the policy
        resources: ['deployments'] # Kubernetes resource that can be viewed from "kubectl api-resources"
```
#### 4. Define Validation Rule with CEL 
This defines the validation expressions that Kyverno will be evaluating.
```
validations:
    - message: 'Deployment is missing required label' # Message to display to user if failed. OR
    - messageExpression: '"Deployment " + object.metadata.name + " is missing required label 'environment'"' 
    # A more flexible form of message where variables such as resource name can be injected dynamically.
      expression: 'environment' in object.metadata.labels' # CEL logic that is being evaluated
```
### Image Validating Policy
Ensures integrity of the images by checking if they are signed. 
#### Use Cases:
**Signature Verification:** Checks if an resource has been signed by a trusted Authority for enhanced security.  
**Registry Enforcement:** Ensures that container images are only pulled from approved, secure registries rather than public, untrusted sources.  
**Integrity Chceking:** Checks if the resource has been tampered with or modified.
### Generating Policy 
Automatically creates or clones new resources in response to another resource being created.
#### Use Cases:
**Multi-Tenancy Automation:** Automatically provide a default set of resources such as "Role Bindings" when a new Namespace is created.  
**Credential-Syncing:** Clones a TLS certificate from a secure admin namespace into the new Namespace.
### Deleting Policy
Cleans up resources on a schedule or condition.
#### Use Cases:
**Resource TTL Management:** Automatically cleans up test environments after a specified TTL duration has passed.  
**Stale Resources Removal:** Scans for and removes unutilised resources that no longer have a purpose within the cluster.
>⚠️ **Notice:**
>
> For our specific context, we will be more interested on **validating** and **mutating**.  
> More information on the others could be found under [further reading.](kyverno-further-reading.md#five-policy-types)

## Policy Exceptions
A [Policy Exception](https://kyverno.io/docs/guides/exceptions/) is a Namespaced Custom Resource that allows a resource to be allowed past a given policy and rule combination. There may be times where a team must allow certain exceptions which would normally violate the configured rules. Instead of making adjustments to the policy each time, an exception could be implemented instead. 

### General Approach
#### 1. Identify Policy to Exclude from
```
policyRefs:
- name: require-prod-label # Name of the Policy
  kind: ValidatingPolicy # Kind of the Policy
```
#### 2. Identify CEL to Execute
```
matchConditions:
- name: skip-by-name # General Name
  expression: "object.metadata.name == 'skipped-deployment'" # Name of Deployment to be Excluded
```

>⚠️ **Notice:**
>
> Policy Exceptions are disabled by default.
> To enable, one must set the flag, <span style="color: yellow;"><i>enablePolicyException</i></span>, to true and  
> specify the namespaces where policy exceptions are permitted via the <span style="color: yellow;"><i>exceptionNamespace</i></span> flag.

## Policy Reports
Policy Reports are K8s Custom Resources that are generated and managed automatically by Kyverno. It contains the results of applying matching Kubernetes resources to policies configured.

> ⚙️ **Features of Policy Reports**:
>
> Resources violating multiple rules will result in mulitple entries.  
> Reports always represent the current state of the cluster and do not record historical information.  
> Standard Kubernetes RBAC can be applied to seperate roles that create policies and those who can view reports.  
> There are two ways a policy report is generated. One is through an admission event (CREATE, UPDATE, DELETE) and the other is the result of a background scan on existing resources. 

### Viewing Reports in K8s
```
# See all reports
kubectl get policyreport -A

# Detailed view of a specific report
kubectl describe policyreport -n default
```
### Report Entry Example
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
## CLI for Local Testing
Kyverno provides a [CLI](https://kyverno.io/docs/kyverno-cli/reference/kyverno/) to work with Kyverno resources. It can be used to validate and test policy behaviour to resources prior to applying them to a cluster. This should be used to ensure that the implementation of new policies does not have any unintended side effects on the cluster. 

### Testing Configured Policies
<span style="color: yellow;"><i>kyverno apply</i></span> is used to test resources against policies. It checks whether specific resources would pass or fail with the configured policies without having the need to touch the real cluster. 
```
kyverno apply /path/to/policy.yaml /path/to/folderOfPolicies --resource=/path/to/resource1 --resource=/path/to/resource2 # Applying on resources
kyverno apply /path/to/policy.yaml /path/to/folderOfPolicies --resource=/path/to/resources/ # Applying on a folder of resource 
kyverno apply /path/to/policy.yaml /path/to/folderOfPolicies --cluster # Applying on a cluster
```
<span style="color: yellow;"><i>kyverno test</i></span> is used to ensure a set of policies and resources always produced a predefined set of outcomes.
```
Example File Directory:
tests/
└── require_labels/
    ├── kyverno-test.yaml   # declares expected pass/fail per resource
    ├── require_labels.yaml # the policy
    └── resource.yaml       # the resource(s) to test

kyverno test tests/ # Determines if the actual results matches the expected ones declared
```
>💡 **To Note:**
>
> Tests for Kyverno Policies may be executed via a workflow through [GitHub Action](https://kyverno.io/docs/guides/testing-policies/#:~:text=in%20a%20cluster.-,GitHub%20Actions,-Section%20titled%20%E2%80%9CGitHub).  
> Tests can be executed on the pull request by applying policies against the resources in the pull request and if one or more fails, the pipeline will be halted. 
#
# What's Next?
This document covers the core fundamentals of Kyverno. Do access the other links to find out more about other areas:
- [Installation](../installation/kyverno-installation.md)
- [Mutation Examples](../example/kyverno-mutate-policy/mutate-label-apply.yaml)
- [Validation Examples](../example/kyverno-validate-policy/validate-label-deny.yaml)
- [Further Reading on Kyverno](kyverno-further-reading.md)

---
 🗓️ *Last Updated: 24/06/2026*  
 ⚠️ *Based on: kyverno v1.18.1.*


