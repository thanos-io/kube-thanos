// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
{
  local defaults = self,
  name: 'thanos-compact',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  imagePullPolicy: 'IfNotPresent',
  objectStorageConfig: error 'must provide objectStorageConfig',
  resources: {},
  logLevel: 'info',
  logFormat: 'logfmt',
  serviceMonitor: false,
  volumeClaimTemplate: {},
  retentionResolutionRaw: '0d',
  retentionResolution5m: '0d',
  retentionResolution1h: '0d',
  compactConcurrency: 1,
  deduplicationReplicaLabels: [],
  deleteDelay: '48h',
  disableDownsampling: false,
  downsampleConcurrency: 1,
  ports: {
    http: 10902,
  },
  tracing: {},
  extraEnv: [],

  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-compact',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'database-compactor',
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if labelName != 'app.kubernetes.io/version'
  },

  securityContext:: {
    fsGroup: 65534,
    runAsUser: 65534,
  },

  serviceAccountAnnotations:: {},
}
