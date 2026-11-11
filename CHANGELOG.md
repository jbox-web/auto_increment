## CHANGELOG

### Unreleased

#### Fixed — silent duplicate values

* Exclude NULLs from the string-max query. On PostgreSQL, NULLs sort first under
  `ORDER BY … DESC`, so a single row with a NULL in the column made the maximum read
  as nil and every later record restart at `initial` — unlimited duplicates, nothing
  raised. Did not reproduce on SQLite, which sorts NULLs last.
* Infer the value type from the column as well as from `initial`. A string column
  left with the default integer `initial` used SQL `MAX()`, which is lexicographic:
  `'Z'` outranks `'AA'`, so the sequence stopped advancing at the first carry and
  emitted `'AA'` forever.
* Compute the maximum on `unscoped`. A `default_scope` that hides part of the table
  (soft delete, single tenant) hid rows that still occupy values, so the next value
  duplicated one of them. Single-table inheritance is unaffected: the type condition
  is preserved.
* Exclude the record being saved from its own maximum. With `before: :save` and
  `force: true` the value climbed on every update, the record reading its own value
  as the maximum.
* Read the raw attribute in the blank check, symmetrically with the write. A model
  overriding the reader of the incremented column made the write a silent no-op and
  the column was persisted NULL.

#### Fixed — errors

* `lock: true` no longer applies `FOR UPDATE` to an aggregate. PostgreSQL rejects
  `SELECT MAX(col) … FOR UPDATE` (`FOR UPDATE is not allowed with aggregate
  functions`), so every create raised there; the locked read now returns a row.

#### Added

* Retry on `ActiveRecord::RecordNotUnique`: the value is recomputed and the insert
  retried, up to 3 attempts, each in its own SAVEPOINT. **A unique index on the
  incremented column is now the documented mechanism for concurrency safety** — the
  gem cannot create it for you. The savepoint is required, not defensive: on
  PostgreSQL a unique violation leaves the surrounding transaction aborted.
* `lock: :advisory` — a PostgreSQL transaction-scoped advisory lock keyed on table,
  column and scope values. Unlike a row lock it also covers an empty scope. Held
  until the outermost transaction commits; a no-op on other adapters.
* Support for several `auto_increment` declarations on one model.

#### Changed — may need attention

* An unknown `scope:` now raises `ArgumentError` instead of being skipped, which
  used to turn a per-scope sequence into a table-wide one on a simple typo.
* `model_scope:` is dispatched with `public_send` and must name a real scope; a
  plain `ActiveRecord::Relation` method is refused (`model_scope: :delete_all`
  emptied the table on every create).
* An unknown `before:` raises `ArgumentError` at class definition.
* An unknown `lock:` mode raises `ArgumentError` instead of being read as truthy.
* Runtime dependency narrowed from `rails` to `activerecord` + `railties`.

#### Earlier in this cycle

* Fix `lock: true` being a no-op (the locked relation returned by `Relation#lock` was discarded)
* Fix shared callback-object state: the record is now threaded through instead of stored in `@record`, avoiding cross-record corruption under concurrent creates
* Quote the incremented column name in the string-max query
* Document concurrency semantics and the need for a unique index
* Modernize support matrix: Ruby >= 3.2, Rails >= 7.0 (drops Ruby < 3.2 and Rails < 7.0)

#### Development

* The suite now runs on PostgreSQL as well as SQLite (`DATABASE_ADAPTER=postgresql`),
  with a dedicated CI job. Two of the defects above were invisible to a SQLite-only
  suite at 100 % line coverage.
* Fixtures moved out of `before(:all)`, whose rows escaped DatabaseCleaner's
  per-example transaction and survived the whole run.
* Removed `spec/dummy/config/secrets.yml` (two committed keys, unread since Rails 7)
  and the dead migration duplicating `schema.rb`.

### 1.8.0 - 2020-04-04

* Add support of Ruby 2.7
* Add support of Rails 6.x
* Add binstubs to ease development

* This is the last version to support Ruby 2.4.x

### 1.7.0 - 2019-02-26

* Add support of Ruby 2.6
* Add support of Rails 5.2.x
* Drop support of Rails 4.2.x
* Switch to Zeitwerk to load gem files

### 1.6.0 - 2019-02-26

* Test with latest versions of Rails (4.2.11, 5.0.7, 5.1.6, 5.2.2) and Ruby (2.6.1, 2.5.3, 2.4.5)
* This is the last version to support Rails 4.2.x
