local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local tr = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',
    ruleFiles: [],
    alertmanagersURLs: [],
    queriers: [],

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-rule',
      'app.kubernetes.io/instance': tr.config.name,
      'app.kubernetes.io/version': tr.config.version,
      'app.kubernetes.io/component': 'rule-evaluation-engine',
    },

    podLabelSelector:: {
      [labelName]: tr.config.commonLabels[labelName]
      for labelName in std.objectFields(tr.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      tr.config.name,
      tr.config.podLabelSelector,
      [
        ports.newNamed('grpc', 10901, 'grpc'),
        ports.newNamed('http', 10902, 'http'),
      ],
    ) +
    service.mixin.metadata.withNamespace(tr.config.namespace) +
    service.mixin.metadata.withLabels(tr.config.commonLabels) +
    service.mixin.spec.withClusterIp('None'),

  statefulSet:
    local statefulSet = k.apps.v1.statefulSet;
    local volume = statefulSet.mixin.spec.template.spec.volumesType;
    local container = statefulSet.mixin.spec.template.spec.containersType;
    local containerEnv = container.envType;
    local containerVolumeMount = container.volumeMountsType;

    local c =
      container.new('thanos-rule', tr.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs(
        [
          'rule',
          '--log.level=' + tr.config.logLevel,
          '--grpc-address=0.0.0.0:%d' % tr.service.spec.ports[0].port,
          '--http-address=0.0.0.0:%d' % tr.service.spec.ports[1].port,
          '--objstore.config=$(OBJSTORE_CONFIG)',
          '--data-dir=/var/thanos/rule',
          '--label=rule_replica="$(NAME)"',
          '--alert.label-drop=rule_replica',
        ] +
        (['--query=%s' % querier for querier in tr.config.queriers]) +
        (['--rule-file=%s' % path for path in tr.config.ruleFiles]) +
        (['--alertmanagers.url=%s' % url for url in tr.config.alertmanagersURLs])
      ) +
      container.withEnv([
        containerEnv.fromFieldPath('NAME', 'metadata.name'),
        containerEnv.fromSecretRef(
          'OBJSTORE_CONFIG',
          tr.config.objectStorageConfig.name,
          tr.config.objectStorageConfig.key,
        ),
      ]) +
      container.withVolumeMounts([
        containerVolumeMount.new('data', '/var/thanos/rule', false),
      ]) +
      container.withPorts([
        { name: 'grpc', containerPort: tr.service.spec.ports[0].port },
        { name: 'http', containerPort: tr.service.spec.ports[1].port },
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(5) +
      container.mixin.livenessProbe.withFailureThreshold(24) +
      container.mixin.livenessProbe.httpGet.withPort(tr.service.spec.ports[1].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withInitialDelaySeconds(10) +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(18) +
      container.mixin.readinessProbe.httpGet.withPort(tr.service.spec.ports[1].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    statefulSet.new(tr.config.name, tr.config.replicas, c, [], tr.config.commonLabels) +
    statefulSet.mixin.metadata.withNamespace(tr.config.namespace) +
    statefulSet.mixin.metadata.withLabels(tr.config.commonLabels) +
    statefulSet.mixin.spec.withServiceName(tr.service.metadata.name) +
    statefulSet.mixin.spec.selector.withMatchLabels(tr.config.podLabelSelector) +
    statefulSet.mixin.spec.template.spec.withVolumes([
      volume.fromEmptyDir('data'),
    ]) + {
      spec+: {
        volumeClaimTemplates: null,
      },
    },

  withServiceMonitor:: {
    local tr = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: tr.config.name,
        namespace: tr.config.namespace,
        labels: tr.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: tr.config.podLabelSelector,
        },
        endpoints: [
          {
            port: 'http',
            relabelings: [{
              sourceLabels: ['namespace', 'pod'],
              separator: '/',
              targetLabel: 'instance',
            }],
          },
        ],
      },
    },
  },

  withVolumeClaimTemplate:: {
    local tr = self,
    config+:: {
      volumeClaimTemplate: error 'must provide volumeClaimTemplate',
    },
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            volumes: std.filter(function(v) v.name != 'data', super.volumes),
          },
        },
        volumeClaimTemplates: [tr.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tr.config.podLabelSelector,
          },
        }],
      },
    },
  },

  withResources:: {
    local tr = self,
    config+:: {
      resources: error 'must provide resources',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-rule' then c {
                resources: tr.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
