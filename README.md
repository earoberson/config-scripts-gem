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

## Usage

### Config Scripts

#### Generate a new config script:

    $ rails g config_scripts:config_script MyConfigScript

This will add a file to the `db/config_scripts` directory.

#### Run all the pending config scripts:

    $ rake config_scripts:run_pending

### Seed Data

#### Defining Seed Data:

Create a file in the directory `db/seeds/definitions`. Examples of defining seed
data will be coming in the future.

#### Dumping seed data to the disk:

    $ rake config_scripts:seeds:dump

#### Loading the seed data from the disk:

    $ rake config_scripts::seeds::load