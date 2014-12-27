# encoding: utf-8
class Gw::PropGroupSetting < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  belongs_to :prop_other,  :foreign_key => :id, :class_name => 'Gw::PropOther'
  belongs_to :prop_group, :foreign_key => :id, :class_name => 'Gw::PropGroup'

  def self.getajax(params)
    cond = "type_id = #{params[:type_id]} and delete_state=0"
    @schedule_prop_admin = System::Model::Role.get(1, Core.user.id ,'schedule_prop_admin', 'admin')
    admin = Gw.is_admin_admin? || @schedule_prop_admin
    item = Gw::PropOther.find(:all, :conditions=> cond,
      :order=>"type_id, gid, sort_no, name").select{|x|
      if admin
        true
      end
      }.collect{|x| ["other", x.id, "(" + System::Group.find(x.gid).name.to_s + ")" + x.name.to_s, x.gname]}
    item = {:errors=>'該当する候補がありません'} if item.blank?
    return item
  end
end
