// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-bucket-replicate',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  imagePullPolicy: 'IfNotPresent',
  objectStorageConfig: error 'must provide objectStorageConfig',
  objectStorageToConfig: error 'must provide objectStorageToConfig',  // Destination object store configuration.
  resources: {},
  logLevel: 'info',
  logFormat: 'logfmt',
  ports: {
    http: 10902,
  },
  tracing: {},
  minTime: '',
  maxTime: '',
  compactionLevels: [],
  resolutions: [],
  extraEnv: [],

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-bucket-replicate',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'object-store-bucket-replicate',
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
};

function(params) {
  local tbr = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tbr.config.replicas) && tbr.config.replicas >= 0 : 'thanos bucket replicate replicas has to be number >= 0',
  assert std.isObject(tbr.config.resources),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tbr.config.name,
      namespace: tbr.config.namespace,
      labels: tbr.config.commonLabels,
    },
    spec: {
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tbr.config.ports[name]),

          name: name,
          port: tbr.config.ports[name],
          targetPort: tbr.config.ports[name],
        }
        for name in std.objectFields(tbr.config.ports)
      ],
      selector: tbr.config.podLabelSelector,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tbr.config.name,
      namespace: tbr.config.namespace,
      labels: tbr.config.commonLabels,
    },
  },

  deployment:
    local container = {
      name: 'thanos-bucket-replicate',
      image: tbr.config.image,
      imagePullPolicy: tbr.config.imagePullPolicy,
      args: [
        'tools',
        'bucket',
        'replicate',
        '--log.level=' + tbr.config.logLevel,
        '--log.format=' + tbr.config.logFormat,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--objstore-to.config=$(OBJSTORE_TO_CONFIG)',
      ] + (
        if std.length(tbr.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + tbr.config.tracing
          ),
        ] else []
      ) + (
        if std.length(tbr.config.minTime) > 0 then [
          '--min-time=' + tbr.config.minTime,
        ] else []
      ) + (
        if std.length(tbr.config.maxTime) > 0 then [
          '--max-time=' + tbr.config.maxTime,
        ] else []
      ) + (
        if std.length(tbr.config.compactionLevels) > 0 then [
          '--compaction=%d' % compactionLevel
          for compactionLevel in tbr.config.compactionLevels
        ] else []
      ) + (
        if std.length(tbr.config.resolutions) > 0 then [
          '--resolution=%s' % resolution
          for resolution in tbr.config.resolutions
        ] else []
      ),
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tbr.config.objectStorageConfig.key,
          name: tbr.config.objectStorageConfig.name,
        } } },
        { name: 'OBJSTORE_TO_CONFIG', valueFrom: { secretKeyRef: {
          key: tbr.config.objectStorageToConfig.key,
          name: tbr.config.objectStorageToConfig.name,
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
        if std.length(tbr.config.extraEnv) > 0 then tbr.config.extraEnv else []
      ),
      ports: [
        { name: name, containerPort: tbr.config.ports[name] }
        for name in std.objectFields(tbr.config.ports)
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tbr.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tbr.config.ports.http,
        path: '/-/ready',
      } },
      resources: if tbr.config.resources != {} then tbr.config.resources else {},
      terminationMessagePolicy: 'FallbackToLogsOnError',
      volumeMounts: if std.objectHas(tbr.config.objectStorageConfig, 'tlsSecretName') && std.length(tbr.config.objectStorageConfig.tlsSecretName) > 0 then [
        { name: 'tls-secret', mountPath: tbr.config.objectStorageConfig.tlsSecretMountPath },
      ] else [],
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tbr.config.name,
        namespace: tbr.config.namespace,
        labels: tbr.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: tbr.config.podLabelSelector },
        template: {
          metadata: { labels: tbr.config.commonLabels },
          spec: {
            serviceAccountName: tbr.serviceAccount.metadata.name,
            securityContext: tbr.config.securityContext,
            containers: [container],
            volumes: if std.objectHas(tbr.config.objectStorageConfig, 'tlsSecretName') && std.length(tbr.config.objectStorageConfig.tlsSecretName) > 0 then [{
              name: 'tls-secret',
              secret: { secretName: tbr.config.objectStorageConfig.tlsSecretName },
            }] else [],
            terminationGracePeriodSeconds: 120,
            nodeSelector: {
              'beta.kubernetes.io/os': 'linux',
            },
          },
        },
      },
    },
}
