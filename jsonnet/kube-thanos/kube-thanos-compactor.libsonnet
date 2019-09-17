local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  thanos+:: {
    compactor+: {
      service:
        local service = k.core.v1.service;
        local ports = service.mixin.spec.portsType;

        service.new(
          'thanos-compactor',
          $.thanos.compactor.statefulSet.metadata.labels,
          [
            ports.newNamed('http', 10902, 'http'),
          ],
        ) +
        service.mixin.metadata.withNamespace('monitoring') +
        service.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.compactor.service.metadata.name }),

      statefulSet:
        local statefulSet = k.apps.v1.statefulSet;
        local volume = statefulSet.mixin.spec.template.spec.volumesType;
        local container = statefulSet.mixin.spec.template.spec.containersType;
        local containerEnv = container.envType;
        local containerVolumeMount = container.volumeMountsType;

        local c =
          container.new($.thanos.compactor.statefulSet.metadata.name, $.thanos.variables.image) +
          container.withArgs([
            'compact',
            '--wait',
            '--retention.resolution-raw=16d',
            '--retention.resolution-5m=42d',
            '--retention.resolution-1h=180d',
            '--objstore.config=$(OBJSTORE_CONFIG)',
            '--data-dir=/var/thanos/compactor',
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
          ]) +
          container.mixin.resources.withRequests({ cpu: '100m', memory: '1Gi' }) +
          container.mixin.resources.withLimits({ cpu: '500m', memory: '2Gi' }) +
          container.withVolumeMounts([
            containerVolumeMount.new('thanos-compactor-data', '/var/thanos/compactor', false),
          ])
          +
          container.mixin.livenessProbe.httpGet.withPort($.thanos.querier.service.spec.ports[0].port).withScheme('HTTP').withPath('/-/healthy') +
          container.mixin.readinessProbe.httpGet.withPort($.thanos.querier.service.spec.ports[0].port).withScheme('HTTP').withPath('/-/ready');

        statefulSet.new('thanos-compactor', 1, c, [], $.thanos.compactor.statefulSet.metadata.labels) +
        statefulSet.mixin.metadata.withNamespace('monitoring') +
        statefulSet.mixin.metadata.withLabels({ 'app.kubernetes.io/name': $.thanos.compactor.statefulSet.metadata.name }) +
        statefulSet.mixin.spec.withServiceName($.thanos.compactor.service.metadata.name) +
        statefulSet.mixin.spec.template.spec.withVolumes([
          volume.fromEmptyDir('thanos-compactor-data'),
        ]) +
        statefulSet.mixin.spec.selector.withMatchLabels($.thanos.compactor.statefulSet.metadata.labels),
    },
  },
}
