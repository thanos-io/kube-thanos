// Usually this should be an absolute import paths.
// In this instance, however, we use a local symlink cause this is within the same repository.
local thanos = import 'kube-thanos/thanos.libsonnet';

// This example demonstrates how to overwrite or extends each component,
// whenever out-of-the-box configuration isn't enough.

local query = thanos.query({
  namespace: 'thanos',
  version: 'v0.13.0',
  image: 'quay.io/thanos/thanos:' + self.version,
  replicas: 1,
  replicaLabels: ['replica'],
});

local queryExtended = query {
  deployment+: {
    metadata+: {
      // Let's extend the deployment with our specific annotations
      annotations: {
        'some-specific-annotation': 'foobar',
      },
      // We can also overwrite existing labels completely.
      labels: {
        app: 'thanos-query',
      },
    },
    // We can even add a sidecar without changing the initial component.
    // By doing that, we can still upgrade kube-thanos but never lose our own sidecar.
    spec+: {
      template+: {
        spec+: {
          containers+: [
            {
              name: 'thanos-query-sidecar',
              image: 'quay.io/org/app:dont-use-latest',
              args: ['--foo=bar'],
            },
          ],
        },
      },
    },
  },
};

{ ['thanos-query-' + name]: queryExtended[name] for name in std.objectFields(queryExtended) if queryExtended[name] != null }

// The same can be done without the extra variable:

// local query = thanos.query({
//   namespace: 'thanos',
//   version: 'v0.13.0',
//   image: 'quay.io/thanos/thanos:' + self.version,
//   replicas: 1,
//   replicaLabels: ['replica'],
// }) + {
//   deployment+: {
//     metadata+: {
//       annotations: {
//         'some-specific-annotation': 'foobar',
//       },
//     },
//   },
// };



