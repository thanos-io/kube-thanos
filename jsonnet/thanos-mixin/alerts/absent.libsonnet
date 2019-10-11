{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'component-absent',
        rules: [
          {
            alert: '%sIsDown' % name,
            expr: |||
              absent(up{%s} == 1)
            ||| % $._config.jobs[name],
            'for': '10m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: '%s has disappeared from Prometheus target discovery.' % name,
            },
          }
          for name in std.objectFields($._config.jobs)
        ],
      },
    ],
  },
}
