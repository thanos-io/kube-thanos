local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    store: {
      variables+:: {
        objectStorageConfig+: {
          name: $.thanos.variables.objectStorageConfig.name,
          key: $.thanos.variables.objectStorageConfig.key,
        },
      },

      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          'thanos-store',
          $.thanos.store.statefulSet.metadata.labels,
          [
            ports.newNamed('grpc', 10901, 10901),
            ports.newNamed('http', 10902, 10902),
          ]
        ) +
        service.mixin.metadata.withNamespace('monitoring') +
        service.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.store.service.metadata.name }) +
        service.mixin.spec.withClusterIp('None'),

      statefulSet:
        local sts = k.apps.v1.statefulSet;
        local volume = sts.mixin.spec.template.spec.volumesType;
        local container = sts.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;
        local containerVolumeMount = container.volumeMountsType;

        local c =
          container.new($.thanos.store.statefulSet.metadata.name, $.thanos.variables.image) +
          container.withArgs([
            'store',
            '--data-dir=/var/thanos/store',
            '--grpc-address=0.0.0.0:%d' % $.thanos.store.service.spec.ports[0].port,
            '--http-address=0.0.0.0:%d' % $.thanos.store.service.spec.ports[1].port,
            '--objstore.config=$(OBJSTORE_CONFIG)',
          ]) +
          container.withEnv([
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              $.thanos.store.variables.objectStorageConfig.name,
              $.thanos.store.variables.objectStorageConfig.key,
            ),
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: $.thanos.store.service.spec.ports[0].port },
            { name: 'http', containerPort: $.thanos.store.service.spec.ports[1].port },
          ]) +
          container.mixin.resources.withRequests({ cpu: '500m', memory: '1Gi' }) +
          container.mixin.resources.withLimits({ cpu: '2', memory: '8Gi' }) +
          container.withVolumeMounts([
            containerVolumeMount.new($.thanos.store.statefulSet.metadata.name + '-data', '/var/thanos/store', false),
          ]);

        sts.new('thanos-store', 3, c, [], $.thanos.store.statefulSet.metadata.labels) +
        sts.mixin.metadata.withNamespace('monitoring') +
        sts.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.store.statefulSet.metadata.name }) +
        sts.mixin.spec.withServiceName($.thanos.store.service.metadata.name) +
        sts.mixin.spec.selector.withMatchLabels($.thanos.store.statefulSet.metadata.labels) +
        sts.mixin.spec.template.spec.withVolumes([
          volume.fromEmptyDir($.thanos.store.statefulSet.metadata.name + '-data'),
        ]) +
        {
          spec+: {
            volumeClaimTemplates:: null,
          },
        },
    },

    querier+: {
      deployment+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                super.containers[0]
                { args+: [
                  '--store=dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [
                    $.thanos.store.service.metadata.name,
                    $.thanos.store.service.metadata.namespace,
                  ],
                ] },
              ],
            },
          },
        },
      },
    },
  },
}
