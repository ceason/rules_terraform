variable namespace {
  description = "The Kubernetes namespace."
}

resource kubectl_generic_object test_admin_clusterrolebinding {
  # language=yaml
  yaml = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: test-admin
roleRef:
  {name: admin, kind: ClusterRole, apiGroup: rbac.authorization.k8s.io}
subjects:
- kind: ServiceAccount
  name: test-admin
  namespace: ${var.namespace}
EOF
}