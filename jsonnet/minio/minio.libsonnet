// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  namespace: error 'must provide namespace',
  buckets: error 'must provide buckets',
  accessKey: error 'must provide accessKey',
  secretKey: error 'must provide secretKey',

  commonLabels:: { 'app.kubernetes.io/name': 'minio' },
};

function(params) {
  local minio = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,

  deployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'minio',
      namespace: minio.config.namespace,
    },
    spec: {
      selector: {
        matchLabels: minio.config.commonLabels,
      },
      strategy: { type: 'Recreate' },
      template: {
        metadata: {
          labels: minio.config.commonLabels,
        },
        spec: {
          containers: [
            {
              command: [
                '/bin/sh',
                '-c',
                |||
                  mkdir -p %s && \
                  /usr/bin/docker-entrypoint.sh minio server /storage
                ||| % std.join(' ', ['/storage/%s' % bucket for bucket in minio.config.buckets]),
              ],
              env: [
                {
                  name: 'MINIO_ROOT_USER',
                  value: minio.config.accessKey,
                },
                {
                  name: 'MINIO_ROOT_PASSWORD',
                  value: minio.config.secretKey,
                },
              ],
              image: 'minio/minio:RELEASE.2023-05-27T05-56-19Z',
              imagePullPolicy: 'IfNotPresent',
              name: 'minio',
              ports: [
                { containerPort: 9000 },
              ],
              volumeMounts: [
                { mountPath: '/storage', name: 'storage' },
              ],
            },
          ],
          volumes: [{
            name: 'storage',
            persistentVolumeClaim: { claimName: 'minio' },
          }],
        },
      },
    },
  },

  pvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      labels: minio.config.commonLabels,
      name: 'minio',
      namespace: minio.config.namespace,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      resources: {
        requests: { storage: '5Gi' },
      },
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'minio',
      namespace: minio.config.namespace,
    },
    spec: {
      ports: [
        { port: 9000, protocol: 'TCP', targetPort: 9000 },
      ],
      selector: minio.config.commonLabels,
      type: 'ClusterIP',
    },
  },
}
