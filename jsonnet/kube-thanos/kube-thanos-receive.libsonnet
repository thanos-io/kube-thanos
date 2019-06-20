local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    receive+: {
      name: 'thanos-receive',
      labels: { app: $._config.receive.name },
      ports: {
        grpc: 10901,
        remoteWrite: 19291,
      },
    },
  },

  thanos+:: {
    receive: {
      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          $._config.receive.name,
          $._config.receive.labels,
          [
            ports.newNamed('grpc', $._config.receive.ports.grpc, $._config.receive.ports.grpc),
            ports.newNamed('remote-write', $._config.receive.ports.remoteWrite, $._config.receive.ports.remoteWrite),
          ]
        ) +
        service.mixin.metadata.withNamespace($._config.namespace) +
        service.mixin.metadata.withLabels($._config.receive.labels) +
        service.mixin.spec.withClusterIp('None'),

      statefulSet:
        local sts = k.apps.v1.statefulSet;
        local volume = sts.mixin.spec.template.spec.volumesType;
        local container = sts.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;
        local containerVolumeMount = container.volumeMountsType;

        local c =
          container.new($._config.store.name, $._config.images.thanos) +
          container.withArgs([
            'receive',
            '--remote-write.address=0.0.0.0:%d' % $._config.receive.ports.remoteWrite,
            '--grpc-address=0.0.0.0:%d' % $._config.receive.ports.grpc,
            '--objstore.config=$(OBJSTORE_CONFIG)',
          ]) +
          container.withEnv([
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              $._config.thanos.objectStorageConfig.name,
              $._config.thanos.objectStorageConfig.key,
            ),
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: $._config.receive.ports.grpc },
            { name: 'remote-write', containerPort: $._config.receive.ports.remoteWrite },
          ]);

        sts.new($._config.receive.name, 3, c, [], $._config.receive.labels) +
        sts.mixin.metadata.withNamespace($._config.namespace) +
        sts.mixin.metadata.withLabels($._config.receive.labels) +
        sts.mixin.spec.withServiceName($.thanos.receive.service.metadata.name) +
        sts.mixin.spec.selector.withMatchLabels($._config.receive.labels),
    },

    querier+: {
      deployment+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                super.containers[0] +
                { args+: [
                  '--store=dnssrv+%s.%s.svc.cluster.local:%d' % [
                    $.thanos.receive.service.metadata.name,
                    $.thanos.receive.service.metadata.namespace,
                    $.thanos.receive.service.spec.ports[0].port,
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
