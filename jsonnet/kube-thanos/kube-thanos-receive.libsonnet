// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-receive',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  replicationFactor: error 'must provide replication factor',
  objectStorageConfig: error 'must provide objectStorageConfig',
  podDisruptionBudgetMaxUnavailable: (std.floor(defaults.replicationFactor / 2)),
  hashringConfigMapName: '',
  volumeClaimTemplate: {},
  retention: '15d',
  logLevel: 'info',
  resources: {},
  serviceMonitor: false,

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-receive',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'database-write-hashring',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local tr = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tr.config.replicas) && tr.config.replicas >= 0 : 'thanos receive replicas has to be number >= 0',
  assert std.isArray(tr.config.replicaLabels),
  assert std.isObject(tr.config.resources),
  assert std.isBoolean(tr.config.serviceMonitor),
  assert std.isObject(tr.config.volumeClaimTemplate),

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
    local localEndpointFlag = '--receive.local-endpoint=$(NAME).%s.$(NAMESPACE).svc.cluster.local:%d' % [
      tr.config.name,
      tr.service.spec.ports[0].port,
    ];

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
        '--tsdb.retention=' + tr.config.retention,
        localEndpointFlag,
      ] + (
        if tr.config.hashringConfigMapName != '' then [
          '--receive.hashrings-file=/var/lib/thanos-receive/hashrings.json',
        ] else []
      ),
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
      }] + (
        if tr.config.hashringConfigMapName != '' then [
          { name: 'hashring-config', mountPath: '/var/lib/thanos-receive' },
        ] else []
      ),
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
      resources: if tr.config.resources != {} then tr.config.resources else {},
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
            volumes: if tr.config.hashringConfigMapName != '' then [{
              name: 'hashring-config',
              configMap: { name: tr.config.hashringConfigMapName },
            }] else [],
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
        volumeClaimTemplates: if std.length(tr.config.volumeClaimTemplate) > 0 then [tr.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tr.config.podLabelSelector,
          },
        }] else [],
      },
    },

  serviceMonitor: if tr.config.serviceMonitor == true then {
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

  podDisruptionBudget:
    {
      apiVersion: 'policy/v1beta1',
      kind: 'PodDisruptionBudget',
      metadata: {
        name: tr.config.name,
        namespace: tr.config.namespace,
      },
      spec: {
        maxUnavailable: tr.config.podDisruptionBudgetMaxUnavailable,
        selector: { matchLabels: tr.config.podLabelSelector },
      },
    },
}
