// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'thanos-sidecar',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  serviceMonitor: false,
  ports: {
    grpc: 10901,
    http: 10902,
  },

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-sidecar',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'prometheus-sidecar',
  },

  podLabelSelector:: error 'must provide podLabelSelector',

  serviceLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local tsc = self,
  config:: defaults + params,

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: tsc.config.name,
      namespace: tsc.config.namespace,
      labels: tsc.config.commonLabels,
    },
    spec: {
      clusterIP: 'None',
      selector: tsc.config.podLabelSelector,
      ports: [
        {
          assert std.isString(name),
          assert std.isNumber(tsc.config.ports[name]),

          name: name,
          port: tsc.config.ports[name],
          targetPort: tsc.config.ports[name],
        }
        for name in std.objectFields(tsc.config.ports)
      ],
    },
  },

  serviceMonitor: if tsc.config.serviceMonitor == true then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: tsc.config.name,
      namespace: tsc.config.namespace,
      labels: tsc.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: tsc.config.serviceLabelSelector,
      },
      relabelings: [{
        sourceLabels: ['namespace', 'pod'],
        separator: '/',
        targetLabel: 'instance',
      }],
      endpoints: [
        { port: 'http' },
      ],
    },
  },
}
