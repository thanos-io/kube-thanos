local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    store+: {
      local spvc = self,
      pvc+:: {
        class: 'standard',
        size: error 'must set PVC size for Thanos store',
      },

      statefulSet+:
        local sts = k.apps.v1.statefulSet;
        local pvc = sts.mixin.spec.volumeClaimTemplatesType;

        {
          spec+: {
            template+: {
              spec+: {
                volumes: null,
              },
            },
            volumeClaimTemplates::: [
              {
                metadata: {
                  name: $.thanos.store.statefulSet.metadata.name + '-data',
                },
                spec: {
                  accessModes: [
                    'ReadWriteOnce',
                  ],
                  storageClassName: spvc.pvc.class,
                  resources: {
                    requests: {
                      storage: spvc.pvc.size,
                    },
                  },
                },
              },
            ],
          },
        },
    },
  },
}
