# encoding: utf-8
class Gw::Admin::SchedulePropsController < Gw::Admin::SchedulesController
  include System::Controller::Scaffold
  include Gw::RumiHelper
  layout "admin/template/schedule"

  def initialize_scaffold
    return redirect_to(request.env['PATH_INFO']) if params[:reset]
    Page.title = "施設予約"
  end

  def init_params
    @genre = params[:s_genre]
    @genre = Gw.trim(nz(@genre)).downcase
    genre = @genre

    @cls = params[:cls]

    case params['action']
    when 'getajax'

    else
      raise Gw::ApplicationError, "指定がおかしいです(#{genre})" if genre.blank?
    end
    @title = "施設"
    @s_genre = "?s_genre=other"
    @piece_head_title = '施設予約'
    @index_order = 'extra_flag, sort_no, gid, name'
    @js= ['/_common/js/gw_schedules.js'] +
      %w(gw_schedules popup_calendar/popup_calendar dateformat).collect{|x| "/_common/js/#{x}.js"} +
      %w(yahoo dom event container menu animation calendar).collect{|x| "/_common/js/yui/build/#{x}/#{x}-min.js"}
    @css = %w(/_common/js/yui/build/menu/assets/menu.css /_common/themes/gw/css/schedule.css)
    @uid = Gw::Model::Schedule.get_uids(params)[0]
    @gid = nz(params[:gid], Gw::Model::Schedule.get_user(@uid).groups[0].id) rescue Site.user_group.id
    @state_user_or_group = params[:gid].blank? ? :user : :group
    @sp_mode = :prop

    a_qs = []
    a_qs.push "uid=#{params[:uid]}" unless params[:uid].nil?
    a_qs.push "gid=#{params[:gid]}" unless params[:gid].nil?
    a_qs.push "cls=#{@cls}"
    a_qs.push "s_genre=#{@genre}"
    @schedule_move_qs = a_qs.join('&')


    @up_schedules = nz(Gw::Model::UserProperty.get('schedules'.singularize), {})

    #施設マスタ権限を持つユーザーかの情報
    @schedule_prop_admin = System::Model::Role.get(1, Core.user.id ,'schedule_prop_admin', 'admin')

    @is_gw_admin = Gw.is_admin_admin?
    @is_gw_admin = @is_gw_admin || @schedule_prop_admin

    gids = Array.new
    Core.user.groups.each do |group|
      gids << group.id
      gids << group.parent_id
    end
    @prop_other_admin = false
    if gids.present?
      gids.uniq!
      search_gids = Gw.join([gids], ',')
      cond = " auth='admin' and gid in (#{search_gids}) "
      auth_admin = Gw::PropOtherRole.find(:all, :conditions => cond)
      @prop_other_admin = true if auth_admin.present?
    end

    @schedule_settings = Gw::Model::Schedule.get_settings 'schedules', {}
    @s_other_admin_gid = nz(params[:s_other_admin_gid], "0").to_i

    @ie = Gw.ie?(request)
    @hedder2lnk = 7

    #現状の@prop_typesを施設グループも含めるようにする
    #@prop_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no, id')
    @prop_types = select_prop_type
    @prop_types += select_prop_group_tree('partition')
    prop_type_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no, id')

    if params[:type_id].present?
      @type_id = params[:type_id]
    else
      if prop_type_types.present?
        @type_id = @prop_types[0]
        match_type_id = @type_id[1].match(/^type_(\d+)$/)
        @default_type_id = match_type_id[1]
      end
    end
    @images = Gw::PropOtherImage.find(:all, :order => "parent_id")
  end

  def show
    init_params
    @line_box = 1
    @st_date = Gw.date8_to_date params[:id]
    @calendar_first_day = @st_date
    @calendar_end_day = @calendar_first_day

    _props
    if @prop_edit_ids.length > 0 || @prop_read_ids.length > 0
      @show_flg = true
    else
      @show_flg = false
    end

    _schedule_data
    _schedule_day_data
  end

  def show_week
    init_params
    @line_box = 1
    kd = params['s_date']
    @st_date = kd =~ /[0-9]{8}/ ? Date.strptime(kd, '%Y%m%d') : Date.today
    @calendar_first_day = @st_date
    @calendar_end_day = @calendar_first_day + 6
    @view = "week"

    @prop_gid = Gw::PropOther.find(:first, :conditions => "id=#{params[:prop_id]}").gid if !params[:prop_id].blank?
    _props
    if @prop_edit_ids.length > 0 || @prop_read_ids.length > 0
      @show_flg = true
    else
      @show_flg = false
    end

    _schedule_data
  end

  def _schedule_data
    if @prop_ids.blank?
      @schedules = []
    else
