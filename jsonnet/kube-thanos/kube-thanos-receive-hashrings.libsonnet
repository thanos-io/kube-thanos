local receiveConfigDefaults = import 'kube-thanos/kube-thanos-receive-default-params.libsonnet';
local receive = import 'kube-thanos/kube-thanos-receive.libsonnet';

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = receiveConfigDefaults {
  local defaults = self,
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
    [h.hashring]: receive(config {
      name+: '-' + h.hashring,
      commonLabels+:: {
        'controller.receive.thanos.io/hashring': h.hashring,
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
    for h in config.hashrings
  }
