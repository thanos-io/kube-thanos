local storeConfigDefaults = import 'kube-thanos/kube-thanos-store-default-params.libsonnet';
local store = import 'kube-thanos/kube-thanos-store.libsonnet';

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = storeConfigDefaults {
  shards: 1,
};

function(params)
  // Combine the defaults and the passed params to make the component's config.
  local config = defaults + params;

  // Safety checks for combined config of defaults and params
  assert std.isNumber(config.shards) && config.shards >= 0 : 'thanos store shards has to be number >= 0';

  { config:: config } + {
    local allShards = self,

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: config.name,
        namespace: config.namespace,
        labels: config.commonLabels,
      },
    },

    shards: {
      ['shard' + i]: store(config {
        name+: '-%d' % i,
        commonLabels+:: { 'store.thanos.io/shard': 'shard-' + i },
      }) {
        serviceAccount: null,  // one service account for all stores
        serviceMonitor: null,  // one service monitor foal all stores

        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                serviceAccountName: allShards.serviceAccount.metadata.name,
                containers: [
                  if c.name == 'thanos-store' then c {
                    args+: [
                      |||
                        --selector.relabel-config=
                          - action: hashmod
                            source_labels: ["__block_id"]
                            target_label: shard
                            modulus: %d
                          - action: keep
                            source_labels: ["shard"]
                            regex: %d
                      ||| % [config.shards, i],
                    ],
                  } else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      }
      for i in std.range(0, config.shards - 1)
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
                sourceLabels: ['__meta_kubernetes_service_label_store_thanos_io_shard'],
                regex: 'shard\\-(\\d+)',
                replacement: '$1',
                targetLabel: 'shard',
              },
            ],
          },
        ],
      },
    },
  }
