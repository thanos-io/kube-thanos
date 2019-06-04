local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

(import 'kube-thanos-querier.libsonnet') +
(import 'kube-thanos-store.libsonnet') +
(import 'kube-thanos-pvc.libsonnet') +
{
  _config+:: {
    namespace: 'thanos',

    images+: {
      thanos: 'improbable/thanos:v0.5.0-rc.0',
    },

    thanos+: {
      // MAKE SURE TO CREATE THE SECRET FIRST
      objectStorageConfig+: {
        name: 'thanos-objectstorage',
        key: 'thanos.yaml',
      },
    },

    store+: {
      replicas: 3,
    },
  },
}
