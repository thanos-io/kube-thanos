// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-store',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  objectStorageConfig: error 'must provide objectStorageConfig',
  ignoreDeletionMarksDelay: '24h',
  logLevel: 'info',
  resources: {},
  volumeClaimTemplate: {},
  serviceMonitor: false,
  bucketCache: {},
  indexCache: {},
  ports: {
    grpc: 10901,
    http: 10902,
  },

  memcachedDefaults+:: {
    config+: {
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses+: error 'must provide memcached addresses',
      timeout: '500ms',
      max_idle_connections: 100,
      max_async_concurrency: 20,
      max_async_buffer_size: 10000,
      max_item_size: '1MiB',
      max_get_multi_concurrency: 100,
      max_get_multi_batch_size: 0,
      dns_provider_update_interval: '10s',
    },
  },

  indexCacheDefaults+:: {},

  bucketCacheMemcachedDefaults+:: {
    chunk_subrange_size: 16000,
    max_chunks_get_range_requests: 3,
    chunk_object_attrs_ttl: '24h',
    chunk_subrange_ttl: '24h',
    blocks_iter_ttl: '5m',
    metafile_exists_ttl: '2h',
    metafile_doesnt_exist_ttl: '15m',
    metafile_content_ttl: '24h',
    metafile_max_size: '1MiB',
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
  config:: defaults + params + {
    // If indexCache is given and of type memcached, merge defaults with params
    indexCache+:
      if std.objectHas(params, 'indexCache') && params.indexCache.type == 'memcached' then
        defaults.memcachedDefaults + defaults.indexCacheDefaults + params.indexCache
      else {},
    bucketCache+:
      if std.objectHas(params, 'bucketCache') && params.bucketCache.type == 'memcached' then
        defaults.memcachedDefaults + defaults.bucketCacheMemcachedDefaults + params.bucketCache
      else {},
  },

  // Safety checks for combined config of defaults and params
  assert std.isNumber(ts.config.replicas) && ts.config.replicas >= 0 : 'thanos receive replicas has to be number >= 0',
  assert std.isObject(ts.config.resources),
  assert std.isBoolean(ts.config.serviceMonitor),
  assert std.isObject(ts.config.volumeClaimTemplate),

  service:
    {
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
            port: ts.config.ports[name],
            targetPort: ts.config.ports[name],
          }
          for name in std.objectFields(ts.config.ports)
        ],
      },
    },

  statefulSet:
    local c = {
      name: 'thanos-store',
      image: ts.config.image,
      args: [
        'store',
        '--log.level=' + ts.config.logLevel,
        '--data-dir=/var/thanos/store',
        '--grpc-address=0.0.0.0:%d' % ts.config.ports.grpc,
        '--http-address=0.0.0.0:%d' % ts.config.ports.http,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--ignore-deletion-marks-delay=' + ts.config.ignoreDeletionMarksDelay,
      ] + (
        if std.length(ts.config.indexCache) > 0 then [
          '--experimental.enable-index-cache-postings-compression',
          '--index-cache.config=' + std.manifestYamlDoc(ts.config.indexCache),
        ] else []
      ) + (
        if std.length(ts.config.bucketCache) > 0 then [
          '--store.caching-bucket.config=' + std.manifestYamlDoc(ts.config.bucketCache),
        ] else []
      ),
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: ts.config.objectStorageConfig.key,
          name: ts.config.objectStorageConfig.name,
        } } },
      ],
      ports: [
        { name: name, containerPort: ts.config.ports[name] }
        for name in std.objectFields(ts.config.ports)
      ],
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/store',
        readOnly: false,
      }],
      livenessProbe: { failureThreshold: 8, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: ts.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: ts.config.ports.http,
        path: '/-/ready',
      } },
      resources: if ts.config.resources != {} then ts.config.resources else {},
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
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
          metadata: {
            labels: ts.config.commonLabels,
          },
          spec: {
            containers: [c],
            volumes: [],
            terminationGracePeriodSeconds: 120,
            affinity: { podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [{
                podAffinityTerm: {
                  namespaces: [ts.config.namespace],
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: { matchExpressions: [{
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [ts.statefulSet.metadata.labels['app.kubernetes.io/name']],
                  }, {
                    key: 'app.kubernetes.io/instance',
                    operator: 'In',
                    values: [ts.statefulSet.metadata.labels['app.kubernetes.io/instance']],
                  }] },
                },
                weight: 100,
              }],
            } },
          },
        },
        volumeClaimTemplates: if std.length(ts.config.volumeClaimTemplate) > 0 then [ts.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: ts.config.podLabelSelector,
          },
        }] else [],
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
  },
}
