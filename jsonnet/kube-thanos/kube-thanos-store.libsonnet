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
          { name: 'grpc', targetPort: 'grpc', port: 10901 },
          { name: 'http', targetPort: 'http', port: 10902 },
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
        '--grpc-address=0.0.0.0:%d' % ts.service.spec.ports[0].port,
        '--http-address=0.0.0.0:%d' % ts.service.spec.ports[1].port,
        '--objstore.config=$(OBJSTORE_CONFIG)',
      ],
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: ts.config.objectStorageConfig.key,
          name: ts.config.objectStorageConfig.name,
        } } },
      ],
      ports: [
        { name: port.name, containerPort: port.port }
        for port in ts.service.spec.ports
      ],
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/store',
        readOnly: false,
      }],
      livenessProbe: { failureThreshold: 8, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: ts.service.spec.ports[1].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: ts.service.spec.ports[1].port,
        path: '/-/ready',
      } },
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
