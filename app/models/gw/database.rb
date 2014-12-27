# -*- encoding: utf-8 -*-
class Gw::Database < ActiveRecord::Base
  self.abstract_class = true
  establish_connection "#{Rails.env}_jgw_gw"
end
