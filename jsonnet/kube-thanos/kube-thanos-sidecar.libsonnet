// This example adds the --store flag to the querier to find sidecars.
// The used values are the defaults in kube-prometheus.
// If you need to modify this, you most likely want to
// copy this file into your project and change it accordingly.

{
  thanos+:: {
    querier+: {
      local tq = self,
      sidecarName:: 'prometheus-k8s',
      sidecarNamespace:: tq.namespace,

      deployment+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                super.containers[0]
                { args+: [
                  '--store=dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [
                    tq.sidecarName,
                    tq.sidecarNamespace,
                  ],
                ] },
              ],
            },
          },
        },
      },
    },
  },
}
