# encoding: utf-8
class System::UsersProfileSetting < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Base::Content

  def self.get_column_name(key_name)
    item = find(:first, :conditions=>"key_name = '#{key_name}'")
    return nil if item.blank?
    return item.name
  end
  
  def self.column_used?(key_name)
    item = find(:first, :conditions=>"key_name = '#{key_name}'")
    return false if item.blank?
    return true if item.used == 1
    return false
  end

  def self.add_column_used?
    items = find(:all, :conditions=>["key_name like ?", "add_column%"])
    return false if items.blank?
    is_used = false
    items.each do |item|
      is_used = true if item.used == 1 && item.name.present?
    end
    return is_used
  end

end
