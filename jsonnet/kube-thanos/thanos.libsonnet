{
  bucket: (import 'kube-thanos-bucket.libsonnet'),
  compact: (import 'kube-thanos-compact.libsonnet'),
  query: (import 'kube-thanos-query.libsonnet'),
  receive: (import 'kube-thanos-receive.libsonnet'),
  receiveHashrings: (import 'kube-thanos-receive-hashrings.libsonnet'),
  rule: (import 'kube-thanos-rule.libsonnet'),
  sidecar: (import 'kube-thanos-sidecar.libsonnet'),
  store: (import 'kube-thanos-store.libsonnet'),
  storeShards: (import 'kube-thanos-store-shards.libsonnet'),
  queryFrontend: (import 'kube-thanos-query-frontend.libsonnet'),
}
