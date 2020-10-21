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
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: tc.config.name,
        namespace: tc.config.namespace,
        labels: tc.config.commonLabels,
      },
      spec: {
        selector: tc.config.podLabelSelector,
        ports: [{ name: 'http', targetPort: 'http', port: 10902 }],
      },
    },

  statefulSet:
    local c = {
      name: 'thanos-compact',
      image: tc.config.image,
      args: [
        'compact',
        '--wait',
        '--log.level=' + tc.config.logLevel,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--data-dir=/var/thanos/compact',
        '--debug.accept-malformed-index',
      ],
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tc.config.objectStorageConfig.key,
          name: tc.config.objectStorageConfig.name,
        } } },
      ],
      ports: [{ name: 'http', containerPort: tc.service.spec.ports[0].port }],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tc.service.spec.ports[0].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tc.service.spec.ports[0].port,
        path: '/-/ready',
      } },
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/compact',
        readOnly: false,
      }],
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'StatefulSet',
      metadata: {
        name: tc.config.name,
        namespace: tc.config.namespace,
        labels: tc.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: tc.config.podLabelSelector },
        serviceName: tc.service.metadata.name,
        template: {
          metadata: {
            labels: tc.config.commonLabels,
          },
          spec: {
            containers: [c],
            volumes: [],
            terminationGracePeriodSeconds: 120,
          },
        },
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
