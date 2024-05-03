// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-query-frontend',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  imagePullPolicy: 'IfNotPresent',
  replicas: error 'must provide replicas',
  downstreamURL: error 'must provide downstreamURL',
  splitInterval: '24h',
  maxRetries: 5,
  logQueriesLongerThan: '0',
  fifoCache+:: {
    config+: {
      max_size: '0',  // Don't limit maximum item size.
      max_size_items: 2048,
      validity: '6h',
    },
  },
  queryRangeCache: {},
  labelsCache: {},
  logLevel: 'info',
  logFormat: 'logfmt',
  resources: {},
  serviceMonitor: false,
  ports: {
    http: 9090,
  },
  tracing: {},
  extraEnv: [],

  memcachedDefaults+:: {
    config+: {
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses+: error 'must provide memcached addresses',
      timeout: '500ms',
      max_idle_connections: 100,
      max_async_concurrency: 20,
      max_async_buffer_size: 10000,
      max_get_multi_concurrency: 100,
      max_get_multi_batch_size: 0,
      dns_provider_update_interval: '10s',
    },
  },

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-query-frontend',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'query-cache',
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
  local tqf = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params + {
    queryRangeCache+:
      if std.objectHas(params, 'queryRangeCache')
         && std.objectHas(params.queryRangeCache, 'type')
         && std.asciiUpper(params.queryRangeCache.type) == 'MEMCACHED' then

        defaults.memcachedDefaults + params.queryRangeCache
      else if std.objectHas(params, 'queryRangeCache')
              && std.objectHas(params.queryRangeCache, 'type')
              && std.asciiUpper(params.queryRangeCache.type) == 'IN-MEMORY' then

        defaults.fifoCache + params.queryRangeCache
      else {},
    labelsCache+:
      if std.objectHas(params, 'labelsCache')
         && std.objectHas(params.labelsCache, 'type')
         && std.asciiUpper(params.labelsCache.type) == 'MEMCACHED' then

        defaults.memcachedDefaults + params.labelsCache
      else if std.objectHas(params, 'labelsCache')
              && std.objectHas(params.labelsCache, 'type')
              && std.asciiUpper(params.labelsCache.type) == 'IN-MEMORY' then

        defaults.fifoCache + params.labelsCache
      else {},
  },
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tqf.config.replicas) && tqf.config.replicas >= 0 : 'thanos query frontend replicas has to be number >= 0',
  assert std.isObject(tqf.config.resources),
  assert std.isBoolean(tqf.config.serviceMonitor),
  assert std.isNumber(tqf.config.maxRetries) && tqf.config.maxRetries >= 0 : 'thanos query frontend maxRetries has to be number >= 0',

  networkPolicy: {
    kind: 'NetworkPolicy',
    apiVersion: 'networking.k8s.io/v1',
    metadata: {
      name: 'thanos-query-frontend',
      namespace: cfg.namespace,
    },
    spec: {
      podSelector: {
        matchLabels: {
          'app.kubernetes.io/name': 'thanos-query-frontend',
        },
      },
      egress: [{}],  // Allow all outside egress to connect
      ingress: [{
        from: [{
          namespaceSelector: {
            matchLabels: {
              'kubernetes.io/metadata.name': cfg.namespace,
            },
          },
          podSelector: {
            matchLabels: {
              'app.kubernetes.io/name': 'thanos-query',
            },
          },
        }],
      }],
      policyTypes: ['Egress'],
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tqf.config.name,
      namespace: tqf.config.namespace,
      labels: tqf.config.commonLabels,
    },
    spec: {
      selector: tqf.config.podLabelSelector,
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tqf.config.ports[name]),

          name: name,
          port: tqf.config.ports[name],
          targetPort: tqf.config.ports[name],
        }
        for name in std.objectFields(tqf.config.ports)
      ],
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tqf.config.name,
      namespace: tqf.config.namespace,
      labels: tqf.config.commonLabels,
      annotations: tqf.config.serviceAccountAnnotations,
    },
  },

  deployment:
    local c = {
      name: 'thanos-query-frontend',
      image: tqf.config.image,
      imagePullPolicy: tqf.config.imagePullPolicy,
      args: [
        'query-frontend',
        '--log.level=' + tqf.config.logLevel,
        '--log.format=' + tqf.config.logFormat,
        '--query-frontend.compress-responses',
        '--http-address=0.0.0.0:%d' % tqf.config.ports.http,
        '--query-frontend.downstream-url=%s' % tqf.config.downstreamURL,
        '--query-range.split-interval=%s' % tqf.config.splitInterval,
        '--labels.split-interval=%s' % tqf.config.splitInterval,
        '--query-range.max-retries-per-request=%d' % tqf.config.maxRetries,
        '--labels.max-retries-per-request=%d' % tqf.config.maxRetries,
        '--query-frontend.log-queries-longer-than=%s' % tqf.config.logQueriesLongerThan,
      ] + (
        if std.length(tqf.config.queryRangeCache) > 0 then [
          '--query-range.response-cache-config=' + std.manifestYamlDoc(
            tqf.config.queryRangeCache
          ),
        ] else []
      ) + (
        if std.length(tqf.config.labelsCache) > 0 then [
          '--labels.response-cache-config=' + std.manifestYamlDoc(
            tqf.config.labelsCache
          ),
        ] else []
      ) + (
        if std.length(tqf.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + tqf.config.tracing
          ),
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
        if std.length(tqf.config.extraEnv) > 0 then tqf.config.extraEnv else []
      ),
      ports: [
        { name: name, containerPort: tqf.config.ports[name] }
        for name in std.objectFields(tqf.config.ports)
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tqf.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tqf.config.ports.http,
        path: '/-/ready',
      } },
      resources: if tqf.config.resources != {} then tqf.config.resources else {},
      securityContext: tqf.config.securityContextContainer,
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tqf.config.name,
        namespace: tqf.config.namespace,
        labels: tqf.config.commonLabels,
      },
      spec: {
        replicas: tqf.config.replicas,
        selector: { matchLabels: tqf.config.podLabelSelector },
        template: {
          metadata: { labels: tqf.config.commonLabels },
          spec: {
            containers: [c],
            serviceAccountName: tqf.serviceAccount.metadata.name,
            securityContext: tqf.config.securityContext,
            terminationGracePeriodSeconds: 120,
            nodeSelector: {
              'kubernetes.io/os': 'linux',
            },
            affinity: { podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [{
                podAffinityTerm: {
                  namespaces: [tqf.config.namespace],
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: { matchExpressions: [{
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [tqf.deployment.metadata.labels['app.kubernetes.io/name']],
                  }] },
                },
                weight: 100,
              }],
            } },
          },
        },
      },
    },

  serviceMonitor: if tqf.config.serviceMonitor == true then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: tqf.config.name,
      namespace: tqf.config.namespace,
      labels: tqf.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: tqf.config.podLabelSelector,
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
