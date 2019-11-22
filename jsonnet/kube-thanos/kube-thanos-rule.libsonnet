local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    namespace:: 'monitoring',
    image:: error 'must set thanos image',

    rule+: {
      local tr = self,
      name:: 'thanos-rule',
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
        service.mixin.metadata.withLabels(tr.labels),

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
              'ruler',
              '--grpc-address=0.0.0.0:%d' % tr.ports.grpc,
              '--http-address=0.0.0.0:%d' % tr.ports.http,
              '--objstore.config=$(OBJSTORE_CONFIG)',
              '--data-dir=/var/thanos/rule',
              '--label=replica="$(NAME)"',
              '--alert.label-drop="replica"',
              '--query=dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [
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
          container.mixin.resources.withRequests({ cpu: '100m', memory: '256Mi' }) +
          container.mixin.resources.withLimits({ cpu: '1', memory: '1Gi' }) +
          container.withVolumeMounts([
            containerVolumeMount.new('thanos-rule-data', '/var/thanos/rule', false),
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: tr.ports.grpc },
            { name: 'http', containerPort: tr.ports.http },
          ]) +
          container.mixin.livenessProbe +
          container.mixin.livenessProbe.withPeriodSeconds(30) +
          container.mixin.livenessProbe.withFailureThreshold(4) +
          container.mixin.livenessProbe.httpGet.withPort(tr.ports.http) +
          container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
          container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
          container.mixin.readinessProbe +
          container.mixin.readinessProbe.withInitialDelaySeconds(10) +
          container.mixin.readinessProbe.withPeriodSeconds(30) +
          container.mixin.readinessProbe.httpGet.withPort(tr.ports.http) +
          container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
          container.mixin.readinessProbe.httpGet.withPath('/-/ready');

        statefulSet.new(tr.name, tr.replicas, c, [], $.thanos.rule.statefulSet.metadata.labels) +
        statefulSet.mixin.metadata.withNamespace(tr.namespace) +
        statefulSet.mixin.metadata.withLabels({ 'app.kubernetes.io/name': tr.name }) +
        statefulSet.mixin.spec.selector.withMatchLabels(tr.labels) +
        statefulSet.mixin.spec.template.spec.withVolumes([
          volume.fromEmptyDir('thanos-rule-data'),
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
                  '--store=dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [
                    $.thanos.rule.service.metadata.name,
                    $.thanos.rule.service.metadata.namespace,
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
