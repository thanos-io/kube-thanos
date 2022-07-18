local compactConfigDefaults = import 'kube-thanos/kube-thanos-compact-default-params.libsonnet';
local compact = import 'kube-thanos/kube-thanos-compact.libsonnet';

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = compactConfigDefaults {
  shards: 1,
};

function(params)
  // Combine the defaults and the passed params to make the component's config.
  local config = defaults + params;

  // Safety checks for combined config of defaults and params
  assert std.isNumber(config.shards) && config.shards >= 0 : 'thanos compact shards has to be number >= 0';
  assert std.isArray(config.sourceLabels) && std.length(config.sourceLabels) > 0;

  { config:: config } + {
    local allShards = self,

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: config.name,
        namespace: config.namespace,
        labels: config.commonLabels,
        annotations: config.serviceAccountAnnotations,
      },
    },

    shards: {
      ['shard' + i]: compact(config {
        name+: '-%d' % i,
        commonLabels+:: { 'compact.thanos.io/shard': 'shard-' + i },
      }) {
        serviceAccount: null,  // one service account for all compactors
        serviceMonitor: null,  // one service monitor for all compactors

        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                serviceAccountName: allShards.serviceAccount.metadata.name,
                containers: [
                  if c.name == 'thanos-compact' then c {
                    args+: [
                      |||
                        --selector.relabel-config=
                          - action: hashmod
                            source_labels: %s
                            target_label: shard
                            modulus: %d
                          - action: keep
                            source_labels: ["shard"]
                            regex: %d
                      ||| % [config.sourceLabels, config.shards, i],
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
                sourceLabels: ['__meta_kubernetes_service_label_compact_thanos_io_shard'],
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
