# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_23_234906) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "game_symbols", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.string "name"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.boolean "wild", default: false, null: false
    t.index ["game_id", "code"], name: "index_game_symbols_on_game_id_and_code", unique: true
    t.index ["game_id"], name: "index_game_symbols_on_game_id"
    t.index ["game_id"], name: "index_one_wild_per_game", unique: true, where: "wild"
  end

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "reel_count", null: false
    t.integer "row_count", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "win_mechanic", default: "lines", null: false
    t.index ["user_id", "name"], name: "index_games_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_games_on_user_id"
  end

  create_table "paylines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.integer "position", null: false
    t.integer "rows", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.index ["game_id", "position"], name: "index_paylines_on_game_id_and_position", unique: true
    t.index ["game_id"], name: "index_paylines_on_game_id"
  end

  create_table "paytable_entries", force: :cascade do |t|
    t.integer "count", null: false
    t.datetime "created_at", null: false
    t.bigint "game_symbol_id", null: false
    t.integer "payout", null: false
    t.datetime "updated_at", null: false
    t.bigint "variation_id", null: false
    t.index ["game_symbol_id"], name: "index_paytable_entries_on_game_symbol_id"
    t.index ["variation_id", "game_symbol_id", "count"], name: "index_paytable_entries_on_variation_symbol_count", unique: true
    t.index ["variation_id"], name: "index_paytable_entries_on_variation_id"
  end

  create_table "reel_strips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.string "symbols", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.bigint "variation_id", null: false
    t.index ["variation_id", "position"], name: "index_reel_strips_on_variation_id_and_position", unique: true
    t.index ["variation_id"], name: "index_reel_strips_on_variation_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "variations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.integer "number", null: false
    t.integer "target_rtp_max"
    t.integer "target_rtp_min"
    t.datetime "updated_at", null: false
    t.index ["game_id", "number"], name: "index_variations_on_game_id_and_number", unique: true
    t.index ["game_id"], name: "index_variations_on_game_id"
  end

  create_table "wild_exclusions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "excluded_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "wild_id", null: false
    t.index ["excluded_id"], name: "index_wild_exclusions_on_excluded_id"
    t.index ["wild_id", "excluded_id"], name: "index_wild_exclusions_on_wild_id_and_excluded_id", unique: true
    t.index ["wild_id"], name: "index_wild_exclusions_on_wild_id"
  end

  add_foreign_key "game_symbols", "games"
  add_foreign_key "games", "users"
  add_foreign_key "paylines", "games"
  add_foreign_key "paytable_entries", "game_symbols"
  add_foreign_key "paytable_entries", "variations"
  add_foreign_key "reel_strips", "variations"
  add_foreign_key "sessions", "users"
  add_foreign_key "variations", "games"
  add_foreign_key "wild_exclusions", "game_symbols", column: "excluded_id", on_delete: :cascade
  add_foreign_key "wild_exclusions", "game_symbols", column: "wild_id", on_delete: :cascade
end
