{
  bucket: (import 'kube-thanos-bucket.libsonnet'),
  compact: (import 'kube-thanos-compact.libsonnet'),
  query: (import 'kube-thanos-query.libsonnet'),
  receive: (import 'kube-thanos-receive.libsonnet'),
  rule: (import 'kube-thanos-rule.libsonnet'),
  store: (import 'kube-thanos-store.libsonnet'),
  queryFrontend: (import 'kube-thanos-query-frontend.libsonnet'),
}
