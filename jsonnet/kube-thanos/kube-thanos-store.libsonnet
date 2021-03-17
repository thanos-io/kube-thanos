local defaults = import 'kube-thanos/kube-thanos-store-default-params.libsonnet';

function(params) {
  local ts = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params + {
    // If indexCache is given and of type memcached, merge defaults with params
    indexCache+:
      if std.objectHas(params, 'indexCache')
         && std.objectHas(params.indexCache, 'type')
         && std.asciiUpper(params.indexCache.type) == 'MEMCACHED' then
        defaults.memcachedDefaults + defaults.indexCacheDefaults + params.indexCache
      else {},
    bucketCache+:
      if std.objectHas(params, 'bucketCache')
         && std.objectHas(params.bucketCache, 'type')
         && std.asciiUpper(params.bucketCache.type) == 'MEMCACHED' then
        defaults.memcachedDefaults + defaults.bucketCacheMemcachedDefaults + params.bucketCache
      else {},
  },

  // Safety checks for combined config of defaults and params
  assert std.isNumber(ts.config.replicas) && ts.config.replicas >= 0 : 'thanos store replicas has to be number >= 0',
  assert std.isObject(ts.config.resources),
  assert std.isBoolean(ts.config.serviceMonitor),
  assert std.isObject(ts.config.volumeClaimTemplate),
  assert !std.objectHas(ts.config.volumeClaimTemplate, 'spec') || std.assertEqual(ts.config.volumeClaimTemplate.spec.accessModes, ['ReadWriteOnce']) : 'thanos store PVC accessMode can only be ReadWriteOnce',

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
          port: ts.config.ports[name],
          targetPort: ts.config.ports[name],
        }
        for name in std.objectFields(ts.config.ports)
      ],
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: ts.config.name,
      namespace: ts.config.namespace,
      labels: ts.config.commonLabels,
    },
  },

  statefulSet:
    local c = {
      name: 'thanos-store',
      image: ts.config.image,
      args: [
        'store',
        '--log.level=' + ts.config.logLevel,
        '--log.format=' + ts.config.logFormat,
        '--data-dir=/var/thanos/store',
        '--grpc-address=0.0.0.0:%d' % ts.config.ports.grpc,
        '--http-address=0.0.0.0:%d' % ts.config.ports.http,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--ignore-deletion-marks-delay=' + ts.config.ignoreDeletionMarksDelay,
      ] + (
        if std.length(ts.config.indexCache) > 0 then [
          '--index-cache.config=' + std.manifestYamlDoc(ts.config.indexCache),
        ] else []
      ) + (
        if std.length(ts.config.bucketCache) > 0 then [
          '--store.caching-bucket.config=' + std.manifestYamlDoc(ts.config.bucketCache),
        ] else []
      ) + (
        if std.length(ts.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + ts.config.tracing
          ),
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
            serviceAccountName: ts.serviceAccount.metadata.name,
            securityContext: ts.config.securityContext,
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
