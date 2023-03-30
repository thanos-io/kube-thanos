local receiveConfigDefaults = import 'kube-thanos/kube-thanos-receive-default-params.libsonnet';

local defaults = receiveConfigDefaults {
  hashrings: [{
    hashring: 'default',
    tenants: [],
  }],
  hashringConfigMapName: 'hashring-config',
  routerReplicas: 1,
  endpoints: error 'must provide ingestor endpoints object',
};

function(params) {
  local tr = self,
  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,

  routerLabels:: tr.config.commonLabels {
    'app.kubernetes.io/component': tr.config.name + '-router',
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tr.config.name + '-router',
      namespace: tr.config.namespace,
      labels: tr.routerLabels,
    },
    spec: {
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
      selector: tr.routerLabels,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: tr.config.name + '-router',
      namespace: tr.config.namespace,
      labels: tr.routerLabels,
      annotations: tr.config.serviceAccountAnnotations,
    },
  },

  configmap: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: tr.config.hashringConfigMapName,
      namespace: tr.config.namespace,
    },
    data: {
      'hashrings.json': std.toString([hashring { endpoints: tr.config.endpoints[hashring.hashring] } for hashring in tr.config.hashrings]),
    },
  },

  // Create the deployment that acts as a router to the ingestor backends
  deployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: tr.config.name + '-router',
      namespace: tr.config.namespace,
      labels: tr.routerLabels,
    },
    spec: {
      replicas: tr.config.routerReplicas,
      selector: { matchLabels: tr.routerLabels },
      template: {
        metadata: {
          labels: tr.routerLabels,
        },
        spec: {
          serviceAccountName: tr.serviceAccount.metadata.name,
          securityContext: tr.config.securityContext,
          containers: [{
            name: 'thanos-receive',
            image: tr.config.image,
            imagePullPolicy: tr.config.imagePullPolicy,
            args: [
              'receive',
              '--log.level=' + tr.config.logLevel,
              '--log.format=' + tr.config.logFormat,
              '--grpc-address=0.0.0.0:%d' % tr.config.ports.grpc,
              '--http-address=0.0.0.0:%d' % tr.config.ports.http,
              '--remote-write.address=0.0.0.0:%d' % tr.config.ports['remote-write'],
              '--receive.replication-factor=%d' % tr.config.replicationFactor,
              '--receive.hashrings-file=/var/lib/thanos-receive/hashrings.json',
            ] + [
              '--label=%s' % label
              for label in tr.config.labels
            ] + (
              if tr.config.tenantLabelName != null then [
                '--receive.tenant-label-name=%s' % tr.config.tenantLabelName,
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
              if std.length(tr.config.extraEnv) > 0 then tr.config.extraEnv else []
            ),
            ports: [{ name: name, containerPort: tr.config.ports[name] } for name in std.objectFields(tr.config.ports)],
            volumeMounts: [{ name: 'hashring-config', mountPath: '/var/lib/thanos-receive' }],
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
          }],
          volumes: [{
            name: 'hashring-config',
            configMap: { name: tr.config.hashringConfigMapName },
          }],
          terminationGracePeriodSeconds: 30,
          nodeSelector: {
            'kubernetes.io/os': 'linux',
          },
        },
      },
    },
  },
}
