local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    querier+: {
      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          'thanos-querier',
          $.thanos.querier.deployment.metadata.labels,
          [
            ports.newNamed('grpc', 10901, 10901),
            ports.newNamed('http', 9090, 10902),
          ]
        ) +
        service.mixin.metadata.withNamespace('monitoring') +
        service.mixin.metadata.withLabels({ app: $.thanos.querier.service.metadata.name }),

      deployment:
        local deployment = k.apps.v1.deployment;
        local container = deployment.mixin.spec.template.spec.containersType;

        local c =
          container.new($.thanos.querier.deployment.metadata.name, $.thanos.variables.image) +
          container.withArgs(['query', '--query.replica-label=replica']);

        deployment.new('thanos-querier', 1, c, $.thanos.querier.deployment.metadata.labels) +
        deployment.mixin.metadata.withNamespace('monitoring') +
        deployment.mixin.metadata.withLabels({ app: $.thanos.querier.deployment.metadata.name }) +
        deployment.mixin.spec.selector.withMatchLabels($.thanos.querier.deployment.metadata.labels),
    },
  },
}
