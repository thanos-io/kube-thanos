// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-query',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  replicaLabels: error 'must provide replicaLabels',
  stores: ['dnssrv+_grpc._tcp.thanos-store.%s.svc.cluster.local' % defaults.namespace],
  externalPrefix: '',
  resources: {},
  queryTimeout: '',
  ports: {
    grpc: 10901,
    http: 9090,
  },
  serviceMonitor: false,

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-query',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'query-layer',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
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

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tq.config.name,
      namespace: tq.config.namespace,
      labels: tq.config.commonLabels,
    },
    spec: {
      selector: tq.config.podLabelSelector,
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tq.config.ports[name]),

          name: name,
          targetPort: name,
          port: tq.config.ports[name],
        }
        for name in std.objectFields(tq.config.ports)
      ],
    },
  },

  deployment: {
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
        metadata: { labels: tq.config.commonLabels },
        spec: {
          containers: [
            {
              name: tq.config.name,
              image: tq.config.image,
              args:
                [
                  'query',
                  '--grpc-address=0.0.0.0:%d' % tq.config.ports.grpc,
                  '--http-address=0.0.0.0:%d' % tq.config.ports.http,
                ] + [
                  '--query.replica-label=%s' % labelName
                  for labelName in tq.config.replicaLabels
                ] + [
                  '--store=%s' % store
                  for store in tq.config.stores
                ] +
                (
                  if tq.config.externalPrefix != '' then [
                    '--web.external-prefix=' + tq.config.externalPrefix,
                  ] else []
                ) +
                (
                  if tq.config.queryTimeout != '' then [
                    '--query.timeout=' + tq.config.queryTimeout,
                  ] else []
                ),
              ports: [
                { name: name, containerPort: tq.config.ports[name] }
                for name in std.objectFields(tq.config.ports)
              ],
              livenessProbe: {
                failureThreshold: 4,
                httpGet: {
                  path: '/-/healthy',
                  port: tq.config.ports.http,
                  scheme: 'HTTP',
                },
                periodSeconds: 30,
              },
              readinessProbe: {
                failureThreshold: 20,
                httpGet: {
                  path: '/-/ready',
                  port: tq.config.ports.http,
                  scheme: 'HTTP',
                },
                periodSeconds: 5,
              },
              terminationMessagePolicy: 'FallbackToLogsOnError',
              resources: if tq.config.resources != {} then tq.config.resources else {},
            },
          ],
          terminationGracePeriodSeconds: 120,
          affinity: {
            podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [
                {
                  podAffinityTerm: {
                    labelSelector: {
                      matchExpressions: [
                        {
                          key: 'app.kubernetes.io/name',
                          operator: 'In',
                          values: [tq.config.name],
                        },
                      ],
                    },
                    namespaces: [tq.config.namespace],
                    topologyKey: 'kubernetes.io/hostname',
                  },
                  weight: 100,
                },
              ],
            },
          },
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
            sourceLabels: ['namespace', 'pod'],
            separator: '/',
            targetLabel: 'instance',
          }],
        },
      ],
    },
  } else null,
}
