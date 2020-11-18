local storeConfigDefaults = import 'kube-thanos/kube-thanos-store-default-params.libsonnet';
local store = import 'kube-thanos/kube-thanos-store.libsonnet';

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = storeConfigDefaults {
  local defaults = self,
  shards: 1,
};

function(params)
  // Combine the defaults and the passed params to make the component's config.
  local config = defaults + params;

  // Safety checks for combined config of defaults and params
  assert std.isNumber(config.shards) && config.shards >= 0 : 'thanos store shards has to be number >= 0';

  { config:: config } + {
    ['shard' + i]: store(config {
      name+: '-%d' % i,
      commonLabels+:: { 'store.observatorium.io/shard': 'shard-' + i },
    }) {
      statefulSet+: {
        spec+: {
          template+: {
            spec+: {
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
  }
