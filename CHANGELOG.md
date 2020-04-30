# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

NOTE: As semantic versioning states all 0.y.z releases can contain breaking changes.

> kube-thanos' major versions are in sync with upstream Thos project.

We use *breaking* word for marking changes that are not backward compatible (relates only to v0.y.z releases.)

## Unreleased

### Changed

- [#118](https://github.com/thanos-io/kube-thanos/pull/118) receive: Extend shutdown grace period to 900s (15min).

### Added

- [#105](https://github.com/thanos-io/kube-thanos/pull/105) compactor, store: Add deduplication replica label flags and delete delay labels

- [#105](https://github.com/thanos-io/kube-thanos/pull/105) compactor, store: Add deduplication replica label flags and delete delay labels

- [#119](https://github.com/thanos-io/kube-thanos/pull/119) receive: Distribute receive instances across node zones via pod anti affinity (note: only available on 1.17+).

### Fixed

-

[Full Changelog](https://github.com/thanos-io/kube-thanos/compare/master...v0.11.0)

## [v0.11.0](https://github.com/thanos-io/kube-thanos/tree/v0.11.0) (2020-02-11)

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
