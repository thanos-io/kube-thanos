local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    querier+: {
      variables+: {
        name: 'thanos-querier',
        namespace: 'monitoring',
        labels: { app: $.thanos.querier.variables.name },
        images: {
          thanos: $.thanos.variables.images.thanos,
        },
      },

      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          $.thanos.querier.variables.name,
          $.thanos.querier.variables.labels,
          [
            ports.newNamed('grpc', 10901, 10901),
            ports.newNamed('http', 9090, 10902),
          ]
        ) +
        service.mixin.metadata.withNamespace($.thanos.querier.variables.namespace) +
        service.mixin.metadata.withLabels($.thanos.querier.variables.labels),

      deployment:
        local deployment = k.apps.v1.deployment;
        local container = deployment.mixin.spec.template.spec.containersType;

        local args = [
          'query',
          '--query.replica-label=replica',
          // '--store=dnssrv+%s.%s.svc.cluster.local:%d' % [
          //   $.thanos.store.service.metadata.name,
          //   $.thanos.store.service.metadata.namespace,
          //   12314,
          // ],
        ];

        local c =
          container.new($.thanos.querier.variables.name, $.thanos.querier.variables.images.thanos) +
          container.withArgs(args);

        deployment.new($.thanos.querier.variables.name, 1, c, $.thanos.querier.variables.labels) +
        deployment.mixin.metadata.withNamespace($.thanos.querier.variables.namespace) +
        deployment.mixin.spec.selector.withMatchLabels($.thanos.querier.variables.labels),
    },
  },
}
