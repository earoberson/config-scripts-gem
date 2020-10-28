# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2014_02_09_132911) do

  create_table "config_scripts", force: :cascade do |t|
    t.string "script_name"
  end

  create_table "hair_colors", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "hex_value"
  end

  create_table "people", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "hair_color_id"
    t.string "scope_type"
    t.integer "scope_id"
    t.index ["hair_color_id"], name: "index_people_on_hair_color_id"
  end

end
