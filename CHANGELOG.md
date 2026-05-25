# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0]

First stable release. The public DSL (`access_allow`, `access_require`,
`access_no_match`, `access_allowed?`) is unchanged and considered stable.

### Added
- Configurable logging: `config.logger` (defaults to `Rails.logger`) and
  `config.permission_check_log_level` (defaults to `:debug`).

### Changed
- Per-check "user cannot do X" lines now log at `:debug` instead of `:info`.
  These fire on every failed ability check (menu visibility, record scoping)
  and are normal control flow, not violations, so they no longer flood
  request logs. Set `config.permission_check_log_level = nil` to silence them
  entirely. Actual access violations remain logged at `:info`/`:error`.

### Fixed
- `Abilities.parse_qualified_name` raised `NoMethodError` instead of a
  descriptive `StandardError` for blank or malformed ability names (missing
  comma in the `raise` call).

### Removed
- Dead `AbilitiesManager#about_user` method.

### Internal
- Test coverage raised to 100% line / 98% branch; the two remaining branches
  are unreachable defensive guards.
- Added a project `.standard.yml`.

## [0.3.0]
- Earlier releases (pre-changelog). See the git history for details.
