{
  _config+:: {
    jsonnet: 'quay.io/coreos/jsonnet-ci:latest',
  },

  kind: 'pipeline',
  name: 'build',
  platform: {
    os: 'linux',
    arch: 'amd64',
  },

  local jsonnet = {
    name: 'jsonnet',
    image: $._config.jsonnet,
    pull: 'always',
    environment: {
      GO111MODULE: 'on',
    },
    when: {
      event: {
        exclude: ['tag'],
      },
    },
  },

  steps: [
    jsonnet {
      name: 'vendor',
      commands: [
        'make --always-make vendor',
        'git diff --exit-code',
      ],
    },

    jsonnet {
      name: 'generate',
      commands: [
        'make --always-make generate',
        'git diff --exit-code',
      ],
    },
  ],
}
