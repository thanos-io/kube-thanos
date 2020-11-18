// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-compact',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  objectStorageConfig: error 'must provide objectStorageConfig',
  resources: {},
  logLevel: 'info',
  serviceMonitor: false,
  volumeClaimTemplate: {},
  retentionResolutionRaw: '0d',
  retentionResolution5m: '0d',
  retentionResolution1h: '0d',
  deleteDelay: '48h',
  disableDownsampling: false,
  deduplicationReplicaLabels: [],
  ports: {
    http: 10902,
  },
  tracing: {},

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-compact',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'database-compactor',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local tc = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tc.config.replicas) && (tc.config.replicas == 0 || tc.config.replicas == 1) : 'thanos compact replicas can only be 0 or 1',
  assert std.isObject(tc.config.resources),
  assert std.isObject(tc.config.volumeClaimTemplate),
  assert std.isBoolean(tc.config.serviceMonitor),
  assert std.isArray(tc.config.deduplicationReplicaLabels),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tc.config.name,
      namespace: tc.config.namespace,
      labels: tc.config.commonLabels,
    },
    spec: {
      selector: tc.config.podLabelSelector,
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tc.config.ports[name]),

          name: name,
          port: tc.config.ports[name],
          targetPort: tc.config.ports[name],
        }
        for name in std.objectFields(tc.config.ports)
      ],
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
        '--retention.resolution-raw=' + tc.config.retentionResolutionRaw,
        '--retention.resolution-5m=' + tc.config.retentionResolution5m,
        '--retention.resolution-1h=' + tc.config.retentionResolution1h,
        '--delete-delay=' + tc.config.deleteDelay,
      ] + (
        if tc.config.disableDownsampling then ['--downsampling.disable'] else []
      ) + (
        if std.length(tc.config.deduplicationReplicaLabels) > 0 then
          [
            '--deduplication.replica-label=' + l
            for l in tc.config.deduplicationReplicaLabels
          ] else []
      ) + (
        if std.length(tc.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + tc.config.tracing
          ),
        ] else []
      ),
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tc.config.objectStorageConfig.key,
          name: tc.config.objectStorageConfig.name,
        } } },
      ],
      ports: [
        { name: name, containerPort: tc.config.ports[name] }
        for name in std.objectFields(tc.config.ports)
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tc.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tc.config.ports.http,
        path: '/-/ready',
      } },
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/compact',
        readOnly: false,
      }],
      resources: if tc.config.resources != {} then tc.config.resources else {},
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
        volumeClaimTemplates: if std.length(tc.config.volumeClaimTemplate) > 0 then [tc.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tc.config.podLabelSelector,
          },
        }] else [],
      },
    },

  serviceMonitor: if tc.config.serviceMonitor == true then {
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
}
