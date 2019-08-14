local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;

(import 'grafana-builder/grafana.libsonnet') +
{
  collapse: {
    collapse: true,
  },

  addDashboardLink(name): {
    links+: [
      {
        dashboard: name,
        includeVars: true,
        keepTime: true,
        title: name,
        type: 'dashboard',
        // url: '/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive',
      },
    ],
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
    yaxes: $.yaxes('s'),
  },

  qpsErrTotalPanel(selectorErr, selectorTotal):: {
    local expr(selector) = 'sum(rate(' + selector + '[$interval]))',

    aliasColors: {
      success: '#7EB26D',
      'error': '#E24D42',
    },
    targets: [
      {
        expr: '%s / %s ' % [expr(selectorErr), expr(selectorTotal)],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'error',
        refId: 'A',
        step: 10,
      },
      {
        expr: '(%s - %s) / %s' % [expr(selectorTotal), expr(selectorErr), expr(selectorTotal)],
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: 'success',
        refId: 'B',
        step: 10,
      },
    ],
    yaxes: $.yaxes({ format: 'percentunit', max: 1 }),
  } + $.stack,

  resourceUtilizationRow(selector)::
    $.row('Resources')
    .addPanel(
      $.panel('Memory Used') +
      $.queryPanel(
        [
          'go_memstats_alloc_bytes{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}' % selector,
          'go_memstats_heap_alloc_bytes{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}' % selector,
          'rate(go_memstats_alloc_bytes_total{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}[30s])' % selector,
          'rate(go_memstats_heap_alloc_bytes{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}[30s])' % selector,
          'go_memstats_stack_inuse_bytes{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}' % selector,
          'go_memstats_heap_inuse_bytes{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}' % selector,
        ],
        [
          'alloc all {{pod}}',
          'alloc heap {{pod}}',
          'alloc rate all {{pod}}',
          'alloc rate heap {{pod}}',
          'inuse stack {{pod}}',
          'inuse heap {{pod}}',
        ]
      ),
    )
    .addPanel(
      $.panel('Goroutines') +
      $.queryPanel(
        'go_goroutines{namespace="$namespace",%s}' % selector,
        '{{pod}}'
      )
    )
    .addPanel(
      $.panel('GC Time Quantiles') +
      $.queryPanel(
        'go_gc_duration_seconds{namespace="$namespace",%s,kubernetes_pod_name=~"$pod"}' % selector,
        '{{quantile}} {{pod}}'
      )
    ) +
    $.collapse,
} +
(import 'grpc.libsonnet') +
(import 'http.libsonnet') +
(import 'slo.libsonnet')
