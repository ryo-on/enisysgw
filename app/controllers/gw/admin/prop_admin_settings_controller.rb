# encoding: utf-8
class Gw::Admin::PropAdminSettingsController < Gw::Admin::PropGenreCommonController
  include System::Controller::Scaffold
  include Gw::RumiHelper
  layout "admin/template/schedule"

  def initialize_scaffold
    super
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    Page.title = "施設予約可能期間･時間設定"
    @sp_mode = :prop
    @schedule_prop_admin = System::Model::Role.get(1, Core.user.id ,'schedule_prop_admin', 'admin')
    @is_gw_admin = Gw.is_admin_admin? || @schedule_prop_admin
    @genre = 'group'
    @model = Gw::PropAdminSetting
    @type = Gw::PropType.find(:all,
      :conditions => ["state = ?", "public"],
      :order => "sort_no")
    return authentication_error(403) unless @is_gw_admin
  end

  def index
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    @item = @model.find(:all,
            :joins => :prop_admin_setting_roles, :group => "prop_setting_id", :order =>"type_id,id")
    @type = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id", :order => 'sort_no,id')
    @items = Array.new
    @type.each do |type|
      @item.each do | item|
        if type.id == item.type_id
          @items << item
        end
      end
    end
  end

  def new
    @group = Site.user_group
    @item = @model.new({})
    @item.type_id=1

    json = []
    json = json.to_json
    @admin_json = json
  end

  def create
    @item = @model.new()
    @item.name = params[:item][:name]
    @item.type_id = params[:item][:type_id]
    @item.span = params[:item][:span]
    @item.span_limit = params[:item][:span_limit]
    @item.span_hour =params[:item][:span_hour]
    @item.time_limit =params[:item][:time_limit]
    if @item.time_limit==1
      @item.span_hour = ""
    end
    @item.created_at ='now()'
    @item.updated_at = 'now()'
    @item.save
    if @item.name.blank? || (@item.span.blank? || @item.span<1 || @item.span>999) && @item.span_limit==0 || (@item.span_hour.blank? || @item.span_hour<1 || @item.span_hour>999) && @item.span_limit==0
      _create @item
    else
      id=@model.find(:all, :select => "id")
      @id=0
      id.each do |id|
        @id=id.id if @id<id.id
      end
      admin_groups = ::JsonParser.new.parse(params[:item][:admin_json])
      admin_groups.each_with_index{|admin_group, y|
        new_admin_group = Gw::PropAdminSettingRole.new()
        new_admin_group.gid = admin_group[1]
        new_admin_group.prop_setting_id = @id
        new_admin_group.created_at = 'now()'
        new_admin_group.updated_at = 'now()'
        new_admin_group.save
      }
      _create @item
    end
  end

  def edit
    @item = @model.find(params[:id])
    return http_error(404) if @item.blank?
    parent_groups = Gw::PropAdminSetting.get_parent_groups
    @admin_json = @item.admin(:select, parent_groups).to_json
  end

  def update
    _params = params.dup
    @item = Gw::PropAdminSetting.find(params[:id])
    @item.name = params[:item][:name]
    @item.type_id = params[:item][:type_id]
    @item.span = params[:item][:span]
    @item.span_limit = params[:item][:span_limit]
    @item.span_hour =params[:item][:span_hour]
    @item.span_min =params[:item][:span_min]
    @item.time_limit =params[:item][:time_limit]
    if @item.time_limit==1
      @item.span_hour = ""
      @item.span_min = ""
    end
    now = DateTime.now
    @item.updated_at = now.strftime("%Y-%m-%-d %-H:%-M")
    @item.save
    _params = params.dup
    return http_error(404) if @item.blank?

    admin_groups = JsonParser.new.parse(params[:item][:admin_json])
    prop_setting_id = params[:id]
    Gw::PropAdminSettingRole.destroy_all("prop_setting_id = #{prop_setting_id}")
    admin_groups.each_with_index{|admin_group, y|
      new_admin_group = Gw::PropAdminSettingRole.new()
      new_admin_group.prop_setting_id = params[:id]
      new_admin_group.gid = admin_group[1]
      new_admin_group.created_at = 'now()'
      new_admin_group.updated_at = 'now()'
      new_admin_group.save
    }
    @item.save
    _update @item, :notice => "編集に成功しました。"
  end

  def destroy
    @items = @model.find_by_id(params[:id])
    return http_error(404) if @items.blank?
    @items.destroy
    prop_setting_id = params[:id]
    Gw::PropAdminSettingRole.destroy_all("prop_setting_id = #{prop_setting_id}")
    _update @items, :notice => "削除処理は完了しました。"
  end

  class DummyItem
    attr_accessor  :id, :name, :type_id, :type_name, :span, :time, :hour, :min
  end

  class DummyItem2
    attr_accessor  :id, :name
  end
end