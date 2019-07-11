local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local sts = k.apps.v1.statefulSet;
local deployment = k.apps.v1.deployment;

local kt =
  (import 'kube-thanos/kube-thanos-querier.libsonnet') +
  (import 'kube-thanos/kube-thanos-store.libsonnet') +
  // (import 'kube-thanos/kube-thanos-pvc.libsonnet') + // Uncomment this line to enable PVCs
  // (import 'kube-thanos/kube-thanos-receive.libsonnet') +
  // (import 'kube-thanos/kube-thanos-sidecar.libsonnet') +
  // (import 'kube-thanos/kube-thanos-servicemonitors.libsonnet') +
  {
    thanos+:: {
      variables+:: {
        image: 'improbable/thanos:v0.5.0',
        objectStorageConfig+: {
          name: 'thanos-objectstorage',
          key: 'thanos.yaml',
        },
      },

      querier+: {
        deployment+:
          deployment.mixin.spec.withReplicas(3),
      },
      store+: {
        statefulSet+:
          sts.mixin.spec.withReplicas(5),
      },
    },
  };

{ ['thanos-querier-' + name]: kt.thanos.querier[name] for name in std.objectFields(kt.thanos.querier) } +
{ ['thanos-store-' + name]: kt.thanos.store[name] for name in std.objectFields(kt.thanos.store) }
// { ['thanos-receive-' + name]: kt.thanos.receive[name] for name in std.objectFields(kt.thanos.receive) }
