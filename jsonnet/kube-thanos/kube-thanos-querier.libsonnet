local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    namespace:: 'monitoring',
    image:: error 'must set thanos image',

    querier+: {
      local tq = self,
      name:: 'thanos-querier',
      namespace:: $.thanos.namespace,
      image:: $.thanos.image,
      replicas:: 1,
      replicaLabel:: 'prometheus_replica',

      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          tq.name,
          $.thanos.querier.deployment.metadata.labels,
          [
            ports.newNamed('grpc', 10901, 'grpc'),
            ports.newNamed('http', 9090, 'http'),
          ]
        ) +
        service.mixin.metadata.withNamespace(tq.namespace) +
        service.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.querier.service.metadata.name }),

      deployment:
        local deployment = k.apps.v1.deployment;
        local container = deployment.mixin.spec.template.spec.containersType;

        local c =
          container.new($.thanos.querier.deployment.metadata.name, tq.image) +
          container.withArgs([
            'query',
            '--query.replica-label=%s' % tq.replicaLabel,
            '--grpc-address=0.0.0.0:%d' % $.thanos.querier.service.spec.ports[0].port,
            '--http-address=0.0.0.0:%d' % $.thanos.querier.service.spec.ports[1].port,
          ]) +
          container.mixin.resources.withRequests({ cpu: '100m', memory: '256Mi' }) +
          container.mixin.resources.withLimits({ cpu: '1', memory: '1Gi' }) +
          container.withPorts([
            { name: 'grpc', containerPort: $.thanos.querier.service.spec.ports[0].port },
            { name: 'http', containerPort: $.thanos.querier.service.spec.ports[1].port },
          ]) +
          container.mixin.livenessProbe.httpGet.withPort($.thanos.querier.service.spec.ports[1].port).withScheme('HTTP').withPath('/-/healthy') +
          container.mixin.readinessProbe.httpGet.withPort($.thanos.querier.service.spec.ports[1].port).withScheme('HTTP').withPath('/-/ready');

        deployment.new(tq.name, tq.replicas, c, $.thanos.querier.deployment.metadata.labels) +
        deployment.mixin.metadata.withNamespace(tq.namespace) +
        deployment.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.querier.deployment.metadata.name }) +
        deployment.mixin.spec.selector.withMatchLabels($.thanos.querier.deployment.metadata.labels),
    },
  },
}
