local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    bucket+: {
      local tb = self,
      name:: 'thanos-bucket',
      namespace:: 'monitoring',
      image:: $.thanos.image,
      labels+:: {
        'app.kubernetes.io/name': tb.name,
      },
      objectStorageConfig:: $.thanos.objectStorageConfig,
      ports:: {
        http: 8080,
      },

      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          tb.name,
          tb.labels,
          [ports.newNamed('http', tb.ports.http, 'http')],
        ) +
        service.mixin.metadata.withNamespace(tb.namespace) +
        service.mixin.metadata.withLabels(tb.labels),

      deployment:
        local deployment = k.apps.v1.deployment;
        local container = deployment.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;

        local c =
          container.new(tb.name, tb.image) +
          container.withArgs([
            'bucket',
            'web',
            '--objstore.config=$(OBJSTORE_CONFIG)',
          ]) +
          container.withEnv([
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              tb.objectStorageConfig.name,
              tb.objectStorageConfig.key,
            ),
          ]) +
          container.mixin.resources.withRequests({ cpu: '100m', memory: '256Mi' }) +
          container.mixin.resources.withLimits({ cpu: '250m', memory: '512Mi' }) +
          container.withPorts([
            { name: 'http', containerPort: tb.ports.http },
          ]);

        deployment.new(tb.name, 1, c, $.thanos.bucket.deployment.metadata.labels) +
        deployment.mixin.metadata.withNamespace(tb.namespace) +
        deployment.mixin.metadata.withLabels({ 'app.kubernetes.io/name': tb.name }) +
        deployment.mixin.spec.selector.withMatchLabels(tb.labels),
    },
  },
}
