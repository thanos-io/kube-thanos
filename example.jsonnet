local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

local kt =
  (import 'kube-thanos/kube-thanos-querier.libsonnet') +
  (import 'kube-thanos/kube-thanos-store.libsonnet') +
  (import 'kube-thanos/kube-thanos-pvc.libsonnet') +
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
  };

{ ['thanos-querier-' + name]: kt.thanos.querier[name] for name in std.objectFields(kt.thanos.querier) } +
{ ['thanos-store-' + name]: kt.thanos.store[name] for name in std.objectFields(kt.thanos.store) }
