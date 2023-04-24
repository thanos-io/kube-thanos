// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-query',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  imagePullPolicy: 'IfNotPresent',
  replicas: error 'must provide replicas',
  replicaLabels: error 'must provide replicaLabels',
  stores: ['dnssrv+_grpc._tcp.thanos-store.%s.svc.cluster.local' % defaults.namespace],
  rules: [],  // TODO(bwplotka): This is deprecated, switch to endpoints while ready.
  externalPrefix: '',
  prefixHeader: '',
  autoDownsampling: true,
  useThanosEngine: false,
  resources: {},
  queryTimeout: '',
  lookbackDelta: '',
  ports: {
    grpc: 10901,
    http: 9090,
  },
  serviceMonitor: false,
  logLevel: 'info',
  logFormat: 'logfmt',
  tracing: {},
  extraEnv: [],
  telemetryDurationQuantiles: '',
  telemetrySamplesQuantiles: '',
  telemetrySeriesQuantiles: '',

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-query',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'query-layer',
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
  local tq = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tq.config.replicas) && tq.config.replicas >= 0 : 'thanos query replicas has to be number >= 0',
  assert std.isArray(tq.config.replicaLabels),
  assert std.isObject(tq.config.resources),
  assert std.isString(tq.config.externalPrefix),
  assert std.isString(tq.config.queryTimeout),
  assert std.isBoolean(tq.config.serviceMonitor),
  assert std.isBoolean(tq.config.autoDownsampling),
  assert std.isBoolean(tq.config.useThanosEngine),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tq.config.name,
      namespace: tq.config.namespace,
      labels: tq.config.commonLabels,
    },
    spec: {
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tq.config.ports[name]),

          name: name,
          port: tq.config.ports[name],
          targetPort: tq.config.ports[name],
        }
        for name in std.objectFields(tq.config.ports)
      ],
      selector: tq.config.podLabelSelector,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tq.config.name,
      namespace: tq.config.namespace,
      labels: tq.config.commonLabels,
      annotations: tq.config.serviceAccountAnnotations,
    },
  },

  deployment:
    local c = {
      name: 'thanos-query',
      image: tq.config.image,
      imagePullPolicy: tq.config.imagePullPolicy,
      args:
        [
          'query',
          '--grpc-address=0.0.0.0:%d' % tq.config.ports.grpc,
          '--http-address=0.0.0.0:%d' % tq.config.ports.http,
          '--log.level=' + tq.config.logLevel,
          '--log.format=' + tq.config.logFormat,
        ] + [
          '--query.replica-label=%s' % labelName
          for labelName in tq.config.replicaLabels
        ] + [
          '--endpoint=%s' % store
          for store in tq.config.stores
        ] + [
          '--rule=%s' % store
          for store in tq.config.rules
        ] +
        (
          if tq.config.externalPrefix != '' then [
            '--web.external-prefix=' + tq.config.externalPrefix,
          ] else []
        ) +
        (
          if tq.config.prefixHeader != '' then [
            '--web.prefix-header=' + tq.config.prefixHeader,
          ] else []
        ) +
        (
          if tq.config.queryTimeout != '' then [
            '--query.timeout=' + tq.config.queryTimeout,
          ] else []
        ) +
        (
          if tq.config.lookbackDelta != '' then [
            '--query.lookback-delta=' + tq.config.lookbackDelta,
          ] else []
        ) + (
          if std.length(tq.config.tracing) > 0 then [
            '--tracing.config=' + std.manifestYamlDoc(
              { config+: { service_name: defaults.name } } + tq.config.tracing
            ),
          ] else []
        ) + (
          if tq.config.autoDownsampling then [
            '--query.auto-downsampling',
          ] else []
        ) + (
          if tq.config.useThanosEngine then [
            '--query.promql-engine=thanos',
          ] else []
        ) + (
          if tq.config.telemetryDurationQuantiles != '' then [
            '--query.telemetry.request-duration-seconds-quantiles=' + std.stripChars(quantile, ' ')
            for quantile in std.split(tq.config.telemetryDurationQuantiles, ',')
          ] else []
        ) + (
          if tq.config.telemetrySamplesQuantiles != '' then [
            '--query.telemetry.request-samples-quantiles=' + std.stripChars(quantile, ' ')
            for quantile in std.split(tq.config.telemetrySamplesQuantiles, ',')
          ] else []
        ) + (
          if tq.config.telemetrySeriesQuantiles != '' then [
            '--query.telemetry.request-series-seconds-quantiles=' + std.stripChars(quantile, ' ')
            for quantile in std.split(tq.config.telemetrySeriesQuantiles, ',')
          ] else []
        ),
      env: [
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
        if std.length(tq.config.extraEnv) > 0 then tq.config.extraEnv else []
      ),
      ports: [
        { name: port.name, containerPort: port.port }
        for port in tq.service.spec.ports
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tq.service.spec.ports[1].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tq.service.spec.ports[1].port,
        path: '/-/ready',
      } },
      resources: if tq.config.resources != {} then tq.config.resources else {},
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tq.config.name,
        namespace: tq.config.namespace,
        labels: tq.config.commonLabels,
      },
      spec: {
        replicas: tq.config.replicas,
        selector: { matchLabels: tq.config.podLabelSelector },
        template: {
          metadata: {
            labels: tq.config.commonLabels,
          },
          spec: {
            containers: [c],
            securityContext: tq.config.securityContext,
            serviceAccountName: tq.serviceAccount.metadata.name,
            terminationGracePeriodSeconds: 120,
            nodeSelector: {
              'kubernetes.io/os': 'linux',
            },
            affinity: { podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [{
                podAffinityTerm: {
                  namespaces: [tq.config.namespace],
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: { matchExpressions: [{
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [tq.deployment.metadata.labels['app.kubernetes.io/name']],
                  }] },
                },
                weight: 100,
              }],
            } },
          },
        },
      },
    },

  serviceMonitor: if tq.config.serviceMonitor == true then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: tq.config.name,
      namespace: tq.config.namespace,
      labels: tq.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: tq.config.podLabelSelector,
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
      ],
    },
  },
}
