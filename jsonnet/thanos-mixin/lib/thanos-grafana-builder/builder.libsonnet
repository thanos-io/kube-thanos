local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;
local g = import 'grafana-builder/grafana.libsonnet';

{
  stack:: {
    stack: true,
    fill: 10,
    linewidth: 0,
  },

  collapse: {
    collapse: true,
  },

  podTemplate(selector)::
    {
      templating+: {
        list+: [
          template.new(
            'pod',
            '$datasource',
            'label_values(kube_pod_info{%s}, pod)' % selector,
            label='pod',
            refresh=1,
            sort=2,
            current='all',
            allValues='.*',
            includeAll=true
          ),
        ],
      },
    },

  qpsPanel(metricName, selector):: {
    aliasColors: {
      '1xx': '#EAB839',
      '2xx': '#7EB26D',
      '3xx': '#6ED0E0',
      '4xx': '#EF843C',
      '5xx': '#E24D42',
      success: '#7EB26D',
      'error': '#E24D42',
    },
    targets: [
      {
        expr: 'sum(label_replace(rate(%s{%s}[$interval]),"status_code", "${1}xx", "code", "([0-9])..")) by (status_code)' % [metricName, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: '{{status_code}}',
        refId: 'A',
        step: 10,
      },
    ],
  } + $.stack,

  grpcQpsPanel(selector):: {
    aliasColors: {
      Aborted: '#EAB839',
      AlreadyExists: '#7EB26D',
      FailedPrecondition: '#6ED0E0',
      Unimplemented: '#6ED0E0',
      InvalidArgument: '#EF843C',
      NotFound: '#EF843C',
      PermissionDenied: '#EF843C',
      Unauthenticated: '#EF843C',
      Canceled: '#E24D42',
      DataLoss: '#E24D42',
      DeadlineExceeded: '#E24D42',
      Internal: '#E24D42',
      OutOfRange: '#E24D42',
      ResourceExhausted: '#E24D42',
      Unavailable: '#E24D42',
      Unknown: '#E24D42',
      OK: '#7EB26D',
      'error': '#E24D42',
    },
    targets: [
      {
        expr: 'sum(rate(grpc_server_handled_total{%s}[$interval])) by (grpc_code)' % selector,
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: '{{grpc_code}}',
        refId: 'A',
        step: 10,
      },
    ],
  } + $.stack,

  errorsPanel(metricName, selector)::
    g.queryPanel(
      |||
        sum(rate(%s{%s,code!~"2.."}[$interval])) by (handler)
        /
        sum(rate(%s{%s}[$interval])) by (handler)
      ||| % [metricName, selector, metricName, selector],
      '{{handler}}'
    ) +
    { yaxes: g.yaxes({ format: 'percentunit', max: 1 }) } +
    $.stack,

  grpcErrorsPanel(selector)::
    g.queryPanel(
      |||
        sum(
          rate(grpc_server_handled_total{grpc_code!="OK",%s}[$interval])
          /
          rate(grpc_server_started_total{%s}[$interval])
        ) by (grpc_code, grpc_method)
      ||| % [selector, selector],
      '{{grpc_code}}'
    ) +
    { yaxes: g.yaxes({ format: 'percentunit', max: 1 }) } +
    $.stack,

  latencyPanel(metricName, selector, multiplier='1'):: {
    nullPointMode: 'null as zero',
    targets: [
      {
        expr: 'histogram_quantile(0.99, sum(rate(%s_bucket{%s}[$interval])) by (le)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P99',
        refId: 'A',
        step: 10,
      },
      {
        expr: 'histogram_quantile(0.50, sum(rate(%s_bucket{%s}[$interval])) by (le)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P50',
        refId: 'B',
        step: 10,
      },
      {
        expr: 'sum(rate(%s_sum{%s}[$interval])) * %s / sum(rate(%s_count{%s}[$interval]))' % [metricName, selector, multiplier, metricName, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'mean',
        refId: 'C',
        step: 10,
      },
    ],
    yaxes: g.yaxes('ms'),
  },

  grpcLatencyPanel(selector, multiplier='1')::
    g.queryPanel(
      [
        'histogram_quantile(0.99, sum(rate(grpc_server_handling_seconds_bucket{%s}[$interval])) by (le)) * %s' % [selector, multiplier],
        |||
          sum(rate(grpc_server_handling_seconds_sum{%s}[$interval])) * %s
          /
          sum(rate(grpc_server_handling_seconds_count{%s}[$interval]))
        ||| % [selector, multiplier, selector],
        'histogram_quantile(0.50, sum(rate(grpc_server_handling_seconds_bucket{%s}[$interval])) by (le)) * %s' % [selector, multiplier],
      ],
      [
        'P99',
        'mean',
        'P50',
      ]
    ) +
    { yaxes: g.yaxes('s') },

  selector:: {
    eq(label, value):: { label: label, op: '=', value: value },
    neq(label, value):: { label: label, op: '!=', value: value },
    re(label, value):: { label: label, op: '=~', value: value },
    nre(label, value):: { label: label, op: '!~', value: value },
  },
}
