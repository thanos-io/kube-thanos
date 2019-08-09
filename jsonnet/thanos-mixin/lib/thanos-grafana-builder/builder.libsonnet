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

  spanSize(size):: {
    span: size,
  },

  postfix(postfix):: {
    postfix: postfix,
  },

  sparkline:: {
    sparkline: {
      show: true,
      lineColor: 'rgb(31, 120, 193)',
      fillColor: 'rgba(31, 118, 189, 0.18)',
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

  qpsPanelDetailed(metricName, selector)::
    $.qpsPanel(metricName, selector) {
      targets: [
        {
          expr: 'sum(label_replace(rate(%s{%s}[$interval]),"status_code", "${1}xx", "code", "([0-9])..")) by (handler, status_code)' % [metricName, selector],
          format: 'time_series',
          intervalFactor: 2,
          legendFormat: '{{handler}} {{status_code}}',
          refId: 'A',
          step: 10,
        },
      ],
    },

  grpcQpsPanel(type, selector):: {
    local prefix = if type == 'client' then 'grpc_client' else 'grpc_server',

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
        expr: 'sum(rate(%s_handled_total{%s}[$interval])) by (grpc_code)' % [prefix, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: '{{grpc_code}}',
        refId: 'A',
        step: 10,
      },
    ],
  } + $.stack,

  grpcQpsPanelDetailed(type, selector):: {
    local prefix = if type == 'client' then 'grpc_client' else 'grpc_server',
    targets: [
      {
        expr: 'sum(rate(%s_handled_total{%s}[$interval])) by (grpc_method, grpc_code)' % [prefix, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: '{{grpc_method}} {{grpc_code}}',
        refId: 'A',
        step: 10,
      },
    ],
  } + $.stack,

  errorsPanel(metricName, selector)::
    g.queryPanel(
      |||
        sum(rate(%s{%s,code!~"2.."}[$interval]))
        /
        sum(rate(%s{%s}[$interval]))
      ||| % [metricName, selector, metricName, selector],
      '{{code}}'
    ) +
    { yaxes: g.yaxes({ format: 'percentunit', max: 1 }) } +
    $.stack,

  errorsPanelDetailed(metricName, selector)::
    g.queryPanel(
      |||
        sum(rate(%s{%s,code!~"2.."}[$interval])) by (handler, code)
        /
        sum(rate(%s{%s}[$interval])) by (handler, code)
      ||| % [metricName, selector, metricName, selector],
      '{{handler}} {{code}}'
    ) +
    { yaxes: g.yaxes({ format: 'percentunit', max: 1 }) } +
    $.stack,

  grpcErrorsPanel(type, selector)::
    local prefix = if type == 'client' then 'grpc_client' else 'grpc_server';
    g.queryPanel(
      |||
        sum(rate(%s_handled_total{grpc_code!="OK",%s}[$interval]))
        /
        sum(rate(%s_started_total{%s}[$interval]))
      ||| % [prefix, selector, prefix, selector],
      ''
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
        expr: 'sum(rate(%s_sum{%s}[$interval])) * %s / sum(rate(%s_count{%s}[$interval]))' % [metricName, selector, multiplier, metricName, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'mean',
        refId: 'B',
        step: 10,
      },
      {
        expr: 'histogram_quantile(0.50, sum(rate(%s_bucket{%s}[$interval])) by (le)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P50',
        refId: 'C',
        step: 10,
      },
    ],
    yaxes: g.yaxes('ms'),
  },

  latencyPanelDetailed(metricName, selector, multiplier='1'):: {
    nullPointMode: 'null as zero',
    targets: [
      {
        expr: 'histogram_quantile(0.99, sum(rate(%s_bucket{%s}[$interval])) by (handler, le)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P99 {{handler}}',
        refId: 'A',
        step: 10,
      },
      {
        expr: 'sum(rate(%s_sum{%s}[$interval])) * %s / sum(rate(%s_count{%s}[$interval]))' % [metricName, selector, multiplier, metricName, selector],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'mean',
        refId: 'B',
        step: 10,
      },
      {
        expr: 'histogram_quantile(0.50, sum(rate(%s_bucket{%s}[$interval])) by (lhandler, e)) * %s' % [metricName, selector, multiplier],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'P50 {{handler}}',
        refId: 'C',
        step: 10,
      },
    ],
    yaxes: g.yaxes('ms'),
  },

  grpcLatencyPanel(type, selector, multiplier='1')::
    local prefix = if type == 'client' then 'grpc_client' else 'grpc_server';
    g.queryPanel(
      [
        'histogram_quantile(0.99, sum(rate(%s_handling_seconds_bucket{%s}[$interval])) by (le)) * %s' % [prefix, selector, multiplier],
        |||
          sum(rate(%s_handling_seconds_sum{%s}[$interval])) * %s
          /
          sum(rate(%s_handling_seconds_count{%s}[$interval]))
        ||| % [prefix, selector, multiplier, prefix, selector],
        'histogram_quantile(0.50, sum(rate(%s_handling_seconds_bucket{%s}[$interval])) by (le)) * %s' % [prefix, selector, multiplier],
      ],
      [
        'P99',
        'mean',
        'P50',
      ]
    ) +
    { yaxes: g.yaxes('s') },

  grpcLatencyPanelDetailed(type, selector, multiplier='1')::
    local prefix = if type == 'client' then 'grpc_client' else 'grpc_server';
    g.queryPanel(
      [
        'histogram_quantile(0.99, sum(rate(%s_handling_seconds_bucket{%s}[$interval])) by (grpc_method, le)) * %s' % [prefix, selector, multiplier],
        |||
          sum(rate(%s_handling_seconds_sum{%s}[$interval])) * %s
          /
          sum(rate(%s_handling_seconds_count{%s}[$interval]))
        ||| % [prefix, selector, multiplier, prefix, selector],
        'histogram_quantile(0.50, sum(rate(%s_handling_seconds_bucket{%s}[$interval])) by (grpc_method, le)) * %s' % [prefix, selector, multiplier],
      ],
      [
        'P99 {{grpc_method}}',
        'mean {{grpc_method}}',
        'P50 {{grpc_method}}',
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
