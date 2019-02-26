# AutoIncrement

[![GitHub license](https://img.shields.io/github/license/jbox-web/auto_increment.svg)](https://github.com/jbox-web/auto_increment/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/jbox-web/auto_increment.svg)](https://github.com/jbox-web/auto_increment/releases/latest)
[![Build Status](https://travis-ci.org/jbox-web/auto_increment.svg?branch=master)](https://travis-ci.org/jbox-web/auto_increment)

AutoIncrement provides automatic incrementation for a integer or string fields in Rails.

## Installation

Put this in your `Gemfile` :

```ruby
git_source(:github){ |repo_name| "https://github.com/#{repo_name}.git" }

gem 'auto_increment', github: 'jbox-web/auto_increment', tag: '1.6.0'
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

* scope: you can define columns that will be scoped and you can use as many as you want (default: nil)
* model_scope: you can define model scopes that will be executed and you can use as many as you want (default: nil)
* initial: initial value of column (default: 1)
* force: you can set a value before create and auto_increment will not change that, but if you do want this, set force to true (default: false)
* lock: you can set a lock on the max query. (default: false)
* before: you can choose a different callback to be used (:create, :save, :validation) (default: create)
