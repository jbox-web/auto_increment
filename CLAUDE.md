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

- **String vs integer is inferred from `initial`**, not the column type
  (`string?` checks `@options[:initial].is_a?(String)`). Integer path uses
  SQL `MAXIMUM(column)`; string path orders by `LENGTH(column) DESC, column DESC`
  to get the true lexicographic maximum, then calls `.next` (so `'Z' => 'AA'`).
- **`scope`** filters the max query by column values on the record (`WHERE scope = record.scope`).
  **`model_scope`** chains named ActiveRecord scopes onto the query. Both are
  normalized to arrays and accept multiple entries.
- **`force: true`** overwrites even a user-supplied value; default `false` only
  fills a blank field.
- **`lock: true`** adds `.lock` (SELECT … FOR UPDATE) to the max query to avoid
  races under concurrency; default `false`.
- **`before:`** picks the callback (`:create`, `:save`, `:validation`).

## Testing

- Specs run against a full dummy Rails app under `spec/dummy/` (SQLite). Its
  models (`Account`, `User`) are the fixtures exercising the options matrix —
  `User` demonstrates `scope`, `model_scope`, `initial`, `force`, `lock` together.
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
