# encoding: utf-8
class Gw::PropAdminSetting < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  validates_presence_of :name
  validates_presence_of :span, :unless => "span_limit==1"
  validates_numericality_of :span, :only_integer =>true, :greater_than_or_equal_to =>1, :less_than_or_equal_to =>999, :unless => "span_limit==1 or span.blank?"
  validates_presence_of :span_hour, :unless => "time_limit==1"
  validates_numericality_of :span_hour, :only_integer =>true, :greater_than_or_equal_to =>1, :less_than_or_equal_to =>999, :unless => "time_limit==1 or span_hour.blank?"


  has_many :prop_admin_setting_roles, :foreign_key => :prop_setting_id, :class_name => 'Gw::PropAdminSettingRole', :order=>"gw_prop_admin_setting_roles.id"
  belongs_to :prop_type, :foreign_key => :type_id, :class_name => 'Gw::PropType'

  def admin_gids
    self.prop_admin_setting_roles.select{|x| x.id>0}.collect{|x| x.gid}
  end

  def self.get_parent_groups
    parent_groups = System::GroupHistory.new.find(:all, :conditions =>"level_no = 2", :order=>"sort_no , code, start_at DESC, end_at IS Null ,end_at DESC")
    return parent_groups
  end

  def admin(pattern = :show, parent_groups = Gw::PropAdminSetting.get_parent_groups)
    admin = Array.new
    groups = System::GroupHistory.new.find(:all, :conditions => ["id in (?)", self.admin_gids], :order=>"level_no,  sort_no , code, start_at DESC, end_at IS Null ,end_at DESC")
    parent_groups.each do |parent_group|
      groups.each do |group|
        g = System::GroupHistory.find_by_id(group.id)
        name = g.name
        if !g.blank?
          if g.id == parent_group.id
            admin << [name] if pattern == :show
            admin << ["", g.id, name] if pattern == :select
          elsif g.parent_id == parent_group.id
            if g.state == "disabled"
              admin << ["<span class=\"required\">#{name}</span>"] if pattern == :show
            else
              admin << [name] if pattern == :show
              admin << ["", g.id, name] if pattern == :select
            end
          end
        else
          admin << ["<span class=\"required\">削除所属 gid=#{group.id}</span>"] if pattern == :show
        end
      end
    end
    return admin.uniq
  end
end