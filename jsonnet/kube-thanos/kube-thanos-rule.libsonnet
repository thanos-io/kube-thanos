// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-rule',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  imagePullPolicy: 'IfNotPresent',
  replicas: error 'must provide replicas',
  reloaderImage: error 'must provide reloader image',
  reloaderImagePullPolicy: 'IfNotPresent',
  objectStorageConfig: error 'must provide objectStorageConfig',
  ruleFiles: [],
  rulesConfig: [],
  remoteWriteConfigFile: {},
  alertmanagersURLs: [],
  alertmanagerConfigFile: {},
  extraVolumeMounts: [],
  queriers: [],
  logLevel: 'info',
  logFormat: 'logfmt',
  resources: {},
  retention: '48h',
  blockDuration: '2h',
  serviceMonitor: false,
  ports: {
    grpc: 10901,
    http: 10902,
    reloader: 9533,
  },
  tracing: {},
  extraEnv: [],

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

  securityContext:: {
    fsGroup: 65534,
    runAsUser: 65534,
  },

  serviceAccountAnnotations:: {},
};

function(params) {
  local tr = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tr.config.replicas) && tr.config.replicas >= 0 : 'thanos rule replicas has to be number >= 0',
  assert std.isArray(tr.config.ruleFiles),
  assert std.isArray(tr.config.rulesConfig),
  assert std.isObject(tr.config.remoteWriteConfigFile),
  assert std.isArray(tr.config.alertmanagersURLs),
  assert std.isObject(tr.config.alertmanagerConfigFile),
  assert std.isArray(tr.config.extraVolumeMounts),
  assert std.isObject(tr.config.resources),
  assert std.isBoolean(tr.config.serviceMonitor),
  assert std.isObject(tr.config.volumeClaimTemplate),
  assert !std.objectHas(tr.config.volumeClaimTemplate, 'spec') || std.assertEqual(tr.config.volumeClaimTemplate.spec.accessModes, ['ReadWriteOnce']) : 'thanos rule PVC accessMode can only be ReadWriteOnce',


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
      annotations: tr.config.serviceAccountAnnotations,
    },
  },

  statefulSet:
    local c = {
      name: 'thanos-rule',
      image: tr.config.image,
      imagePullPolicy: tr.config.imagePullPolicy,
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
          '--tsdb.retention=' + tr.config.retention,
          '--tsdb.block-duration=' + tr.config.blockDuration,
        ] +
        (['--query=%s' % querier for querier in tr.config.queriers]) +
        (['--rule-file=%s' % path for path in tr.config.ruleFiles]) +
        (['--alertmanagers.url=%s' % url for url in tr.config.alertmanagersURLs]) +
        (
          if tr.config.alertmanagerConfigFile != {} then [
            '--alertmanagers.config-file=/etc/thanos/config/' + tr.config.alertmanagerConfigFile.name + '/' + tr.config.alertmanagerConfigFile.key,
          ]
          else []
        ) + (
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
        ) + (
          if tr.config.remoteWriteConfigFile != {} then [
            '--remote-write.config-file=/etc/thanos/config/' + tr.config.remoteWriteConfigFile.name + '/' + tr.config.remoteWriteConfigFile.key,
          ]
          else []
        ),
      env: [
        { name: 'NAME', valueFrom: { fieldRef: { fieldPath: 'metadata.name' } } },
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tr.config.objectStorageConfig.key,
          name: tr.config.objectStorageConfig.name,
        } } },
        {
          // Inject the host IP to make configuring tracing convenient.
          name: 'HOST_IP_ADDRESS',
          valueFrom: {
            fieldRef: {
              fieldPath: 'status.hostIP',
            },
          },
        },
      ] + (
        if std.length(tr.config.extraEnv) > 0 then tr.config.extraEnv else []
      ),
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
      ) + (
        if tr.config.alertmanagerConfigFile != {} then [
          { name: tr.config.alertmanagerConfigFile.name, mountPath: '/etc/thanos/config/' + tr.config.alertmanagerConfigFile.name, readOnly: true },
        ] else []
      ) + (
        if std.length(tr.config.extraVolumeMounts) > 0 then [
          { name: volumeMount.name, mountPath: volumeMount.mountPath }
          for volumeMount in tr.config.extraVolumeMounts
        ] else []
      ) + (
        if tr.config.objectStorageConfig != null && std.objectHas(tr.config.objectStorageConfig, 'tlsSecretName') && std.length(tr.config.objectStorageConfig.tlsSecretName) > 0 then [
          { name: 'tls-secret', mountPath: tr.config.objectStorageConfig.tlsSecretMountPath },
        ] else []
      ) + (
        if tr.config.remoteWriteConfigFile != {} then [
          { name: tr.config.remoteWriteConfigFile.name, mountPath: '/etc/thanos/config/' + tr.config.remoteWriteConfigFile.name, readOnly: true },
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
      imagePullPolicy: tr.config.reloaderImagePullPolicy,
      args:
        [
          '-webhook-url=http://localhost:' + tr.service.spec.ports[1].port + '/-/reload',
        ] +
        (
          if std.length(tr.config.rulesConfig) > 0 then [
            '-volume-dir=/etc/thanos/rules/' + ruleConfig.name
            for ruleConfig in tr.config.rulesConfig
          ] else []
        ) + (
          if tr.config.alertmanagerConfigFile != {} then [
            '-volume-dir=/etc/thanos/config/' + tr.config.alertmanagerConfigFile.name,
          ] else []
        ) + (
          if std.length(tr.config.extraVolumeMounts) > 0 then [
            '-volume-dir=' + volumeMount.mountPath
            for volumeMount in tr.config.extraVolumeMounts
          ] else []
        ) + (
          if tr.config.remoteWriteConfigFile != {} then [
            '-volume-dir=/etc/thanos/config/' + tr.config.remoteWriteConfigFile.name,
          ] else []
        ),
      volumeMounts: [
        { name: ruleConfig.name, mountPath: '/etc/thanos/rules/' + ruleConfig.name }
        for ruleConfig in tr.config.rulesConfig
      ] + (
        if tr.config.alertmanagerConfigFile != {} then [
          { name: tr.config.alertmanagerConfigFile.name, mountPath: '/etc/thanos/config/' + tr.config.alertmanagerConfigFile.name },
        ] else []
      ) + (
        if std.length(tr.config.extraVolumeMounts) > 0 then [
          { name: volumeMount.name, mountPath: volumeMount.mountPath }
          for volumeMount in tr.config.extraVolumeMounts
        ] else []
      ) + (
        if tr.config.remoteWriteConfigFile != {} then [
          { name: tr.config.remoteWriteConfigFile.name, mountPath: '/etc/thanos/config/' + tr.config.remoteWriteConfigFile.name },
        ] else []
      ),
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
            securityContext: tr.config.securityContext,
            containers: [c] +
                        (
                          if std.length(tr.config.rulesConfig) > 0 || std.length(tr.config.extraVolumeMounts) > 0 || tr.config.alertmanagerConfigFile != {} || tr.config.remoteWriteConfigFile != {} then [
                            reloadContainer,
                          ] else []
                        ),
            volumes:
              [] +
              (
                if std.length(tr.config.rulesConfig) > 0 then [
                  { name: ruleConfig.name, configMap: { name: ruleConfig.name } }
                  for ruleConfig in tr.config.rulesConfig
                ] else []
              ) + (
                if tr.config.alertmanagerConfigFile != {} then [{
                  name: tr.config.alertmanagerConfigFile.name,
                  configMap: { name: tr.config.alertmanagerConfigFile.name },
                }] else []
              ) + (
                if tr.config.remoteWriteConfigFile != {} then [{
                  name: tr.config.remoteWriteConfigFile.name,
                  configMap: { name: tr.config.remoteWriteConfigFile.name },
                }] else []
              ) + (
                if std.length(tr.config.extraVolumeMounts) > 0 then [
                  { name: volumeMount.name } +
                  (
                    if volumeMount.type == 'configMap' then {
                      configMap: { name: volumeMount.name },
                    }
                    else {
                      secret: { name: volumeMount.name },
                    }
                  )
                  for volumeMount in tr.config.extraVolumeMounts
                ] else []
              ) + (
                if tr.config.objectStorageConfig != null && std.objectHas(tr.config.objectStorageConfig, 'tlsSecretName') && std.length(tr.config.objectStorageConfig.tlsSecretName) > 0 then [{
                  name: 'tls-secret',
                  secret: { secretName: tr.config.objectStorageConfig.tlsSecretName },
                }] else []
              ),
            nodeSelector: {
              'kubernetes.io/os': 'linux',
            },
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
            action: 'replace',
            sourceLabels: ['namespace', 'pod'],
            separator: '/',
            targetLabel: 'instance',
          }],
        },
        { port: 'reloader' },
      ],
    },
  },
}
