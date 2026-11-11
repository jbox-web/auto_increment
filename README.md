# AutoIncrement

[![GitHub license](https://img.shields.io/github/license/jbox-web/auto_increment.svg)](https://github.com/jbox-web/auto_increment/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/jbox-web/auto_increment.svg)](https://github.com/jbox-web/auto_increment/releases/latest)
[![CI](https://github.com/jbox-web/auto_increment/workflows/CI/badge.svg)](https://github.com/jbox-web/auto_increment/actions)

AutoIncrement provides automatic incrementation for an integer or string field in Rails.

## Installation

Put this in your `Gemfile` :

```ruby
git_source(:github){ |repo_name| "https://github.com/#{repo_name}.git" }

gem 'auto_increment', github: 'jbox-web/auto_increment'
```

then run `bundle install`.

Pinning a tag is fine, but note that `1.8.0` predates the correctness fixes listed
in `CHANGELOG.md` — among them duplicate values on PostgreSQL and a `lock: true`
that raised on every create there.

## Usage

To work with an auto increment column you used to do something like this in your model:

```ruby
  before_create :set_code
  def set_code
    max_code = Operation.maximum(:code)
    self.code = max_code.to_i + 1
  end
```

Looks fine, but not when you need to do it over and over again. In fact auto_increment does it under the cover.

All you need to do is this:

```ruby
class Project < ApplicationRecord
  auto_increment :code
end
```

And your code field will be incremented :)

## Customizing

So you have a different column or need a scope. auto_increment provides options. You can use it like this:

```ruby
class Project < ApplicationRecord
  auto_increment :letter, scope: [:account_id, :job_id], model_scope: :in_account, initial: 'C', force: true, lock: false, before: :create
end
```

First argument is the column that will be incremented. It can be an integer or a string column.

* **scope:** columns the sequence is counted within, as many as you want (default: nil). A column the record does not respond to raises `ArgumentError` — it is never skipped silently.
* **model_scope:** named scopes to chain onto the max query, as many as you want (default: nil). Must be a real scope on the model; a plain `ActiveRecord::Relation` method such as `delete_all` is refused.
* **initial:** value used when the sequence is empty (default: 1)
* **force:** by default a value you set yourself is kept; with `force: true` it is overwritten (default: false)
* **before:** which callback to use, one of `:create`, `:save`, `:validation` (default: `:create`). Note that `:save` also runs on updates. Anything else raises `ArgumentError` at class definition.
* **lock:** `false`, `true` or `:advisory` — see below (default: false)

### String columns

The value is advanced with `String#next`, so `'Z'` becomes `'AA'`. Two things follow:

* The maximum of a string sequence is **not** SQL `MAX()`, because `'Z'` sorts above
  `'AA'` while `'AA'` is the real successor. The gem orders by
  `LENGTH(column) DESC, column DESC` instead.
* That ordering is an expression, so **no plain index can serve it**. Measured with
  an index on the column present, the query still plans as a full scan plus a sort
  (`SCAN` + `USE TEMP B-TREE FOR ORDER BY`), while the integer path uses a covering
  index. On a large table, add a functional index on `(LENGTH(column), column)`.

The gem picks the string strategy when the column is `string`/`text` **or** when
`initial` is a String. You do not have to pass `initial` for a string column — but
if you pass an integer `initial` on one, the first value will be that integer.

### Scopes and default_scope

The max query runs on `unscoped`. This is deliberate: a `default_scope` that hides
part of the table — soft delete, a single-tenant scope — hides rows that still
occupy values in the sequence, and the next value would then duplicate one of them.
Use `scope:` and `model_scope:` to narrow the query on purpose.

Single-table inheritance is preserved: `unscoped` drops the default scope but keeps
the type condition, so a subclass counts only its own rows.

### Concurrency

Reading the current maximum and adding one is **not atomic**, so two concurrent
inserts can compute the same value. The guarantee comes from the database:

1. **Add a unique index** on the incremented column, scoped columns included. The
   gem cannot create it for you, and without it there is nothing to fall back on.
2. The gem then **retries** on `ActiveRecord::RecordNotUnique`, clearing the column
   and recomputing, up to 3 attempts. Each attempt runs in its own SAVEPOINT,
   because on PostgreSQL a unique violation leaves the surrounding transaction
   aborted and every later statement in it would fail. The cost is one
   SAVEPOINT/RELEASE per create.

`lock:` reduces how often that retry fires. It is not what makes the result correct:

* `lock: false` (default) — no locking.
* `lock: true` — locks the row holding the current maximum (`SELECT … FOR UPDATE`).
  Partial by construction: a row lock locks the rows it returns, so on an empty
  scope it locks nothing and two concurrent first inserts still collide.
* `lock: :advisory` — a PostgreSQL transaction-scoped advisory lock keyed on table,
  column and scope values. Being a named mutex it also covers the empty scope. Two
  caveats: it is held until the **outermost** transaction commits, so wrapping many
  creates in one transaction serializes every other writer on that key for the whole
  block; and it is a no-op on other adapters (SQLite serializes writers by itself,
  and MySQL's `GET_LOCK` is session-scoped, so it would outlive the commit).

## Development

The suite runs against a dummy Rails app on SQLite by default, and on PostgreSQL
with `DATABASE_ADAPTER=postgresql bin/rspec`. Run both: the generated SQL is not
portable by accident — NULL ordering under `ORDER BY … DESC` is reversed between the
two, and SQLite silently drops lock clauses.
