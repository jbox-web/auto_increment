# AutoIncrement

[![GitHub license](https://img.shields.io/github/license/jbox-web/auto_increment.svg)](https://github.com/jbox-web/auto_increment/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/jbox-web/auto_increment.svg)](https://github.com/jbox-web/auto_increment/releases/latest)
[![CI](https://github.com/jbox-web/auto_increment/workflows/CI/badge.svg)](https://github.com/jbox-web/auto_increment/actions)
[![Code Climate](https://codeclimate.com/github/jbox-web/auto_increment/badges/gpa.svg)](https://codeclimate.com/github/jbox-web/auto_increment)
[![Test Coverage](https://codeclimate.com/github/jbox-web/auto_increment/badges/coverage.svg)](https://codeclimate.com/github/jbox-web/auto_increment/coverage)

AutoIncrement provides automatic incrementation for a integer or string fields in Rails.

## Installation

Put this in your `Gemfile` :

```ruby
git_source(:github){ |repo_name| "https://github.com/#{repo_name}.git" }

gem 'auto_increment', github: 'jbox-web/auto_increment', tag: '1.8.0'
```

then run `bundle install`.


## Usage

To work with a auto increment column you used to do something like this in your model:

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

First argument is the column that will be incremented. Can be integer or string.

* **scope:** you can define columns that will be scoped and you can use as many as you want (default: nil)
* **model_scope:** you can define model scopes that will be executed and you can use as many as you want (default: nil)
* **initial:** initial value of column (default: 1)
* **force:** you can set a value before create and auto_increment will not change that, but if you do want this, set force to true (default: false)
* **lock:** wraps the max query in `SELECT ... FOR UPDATE` (within the save transaction) to serialize concurrent increments. (default: false)
* **before:** you can choose a different callback to be used (:create, :save, :validation) (default: create). Note that `:save` also runs on updates.

### Concurrency

The value is computed by reading the current maximum and adding one, so two
concurrent inserts can still race. `lock: true` mitigates this on databases that
support row locking, but for a hard guarantee add a **unique database index** on
the incremented column (scoped columns included) as a backstop — the gem does
not create one for you.
