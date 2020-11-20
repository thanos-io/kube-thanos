// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
{
  local defaults = self,
  name: 'thanos-store',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  replicas: error 'must provide replicas',
  objectStorageConfig: error 'must provide objectStorageConfig',
  ignoreDeletionMarksDelay: '24h',
  logLevel: 'info',
  logFormat: 'logfmt',
  resources: {},
  volumeClaimTemplate: {},
  serviceMonitor: false,
  bucketCache: {},
  indexCache: {},
  ports: {
    grpc: 10901,
    http: 10902,
  },
  tracing: {},

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
}
