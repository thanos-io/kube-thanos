{
  local tb = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-bucket',
      'app.kubernetes.io/instance': tb.config.name,
      'app.kubernetes.io/version': tb.config.version,
      'app.kubernetes.io/component': 'object-store-bucket-debugging',
    },

    podLabelSelector:: {
      [labelName]: tb.config.commonLabels[labelName]
      for labelName in std.objectFields(tb.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: tb.config.name,
        namespace: tb.config.namespace,
        labels: tb.config.commonLabels,
      },
      spec: {
        ports: [{ name: 'http', targetPort: 'http', port: 10902 }],
        selector: tb.config.podLabelSelector,
      },
    },

  deployment:
    local container = {
      name: 'thanos-bucket',
      image: tb.config.image,
      args: [
        'tools',
        'bucket',
        'web',
        '--log.level=' + tb.config.logLevel,
        '--objstore.config=$(OBJSTORE_CONFIG)',
      ],
      env: [
        { name: 'OBJSTORE_CONFIG', valueFrom: { secretKeyRef: {
          key: tb.config.objectStorageConfig.key,
          name: tb.config.objectStorageConfig.name,
        } } },
      ],
      ports: [{ name: 'http', containerPort: tb.service.spec.ports[0].port }],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tb.service.spec.ports[0].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tb.service.spec.ports[0].port,
        path: '/-/ready',
      } },
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tb.config.name,
        namespace: tb.config.namespace,
        labels: tb.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: tb.config.podLabelSelector },
        template: {
          metadata: { labels: tb.config.commonLabels },
          spec: {
            containers: [container],
            terminationGracePeriodSeconds: 120,
          },
        },
      },
    },

  withResources:: {
    local tb = self,
    config+:: {
      resources: error 'must provide resources',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-bucket' then c {
                resources: tb.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
