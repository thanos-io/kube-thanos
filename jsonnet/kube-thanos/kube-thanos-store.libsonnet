local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local ts = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    objectStorageConfig: error 'must provide objectStorageConfig',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-store',
      'app.kubernetes.io/instance': ts.config.name,
      'app.kubernetes.io/version': ts.config.version,
      'app.kubernetes.io/component': 'object-store-gateway',
    },

    podLabelSelector:: {
      [labelName]: ts.config.commonLabels[labelName]
      for labelName in std.objectFields(ts.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      ts.config.name,
      ts.config.podLabelSelector,
      [
        ports.newNamed('grpc', 10901, 10901),
        ports.newNamed('http', 10902, 10902),
      ]
    ) +
    service.mixin.metadata.withNamespace(ts.config.namespace) +
    service.mixin.metadata.withLabels(ts.config.commonLabels) +
    service.mixin.spec.withClusterIp('None'),

  statefulSet:
    local sts = k.apps.v1.statefulSet;
    local volume = sts.mixin.spec.template.spec.volumesType;
    local container = sts.mixin.spec.template.spec.containersType;
    local containerEnv = container.envType;
    local containerVolumeMount = container.volumeMountsType;

    local c =
      container.new('thanos-store', ts.config.image) +
      container.withArgs([
        'store',
        '--data-dir=/var/thanos/store',
        '--grpc-address=0.0.0.0:%d' % ts.service.spec.ports[0].port,
        '--http-address=0.0.0.0:%d' % ts.service.spec.ports[1].port,
        '--objstore.config=$(OBJSTORE_CONFIG)',
      ]) +
      container.withEnv([
        containerEnv.fromSecretRef(
          'OBJSTORE_CONFIG',
          ts.config.objectStorageConfig.name,
          ts.config.objectStorageConfig.key,
        ),
      ]) +
      container.withPorts([
        { name: 'grpc', containerPort: ts.service.spec.ports[0].port },
        { name: 'http', containerPort: ts.service.spec.ports[1].port },
      ]) +
      container.withVolumeMounts([
        containerVolumeMount.new('data', '/var/thanos/store', false),
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(8) +
      container.mixin.livenessProbe.httpGet.withPort(ts.service.spec.ports[1].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(ts.service.spec.ports[1].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    sts.new(ts.config.name, ts.config.replicas, c, [], ts.config.commonLabels) +
    sts.mixin.metadata.withNamespace(ts.config.namespace) +
    sts.mixin.metadata.withLabels(ts.config.commonLabels) +
    sts.mixin.spec.withServiceName(ts.service.metadata.name) +
    sts.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
    sts.mixin.spec.template.spec.withVolumes([
      volume.fromEmptyDir('data'),
    ]) +
    sts.mixin.spec.selector.withMatchLabels(ts.config.podLabelSelector) +
    {
      spec+: {
        volumeClaimTemplates: null,
      },
    },

  withServiceMonitor:: {
    local ts = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: ts.config.name,
        namespace: ts.config.namespace,
        labels: ts.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: ts.config.podLabelSelector,
        },
        endpoints: [
          { port: 'http' },
        ],
      },
    },
  },

  withVolumeClaimTemplate:: {
    local ts = self,
    config+:: {
      volumeClaimTemplate: error 'must provide volumeClaimTemplate',
    },
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            volumes: null,
          },
        },
        volumeClaimTemplates: [ts.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: ts.config.podLabelSelector,
          },
        }],
      },
    },
  },

  withResources:: {
    local ts = self,
    config+:: {
      resources: error 'must provide resources',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-store' then c {
                resources: ts.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
