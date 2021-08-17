local defaults = import 'kube-thanos/kube-thanos-receive-default-params.libsonnet';
local receive = import 'kube-thanos/kube-thanos-receive.libsonnet';

function(params) {
  local tr = self,
  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,

  // Create the standard receiver statefulset
  local router = receive(tr.config {
    name: tr.config.name + '-router',
    hashringConfigMapName: 'hashring',
    enableLocalEndpoint: false,
  }) + {
    // Convert the standard statefulSet into a Deployment type
    deployment: router.statefulSet {
      kind: 'Deployment',
    },
    // Hide the statefulset field
    statefulSet:: super.statefulSet,
  },
  router: router,

  // Create the standard receiver statefulset
  local ingestor = receive(tr.config { name: tr.config.name + '-ingestor' }) + {
    // Modify the container args to start in 'ingestor' only mode.
  },
  ingestor: ingestor,
}
