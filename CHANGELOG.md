# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

NOTE: As semantic versioning states all 0.y.z releases can contain breaking changes.

> kube-thanos' major and minor versions are in sync with upstream Thanos project.

We use *breaking* word for marking changes that are not backward compatible (relates only to v0.y.z releases.)

## Unreleased

### Breaking Changes

### Changed

### Added

### Fixed

## [v0.27.0](https://github.com/thanos-io/kube-thanos/tree/v0.27.0) (2022-07-07)
- (no changes from `v0.26.0`)

## [v0.26.0](https://github.com/thanos-io/kube-thanos/tree/v0.26.0) (2022-06-13)

### Added

- [#263](https://github.com/thanos-io/kube-thanos/pull/263) Add support for stateless Rulers.


## [v0.24.0](https://github.com/thanos-io/kube-thanos/tree/v0.24.0) (2021-12-17)

### Changed

- [#254](https://github.com/thanos-io/kube-thanos/pull/254) Add support for tenant header configuration to receiver.
- [#247](https://github.com/thanos-io/kube-thanos/pull/247) Make Compact service headless.

### Added

- [#265](https://github.com/thanos-io/kube-thanos/pull/265) Added support for multithreaded thanos compact.
- [#237](https://github.com/thanos-io/kube-thanos/pull/237) Add new bucket replicate component.
- [#245](https://github.com/thanos-io/kube-thanos/pull/245) Support scraping config reloader sidecar for ruler.
- [#251](https://github.com/thanos-io/kube-thanos/pull/251) Add support for extraEnv (custom environment variables) to all components.
- [#260](https://github.com/thanos-io/kube-thanos/pull/260) Add support custom certificate for the object store by configuring `tlsSecretName` and `tlsSecretMountPath` in `objectStorageConfig`.
- [#261](https://github.com/thanos-io/kube-thanos/pull/261) Add support for imagePullPolicy to all components.

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.22.0...v0.24.0)


## [v0.22.0](https://github.com/thanos-io/kube-thanos/tree/v0.22.0) (2021-08-17)

### Added

- [#232](https://github.com/thanos-io/kube-thanos/pull/232) Support compactor hash sharding.

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.21.0...v0.22.0)

## [v0.21.0](https://github.com/thanos-io/kube-thanos/tree/v0.21.0) (2021-08-17)

### Changed

- [#226](https://github.com/thanos-io/kube-thanos/pull/226) Only schedule thanos components on linux nodes.

### Added
- [#244](https://github.com/thanos-io/kube-thanos/pull/244) Add functions to implement Thanos Receive split functionality.
- [#228](https://github.com/thanos-io/kube-thanos/pull/228) Allow configuring `--web.prefix-header` of query.

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.20.0...v0.21.0)

## [v0.20.0](https://github.com/thanos-io/kube-thanos/tree/v0.20.0) (2021-04-28)

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.19.0...v0.20.0)

## [v0.19.0](https://github.com/thanos-io/kube-thanos/tree/v0.19.0) (2020-04-19)

### Breaking Changes

- [#196](https://github.com/thanos-io/kube-thanos/pull/196) Single ServiceAccount for all hashrings, causing hashrings position in the object tree to change.

### Changed

- [#196](https://github.com/thanos-io/kube-thanos/pull/196) Single ServiceAccount for each component.
- [#200](https://github.com/thanos-io/kube-thanos/pull/200) [#202](https://github.com/thanos-io/kube-thanos/pull/200) Run all components as non-root.
- [#208](https://github.com/thanos-io/kube-thanos/pull/208) Documentation: Refer to `main` branch in docs

### Added

- [#192](https://github.com/thanos-io/kube-thanos/pull/192) sidecar: Add pod discovery
- [#194](https://github.com/thanos-io/kube-thanos/pull/194) Allow configuring --label and --receive.tenant-label-name flags.
- [#209](https://github.com/thanos-io/kube-thanos/pull/209) Allow configuring --label and --refresh flags of bucket web.
- [#213](https://github.com/thanos-io/kube-thanos/pull/213) Allow configuring `--min-time` and `--max-time` of store.
- [#218](https://github.com/thanos-io/kube-thanos/pull/218) Enable `--query.auto-downsampling` for query by default.
- [#221](https://github.com/thanos-io/kube-thanos/pull/221) Allow configuring `--tsdb.retention` and `--tsdb.block-duration` for rule.
- [#225](https://github.com/thanos-io/kube-thanos/pull/225) Add support for alertmanager configuration and extra volumes for rule.

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.18.0...v0.19.0)

## [v0.18.0](https://github.com/thanos-io/kube-thanos/tree/v0.18.0) (2020-04-19)

### Breaking Changes

- [#188](https://github.com/thanos-io/kube-thanos/pull/188) Single ServiceMonitor for store shards

### Fixed

- [#185](https://github.com/thanos-io/kube-thanos/pull/185) query-frontend, store: make cache types case insensitive

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.17.0...v0.18.0)

## [v0.17.0](https://github.com/thanos-io/kube-thanos/tree/v0.17.0) (2020-12-08)

### Added

- [#166](https://github.com/thanos-io/kube-thanos/pull/166) Add new flags and memcached support to query frontend
- [#169](https://github.com/thanos-io/kube-thanos/pull/169) Add --tracing.config support to all components
- [#170](https://github.com/thanos-io/kube-thanos/pull/170) Add Store shard and Receive hashring helpers
- [#173](https://github.com/thanos-io/kube-thanos/pull/173) Store, query, frontend: add log.format flag
- [#178](https://github.com/thanos-io/kube-thanos/pull/178) compact, rule, tools: add log format flag

### Fixed

- [#176](https://github.com/thanos-io/kube-thanos/pull/176) store: fix error when bucket cache not used

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.16.0...v0.17.0)

## [v0.16.0](https://github.com/thanos-io/kube-thanos/tree/v0.16.0) (2020-11-04)

### Changed

- [#164](https://github.com/thanos-io/kube-thanos/pull/164) Expose components via functions with params merged with defaults

- #152 #153 #154 #155 #156 #157 #158 #159 Rewrite all components to not use ksonnet anymore (mostly internal change)

### Added

- [#148](https://github.com/thanos-io/kube-thanos/pull/148) Support for configuring Alertmanager on Thanos Ruler

### Fixed

- [#150](https://github.com/thanos-io/kube-thanos/pull/150) Update query frontend flag name

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.15.0...v0.16.0)

## [v0.15.0](https://github.com/thanos-io/kube-thanos/tree/v0.15.0) (2020-09-07)

### Added

- [#142](https://github.com/thanos-io/kube-thanos/pull/142) query-frontend: Add thanos query frontend component.

- [#145](https://github.com/thanos-io/kube-thanos/pull/145) querier: Add a new mixin to specify `--query.lookback-delta` flag.

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.14.0...v0.15.0)

## [v0.14.0](https://github.com/thanos-io/kube-thanos/tree/v0.14.0) (2020-07-10)

Compatible with https://github.com/thanos-io/thanos/releases/tag/v0.14.0

### Changed

- [#135](https://github.com/thanos-io/kube-thanos/pull/135) *: Relabel pod reference into instance label

- [#134](https://github.com/thanos-io/kube-thanos/pull/131) receive: Only perform anti affinity against receive pods

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.13.0...v0.14.0)

## [v0.13.0](https://github.com/thanos-io/kube-thanos/tree/v0.13.0) (2020-06-22)

Compatible with https://github.com/thanos-io/thanos/releases/tag/v0.13.0

### Changed

- [#118](https://github.com/thanos-io/kube-thanos/pull/118) receive: Extend shutdown grace period to 900s (15min).

- [#131](https://github.com/thanos-io/kube-thanos/pull/131) bucket: Update bucket web to tools bucket web

### Added

- [#119](https://github.com/thanos-io/kube-thanos/pull/119) receive: Distribute receive instances across node zones via pod anti affinity (note: only available on Kubernetes 1.17+)

- [#122](https://github.com/thanos-io/kube-thanos/pull/122) store: Rename `withMemcachedIndexCache` to `withIndexCacheMemcached`

- [#122](https://github.com/thanos-io/kube-thanos/pull/122) store: Enable caching bucket support

- [#128](https://github.com/thanos-io/kube-thanos/pull/128) query: Allow configuring query timeout

- [#129](https://github.com/thanos-io/kube-thanos/pull/129) store: Set pod anti affinity between store pods

### Fixed

- [#116](https://github.com/thanos-io/kube-thanos/pull/116) rule: No quotation marks on alert.label-drop

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.12.0...v0.13.0)

## [v0.12.0](https://github.com/thanos-io/kube-thanos/tree/v0.12.0) (2020-04-16)

Compatible with https://github.com/thanos-io/thanos/releases/tag/v0.12.0

### Added

- [#105](https://github.com/thanos-io/kube-thanos/pull/105) compactor, store: Add deduplication replica label flags and delete delay labels

- [#106](https://github.com/thanos-io/kube-thanos/pull/106) store: Add memcached mixin

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.11.0...v0.12.0)

## [v0.11.0](https://github.com/thanos-io/kube-thanos/tree/v0.11.0) (2020-04-08)

Compatible with https://github.com/thanos-io/thanos/releases/tag/v0.11.0

### Fixed

- [#109](https://github.com/thanos-io/kube-thanos/pull/109) compactor: Use tc.config.replicas variable in compact component

### Added

- [#97](https://github.com/thanos-io/kube-thanos/pull/97) store: Enable binary index header

- [#99](https://github.com/thanos-io/kube-thanos/pull/99) receive: Adapt receive local endpoint to gRPC based endpoint

- [#103](https://github.com/thanos-io/kube-thanos/pull/103) *: Add termination message policy to containers

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.10.0...v0.11.0)

## [v0.10.0](https://github.com/thanos-io/kube-thanos/tree/v0.10.0) (2020-02-11)

Compatible with https://github.com/thanos-io/thanos/releases/tag/v0.10.0

### Breaking Changes

> This version includes lots of breaking changes, you may have to change your downstream changes and re-create your resources when you apply.

- [#90](https://github.com/thanos-io/kube-thanos/pull/90)  *: Refactor to not mutate global objects

### Changed

- [#90](https://github.com/thanos-io/kube-thanos/pull/90)  *: Refactor to not mutate global objects

- [#89](https://github.com/thanos-io/kube-thanos/pull/89)  *: Remove resource requests and limits

- [#63](https://github.com/thanos-io/kube-thanos/pull/63)  store, receive: Hide volumes in StatefulSet when null

- [#67](https://github.com/thanos-io/kube-thanos/pull/67)  *: Move thanos-mixin to main Thanos repo

- [#75](https://github.com/thanos-io/kube-thanos/pull/75)  *: Remove references to metalmatze repo

### Added

- [#83](https://github.com/thanos-io/kube-thanos/pull/83)  ruler, querier: De-duplicate ruler_replica when using Thanos Ruler

- [#84](https://github.com/thanos-io/kube-thanos/pull/84)  receive, querier: Add host anti-affinity to receive and querier

### Fixed

- [#78](https://github.com/thanos-io/kube-thanos/pull/78) ruler: Convert ruler service headless for discovery

- [#80](https://github.com/thanos-io/kube-thanos/pull/80) querier: Fix service discovery query

- [#91](https://github.com/thanos-io/kube-thanos/pull/91) receiver: Append hashring configmap mount rather than replacing

- [#93](https://github.com/thanos-io/kube-thanos/pull/93) receiver: Allow PodDisruptionBudget minAvailable to be overridden

- [#95](https://github.com/thanos-io/kube-thanos/pull/95) bucket: fix bucket port

- [#96](https://github.com/thanos-io/kube-thanos/pull/96) *: Filter emptyDir instead of resetting volumes with PVC


[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/v0.9.0...v0.10.0)

## [v0.9.0](https://github.com/thanos-io/kube-thanos/tree/v0.9.0) (2019-12-13)

Compatible with https://github.com/thanos-io/thanos/releases/tag/v0.9.0

`Initial release:` See full changelog for long history of changes.


[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/53b47dd3c5c262bc17a5c37bad004839f7eda866...v0.9.0)
