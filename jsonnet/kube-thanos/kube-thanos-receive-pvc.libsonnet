local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    receive+: {
      local tr = self,
      pvc+:: {
        class: 'standard',
        size: error 'must set PVC size for Thanos receive',
      },

      statefulSet+:
        local sts = k.apps.v1.statefulSet;
        local pvc = sts.mixin.spec.volumeClaimTemplatesType;

        {
          spec+: {
            template+: {
              spec+: {
                volumes:: null,
              },
            },
            volumeClaimTemplates::: [
              {
                metadata: {
                  name: $.thanos.receive.statefulSet.metadata.name + '-data',
                },
                spec: {
                  accessModes: [
                    'ReadWriteOnce',
                  ],
                  storageClassName: tr.pvc.class,
                  resources: {
                    requests: {
                      storage: tr.pvc.size,
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
