local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;

(import 'grafana-builder/grafana.libsonnet') +
{
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
    yaxes: $.yaxes('ms'),
  },

  qpsErrTotalPanel(selectorErr, selectorTotal):: {
    local expr(selector) = 'sum(rate(' + selector + '[$interval]))',

    aliasColors: {
      success: '#7EB26D',
      'error': '#E24D42',
    },
    targets: [
      {
        expr: expr(selectorErr),
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'error',
        refId: 'A',
        step: 10,
      },
      {
        expr: expr(selectorTotal) + ' - ' + expr(selectorErr),
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'success',
        refId: 'B',
        step: 10,
      },
    ],
  } + $.stack,
} +
(import 'grpc.libsonnet') +
(import 'http.libsonnet') +
(import 'slo.libsonnet')
