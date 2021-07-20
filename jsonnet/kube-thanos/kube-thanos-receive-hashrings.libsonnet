local receiveConfigDefaults = import 'kube-thanos/kube-thanos-receive-default-params.libsonnet';
local receive = import 'kube-thanos/kube-thanos-receive.libsonnet';

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = receiveConfigDefaults {
  hashrings: [{
    hashring: 'default',
    tenants: [],
  }],
};

function(params)
  // Combine the defaults and the passed params to make the component's config.
  local config = defaults + params;

  // Safety checks for combined config of defaults and params
  assert std.isArray(config.hashrings) : 'thanos receive hashrings has to be an array';

  { config:: config } + {
    local allHashrings = self,

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: config.name,
        namespace: config.namespace,
        labels: config.commonLabels,
      },
    },
    hashrings: {
      [h.hashring]: receive(config {
        name+: '-' + h.hashring,
        commonLabels+:: {
          'controller.receive.thanos.io/hashring': h.hashring,
        },
      }) {
        local receiver = self,

        serviceAccount: null,  // one service account for all receivers
        serviceMonitor: null,  // one service monitor for all receivers

        statefulSet+: {
          metadata+: {
            labels+: {
              'controller.receive.thanos.io': 'thanos-receive-controller',
            },
          },
          spec+: {
            template+: {
              spec+: {
                serviceAccountName: allHashrings.serviceAccount.metadata.name,
                containers: [
                  if c.name == 'thanos-receive' then c {
                    env+: if std.objectHas(receiver.config, 'debug') && receiver.config.debug != '' then [
                      { name: 'DEBUG', value: receiver.config.debug },
                    ] else [],
                  }
                  else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      }
      for h in config.hashrings
    },
  } + {
    serviceMonitor: if config.serviceMonitor == true then {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: config.name,
        namespace: config.namespace,
        labels: config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: {
            [key]: config.podLabelSelector[key]
            for key in std.objectFields(config.podLabelSelector)
            if key != 'app.kubernetes.io/instance'
          },
        },
        endpoints: [
          {
            port: 'http',
            relabelings: [
              {
                sourceLabels: ['namespace', 'pod'],
                separator: '/',
                targetLabel: 'instance',
              },
              {
                sourceLabels: ['__meta_kubernetes_service_label_controller_receive_thanos_io_shard'],
                targetLabel: 'hashring',
              },
            ],
          },
        ],
      },
    },
  }
