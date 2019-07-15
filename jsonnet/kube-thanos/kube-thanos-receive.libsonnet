local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    receive: {
      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          'thanos-receive',
          $.thanos.receive.statefulSet.metadata.labels,
          [
            ports.newNamed('grpc', 10901, 10901),
            ports.newNamed('http', 10902, 10902),
            ports.newNamed('remote-write', 19291, 19291),
          ]
        ) +
        service.mixin.metadata.withNamespace('monitoring') +
        service.mixin.metadata.withLabels({ app: $.thanos.receive.service.metadata.name }) +
        service.mixin.spec.withClusterIp('None'),

      statefulSet:
        local sts = k.apps.v1.statefulSet;
        local volume = sts.mixin.spec.template.spec.volumesType;
        local container = sts.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;
        local containerVolumeMount = container.volumeMountsType;

        local c =
          container.new($.thanos.receive.statefulSet.metadata.name, $.thanos.variables.image) +
          container.withArgs([
            'receive',
            '--grpc-address=0.0.0.0:%d' % $.thanos.receive.service.spec.ports[0].port,
            '--remote-write.address=0.0.0.0:%d' % $.thanos.receive.service.spec.ports[2].port,
            '--objstore.config=$(OBJSTORE_CONFIG)',
            '--tsdb.path=/var/thanos/tsdb',
            '--labels=receive=$(NAME)',
          ]) +
          container.withEnv([
            containerEnv.fromFieldPath('NAME', 'metadata.name'),
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              $.thanos.variables.objectStorageConfig.name,
              $.thanos.variables.objectStorageConfig.key,
            ),
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: $.thanos.receive.service.spec.ports[0].port },
            { name: 'http', containerPort: $.thanos.receive.service.spec.ports[1].port },
            { name: 'remote-write', containerPort: $.thanos.receive.service.spec.ports[2].port },
          ]) +
          container.withVolumeMounts([
            containerVolumeMount.new('data', '/var/thanos/tsdb', false),
          ]);

        sts.new('thanos-receive', 3, c, [], $.thanos.receive.statefulSet.metadata.labels) +
        sts.mixin.metadata.withNamespace('monitoring') +
        sts.mixin.metadata.withLabels({ app: $.thanos.receive.statefulSet.metadata.name }) +
        sts.mixin.spec.withServiceName($.thanos.receive.service.metadata.name) +
        sts.mixin.spec.selector.withMatchLabels($.thanos.receive.statefulSet.metadata.labels) +
        sts.mixin.spec.template.spec.withVolumes([
          volume.fromEmptyDir('data'),
        ]),
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
                    $.thanos.receive.service.metadata.name,
                    $.thanos.receive.service.metadata.namespace,
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
