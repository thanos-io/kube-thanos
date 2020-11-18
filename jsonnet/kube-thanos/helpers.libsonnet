local t = import 'kube-thanos/thanos.libsonnet';

{
  storeShards(shards, cfg):: {
    config:: cfg {
      shards: shards,
    },
  } + {
    ['shard' + i]: t.store(cfg {
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
                    ||| % [shards, i],
                  ],
                } else c
                for c in super.containers
              ],
            },
          },
        },
      },
    }
    for i in std.range(0, shards - 1)
  },

  receiveHashrings(hashrings, cfg):: {
    config:: cfg,
  } + {
    [hashring.hashring]: t.receive(cfg {
      name+: '-' + hashring.hashring,
      commonLabels+:: {
        'controller.receive.thanos.io/hashring': hashring.hashring,
      },
    }) {
      local receiver = self,
      podDisruptionBudget:: {},  // hide this object, we don't want it
      statefulSet+: {
        metadata+: {
          labels+: {
            'controller.receive.thanos.io': 'thanos-receive-controller',
          },
        },
        spec+: {
          template+: {
            spec+: {
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
    for hashring in hashrings
  },
}
