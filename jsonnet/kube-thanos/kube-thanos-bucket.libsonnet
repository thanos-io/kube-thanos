// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-bucket',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  imagePullPolicy: 'IfNotPresent',
  objectStorageConfig: error 'must provide objectStorageConfig',
  resources: {},
  logLevel: 'info',
  logFormat: 'logfmt',
  ports: {
    http: 10902,
  },
  tracing: {},
  extraEnv: [],

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-bucket',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'object-store-bucket-debugging',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if labelName != 'app.kubernetes.io/version'
  },

  securityContext:: {
    fsGroup: 65534,
    runAsUser: 65534,
    runAsGroup: 65532,
    runAsNonRoot: true,
    seccompProfile: { type: 'RuntimeDefault' },
  },
  securityContextContainer:: {
    runAsUser: defaults.securityContext.runAsUser,
    runAsGroup: defaults.securityContext.runAsGroup,
    runAsNonRoot: defaults.securityContext.runAsNonRoot,
    seccompProfile: defaults.securityContext.seccompProfile,
    allowPrivilegeEscalation: false,
    readOnlyRootFilesystem: true,
    capabilities: { drop: ['ALL'] },
  },

  serviceAccountAnnotations:: {},
};

function(params) {
  local tb = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tb.config.replicas) && tb.config.replicas >= 0 : 'thanos bucket replicas has to be number >= 0',
  assert std.isObject(tb.config.resources),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tb.config.name,
      namespace: tb.config.namespace,
      labels: tb.config.commonLabels,
    },
    spec: {
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tb.config.ports[name]),

          name: name,
          port: tb.config.ports[name],
          targetPort: tb.config.ports[name],
        }
        for name in std.objectFields(tb.config.ports)
      ],
      selector: tb.config.podLabelSelector,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tb.config.name,
      namespace: tb.config.namespace,
      labels: tb.config.commonLabels,
      annotations: tb.config.serviceAccountAnnotations,
    },
  },

  deployment:
    local container = {
      name: 'thanos-bucket',
      image: tb.config.image,
      imagePullPolicy: tb.config.imagePullPolicy,
      args: [
        'tools',
        'bucket',
        'web',
        '--log.level=' + tb.config.logLevel,
        '--log.format=' + tb.config.logFormat,
        '--objstore.config=$(OBJSTORE_CONFIG)',
      ] + (
        if std.length(tb.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + tb.config.tracing
          ),
        ] else []
      ) + (
        if std.objectHas(tb.config, 'label') then [
          '--label=' + tb.config.label,
        ] else []
      ) + (
        if std.objectHas(tb.config, 'refresh') then [
          '--refresh=' + tb.config.refresh,
        ] else []
      ),
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tb.config.objectStorageConfig.key,
          name: tb.config.objectStorageConfig.name,
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
        if std.length(tb.config.extraEnv) > 0 then tb.config.extraEnv else []
      ),
      ports: [
        { name: name, containerPort: tb.config.ports[name] }
        for name in std.objectFields(tb.config.ports)
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tb.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tb.config.ports.http,
        path: '/-/ready',
      } },
      resources: if tb.config.resources != {} then tb.config.resources else {},
      securityContext: tb.config.securityContextContainer,
      terminationMessagePolicy: 'FallbackToLogsOnError',
      volumeMounts: if std.objectHas(tb.config.objectStorageConfig, 'tlsSecretName') && std.length(tb.config.objectStorageConfig.tlsSecretName) > 0 then [
        { name: 'tls-secret', mountPath: tb.config.objectStorageConfig.tlsSecretMountPath },
      ] else [],
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tb.config.name,
        namespace: tb.config.namespace,
        labels: tb.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: tb.config.podLabelSelector },
        template: {
          metadata: { labels: tb.config.commonLabels },
          spec: {
            serviceAccountName: tb.serviceAccount.metadata.name,
            securityContext: tb.config.securityContext,
            containers: [container],
            volumes: if std.objectHas(tb.config.objectStorageConfig, 'tlsSecretName') && std.length(tb.config.objectStorageConfig.tlsSecretName) > 0 then [{
              name: 'tls-secret',
              secret: { secretName: tb.config.objectStorageConfig.tlsSecretName },
            }] else [],
            terminationGracePeriodSeconds: 120,
            nodeSelector: {
              'kubernetes.io/os': 'linux',
            },
          },
        },
      },
    },
}