=begin
      cond_date = "('#{@calendar_first_day.strftime('%Y-%m-%d 0:0:0')}' <= gw_schedules.ed_at" +
            " and '#{@calendar_end_day.strftime('%Y-%m-%d 23:59:59')}' >= gw_schedules.st_at)"
      cond = "gw_schedule_props.prop_id in (#{Gw.join(@prop_ids, ',')})" + " and gw_schedules.delete_state = 0" +
          " and #{cond_date}"
=end

      #@schedules = Gw::Schedule.find(:all, :order => 'gw_schedules.allday DESC, gw_schedules.st_at, gw_schedules.ed_at, gw_schedules.id',
      #  :include => :schedule_props, :conditions => cond)
      @schedules = Gw::Schedule.find_for_show(@prop_ids,
        @calendar_first_day, @calendar_end_day,Site.user.id)

    end

    @holidays = Gw::Holiday.find_by_range_cache(@calendar_first_day, @calendar_end_day)
  end

  def show_month
    init_params
    @line_box = 1
    kd = params['s_date']
    @st_date = kd =~ /[0-9]{8}/ ? Date.strptime(kd, '%Y%m%d') : Date.today

    _month_date

    @hedder2lnk = 7
    @view = "month"
    @prop = Gw::PropOther.find_by_id(params[:prop_id])

    if @prop.delete_state == 1
      @read = false
      @edit = false
    elsif @is_gw_admin
      @read = true
      @edit = true
    else
      edit = Gw::PropOtherRole.is_edit?(params[:prop_id])
      read = Gw::PropOtherRole.is_read?(params[:prop_id])
      @edit = edit
      @read = edit || read
    end
    @show_flg = @read
=begin
    cond = ("gw_schedule_props.prop_id = #{params[:prop_id]} and ") + "gw_schedules.delete_state = 0 and " +
        " ('#{@calendar_first_day.strftime('%Y-%m-%d 0:0:0')}' <= gw_schedules.ed_at" +
          " and '#{@calendar_end_day.strftime('%Y-%m-%d 23:59:59')}' >= gw_schedules.st_at)"
=end
    #@schedules = Gw::Schedule.find(:all, :order => 'allday DESC, gw_schedules.st_at, gw_schedules.ed_at',
    #  :conditions => cond, :include => :schedule_props )
    @prop_ids = Array.new
    @prop_ids << params[:prop_id]
    @schedules = Gw::Schedule.find_for_show(@prop_ids,
        @calendar_first_day, @calendar_end_day,Site.user.id)

    @holidays = Gw::Holiday.find_by_range_cache(@calendar_first_day, @calendar_end_day)
  end

  def _props
    #種別と施設グループで取得する条件を変更する
    if(params[:type_id]).present?
      if (match_result = params[:type_id].match(/^groups_(\d+)$/))
        @props  =  Gw::Model::Schedule.get_props(params, @is_gw_admin, {:s_other_admin_gid=>@s_other_admin_gid, :prop_group_id => match_result[1]})
      elsif (match_result = params[:type_id].match(/^type_(\d+)$/))
        @props  =  Gw::Model::Schedule.get_props(params, @is_gw_admin, {:s_other_admin_gid=>@s_other_admin_gid, :type_id => match_result[1]})
      else
        @props  =  []
      end
    else
      @props  =  Gw::Model::Schedule.get_props(params, @is_gw_admin, {:s_other_admin_gid=>@s_other_admin_gid, :type_id => @default_type_id})
    end
    @prop_ids = @props.map{|x| x.id}
    if @is_gw_admin
      @prop_edit_ids = @prop_ids
      @prop_read_ids = @prop_ids
    else
      @prop_edit_ids = Gw::PropOtherRole.find(:all, :select => "id, prop_id",
        :conditions=>["prop_id in (?) and gid in (#{search_ids}) and auth = 'edit'", @prop_ids] ).map{|x| x.prop_id}
      @prop_read_ids = Gw::PropOtherRole.find(:all, :select => "id, prop_id",
        :conditions=>["prop_id in (?) and gid in (#{search_ids}) and auth = 'read'", @prop_ids] ).map{|x| x.prop_id}
    end

    #並び順の昇順でソート
    @props = @props.sort{|a, b|
      a.sort_no <=> b.sort_no
    }
  end

  def getajax
    @item = Gw::ScheduleProp.getajax params
    respond_to do |format|
      format.json { render :json => @item }
    end
  end

  # === 表示切替ボタン（全部表示/一部表示）押下時の処理メソッド
  def schedule_display
    ret = Gw::Controller::Schedule.update_schedule_title_display

    s_params = params[:s_params]
    redirect_to s_params
  end

  def search_ids
    groups = Site.user.groups
    gids = Array.new
    groups.each do |sg|
      gids << sg.id
      gids << sg.parent_id
    end
    gids << 0
    gids.uniq!
    search_gids = Gw.join([gids], ',')

    return search_gids
  end

end
