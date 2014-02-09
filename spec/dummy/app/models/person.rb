class Person < ActiveRecord::Base
  belongs_to :hair_color
  belongs_to :scope, polymorphic: true
end
