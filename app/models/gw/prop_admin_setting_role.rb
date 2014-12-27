# encoding: utf-8
class Gw::PropAdminSettingRole < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  belongs_to :prop_admin_setting,  :foreign_key => :prop_setting_id,     :class_name => 'Gw::PropAdminSetting'
  belongs_to :group,       :foreign_key => :gid,         :class_name => 'System::Group'
end
