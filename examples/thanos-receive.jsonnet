local t = import 'kube-thanos/kube-thanos-receive.libsonnet';

t.receive {
  local tr = self,
  name:: 'thanos-receive',
  namespace:: 'observability',
  version:: 'v0.17.2',
  image:: 'quay.io/thanos/thanos:v' + tr.version,
  replicas:: 3,
  replicationFactor:: 3,
  objectStorageConfig:: {
    name: 'thanos-objectstorage',
    key: 'thanos.yaml',
  },
  pvcTemplate+:: {
    size: '50G',
  },
}
