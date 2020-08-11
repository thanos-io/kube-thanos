local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local tc = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-compact',
      'app.kubernetes.io/instance': tc.config.name,
      'app.kubernetes.io/version': tc.config.version,
      'app.kubernetes.io/component': 'database-compactor',
    },

    podLabelSelector:: {
      [labelName]: tc.config.commonLabels[labelName]
      for labelName in std.objectFields(tc.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      tc.config.name,
      tc.config.podLabelSelector,
      [
        ports.newNamed('http', 10902, 'http'),
      ],
    ) +
    service.mixin.metadata.withNamespace(tc.config.namespace) +
    service.mixin.metadata.withLabels(tc.config.commonLabels),

  statefulSet:
    local statefulSet = k.apps.v1.statefulSet;
    local volume = statefulSet.mixin.spec.template.spec.volumesType;
    local container = statefulSet.mixin.spec.template.spec.containersType;
    local containerEnv = container.envType;
    local containerVolumeMount = container.volumeMountsType;

    local c =
      container.new('thanos-compact', tc.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs([
        'compact',
        '--wait',
        '--log.level=' + tc.config.logLevel,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--data-dir=/var/thanos/compact',
        '--debug.accept-malformed-index',
      ]) +
      container.withEnv([
        containerEnv.fromSecretRef(
          'OBJSTORE_CONFIG',
          tc.config.objectStorageConfig.name,
          tc.config.objectStorageConfig.key,
        ),
      ]) +
      container.withPorts([
        { name: 'http', containerPort: tc.service.spec.ports[0].port },
      ]) +
      container.withVolumeMounts([
        containerVolumeMount.new('data', '/var/thanos/compact', false),
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(4) +
      container.mixin.livenessProbe.httpGet.withPort(tc.service.spec.ports[0].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(tc.service.spec.ports[0].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    statefulSet.new(tc.config.name, tc.config.replicas, c, [], tc.config.commonLabels) +
    statefulSet.mixin.metadata.withNamespace(tc.config.namespace) +
    statefulSet.mixin.metadata.withLabels(tc.config.commonLabels) +
    statefulSet.mixin.spec.withServiceName(tc.service.metadata.name) +
    statefulSet.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
    statefulSet.mixin.spec.template.spec.withVolumes([
      volume.fromEmptyDir('data'),
    ]) +
    statefulSet.mixin.spec.selector.withMatchLabels(tc.config.podLabelSelector) +
    {
      spec+: {
        volumeClaimTemplates: null,
      },
    },

  withServiceMonitor:: {
    local tc = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: tc.config.name,
        namespace: tc.config.namespace,
        labels: tc.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: tc.config.podLabelSelector,
        },
        endpoints: [
          {
            port: 'http',
            relabelings: [{
              sourceLabels: ['namespace', 'pod'],
              separator: '/',
              targetLabel: 'instance',
            }],
          },
        ],
      },
    },
  },

  withVolumeClaimTemplate:: {
    local tc = self,
    config+:: {
      volumeClaimTemplate: error 'must provide volumeClaimTemplate',
    },
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            volumes: std.filter(function(v) v.name != 'data', super.volumes),
          },
        },
        volumeClaimTemplates: [tc.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tc.config.podLabelSelector,
          },
        }],
      },
    },
  },

  withRetention:: {
    local tc = self,
    config+:: {
      retentionResolutionRaw: error 'must provide retentionResolutionRaw',
      retentionResolution5m: error 'must provide retentionResolution5m',
      retentionResolution1h: error 'must provide retentionResolution1h',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-compact' then c {
                args+: [
                  '--retention.resolution-raw=' + tc.config.retentionResolutionRaw,
                  '--retention.resolution-5m=' + tc.config.retentionResolution5m,
                  '--retention.resolution-1h=' + tc.config.retentionResolution1h,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withDownsamplingDisabled:: {
    local tc = self,

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-compact' then c {
                args+: [
                  '--downsampling.disable',
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withDeduplication:: {
    local tc = self,

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-compact' then c {
                args+: [
                  '--deduplication.replica-label=' + l
                  for l in tc.config.deduplicationReplicaLabels
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withDeleteDelay:: {
    local tc = self,

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-compact' then c {
                args+: [
                  '--delete-delay=' + tc.config.deleteDelay,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withResources:: {
    local tc = self,
    config+:: {
      resources: error 'must provide resources',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-compact' then c {
                resources: tc.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
