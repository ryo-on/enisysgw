class Gwsub::GwsubPref < ActiveRecord::Base
  # このモデルはテーブルと関連づかない抽象的なクラスと見做すためのフラグ
  self.abstract_class = true
  establish_connection "#{Rails.env}_jgw_gw_pref"
end
