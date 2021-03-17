local defaults = import 'kube-thanos/kube-thanos-receive-default-params.libsonnet';

function(params) {
  local tr = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tr.config.replicas) && tr.config.replicas >= 0 : 'thanos receive replicas has to be number >= 0',
  assert std.isArray(tr.config.replicaLabels),
  assert std.isObject(tr.config.resources),
  assert std.isBoolean(tr.config.serviceMonitor),
  assert std.isObject(tr.config.volumeClaimTemplate),
  assert !std.objectHas(tr.config.volumeClaimTemplate, 'spec') || std.assertEqual(tr.config.volumeClaimTemplate.spec.accessModes, ['ReadWriteOnce']) : 'thanos receive PVC accessMode can only be ReadWriteOnce',

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tr.config.name,
      namespace: tr.config.namespace,
      labels: tr.config.commonLabels,
    },
    spec: {
      clusterIP: 'None',
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tr.config.ports[name]),

          name: name,
          port: tr.config.ports[name],
          targetPort: tr.config.ports[name],
        }
        for name in std.objectFields(tr.config.ports)
      ],
      selector: tr.config.podLabelSelector,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tr.config.name,
      namespace: tr.config.namespace,
      labels: tr.config.commonLabels,
    },
  },

  statefulSet:
    local localEndpointFlag = '--receive.local-endpoint=$(NAME).%s.$(NAMESPACE).svc.cluster.local:%d' % [
      tr.config.name,
      tr.config.ports.grpc,
    ];

    local c = {
      name: 'thanos-receive',
      image: tr.config.image,
      args: [
        'receive',
        '--log.level=' + tr.config.logLevel,
        '--log.format=' + tr.config.logFormat,
        '--grpc-address=0.0.0.0:%d' % tr.config.ports.grpc,
        '--http-address=0.0.0.0:%d' % tr.config.ports.http,
        '--remote-write.address=0.0.0.0:%d' % tr.config.ports['remote-write'],
        '--receive.replication-factor=%d' % tr.config.replicationFactor,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--tsdb.path=/var/thanos/receive',
        '--tsdb.retention=' + tr.config.retention,
        localEndpointFlag,
      ] + [
        '--label=%s' % label
        for label in tr.config.labels
      ] + (
        if tr.config.tenantLabelName != null then [
          '--receive.tenant-label-name=%s' % tr.config.tenantLabelName,
        ] else []
      ) + (
        if tr.config.hashringConfigMapName != '' then [
          '--receive.hashrings-file=/var/lib/thanos-receive/hashrings.json',
        ] else []
      ) + (
        if std.length(tr.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + tr.config.tracing
          ),
        ] else []
      ),
      env: [
        { name: 'NAME', valueFrom: { fieldRef: { fieldPath: 'metadata.name' } } },
        { name: 'NAMESPACE', valueFrom: { fieldRef: { fieldPath: 'metadata.namespace' } } },
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tr.config.objectStorageConfig.key,
          name: tr.config.objectStorageConfig.name,
        } } },
      ],
      ports: [
        { name: name, containerPort: tr.config.ports[name] }
        for name in std.objectFields(tr.config.ports)
      ],
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/receive',
        readOnly: false,
      }] + (
        if tr.config.hashringConfigMapName != '' then [
          { name: 'hashring-config', mountPath: '/var/lib/thanos-receive' },
        ] else []
      ),
      livenessProbe: { failureThreshold: 8, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tr.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tr.config.ports.http,
        path: '/-/ready',
      } },
      resources: if tr.config.resources != {} then tr.config.resources else {},
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'StatefulSet',
      metadata: {
        name: tr.config.name,
        namespace: tr.config.namespace,
        labels: tr.config.commonLabels,
      },
      spec: {
        replicas: tr.config.replicas,
        selector: { matchLabels: tr.config.podLabelSelector },
        serviceName: tr.service.metadata.name,
        template: {
          metadata: {
            labels: tr.config.commonLabels,
          },
          spec: {
            serviceAccountName: tr.serviceAccount.metadata.name,
            securityContext: tr.config.securityContext,
            containers: [c],
            volumes: if tr.config.hashringConfigMapName != '' then [{
              name: 'hashring-config',
              configMap: { name: tr.config.hashringConfigMapName },
            }] else [],
            terminationGracePeriodSeconds: 900,
            affinity: { podAntiAffinity: {
              local labelSelector = { matchExpressions: [{
                key: 'app.kubernetes.io/name',
                operator: 'In',
                values: [tr.statefulSet.metadata.labels['app.kubernetes.io/name']],
              }, {
                key: 'app.kubernetes.io/instance',
                operator: 'In',
                values: [tr.statefulSet.metadata.labels['app.kubernetes.io/instance']],
              }] },
              preferredDuringSchedulingIgnoredDuringExecution: [
                {
                  podAffinityTerm: {
                    namespaces: [tr.config.namespace],
                    topologyKey: 'kubernetes.io/hostname',
                    labelSelector: labelSelector,
                  },
                  weight: 100,
                },
                {
                  podAffinityTerm: {
                    namespaces: [tr.config.namespace],
                    topologyKey: 'topology.kubernetes.io/zone',
                    labelSelector: labelSelector,
                  },
                  weight: 100,
                },
              ],
            } },
          },
        },
        volumeClaimTemplates: if std.length(tr.config.volumeClaimTemplate) > 0 then [tr.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tr.config.podLabelSelector,
          },
        }] else [],
      },
    },

  serviceMonitor: if tr.config.serviceMonitor == true then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: tr.config.name,
      namespace: tr.config.namespace,
      labels: tr.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: tr.config.podLabelSelector,
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

  podDisruptionBudget: if tr.config.podDisruptionBudgetMaxUnavailable >= 1 then {
    apiVersion: 'policy/v1beta1',
    kind: 'PodDisruptionBudget',
    metadata: {
      name: tr.config.name,
      namespace: tr.config.namespace,
    },
    spec: {
      maxUnavailable: tr.config.podDisruptionBudgetMaxUnavailable,
      selector: { matchLabels: tr.config.podLabelSelector },
    },
  } else null,
}
