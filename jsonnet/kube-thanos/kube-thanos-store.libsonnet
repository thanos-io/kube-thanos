local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local ts = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-store',
      'app.kubernetes.io/instance': ts.config.name,
      'app.kubernetes.io/version': ts.config.version,
      'app.kubernetes.io/component': 'object-store-gateway',
    },

    podLabelSelector:: {
      [labelName]: ts.config.commonLabels[labelName]
      for labelName in std.objectFields(ts.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      ts.config.name,
      ts.config.podLabelSelector,
      [
        ports.newNamed('grpc', 10901, 10901),
        ports.newNamed('http', 10902, 10902),
      ]
    ) +
    service.mixin.metadata.withNamespace(ts.config.namespace) +
    service.mixin.metadata.withLabels(ts.config.commonLabels) +
    service.mixin.spec.withClusterIp('None'),

  statefulSet:
    local sts = k.apps.v1.statefulSet;
    local volume = sts.mixin.spec.template.spec.volumesType;
    local container = sts.mixin.spec.template.spec.containersType;
    local containerEnv = container.envType;
    local containerVolumeMount = container.volumeMountsType;
    local affinity = sts.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
    local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;

    local c =
      container.new('thanos-store', ts.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs([
        'store',
        '--log.level=' + ts.config.logLevel,
        '--data-dir=/var/thanos/store',
        '--grpc-address=0.0.0.0:%d' % ts.service.spec.ports[0].port,
        '--http-address=0.0.0.0:%d' % ts.service.spec.ports[1].port,
        '--objstore.config=$(OBJSTORE_CONFIG)',
      ]) +
      container.withEnv([
        containerEnv.fromSecretRef(
          'OBJSTORE_CONFIG',
          ts.config.objectStorageConfig.name,
          ts.config.objectStorageConfig.key,
        ),
      ]) +
      container.withPorts([
        { name: 'grpc', containerPort: ts.service.spec.ports[0].port },
        { name: 'http', containerPort: ts.service.spec.ports[1].port },
      ]) +
      container.withVolumeMounts([
        containerVolumeMount.new('data', '/var/thanos/store', false),
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(8) +
      container.mixin.livenessProbe.httpGet.withPort(ts.service.spec.ports[1].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(ts.service.spec.ports[1].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    sts.new(ts.config.name, ts.config.replicas, c, [], ts.config.commonLabels) +
    sts.mixin.metadata.withNamespace(ts.config.namespace) +
    sts.mixin.metadata.withLabels(ts.config.commonLabels) +
    sts.mixin.spec.withServiceName(ts.service.metadata.name) +
    sts.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
    sts.mixin.spec.template.spec.withVolumes([
      volume.fromEmptyDir('data'),
    ]) +
    sts.mixin.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
      affinity.new() +
      affinity.withWeight(100) +
      affinity.mixin.podAffinityTerm.withNamespaces(ts.config.namespace) +
      affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
      affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/name') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([ts.statefulSet.metadata.labels['app.kubernetes.io/name']]),
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/instance') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([ts.statefulSet.metadata.labels['app.kubernetes.io/instance']]),
      ]),
    ]) +
    sts.mixin.spec.selector.withMatchLabels(ts.config.podLabelSelector) +
    {
      spec+: {
        volumeClaimTemplates: null,
      },
    },

  withIgnoreDeletionMarksDelay:: {
    local ts = self,
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-store' then c {
                args+: [
                  '--ignore-deletion-marks-delay=' + ts.config.ignoreDeletionMarksDelay,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  local memcachedDefaults = {
    // List of memcached addresses, that will get resolved with the DNS service discovery provider.
    // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
    addresses: error 'must provide memcached addresses',
    timeout: '500ms',
    maxIdleConnections: 100,
    maxAsyncConcurrency: 20,
    maxAsyncBufferSize: 10000,
    maxItemSize: '1MiB',
    maxGetMultiConcurrency: 100,
    maxGetMultiBatchSize: 0,
    dnsProviderUpdateInterval: '10s',
  },

  withIndexCacheMemcached:: {
    local ts = self,
    config+:: {
      memcached+: memcachedDefaults,
    },
    local m = if std.objectHas(ts.config.memcached, 'indexCache')
    then
      ts.config.memcached.indexCache
    else
      ts.config.memcached,
    local cfg =
      {
        type: 'memcached',
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
      },
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-store' then c {
                args+: if m != {} then [
                  '--experimental.enable-index-cache-postings-compression',
                  '--index-cache.config=' + std.manifestYamlDoc(cfg),
                ] else [],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withCachingBucketMemcached:: {
    local ts = self,
    config+:: {
      memcached+: memcachedDefaults,
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
    local m = if std.objectHas(ts.config.memcached, 'bucketCache')
    then
      ts.config.memcached.bucketCache
    else
      ts.config.memcached,
    local c = ts.config.bucketCacheConfig,
    local cfg =
      {
        type: 'memcached',
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

        chunk_subrange_size: c.chunkSubrangeSize,
        max_chunks_get_range_requests: c.maxChunksGetRangeRequests,
        chunk_object_attrs_ttl: c.chunkObjectAttrsTTL,
        chunk_subrange_ttl: c.chunkSubrangeTTL,
        blocks_iter_ttl: c.blocksIterTTL,
        metafile_exists_ttl: c.metafileExistsTTL,
        metafile_doesnt_exist_ttl: c.metafileDoesntExistTTL,
        metafile_content_ttl: c.metafileContentTTL,
        metafile_max_size: m.maxItemSize,
      },
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-store' then c {
                args+: if m != {} then [
                  '--store.caching-bucket.config=' + std.manifestYamlDoc(cfg),
                ] else [],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withServiceMonitor:: {
    local ts = self,
    serviceMonitor: {
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
  },

  withVolumeClaimTemplate:: {
    local ts = self,
    config+:: {
      volumeClaimTemplate: error 'must provide volumeClaimTemplate',
    },
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            volumes: std.filter(function(v) v.name != 'data', super.volumes),
          },
        },
        volumeClaimTemplates: [ts.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: ts.config.podLabelSelector,
          },
        }],
      },
    },
  },

  withResources:: {
    local ts = self,
    config+:: {
      resources: error 'must provide resources',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-store' then c {
                resources: ts.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
