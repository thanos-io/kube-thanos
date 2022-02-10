local defaults = import 'kube-thanos/kube-thanos-compact-default-params.libsonnet';

function(params) {
  local tc = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params
  assert std.isNumber(tc.config.compactConcurrency),
  assert std.isNumber(tc.config.downsampleConcurrency),
  assert std.isNumber(tc.config.replicas) && (tc.config.replicas == 0 || tc.config.replicas == 1) : 'thanos compact replicas can only be 0 or 1',
  assert std.isObject(tc.config.resources),
  assert std.isObject(tc.config.volumeClaimTemplate),
  assert !std.objectHas(tc.config.volumeClaimTemplate, 'spec') || std.assertEqual(tc.config.volumeClaimTemplate.spec.accessModes, ['ReadWriteOnce']) : 'thanos compact PVC accessMode can only be ReadWriteOnce',
  assert std.isBoolean(tc.config.serviceMonitor),
  assert std.isArray(tc.config.deduplicationReplicaLabels),

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tc.config.name,
      namespace: tc.config.namespace,
      labels: tc.config.commonLabels,
    },
    spec: {
      clusterIP: 'None',
      selector: tc.config.podLabelSelector,
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tc.config.ports[name]),

          name: name,
          port: tc.config.ports[name],
          targetPort: tc.config.ports[name],
        }
        for name in std.objectFields(tc.config.ports)
      ],
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tc.config.name,
      namespace: tc.config.namespace,
      labels: tc.config.commonLabels,
    },
  },

  statefulSet:
    local c = {
      name: 'thanos-compact',
      image: tc.config.image,
      imagePullPolicy: tc.config.imagePullPolicy,
      args: [
        'compact',
        '--wait',
        '--log.level=' + tc.config.logLevel,
        '--log.format=' + tc.config.logFormat,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--data-dir=/var/thanos/compact',
        '--debug.accept-malformed-index',
        '--retention.resolution-raw=' + tc.config.retentionResolutionRaw,
        '--retention.resolution-5m=' + tc.config.retentionResolution5m,
        '--retention.resolution-1h=' + tc.config.retentionResolution1h,
        '--delete-delay=' + tc.config.deleteDelay,
        '--compact.concurrency=' + tc.config.compactConcurrency,
        '--downsample.concurrency=' + tc.config.downsampleConcurrency,
      ] + (
        if tc.config.disableDownsampling then ['--downsampling.disable'] else []
      ) + (
        if std.length(tc.config.deduplicationReplicaLabels) > 0 then
          [
            '--deduplication.replica-label=' + l
            for l in tc.config.deduplicationReplicaLabels
          ] else []
      ) + (
        if std.length(tc.config.tracing) > 0 then [
          '--tracing.config=' + std.manifestYamlDoc(
            { config+: { service_name: defaults.name } } + tc.config.tracing
          ),
        ] else []
      ),
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tc.config.objectStorageConfig.key,
          name: tc.config.objectStorageConfig.name,
        } } },
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
        if std.length(tc.config.extraEnv) > 0 then tc.config.extraEnv else []
      ),
      ports: [
        { name: name, containerPort: tc.config.ports[name] }
        for name in std.objectFields(tc.config.ports)
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tc.config.ports.http,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tc.config.ports.http,
        path: '/-/ready',
      } },
      volumeMounts: [{
        name: 'data',
        mountPath: '/var/thanos/compact',
        readOnly: false,
      }] + (
        if std.objectHas(tc.config.objectStorageConfig, 'tlsSecretName') && std.length(tc.config.objectStorageConfig.tlsSecretName) > 0 then [
          { name: 'tls-secret', mountPath: tc.config.objectStorageConfig.tlsSecretMountPath },
        ] else []
      ),
      resources: if tc.config.resources != {} then tc.config.resources else {},
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'StatefulSet',
      metadata: {
        name: tc.config.name,
        namespace: tc.config.namespace,
        labels: tc.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: tc.config.podLabelSelector },
        serviceName: tc.service.metadata.name,
        template: {
          metadata: {
            labels: tc.config.commonLabels,
          },
          spec: {
            serviceAccountName: tc.serviceAccount.metadata.name,
            securityContext: tc.config.securityContext,
            containers: [c],
            volumes: if std.objectHas(tc.config.objectStorageConfig, 'tlsSecretName') && std.length(tc.config.objectStorageConfig.tlsSecretName) > 0 then [{
              name: 'tls-secret',
              secret: { secretName: tc.config.objectStorageConfig.tlsSecretName },
            }] else [],
            terminationGracePeriodSeconds: 120,
            nodeSelector: {
              'kubernetes.io/os': 'linux',
            },
            affinity: { podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [{
                podAffinityTerm: {
                  namespaces: [tc.config.namespace],
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: { matchExpressions: [{
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [tc.statefulSet.metadata.labels['app.kubernetes.io/name']],
                  }, {
                    key: 'app.kubernetes.io/instance',
                    operator: 'In',
                    values: [tc.statefulSet.metadata.labels['app.kubernetes.io/instance']],
                  }] },
                },
                weight: 100,
              }],
            } },
          },
        },
        volumeClaimTemplates: if std.length(tc.config.volumeClaimTemplate) > 0 then [tc.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tc.config.podLabelSelector,
          },
        }] else [],
      },
    },

  serviceMonitor: if tc.config.serviceMonitor == true then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: tc.config.name,
      namespace: tc.config.namespace,
      labels: tc.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: tc.config.podLabelSelector,
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
