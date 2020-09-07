local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local sts = k.apps.v1.statefulSet;
local deployment = k.apps.v1.deployment;
local t = (import 'kube-thanos/kube-thanos-receive.libsonnet');

t.receive {
  local tr = self,
  name:: 'thanos-receive',
  namespace:: 'observability',
  version:: 'v0.15.0',
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
