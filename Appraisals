# frozen_string_literal: true

RAILS_VERSIONS = %w(
  4.2.11
  5.0.7
  5.1.6
  5.2.2
)

RAILS_VERSIONS.each do |version|
  appraise "rails_#{version}" do
    gem 'activerecord', version
    gem 'activesupport', version
  end
end
