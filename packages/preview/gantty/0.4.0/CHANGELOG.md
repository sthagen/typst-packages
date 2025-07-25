# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0]

### Added

- The `intervals` field to task to allow for specifying multiple intervals in
  which as task is valid.
- You can now manually specify interviews for a taskgroup

### Changed

- `form-well` is now called `normalize-gantt`
- The `normalize-gantt` function now parses all datetimes as well.
- Update `cetz`

### Fixed

- Certain properties on `block` and `baseline` causing messed up gridlines

## [0.3.0]

### Added

- The `today-localized` field to change the translation of "Today".
- Documented the package.
- The `create-header`, `create-custom-year-header`, `create-custom-month-header`,
  `create-custom-day-header`, and `create-custom-week-header`.
- The ability for anonymous taskgroups

## [0.2.1]

### Fixed

- Days overrunning the header.

## [0.2.0] - 2025-03-06

### Added

- Support for custom start end and dates.

### Fixed

- A floating point precision error causing milestones to fail to resolve.
- A typo in the documentation.
