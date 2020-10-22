{
  local tr = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    replicationFactor: error 'must provide replication factor',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-receive',
      'app.kubernetes.io/instance': tr.config.name,
      'app.kubernetes.io/version': tr.config.version,
      'app.kubernetes.io/component': 'database-write-hashring',
    },

    podLabelSelector:: {
      [labelName]: tr.config.commonLabels[labelName]
      for labelName in std.objectFields(tr.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: tr.config.name,
        namespace: tr.config.namespace,
        labels: tr.config.commonLabels,
      },
      spec: {
        clusterIP: 'None',
        ports: [
          { name: 'grpc', targetPort: 'grpc', port: 10901 },
          { name: 'http', targetPort: 'http', port: 10902 },
          { name: 'remote-write', targetPort: 'remote-write', port: 19291 },
        ],
        selector: tr.config.podLabelSelector,
      },
    },

  statefulSet:
    local localEndpointFlag = '--receive.local-endpoint=$(NAME).%s.$(NAMESPACE).svc.cluster.local:%d' % [tr.config.name, tr.service.spec.ports[0].port];

    local c = {
      name: 'thanos-receive',
      image: tr.config.image,
      args: [
        'receive',
        '--log.level=' + tr.config.logLevel,
        '--grpc-address=0.0.0.0:%d' % tr.service.spec.ports[0].port,
        '--http-address=0.0.0.0:%d' % tr.service.spec.ports[1].port,
        '--remote-write.address=0.0.0.0:%d' % tr.service.spec.ports[2].port,
        '--receive.replication-factor=%d' % tr.config.replicationFactor,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--tsdb.path=/var/thanos/receive',
        '--label=replica="$(NAME)"',
        '--label=receive="true"',
        localEndpointFlag,
      ],
      env: [
        { name: 'NAME', valueFrom: { fieldRef: { fieldPath: 'metadata.name' } } },
        { name: 'NAMESPACE', valueFrom: { fieldRef: { fieldPath: 'metadata.namespace' } } },
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tr.config.objectStorageConfig.key,
          name: tr.config.objectStorageConfig.name,
        } } },
      ],
      ports: [
        { name: port.name, containerPort: port.port }
        for port in tr.service.spec.ports
      ],
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/receive',
        readOnly: false,
      }],
      livenessProbe: { failureThreshold: 8, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tr.service.spec.ports[1].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tr.service.spec.ports[1].port,
        path: '/-/ready',
      } },
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'StatefulSet',
      metadata: {
        name: tr.config.name,
        namespace: tr.config.namespace,
        labels: tr.config.commonLabels,
      },
      spec: {
        replicas: tr.config.replicas,
        selector: { matchLabels: tr.config.podLabelSelector },
        serviceName: tr.service.metadata.name,
        template: {
          metadata: {
            labels: tr.config.commonLabels,
          },
          spec: {
            containers: [c],
            volumes: [],
            terminationGracePeriodSeconds: 900,
            affinity: { podAntiAffinity: {
              local labelSelector = { matchExpressions: [{
                key: 'app.kubernetes.io/name',
                operator: 'In',
                values: [tr.statefulSet.metadata.labels['app.kubernetes.io/name']],
              }, {
                key: 'app.kubernetes.io/instance',
                operator: 'In',
                values: [tr.statefulSet.metadata.labels['app.kubernetes.io/instance']],
              }] },
              preferredDuringSchedulingIgnoredDuringExecution: [
                {
                  podAffinityTerm: {
                    namespaces: [tr.config.namespace],
                    topologyKey: 'kubernetes.io/hostname',
                    labelSelector: labelSelector,
                  },
                  weight: 100,
                },
                {
                  podAffinityTerm: {
                    namespaces: [tr.config.namespace],
                    topologyKey: 'topology.kubernetes.io/zone',
                    labelSelector: labelSelector,
                  },
                  weight: 100,
                },
              ],
            } },
          },
        },
      },
    },

  withServiceMonitor:: {
    local tr = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: tr.config.name,
        namespace: tr.config.namespace,
        labels: tr.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: tr.config.podLabelSelector,
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

  withPodDisruptionBudget:: {
    local tr = self,
    config+:: {
      podDisruptionBudgetMaxUnavailable: (std.floor(tr.config.replicationFactor / 2)),
    },

    podDisruptionBudget:
      {
        apiVersion: 'policy/v1beta1',
        kind: 'PodDisruptionBudget',
        metadata: {
          name: tr.config.name,
          namespace: tr.config.namespace,
        },
        spec: {
          maxUnavailable: 0,
          selector: { matchLabels: tr.config.podLabelSelector },
        },
      },
  },

  withVolumeClaimTemplate:: {
    local tr = self,
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
        volumeClaimTemplates: [tr.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tr.config.podLabelSelector,
          },
        }],
      },
    },
  },

  withRetention:: {
    local tr = self,
    config+:: {
      retention: error 'must provide retention',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                args+: [
                  '--tsdb.retention=' + tr.config.retention,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withHashringConfigMap:: {
    local tr = self,
    config+:: {
      hashringConfigMapName: error 'must provide hashringConfigMapName',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                args+: [
                  '--receive.hashrings-file=/var/lib/thanos-receive/hashrings.json',
                ],
                volumeMounts+: [
                  { name: 'hashring-config', mountPath: '/var/lib/thanos-receive' },
                ],
              } else c
              for c in super.containers
            ],

            volumes+: [{
              name: 'hashring-config',
              configMap: { name: tr.config.hashringConfigMapName },
            }],
          },
        },
      },
    },
  },

  withResources:: {
    local tr = self,
    config+:: {
      resources: error 'must provide resources',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                resources: tr.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
