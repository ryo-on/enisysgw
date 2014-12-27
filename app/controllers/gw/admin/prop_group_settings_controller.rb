# encoding: utf-8
class Gw::Admin::PropGroupSettingsController < Gw::Admin::PropGenreCommonController
  include System::Controller::Scaffold
  layout "admin/template/schedule"

  def initialize_scaffold
    @js = %w(/_common/js/yui/build/animation/animation-min.js /_common/js/popup_calendar/popup_calendar.js /_common/js/yui/build/calendar/calendar.js /_common/js/dateformat.js)
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    Page.title = "施設グループ設定"
    @sp_mode = :prop

    #施設マスタ権限を持つユーザーかの情報
    @schedule_prop_admin = Gw.is_other_admin?('schedule_prop_admin')
    @is_gw_admin = Gw.is_admin_admin? || @schedule_prop_admin

    @genre = 'group'
    @model = Gw::PropGroupSetting

    @prop = Gw::PropType.find(:all,
      :conditions => ["state = ?", "public"],
      :order => "sort_no")
    @group = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and id > ? and parent_id=?", "public","1","1"],
      :order => "sort_no")
    @child = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and parent_id > ?", "public","1"],
      :order => "sort_no")
    @set = @model.find(:all, :select => "gw_prop_group_settings.*,gw_prop_others.id,gw_prop_others.name",
      :joins => "join gw_prop_others on gw_prop_group_settings.prop_other_id = gw_prop_others.id",
      :conditions =>"gw_prop_others.delete_state=0",
      :order => "prop_group_id,prop_other_id")
    @prop_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name")

    return authentication_error(403) unless @is_gw_admin
  end

  def index
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    @groupitems = Array.new
    @group.each do | item|
      num = item.id
      @dummy = DummyItem3.new
      @dummy.id = item.id
      @dummy.name = item.name
      @dummy.setsubi = ""
      @set.each do | set|
        if set.prop_group_id == item.id
          if @dummy.setsubi.blank?
            @dummy.setsubi = set.name
          else
            @dummy.setsubi =  @dummy.setsubi + "," + set.name
          end
        end
      end
      @dummy.setsubi = hbr(@dummy.setsubi)
      @groupitems << @dummy

      @child.each do |child|
        if child.parent_id == item.id
          @dummy = DummyItem3.new
          @dummy.id = child.id
          @dummy.name = "　　"+child.name
          @dummy.setsubi = ""
          @set.each do | set|
            if set.prop_group_id == child.id
              if @dummy.setsubi.blank?
                @dummy.setsubi = set.name
              else
                @dummy.setsubi =  @dummy.setsubi + "," + set.name
              end
            end
          end
          @dummy.setsubi = hbr(@dummy.setsubi)
          @groupitems << @dummy
        end
      end
    end

  end

  def hbr(str)
    str.gsub(/,/, "<br />").html_safe
  end

  class DummyItem3
    attr_accessor  :id, :name, :setsubi, :sort_no
  end

  def init_params
  end

  def edit
    @item = Gw::PropGroup.find(params[:id])
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    @def_prop = Gw::PropType.find(:all, :select => "id",
      :conditions => ["state = ?", "public"],
      :order => "id")
    id=0
    @def_prop.each do | prop|
      id=prop.id if id==0 || id>prop.id
    end
    params[:type_id]=id
    @_props = Array.new
    @props_items = Gw::PropGroupSetting.find(:all, :conditions=>["prop_group_id = ?", params[:id]], :order => "prop_other_id")
    @props_items.each do |props_item|
      @_prop = Gw::PropOther.find(props_item.prop_other_id)
      if @_prop.delete_state==0
        _get_prop_json_array
      end
    end
    @prop_group_settings_json = @_props.to_json
  end

  def _get_prop_json_array
    # セレクトボックス施設の中身用の配列を作成
    gid = @_prop.gid
    if gid.present?
      group = System::Group.find_by_id(gid)
      gname = "(#{System::Group.find_by_id(gid).name.to_s})" if group.present?
    else
      gname = ""
    end
    @_props.push ["other", @_prop.id, "#{gname}#{@_prop.name}"]
  end

  def create
    @item = Gw::PropGroupSetting.new(params[:item])
  end

  def update
    _params = params.dup
      @item = Gw::PropGroup.find(params[:id])
    _params = params.dup

    props = JsonParser.new.parse(params[:item][:prop_group_settings_json])
    prop_group_id = params[:id]
    Gw::PropGroupSetting.destroy_all("prop_group_id = #{prop_group_id}")
    props.each_with_index{|prop, y|
      new_prop = Gw::PropGroupSetting.new()
      new_prop.prop_group_id = params[:id]
      new_prop.prop_other_id = prop[1]
      new_prop.created_at = 'now()'
      new_prop.updated_at = 'now()'
      new_prop.save
    }
    flash[:notice] = '編集に成功しました。'
    redirect_url = "/gw/prop_group_settings"
    redirect_to redirect_url
  end

  def getajax
    @item = Gw::PropGroupSetting.getajax params
    respond_to do |format|
      format.json { render :json => @item }
    end
  end
end
