local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    store+: {
      variables+:: {
        pvc+: {
          class: 'standard',
          size: '50Gi',
        },
      },

      statefulSet+:
        local sts = k.apps.v1.statefulSet;
        local pvc = sts.mixin.spec.volumeClaimTemplatesType;

        {
          spec+: {
            template+: {
              spec+: {
                volumes: [],
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
                  storageClassName: $.thanos.store.variables.pvc.class,
                  resources: {
                    requests: {
                      storage: $.thanos.store.variables.pvc.size,
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
