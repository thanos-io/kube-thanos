local minio = (import 'jsonnet/minio/minio.libsonnet')({
  namespace: 'thanos',
  buckets: ['thanos'],
  accessKey: 'minio',
  secretKey: 'minio123',
});

{
  'minio-deployment': minio.deployment,
  'minio-pvc': minio.pvc,
  'minio-service': minio.service,
  'minio-secret-thanos': {
    apiVersion: 'v1',
    kind: 'Secret',
    metadata: {
      name: 'thanos-objectstorage',
      namespace: minio.config.namespace,
    },
    stringData: {
      'thanos.yaml': |||
        type: s3
        config:
          bucket: thanos
          endpoint: %s.%s.svc.cluster.local:9000
          insecure: true
          access_key: minio
          secret_key: minio123
      ||| % [minio.service.metadata.name, minio.config.namespace],
    },
    type: 'Opaque',
  },
}
