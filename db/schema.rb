# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20181003215237) do

  create_table "active_requests", force: :cascade do |t|
    t.string   "user_id"
    t.string   "document_photo"
    t.string   "document_selfie"
    t.string   "status"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  create_table "api_infos", force: :cascade do |t|
    t.string   "user_id"
    t.string   "key"
    t.string   "secret"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "exchangeorders", force: :cascade do |t|
    t.string   "par"
    t.string   "tipo"
    t.float    "amount"
    t.boolean  "has_execution"
    t.float    "price"
    t.string   "status"
    t.string   "user_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "payments", force: :cascade do |t|
    t.string   "user_id"
    t.string   "status"
    t.string   "label"
    t.string   "endereco"
    t.string   "volume"
    t.string   "network"
    t.string   "txid"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "op_id"
    t.         "string"
    t.string   "hex"
    t.string   "description"
  end

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "persistence_token"
    t.integer  "login_count",        default: 0, null: false
    t.integer  "failed_login_count", default: 0, null: false
    t.datetime "last_request_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.string   "current_login_ip"
    t.string   "last_login_ip"
    t.string   "perishable_token"
    t.string   "username"
    t.string   "birth"
    t.string   "document"
    t.string   "phone"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "role"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.string   "address"
    t.string   "currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "user_id"
    t.string   "dest_tag"
  end

end
