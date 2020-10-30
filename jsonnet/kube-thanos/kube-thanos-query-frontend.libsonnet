// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-query-frontend',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  downstreamURL: error 'must provide downstreamURL',
  splitInterval: '24h',
  maxRetries: 5,
  logQueriesLongerThan: '0',
  fifoCache: {
    max_size: '0',  // Don't limit maximum item size.
    max_size_items: 2048,
    validity: '6h',
  },
  logLevel: 'info',
  resources: {},
  serviceMonitor: false,

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-query-frontend',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'query-cache',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local tqf = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tqf.config.replicas) && tqf.config.replicas >= 0 : 'thanos query frontend replicas has to be number >= 0',
  assert std.isObject(tqf.config.resources),
  assert std.isBoolean(tqf.config.serviceMonitor),
  assert std.isNumber(tqf.config.maxRetries),

  service:
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: tqf.config.name,
        namespace: tqf.config.namespace,
        labels: tqf.config.commonLabels,
      },
      spec: {
        selector: tqf.config.podLabelSelector,
        ports: [{ name: 'http', targetPort: 'http', port: 9090 }],
      },
    },

  deployment:
    local c = {
      name: 'thanos-query-frontend',
      image: tqf.config.image,
      args: [
        'query-frontend',
        '--query-frontend.compress-responses',
        '--http-address=0.0.0.0:%d' % tqf.service.spec.ports[0].port,
        '--query-frontend.downstream-url=%s' % tqf.config.downstreamURL,
        '--query-range.split-interval=%s' % tqf.config.splitInterval,
        '--query-range.max-retries-per-request=%d' % tqf.config.maxRetries,
        '--query-frontend.log-queries-longer-than=%s' % tqf.config.logQueriesLongerThan,
      ] + (
        if std.length(tqf.config.fifoCache) > 0 then [
          '--query-range.response-cache-config=' + std.manifestYamlDoc({
            type: 'in-memory',
            config: tqf.config.fifoCache,
          }),
        ] else []
      ),
      ports: [{ name: 'http', containerPort: tqf.service.spec.ports[0].port }],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tqf.service.spec.ports[0].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tqf.service.spec.ports[0].port,
        path: '/-/ready',
      } },
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
            terminationGracePeriodSeconds: 120,
            resources: if tqf.config.resources != {} then tqf.config.resources else {},
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
            sourceLabels: ['namespace', 'pod'],
            separator: '/',
            targetLabel: 'instance',
          }],
        },
      ],
    },
  },

}
