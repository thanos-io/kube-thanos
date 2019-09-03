local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    compactor+: {
      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          'thanos-compactor',
          $.thanos.compactor.deployment.metadata.labels,
          [
            ports.newNamed('http', 10902, 'http'),
          ],
        ) +
        service.mixin.metadata.withNamespace('monitoring') +
        service.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.compactor.service.metadata.name }),

      deployment:
        local deployment = k.apps.v1.deployment;
        local container = deployment.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;

        local c =
          container.new($.thanos.compactor.deployment.metadata.labels, $.thanos.variables.image) +
          container.withArgs([
            'compact',
            '--wait',
            '--retention.resolution-raw=16d',
            '--retention.resolution-5m=42d',
            '--retention.resolution-1h=180d',
            '--objstore.config=$(OBJSTORE_CONFIG)',
          ]) +
          container.withEnv([
            containerEnv.fromSecretRef(
              'OBJSTORE_CONFIG',
              $.thanos.store.variables.objectStorageConfig.name,
              $.thanos.store.variables.objectStorageConfig.key,
            ),
          ]) +
          container.withPorts([
            { name: 'http', containerPort: $.thanos.compactor.service.spec.ports[0].port },
          ])+
          container.mixin.resources.withRequests({ cpu: '100m', memory: '1Gi' }) +
          container.mixin.resources.withLimits({ cpu: '500m', memory: '2Gi' });

        deployment.new('thanos-compactor', 1, c, $.thanos.compactor.deployment.metadata.labels) +
        deployment.mixin.metadata.withNamespace('monitoring') +
        deployment.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.compactor.deployment.metadata.name }) +
        deployment.mixin.spec.selector.withMatchLabels($.thanos.compactor.deployment.metadata.labels),
    },
  },
}
