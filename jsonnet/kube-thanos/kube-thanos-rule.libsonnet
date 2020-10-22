{
  local tr = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',
    ruleFiles: [],
    alertmanagersURLs: [],
    queriers: [],

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-rule',
      'app.kubernetes.io/instance': tr.config.name,
      'app.kubernetes.io/version': tr.config.version,
      'app.kubernetes.io/component': 'rule-evaluation-engine',
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
        ports: [
          { name: 'grpc', targetPort: 'grpc', port: 10901 },
          { name: 'http', targetPort: 'http', port: 10902 },
        ],
        clusterIP: 'None',
        selector: tr.config.podLabelSelector,
      },
    },

  statefulSet:
    local c = {
      name: 'thanos-rule',
      image: tr.config.image,
      args:
        [
          'rule',
          '--log.level=' + tr.config.logLevel,
          '--grpc-address=0.0.0.0:%d' % tr.service.spec.ports[0].port,
          '--http-address=0.0.0.0:%d' % tr.service.spec.ports[1].port,
          '--objstore.config=$(OBJSTORE_CONFIG)',
          '--data-dir=/var/thanos/rule',
          '--label=rule_replica="$(NAME)"',
          '--alert.label-drop=rule_replica',
        ] +
        (['--query=%s' % querier for querier in tr.config.queriers]) +
        (['--rule-file=%s' % path for path in tr.config.ruleFiles]) +
        (['--alertmanagers.url=%s' % url for url in tr.config.alertmanagersURLs]),
      env: [
        { name: 'NAME', valueFrom: { fieldRef: { fieldPath: 'metadata.name' } } },
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
        mountPath: '/var/thanos/rule',
        readOnly: false,
      }],
      livenessProbe: { failureThreshold: 24, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tr.service.spec.ports[1].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 18, periodSeconds: 5, initialDelaySeconds: 10, httpGet: {
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
              if c.name == 'thanos-rule' then c {
                resources: tr.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withAlertmanagers:: {
    local tr = self,
    config+:: {
      alertmanagersURL: error 'must provide alertmanagersURL',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-rule' then c {
                args+: [
                  '--alertmanagers.url=' + alertmanagerURL
                  for alertmanagerURL in tr.config.alertmanagersURL
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withRules:: {
    local tr = self,
    config+:: {
      rulesConfig: error 'must provide rulesConfig',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-rule' then c {
                args+: [
                  '--rule-file=/etc/thanos/rules/' + ruleConfig.name + '/' + ruleConfig.key
                  for ruleConfig in tr.config.rulesConfig
                ],
                volumeMounts+: [
                  { name: ruleConfig.name, mountPath: '/etc/thanos/rules/' + ruleConfig.name }
                  for ruleConfig in tr.config.rulesConfig
                ],
              } else c
              for c in super.containers
            ],

            volumes+: [
              { name: ruleConfig.name, configMap: { name: ruleConfig.name } }
              for ruleConfig in tr.config.rulesConfig
            ],
          },
        },
      },
    },
  },
}
