local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local tb = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-bucket',
      'app.kubernetes.io/instance': tb.config.name,
      'app.kubernetes.io/version': tb.config.version,
      'app.kubernetes.io/component': 'object-store-bucket-debugging',
    },

    podLabelSelector:: {
      [labelName]: tb.config.commonLabels[labelName]
      for labelName in std.objectFields(tb.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      tb.config.name,
      tb.config.podLabelSelector,
      [ports.newNamed('http', 10902, 'http')],
    ) +
    service.mixin.metadata.withNamespace(tb.config.namespace) +
    service.mixin.metadata.withLabels(tb.config.commonLabels),

  deployment:
    local deployment = k.apps.v1.deployment;
    local container = deployment.mixin.spec.template.spec.containersType;
    local containerEnv = container.envType;

    local c =
      container.new('thanos-bucket', tb.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs([
        'tools',
        'bucket',
        'web',
        '--log.level=' + tb.config.logLevel,
        '--objstore.config=$(OBJSTORE_CONFIG)',
      ]) +
      container.withEnv([
        containerEnv.fromSecretRef(
          'OBJSTORE_CONFIG',
          tb.config.objectStorageConfig.name,
          tb.config.objectStorageConfig.key,
        ),
      ]) +
      container.withPorts([
        { name: 'http', containerPort: tb.service.spec.ports[0].port },
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(4) +
      container.mixin.livenessProbe.httpGet.withPort(tb.service.spec.ports[0].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(tb.service.spec.ports[0].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    deployment.new(tb.config.name, 1, c, tb.config.commonLabels) +
    deployment.mixin.metadata.withNamespace(tb.config.namespace) +
    deployment.mixin.metadata.withLabels(tb.config.commonLabels) +
    deployment.mixin.spec.selector.withMatchLabels(tb.config.podLabelSelector) +
    deployment.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120),

  withResources:: {
    local tb = self,
    config+:: {
      resources: error 'must provide resources',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-bucket' then c {
                resources: tb.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
