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
            ports.newNamed('grpc', 10901, 'grpc'),
            ports.newNamed('http', 9090, 'http'),
          ]
        ) +
        service.mixin.metadata.withNamespace('monitoring') +
        service.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.querier.service.metadata.name }),

      deployment:
        local deployment = k.apps.v1.deployment;
        local container = deployment.mixin.spec.template.spec.containersType;

        local c =
          container.new($.thanos.querier.deployment.metadata.name, $.thanos.variables.image) +
          container.withArgs([
            'query',
            '--query.replica-label=replica',
            '--grpc-address=0.0.0.0:%d' % $.thanos.querier.service.spec.ports[0].port,
            '--http-address=0.0.0.0:%d' % $.thanos.querier.service.spec.ports[1].port,
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: $.thanos.querier.service.spec.ports[0].port },
            { name: 'http', containerPort: $.thanos.querier.service.spec.ports[1].port },
          ]);

        deployment.new('thanos-querier', 1, c, $.thanos.querier.deployment.metadata.labels) +
        deployment.mixin.metadata.withNamespace('monitoring') +
        deployment.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.querier.deployment.metadata.name }) +

        deployment.mixin.spec.selector.withMatchLabels($.thanos.querier.deployment.metadata.labels),
    },
  },
}
