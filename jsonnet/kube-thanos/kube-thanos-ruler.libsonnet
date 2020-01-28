local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    namespace:: 'monitoring',
    image:: error 'must set thanos image',

    ruler+: {
      local tr = self,
      name:: 'thanos-ruler',
      namespace:: $.thanos.namespace,
      image:: $.thanos.image,
      replicas:: 1,
      labels+:: {
        'app.kubernetes.io/name': tr.name,
      },
      ports:: {
        grpc: 10901,
        http: 10902,
      },
      objectStorageConfig:: $.thanos.objectStorageConfig,
      ruleFiles:: [],
      alertmanagersURLs:: [],

      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          tr.name,
          tr.labels,
          [
            ports.newNamed('grpc', tr.ports.grpc, 'grpc'),
            ports.newNamed('http', tr.ports.http, 'http'),
          ],
        ) +
        service.mixin.metadata.withNamespace(tr.namespace) +
        service.mixin.metadata.withLabels(tr.labels) +
        service.mixin.spec.withClusterIp('None'),

      statefulSet:
        local statefulSet = k.apps.v1.statefulSet;
        local volume = statefulSet.mixin.spec.template.spec.volumesType;
        local container = statefulSet.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;
        local containerVolumeMount = container.volumeMountsType;

        local c =
          container.new(tr.name, tr.image) +
          container.withArgs(
            [
              'rule',
              '--grpc-address=0.0.0.0:%d' % tr.ports.grpc,
              '--http-address=0.0.0.0:%d' % tr.ports.http,
              '--objstore.config=$(OBJSTORE_CONFIG)',
              '--data-dir=/var/thanos/ruler',
              '--label=ruler_replica="$(NAME)"',
              '--alert.label-drop="ruler_replica"',
              '--query=dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [
                $.thanos.querier.service.metadata.name,
                $.thanos.querier.service.metadata.namespace,
              ],
            ] +
            (['--rule-file=%s' % path for path in tr.ruleFiles]) +
            (['--alertmanagers.url=%s' % url for url in tr.alertmanagersURLs])
          ) +
          container.withEnv([
            containerEnv.fromFieldPath('NAME', 'metadata.name'),
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              tr.objectStorageConfig.name,
              tr.objectStorageConfig.key,
            ),
          ]) +
          container.withVolumeMounts([
            containerVolumeMount.new('thanos-ruler-data', '/var/thanos/ruler', false),
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: tr.ports.grpc },
            { name: 'http', containerPort: tr.ports.http },
          ]) +
          container.mixin.livenessProbe +
          container.mixin.livenessProbe.withPeriodSeconds(5) +
          container.mixin.livenessProbe.withFailureThreshold(24) +
          container.mixin.livenessProbe.httpGet.withPort(tr.ports.http) +
          container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
          container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
          container.mixin.readinessProbe +
          container.mixin.readinessProbe.withInitialDelaySeconds(10) +
          container.mixin.readinessProbe.withPeriodSeconds(5) +
          container.mixin.readinessProbe.withFailureThreshold(18) +
          container.mixin.readinessProbe.httpGet.withPort(tr.ports.http) +
          container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
          container.mixin.readinessProbe.httpGet.withPath('/-/ready');

        statefulSet.new(tr.name, tr.replicas, c, [], $.thanos.ruler.statefulSet.metadata.labels) +
        statefulSet.mixin.metadata.withNamespace(tr.namespace) +
        statefulSet.mixin.metadata.withLabels({ 'app.kubernetes.io/name': tr.name }) +
        statefulSet.mixin.spec.withServiceName($.thanos.ruler.service.metadata.name) +
        statefulSet.mixin.spec.selector.withMatchLabels(tr.labels) +
        statefulSet.mixin.spec.template.spec.withVolumes([
          volume.fromEmptyDir('thanos-ruler-data'),
        ]) + {
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
                  '--query.replica-label=ruler_replica',
                  '--store=dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [
                    $.thanos.ruler.service.metadata.name,
                    $.thanos.ruler.service.metadata.namespace,
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
