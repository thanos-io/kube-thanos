local receive = import 'kube-thanos/kube-thanos-receive.libsonnet';

receive({
  local tr = self,
  name:: 'thanos-receive',
  namespace:: 'observability',
  version:: 'v0.24.0',
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
})
