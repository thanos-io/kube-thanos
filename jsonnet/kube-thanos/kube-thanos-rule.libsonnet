// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-rule',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  reloaderImage: error 'must provide reloader image',
  objectStorageConfig: error 'must provide objectStorageConfig',
  ruleFiles: [],
  rulesConfig: [],
  alertmanagersURLs: [],
  queriers: [],
  logLevel: 'info',
  logFormat: 'logfmt',
  resources: {},
  serviceMonitor: false,
  ports: {
    grpc: 10901,
    http: 10902,
  },
  tracing: {},

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-rule',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'rule-evaluation-engine',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if labelName != 'app.kubernetes.io/version'
  },
};

function(params) {
  local tr = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tr.config.replicas) && tr.config.replicas >= 0 : 'thanos rule replicas has to be number >= 0',
  assert std.isArray(tr.config.ruleFiles),
  assert std.isArray(tr.config.rulesConfig),
  assert std.isArray(tr.config.alertmanagersURLs),
  assert std.isObject(tr.config.resources),
  assert std.isBoolean(tr.config.serviceMonitor),
  assert std.isObject(tr.config.volumeClaimTemplate),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tr.config.name,
      namespace: tr.config.namespace,
      labels: tr.config.commonLabels,
    },
    spec: {
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tr.config.ports[name]),

          name: name,
          port: tr.config.ports[name],
          targetPort: tr.config.ports[name],
        }
        for name in std.objectFields(tr.config.ports)
      ],
      clusterIP: 'None',
      selector: tr.config.podLabelSelector,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tr.config.name,
      namespace: tr.config.namespace,
      labels: tr.config.commonLabels,
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
          '--log.format=' + tr.config.logFormat,
          '--grpc-address=0.0.0.0:%d' % tr.config.ports.grpc,
          '--http-address=0.0.0.0:%d' % tr.config.ports.http,
          '--objstore.config=$(OBJSTORE_CONFIG)',
          '--data-dir=/var/thanos/rule',
          '--label=rule_replica="$(NAME)"',
          '--alert.label-drop=rule_replica',
        ] +
        (['--query=%s' % querier for querier in tr.config.queriers]) +
        (['--rule-file=%s' % path for path in tr.config.ruleFiles]) +
        (['--alertmanagers.url=%s' % url for url in tr.config.alertmanagersURLs]) +
        (
          if std.length(tr.config.rulesConfig) > 0 then [
            '--rule-file=/etc/thanos/rules/' + ruleConfig.name + '/' + ruleConfig.key
            for ruleConfig in tr.config.rulesConfig
          ]
          else []
        ) + (
          if std.length(tr.config.tracing) > 0 then [
            '--tracing.config=' + std.manifestYamlDoc(
              { config+: { service_name: defaults.name } } + tr.config.tracing
            ),
          ] else []
        ),
      securityContext: {
        runAsUser: 65534,
      },
      env: [
        { name: 'NAME', valueFrom: { fieldRef: { fieldPath: 'metadata.name' } } },
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tr.config.objectStorageConfig.key,
          name: tr.config.objectStorageConfig.name,
        } } },
      ],
      ports: [
        { name: name, containerPort: tr.config.ports[name] }
        for name in std.objectFields(tr.config.ports)
      ],
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/rule',
        readOnly: false,
      }] + (
        if std.length(tr.config.rulesConfig) > 0 then [
          { name: ruleConfig.name, mountPath: '/etc/thanos/rules/' + ruleConfig.name }
          for ruleConfig in tr.config.rulesConfig
        ] else []
      ),
      livenessProbe: { failureThreshold: 24, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tr.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 18, periodSeconds: 5, initialDelaySeconds: 10, httpGet: {
        scheme: 'HTTP',
        port: tr.config.ports.http,
        path: '/-/ready',

      } },
      resources: if tr.config.resources != {} then tr.config.resources else {},
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    local reloadContainer = {
      name: 'configmap-reloader',
      image: tr.config.reloaderImage,
      args:
        [
          '-webhook-url=http://localhost:' + tr.service.spec.ports[1].port + '/-/reload',
        ] +
        (['-volume-dir=/etc/thanos/rules/' + ruleConfig.name for ruleConfig in tr.config.rulesConfig]),
      volumeMounts: [
        { name: ruleConfig.name, mountPath: '/etc/thanos/rules/' + ruleConfig.name }
        for ruleConfig in tr.config.rulesConfig
      ],
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
            serviceAccountName: tr.serviceAccount.metadata.name,
            securityContext: {
              fsGroup: 65534,
            },
            containers: [c] +
                        (if std.length(tr.config.rulesConfig) > 0 then [reloadContainer] else []),
            volumes: [
              { name: ruleConfig.name, configMap: { name: ruleConfig.name } }
              for ruleConfig in tr.config.rulesConfig
            ],
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
}
