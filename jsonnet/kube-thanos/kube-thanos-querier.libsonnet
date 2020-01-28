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
        local affinity = deployment.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
        local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;

        local c =
          container.new($.thanos.querier.deployment.metadata.name, tq.image) +
          container.withArgs([
            'query',
            '--query.replica-label=%s' % tq.replicaLabel,
            '--grpc-address=0.0.0.0:%d' % $.thanos.querier.service.spec.ports[0].port,
            '--http-address=0.0.0.0:%d' % $.thanos.querier.service.spec.ports[1].port,
          ]) +
          container.withPorts([
            { name: 'grpc', containerPort: $.thanos.querier.service.spec.ports[0].port },
            { name: 'http', containerPort: $.thanos.querier.service.spec.ports[1].port },
          ]) +
          container.mixin.livenessProbe +
          container.mixin.livenessProbe.withPeriodSeconds(30) +
          container.mixin.livenessProbe.withFailureThreshold(4) +
          container.mixin.livenessProbe.httpGet.withPort($.thanos.querier.service.spec.ports[1].port) +
          container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
          container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
          container.mixin.readinessProbe +
          container.mixin.readinessProbe.withPeriodSeconds(5) +
          container.mixin.readinessProbe.withFailureThreshold(20) +
          container.mixin.readinessProbe.httpGet.withPort($.thanos.querier.service.spec.ports[1].port) +
          container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
          container.mixin.readinessProbe.httpGet.withPath('/-/ready');

        deployment.new(tq.name, tq.replicas, c, $.thanos.querier.deployment.metadata.labels) +
        deployment.mixin.metadata.withNamespace(tq.namespace) +
        deployment.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.querier.deployment.metadata.name }) +
        deployment.mixin.spec.selector.withMatchLabels($.thanos.querier.deployment.metadata.labels) +
        deployment.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
        deployment.mixin.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
          affinity.new() +
          affinity.withWeight(100) +
          affinity.mixin.podAffinityTerm.withNamespaces(tq.namespace) +
          affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
          affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
            matchExpression.new() +
            matchExpression.withKey('app.kubernetes.io/name') +
            matchExpression.withOperator('In') +
            matchExpression.withValues([$.thanos.querier.deployment.metadata.labels['app.kubernetes.io/name']]),
          ]),
        ]),
    },
  },
}
