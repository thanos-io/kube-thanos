// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,

  name: error 'must provide name',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  objectStorageConfig: error 'must provide objectStorageConfig',
  ignoreDeletionMarksDelay: '',
  ports: {
    grpc: 10901,
    http: 10902,
  },
  resources: {},
  volumeClaimTemplate: error 'must provide volumeClaimTemplate',
  serviceMonitor: false,

  memcached: {
    // List of memcached addresses, that will get resolved with the DNS service discovery provider.
    // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
    addresses: [],
    timeout: '500ms',
    maxIdleConnections: 100,
    maxAsyncConcurrency: 20,
    maxAsyncBufferSize: 10000,
    maxItemSize: '1MiB',
    maxGetMultiConcurrency: 100,
    maxGetMultiBatchSize: 0,
    dnsProviderUpdateInterval: '10s',

    bucketCacheConfig+: {
      chunkSubrangeSize: 16000,
      maxChunksGetRangeRequests: 3,
      chunkObjectAttrsTTL: '24h',
      chunkSubrangeTTL: '24h',
      blocksIterTTL: '5m',
      metafileExistsTTL: '2h',
      metafileDoesntExistTTL: '15m',
      metafileContentTTL: '24h',
    },
  },

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-store',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'object-store-gateway',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local ts = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(ts.config.replicas) && ts.config.replicas >= 0 : 'thanos query replicas has to be number >= 0',
  assert std.isBoolean(ts.config.serviceMonitor),
  assert std.isArray(ts.config.memcached.addresses),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: ts.config.name,
      namespace: ts.config.namespace,
      labels: ts.config.commonLabels,
    },
    spec: {
      clusterIP: 'None',
      selector: ts.config.podLabelSelector,
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(ts.config.ports[name]),

          name: name,
          targetPort: ts.config.ports[name],
          port: ts.config.ports[name],
        }
        for name in std.objectFields(ts.config.ports)
      ],
    },
  },

  statefulSet: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: ts.config.name,
      namespace: ts.config.namespace,
      labels: ts.config.commonLabels,
    },
    spec: {
      replicas: ts.config.replicas,
      selector: { matchLabels: ts.config.podLabelSelector },
      serviceName: ts.service.metadata.name,
      template: {
        metadata: { labels: ts.config.commonLabels },
        spec: {
          containers: [{
            name: 'thanos-store',
            image: ts.config.image,
            args: [
              'store',
              '--data-dir=/var/thanos/store',
              '--grpc-address=0.0.0.0:%d' % ts.config.ports.grpc,
              '--http-address=0.0.0.0:%d' % ts.config.ports.http,
              '--objstore.config=$(OBJSTORE_CONFIG)',
            ] + (
              if ts.config.ignoreDeletionMarksDelay != '' then ['--ignore-deletion-marks-delay=' + ts.config.ignoreDeletionMarksDelay] else []
            ) + (
              // If we get addresses to memcached passed let's add the configuration as multi line string
              if ts.config.memcached.addresses != [] then [
                '--experimental.enable-index-cache-postings-compression',
                '--index-cache.config=' + std.manifestYamlDoc({
                  type: 'memcached',
                  local m = ts.config.memcached,
                  config: {
                    addresses: m.addresses,
                    timeout: m.timeout,
                    max_idle_connections: m.maxIdleConnections,
                    max_async_concurrency: m.maxAsyncConcurrency,
                    max_async_buffer_size: m.maxAsyncBufferSize,
                    max_item_size: m.maxItemSize,
                    max_get_multi_concurrency: m.maxGetMultiConcurrency,
                    max_get_multi_batch_size: m.maxGetMultiBatchSize,
                    dns_provider_update_interval: m.dnsProviderUpdateInterval,
                  },
                }),
              ] else []
            ) + (
              if ts.config.memcached.addresses != [] then [
                '--store.caching-bucket.config=' + std.manifestYamlDoc({
                  type: 'memcached',

                  local m = ts.config.memcached,
                  config: {
                    addresses: m.addresses,
                    timeout: m.timeout,
                    max_idle_connections: m.maxIdleConnections,
                    max_async_concurrency: m.maxAsyncConcurrency,
                    max_async_buffer_size: m.maxAsyncBufferSize,
                    max_item_size: m.maxItemSize,
                    max_get_multi_concurrency: m.maxGetMultiConcurrency,
                    max_get_multi_batch_size: m.maxGetMultiBatchSize,
                    dns_provider_update_interval: m.dnsProviderUpdateInterval,
                  },

                  local c = ts.config.memcached.bucketCacheConfig,
                  chunk_subrange_size: c.chunkSubrangeSize,
                  max_chunks_get_range_requests: c.maxChunksGetRangeRequests,
                  chunk_object_attrs_ttl: c.chunkObjectAttrsTTL,
                  chunk_subrange_ttl: c.chunkSubrangeTTL,
                  blocks_iter_ttl: c.blocksIterTTL,
                  metafile_exists_ttl: c.metafileExistsTTL,
                  metafile_doesnt_exist_ttl: c.metafileDoesntExistTTL,
                  metafile_content_ttl: c.metafileContentTTL,
                  metafile_max_size: m.maxItemSize,
                }),
              ] else []
            ),
            env: [{
              name: 'OBJSTORE_CONFIG',
              valueFrom: {
                secretKeyRef: {
                  key: ts.config.objectStorageConfig.key,
                  name: ts.config.objectStorageConfig.name,
                },
              },
            }],
            ports: [
              { name: name, containerPort: ts.config.ports[name] }
              for name in std.objectFields(ts.config.ports)
            ],
            livenessProbe: {
              failureThreshold: 8,
              httpGet: {
                path: '/-/healthy',
                port: ts.config.ports.http,
                scheme: 'HTTP',
              },
              periodSeconds: 30,
            },
            readinessProbe: {
              failureThreshold: 20,
              httpGet: {
                path: '/-/ready',
                port: ts.config.ports.http,
                scheme: 'HTTP',
              },
              periodSeconds: 5,
            },
            terminationMessagePolicy: 'FallbackToLogsOnError',
            resources: if ts.config.resources != {} then ts.config.resources else {},
            volumeMounts: [{
              mountPath: '/var/thanos/store',
              name: 'data',
              readOnly: false,
            }],
          }],
          volumes: [],
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
                          values: ['thanos-store'],
                        },
                        {
                          key: 'app.kubernetes.io/instance',
                          operator: 'In',
                          values: [ts.config.name],
                        },
                      ],
                    },
                    namespaces: [ts.config.namespace],
                    topologyKey: 'kubernetes.io/hostname',
                  },
                  weight: 100,
                },
              ],
            },
          },
        },
      },
      volumeClaimTemplates: [ts.config.volumeClaimTemplate {
        // overwrite metadata name and labels for consistency
        metadata+: {
          name: 'data',
          labels+: ts.config.podLabelSelector,
        },
      }],
    },
  },

  serviceMonitor: if ts.config.serviceMonitor == true then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: ts.config.name,
      namespace: ts.config.namespace,
      labels: ts.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: ts.config.podLabelSelector,
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
