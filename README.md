# ConfigScripts

This gem provides libraries for generating configuration scripts, and reading
and writing seed data to spreadsheets.

## Installation

Add this line to your application's Gemfile:

    gem 'config_scripts'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install config_scripts

Generate the new migrations for the config_scripts table:

    $ rails g config_scripts:migrations

And run them:

    $ rake db:migrate

## Original Implementation

This project is a fork of https://github.com/kalinchuk/config-scripts-gem, which is a mirror of https://www.rubydoc.info/gems/config_scripts/0.4.7
