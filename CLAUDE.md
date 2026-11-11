# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`auto_increment` is a Rails gem that automatically increments an integer or string
field on an ActiveRecord model via a lifecycle callback. It is mounted as a
`Rails::Engine`; there is no standalone runtime.

## Commands

```sh
bundle install                         # install dependencies
bin/rspec                              # run the full test suite
bin/rspec spec/lib/auto_increment/incrementor_spec.rb   # run a single spec file
bin/rspec spec/lib/auto_increment/incrementor_spec.rb:15 # run a single example (by line)
bin/rubocop                            # lint (RuboCop + performance/rake/rspec plugins)
bin/rubocop -A                         # lint with autocorrect
bundle exec appraisal install          # regenerate gemfiles/ lockfiles from Appraisals
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bin/rspec  # run against a specific Rails version
DATABASE_ADAPTER=postgresql bin/rspec  # run against PostgreSQL instead of SQLite
bundle exec guard                      # watch files and re-run specs on change (Guardfile)
```

## Architecture

The public API is a single class method, `auto_increment`, injected into every
ActiveRecord model. The flow, entry to exit:

- `lib/auto_increment.rb` — Zeitwerk boot; requires the engine only when `Rails` is defined.
- `engine.rb` — on the `active_record` load hook, `extend`s `AutoIncrement::ActiveRecord`
  onto `ActiveRecord::Base`, making `auto_increment` a class macro on all models.
- `active_record.rb` — the `auto_increment(column, options)` macro. It reads
  `before:` (default `:create`) and registers an `Incrementor` instance as a
  `before_<callback>` hook. Because the `Incrementor` responds to `before_create` /
  `before_validation` / `before_save` (aliased to the same method), the instance
  itself is the callback object Rails invokes.
- `incrementor.rb` — the core. On the callback it computes the next value and writes
  it to the column, but only when `can_write?` (the field is blank, or `force: true`).

### Incrementor semantics (the important, non-obvious parts)

- **String vs integer is inferred from the column type OR from `initial`**
  (`string?` is true when `initial` is a String, or when the column is
  `string`/`text`). The union matters: inferring from `initial` alone sent a
  string column with the default integer `initial` down the integer path, where
  SQL `MAX()` over a varchar is plain lexicographic — 'Z' outranks 'AA', so the
  maximum stopped advancing at the first carry and the sequence emitted 'AA'
  forever. Inferring from the column alone would break the reverse case (integer
  column, String `initial`).
- Integer path uses SQL `MAXIMUM(column)`; string path orders by
  `LENGTH(column) DESC, column DESC` to get the true lexicographic maximum, then
  calls `.next` (so `'Z' => 'AA'`). The string path **must** exclude NULLs
  explicitly: adapters disagree on where they sort (PostgreSQL first under DESC,
  SQLite last), and a NULL sorting first makes the maximum read as nil, so every
  later record restarts at `initial`. SQL `MAX()` skips NULLs on its own, hence
  the asymmetry between the two paths.
- **`scope`** filters the max query by column values on the record (`WHERE scope = record.scope`).
  **`model_scope`** chains named ActiveRecord scopes onto the query. Both are
  normalized to arrays and accept multiple entries.
- **`force: true`** overwrites even a user-supplied value; default `false` only
  fills a blank field.
- **`lock: true`** adds `.lock` (SELECT … FOR UPDATE) to the max query to avoid
  races under concurrency; default `false`.
- **`before:`** picks the callback (`:create`, `:save`, `:validation`).

## Testing

- Specs run against a full dummy Rails app under `spec/dummy/`. The adapter is
  chosen by `DATABASE_ADAPTER` (default `sqlite3`, also `postgresql`) — see
  `spec/dummy/config/database.yml`, which emits its whole document from one ERB
  expression because Rails appends `;` after each ERB tag and that breaks a
  `case` spread over several tags.
- **Run both adapters before believing a green suite.** The gem's SQL is not
  portable by accident: NULL ordering under `ORDER BY … DESC` is reversed between
  PostgreSQL and SQLite, PostgreSQL rejects `FOR UPDATE` on an aggregate, and
  SQLite's Arel visitor silently *drops* lock clauses. Several real defects were
  green on a SQLite-only suite at 100 % line coverage.
- **Coverage is per-adapter and cannot reach 100 % in a single run.** PostgreSQL
  alone gives 124/124 lines; SQLite alone gives 120/124, missing exactly the four
  PostgreSQL-only advisory-lock lines — and conversely PostgreSQL never takes the
  non-PostgreSQL early return in `Locking#advisory_lock!`. The union of both runs
  is 124/124 lines and 39/40 branches; the last branch is the `defined?(Rails)`
  guard in `lib/auto_increment.rb`, which a suite that boots Rails cannot exercise.
  Both CI jobs therefore upload coverage, so the published figure is the union.
- **Delete `coverage/` between adapter runs when reading the numbers.** SimpleCov
  merges results from recent runs, so running SQLite then PostgreSQL reports a
  stale union and can show genuinely covered lines as uncovered — that mistake was
  made once here.
- Fixtures: `Account` and `User` exercise the options matrix — `User` demonstrates
  `scope`, `model_scope`, `initial`, `force`, `lock` together, and carries a
  `default_scope` because that interaction is itself under test. `Sequence` and
  `PlainSequence` (table `sequences`) are the *neutral* fixtures for the
  adapter-sensitive integration specs in `spec/lib/auto_increment/maximum_spec.rb`:
  no default scope, so anything observed there is the incrementor's own behavior.
- `spec/spec_helper.rb` boots the dummy app and starts SimpleCov; `config_rspec.rb`
  loads the schema and wires DatabaseCleaner (transaction strategy per example).
- The DB schema lives in `spec/dummy/db/schema.rb` (loaded directly, not migrated).

## Conventions

- Ruby `>= 3.2`, Rails `>= 7.0`. Multi-version testing via Appraisal — the
  `Appraisals` file and `gemfiles/*.gemfile` must stay in sync; edit `Appraisals`
  then run `appraisal install`, never hand-edit the generated gemfiles.
- Every file begins with `# frozen_string_literal: true`.
- RuboCop config (`.rubocop.yml`) intentionally disables most `Layout/EmptyLines*`
  cops — the codebase uses double blank lines between methods; keep that style.
