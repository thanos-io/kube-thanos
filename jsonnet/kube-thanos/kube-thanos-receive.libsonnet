local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    receive: {
      local tr = self,
      name:: 'thanos-receive',
      namespace:: $.thanos.namespace,
      image:: $.thanos.image,
      replicas:: 3,
      objectStorageConfig:: $.thanos.objectStorageConfig,

      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          tr.name,
          $.thanos.receive.statefulSet.metadata.labels,
          [
            ports.newNamed('grpc', 10901, 10901),
            ports.newNamed('http', 10902, 10902),
            ports.newNamed('remote-write', 19291, 19291),
          ]
        ) +
        service.mixin.metadata.withNamespace(tr.namespace) +
        service.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.receive.service.metadata.name }) +
        service.mixin.spec.withClusterIp('None'),

      statefulSet:
        local sts = k.apps.v1.statefulSet;
        local affinity = sts.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
        local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;
        local volume = sts.mixin.spec.template.spec.volumesType;
        local container = sts.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;
        local containerVolumeMount = container.volumeMountsType;

        local c =
          container.new($.thanos.receive.statefulSet.metadata.name, tr.image) +
          container.withArgs([
            'receive',
            '--grpc-address=0.0.0.0:%d' % $.thanos.receive.service.spec.ports[0].port,
            '--http-address=0.0.0.0:%d' % $.thanos.receive.service.spec.ports[1].port,
            '--remote-write.address=0.0.0.0:%d' % $.thanos.receive.service.spec.ports[2].port,
            '--objstore.config=$(OBJSTORE_CONFIG)',
            '--tsdb.path=/var/thanos/receive',
            '--label=replica="$(NAME)"',
            '--label=receive="true"',
          ]) +
          container.withEnv([
            containerEnv.fromFieldPath('NAME', 'metadata.name'),
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              tr.objectStorageConfig.name,
              tr.objectStorageConfig.key,
            ),
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: $.thanos.receive.service.spec.ports[0].port },
            { name: 'http', containerPort: $.thanos.receive.service.spec.ports[1].port },
            { name: 'remote-write', containerPort: $.thanos.receive.service.spec.ports[2].port },
          ]) +
          container.withVolumeMounts([
            containerVolumeMount.new(tr.name + '-data', '/var/thanos/receive', false),
          ]) +
          container.mixin.livenessProbe +
          container.mixin.livenessProbe.withPeriodSeconds(30) +
          container.mixin.livenessProbe.withFailureThreshold(8) +
          container.mixin.livenessProbe.httpGet.withPort($.thanos.receive.service.spec.ports[1].port) +
          container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
          container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
          container.mixin.readinessProbe +
          container.mixin.readinessProbe.withPeriodSeconds(5) +
          container.mixin.readinessProbe.withFailureThreshold(20) +
          container.mixin.readinessProbe.httpGet.withPort($.thanos.receive.service.spec.ports[1].port) +
          container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
          container.mixin.readinessProbe.httpGet.withPath('/-/ready');

        sts.new(tr.name, tr.replicas, c, [], $.thanos.receive.statefulSet.metadata.labels) +
        sts.mixin.metadata.withNamespace(tr.namespace) +
        sts.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.receive.statefulSet.metadata.name }) +
        sts.mixin.spec.withServiceName($.thanos.receive.service.metadata.name) +
        sts.mixin.spec.selector.withMatchLabels($.thanos.receive.statefulSet.metadata.labels) +
        sts.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
        sts.mixin.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
          affinity.new() +
          affinity.withWeight(100) +
          affinity.mixin.podAffinityTerm.withNamespaces(tr.namespace) +
          affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
          affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
            matchExpression.new() +
            matchExpression.withKey('app.kubernetes.io/name') +
            matchExpression.withOperator('In') +
            matchExpression.withValues([$.thanos.receive.statefulSet.metadata.labels['app.kubernetes.io/name']]),
          ]),
        ]) +
        sts.mixin.spec.template.spec.withVolumes([
          volume.fromEmptyDir('data'),
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
