local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local sts = k.apps.v1.statefulSet;
local deployment = k.apps.v1.deployment;

local kt =
  (import 'kube-thanos/kube-thanos-compactor.libsonnet') +
  (import 'kube-thanos/kube-thanos-querier.libsonnet') +
  (import 'kube-thanos/kube-thanos-store.libsonnet') +
  (import 'kube-thanos/kube-thanos-pvc.libsonnet') +
  (import 'kube-thanos/kube-thanos-receive.libsonnet') +
  (import 'kube-thanos/kube-thanos-receive-pvc.libsonnet') +
  (import 'kube-thanos/kube-thanos-sidecar.libsonnet') +
  (import 'kube-thanos/kube-thanos-servicemonitors.libsonnet') +
  {
    thanos+:: {
      // This is just an example image, set what you need
      image:: 'quay.io/thanos/thanos:v0.8.0',
      objectStorageConfig+:: {
        name: 'thanos-objectstorage',
        key: 'thanos.yaml',
      },

      querier+: {
        replicas:: 3,
      },
      store+: {
        replicas:: 1,
        pvc+:: {
          size: '50Gi',
        },
      },
      receive+:{
        replicas:: 3,
        pvc+:: {
          size: '50Gi',
        },
      },
    },
  };

{ ['thanos-compactor-' + name]: kt.thanos.compactor[name] for name in std.objectFields(kt.thanos.compactor) } +
{ ['thanos-querier-' + name]: kt.thanos.querier[name] for name in std.objectFields(kt.thanos.querier) } +
{ ['thanos-receive-' + name]: kt.thanos.receive[name] for name in std.objectFields(kt.thanos.receive) } +
{ ['thanos-store-' + name]: kt.thanos.store[name] for name in std.objectFields(kt.thanos.store) }
