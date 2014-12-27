# encoding: utf-8
class Gw::Admin::SchedulesController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  include Gw::RumiHelper
  layout "admin/template/schedule"

  before_filter :set_groups_user, only: [:new, :create, :edit, :update, :quote]

  def initialize_scaffold
    return redirect_to(request.env['PATH_INFO']) if params[:reset]
    Page.title = "スケジュール"
  end

  # === 初期値のグループ、ユーザー情報
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_groups_user
    @selected_user = System::User.where(id: params[:uid]).first || Core.user
    @selected_group = @selected_user.enable_user_groups.first.group

    # 参加者
    @selected_parent_group_id_to_user = @selected_group.id
    @selectable_affiliated_users = System::UsersGroup.affiliated_users_to_select_option(@selected_parent_group_id_to_user, {without_level_no_2_organization: true, without_schedule_authority_user: true})

    # 公開所属
    @selected_parent_group_id_to_public = @selected_group.parent_id
    @selectable_child_groups = System::Group.child_groups_to_select_option(@selected_parent_group_id_to_public)
  end

  def init_params
    @title = 'ユーザー'
    @piece_head_title = 'スケジュール'
    @js = %w(/_common/js/yui/build/animation/animation-min.js /_common/js/popup_calendar/popup_calendar.js /_common/js/yui/build/calendar/calendar.js /_common/js/dateformat.js)
    @css = %w(/_common/themes/gw/css/schedule.css)

    @users = Gw::Model::Schedule.get_users(params)
    @user   = @users[0]

    if @user.blank?
      @uid = nz(params[:uid], Site.user.id).to_i
      @uids = [@uid]
    else
      @uid    = @user.id
      @uids = @users.collect {|x| x.id}
    end
    @gid = nz(params[:gid], @user.groups[0].id).to_i rescue Site.user_group.id

    if params[:cgid].blank? && @gid != 'me'
      x = System::CustomGroup.get_my_view( {:is_default=>1,:first=>1})
      if x.present?
        @cgid = x.id
      end
    else
      @cgid = params[:cgid]
    end

    @first_custom_group = System::CustomGroup.get_my_view( {:sort_prefix => Site.user.code,:first=>1})
    @ucode = Site.user.code
    @gcode = Site.user_group.code

    @state_user_or_group = params[:cgid].blank? ? ( params[:gid].blank? ? :user : :group ) : :custom_group
    @sp_mode = :schedule

    @group_selected = ( params[:cgid].blank? ? '' : 'custom_group_'+params[:cgid] )

    a_qs = []
    a_qs.push "uid=#{params[:uid]}" unless params[:uid].nil?
    a_qs.push "gid=#{params[:gid]}" unless params[:gid].nil? && !params[:cgid].nil?
    a_qs.push "cgid=#{params[:cgid]}" unless params[:cgid].nil? && !params[:gid].nil?
    a_qs.push "todo=#{params[:todo]}" unless params[:todo].nil?
    @schedule_move_qs = a_qs.join('&')

    #スケジューラー設定権限を持つユーザーかの情報
    @role_schedule = Gw.is_other_admin?('schedule_role')
    @is_gw_admin = Gw.is_admin_admin?

    if params[:cgid].present?
      @custom_group = System::CustomGroup.find(:first, :conditions=>"id=#{params[:cgid]}")
      if @custom_group.present?
        Page.title = "#{@custom_group.name} - スケジュール"
      end
    end

    @up_schedules = nz(Gw::Model::UserProperty.get('schedules'.singularize), {})

    @schedule_settings = Gw::Model::Schedule.get_settings 'schedules', {}

    @topdate = nz(params[:topdate]||Time.now.strftime('%Y%m%d'))
    @dis = nz(params[:dis],'week')


    @show_flg = true

    @params_set = Gw::Schedule.params_set(params.dup)
    @ref = Gw::Schedule.get_ref(params.dup)
    @link_params = Gw.a_to_qs(["gid=#{params[:gid]}", "uid=#{nz(params[:uid], Site.user.id)}", "cgid=#{params[:cgid]}"],{:no_entity=>true})

    @ie = Gw.ie?(request)
    @hedder2lnk = 1
    @link_format = "%Y%m%d"

    @type = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no,id')
    @group = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and id > ? and parent_id=?", "public","1","1"],
      :order => "sort_no")
    @child = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and parent_id > ?", "public","1"],
      :order => "sort_no")
    @prop_types=Array.new
    if !@type.blank?
      @type.each do | type|
        @dummy = DummyItem.new
        @dummy.id = "type_" + type.id.to_s
        @dummy.name = type.name
        @prop_types << @dummy
      end
    end

    if !@group.blank?
      @dummy = DummyItem.new
        @dummy.id = "-"
        @dummy.name = "-----------------"
        @prop_types << @dummy
      @group.each do | group|
        @dummy = DummyItem.new
        @dummy.id = "group_" + group.id.to_s
        @dummy.name = "+" + group.name
        @prop_types << @dummy
        @child.each do |child|
          if child.parent_id == group.id
            @dummy = DummyItem.new
            @dummy.id = "group_" + child.id.to_s
            @dummy.name = "+-" + child.name
            @prop_types << @dummy
          end
        end
      end
    end
    @target = schedule_authority_user
    @auth_flg = true
  end

  def schedule_authority_user
    target = System::ScheduleRole.get_target_uids(Site.user.id)

    return target
  end

  def schedule_role(schedule_id = nil)
    #スケジュール権限判定
    @schedule_edit_flg = false
    _user = System::User.without_disable

    target_user = System::ScheduleRole.get_target_uids_schedule_user(Site.user.id, schedule_id)
    @schedule_edit_flg = target_user.blank?

    #権限対象者ユーザー名取得
    if @schedule_edit_flg == false
      @target_user = ''
      cnt = 0
      target_user.each do |t_user|
        _user.each do |user|
          if user.id == t_user.target_uid
            @target_user += user.name if cnt == 0
            @target_user += ", " + user.name if cnt == 1
            cnt = 1
          end
        end
      end
    end
  end

  def index
    init_params
    @line_box = 1
    @st_date = Gw.date8_to_date params[:s_date]
    @calendar_first_day = @st_date
    @calendar_end_day = @calendar_first_day + 6

    @hedder3lnk = 2
    @view = "week"

    if @users.length > 0
      @show_flg = true
    else
      @show_flg = false
    end

    _schedule_data
  end

  def show
    init_params
    @line_box = 1
    @st_date = Gw.date8_to_date params[:id]
    @calendar_first_day = @st_date
    @calendar_end_day = @calendar_first_day

    @view = "day"

    if @users.length > 0
      @show_flg = true
    else
      @show_flg = false
    end

    _schedule_data
    _schedule_day_data
    _schedule_user_data
  end

  def show_month
    init_params
    @line_box = 1
    kd = params[:s_date]
    @st_date = kd =~ /[0-9]{8}/ ? Date.strptime(kd, '%Y%m%d') : Date.today

    _month_date
    @view = "month"
    @read = true

    if @is_gw_admin || params[:cgid].blank? ||
        ( params[:cgid].present? && System::CustomGroupRole.new.editable?( params[:cgid], Site.user_group.id, Core.user.id ) )
      @edit = true
    else
      @edit = false
    end

    _schedule_data
  end

  def _schedule_data
    if @is_gw_admin || params[:cgid].blank? ||
        ( params[:cgid].present? && System::CustomGroupRole.new.editable?( params[:cgid], Site.user_group.id, Site.user.id ) )
      @edit = true
    else
      @edit = false
    end
=begin
    cond_date = "('#{@calendar_first_day.strftime('%Y-%m-%d 0:0:0')}' <= gw_schedules.ed_at" +
      " and '#{@calendar_end_day.strftime('%Y-%m-%d 23:59:59')}' >= gw_schedules.st_at)"
    cond = "gw_schedule_users.uid in (#{Gw.join(@uids, ',')})" + " and gw_schedules.delete_state = 0" +
      " and #{cond_date}"
=end
    #@schedules = Gw::Schedule.find(:all, :order => 'gw_schedules.allday DESC, gw_schedules.st_at, gw_schedules.ed_at, gw_schedules.id',
    #  :include => :schedule_users, :conditions => cond)
    @schedules = Gw::Schedule.find_for_show_schedule(@uids,
      @calendar_first_day, @calendar_end_day,Site.user.id)

    @holidays = Gw::Holiday.find_by_range_cache(@calendar_first_day, @calendar_end_day)

    if @uid == Site.user.id
      @todos = collect_todos(@uid, @calendar_first_day, @calendar_end_day)
    else
      @todos = []
    end
  end

  def collect_todos(uid, calendar_first_day, calendar_end_day)
    doing = 'todos_display_schedule_doing'
    done  = 'todos_display_schedule_done'

    settings = Gw::Model::Schedule.get_settings 'todos', {:uid => uid}
    display_doing = settings[doing].present? && settings[doing].to_i == 1
    display_done  = settings[done].present?  && settings[done].to_i  == 1

    cond = "class_id = 1 and uid = #{Site.user.id}" +
      " and '#{calendar_first_day.strftime('%Y-%m-%d 0:0:0')}' <= ed_at" +
      " and '#{calendar_end_day.strftime('%Y-%m-%d 23:59:59')}' >= ed_at"

    cond += " and (is_finished is null or is_finished = '' or is_finished != '1')" unless display_done
    cond += " and is_finished = '1'" unless display_doing
    Gw::Todo.find(:all, :conditions => cond)

  end

  def _month_date
    default = Gw::NameValue.get_cache('yaml', nil, "gw_schedules_settings_system_default")
    @month_first_day = Date::new(@st_date.year, @st_date.month, 1)
    @month_end_day = Date::new(@st_date.year, @st_date.month, -1)

    @calendar_first_day = @month_first_day - @month_first_day.wday
    if @up_schedules.blank?
      @calendar_first_day += default['month_view_leftest_weekday'].to_i
    else
      @calendar_first_day += nz(@up_schedules['schedules']['month_view_leftest_weekday'], default['month_view_leftest_weekday']).to_i
    end
    @calendar_first_day = @calendar_first_day - 7 if @month_first_day < @calendar_first_day

    @calendar_end_day = @calendar_first_day + 7 * 4 - 1
    while @calendar_end_day < @month_end_day
      @calendar_end_day += 7
    end
  end

  def _schedule_day_data
    @calendar_first_time = 8
    @calendar_end_time = 19
    @schedules.each do |schedule|
      @calendar_first_time = 0 if schedule.st_at.to_date < @st_date
      @calendar_first_time = schedule.st_at.hour if schedule.st_at.to_date == @st_date && schedule.st_at.hour < @calendar_first_time
      @calendar_end_time = 23 if schedule.ed_at.to_date > @st_date
      @calendar_end_time = schedule.ed_at.hour if schedule.ed_at.to_date == @st_date && schedule.ed_at.hour > @calendar_end_time
    end

    @calendar_space_time = (@calendar_first_time..@calendar_end_time) # 表示する予定表の「最初の時刻」と「最後の時刻」の範囲

    @col = ((@calendar_space_time.last - @calendar_space_time.first) * 2) + 2

    @header_each ||= @schedule_settings[:header_each] rescue 5
    @header_each = nz(@header_each, 5).to_i
  end

  def _schedule_user_data

    @user_schedules = Hash::new
    @users.each do |user|
      key = "user_#{user.id}"
      @user_schedules[key] = Hash::new
      @user_schedules[key][:schedules] = Array.new
      @user_schedules[key][:allday_flg] = false
      @user_schedules[key][:allday_cnt] = 0

      @schedules.each do |schedule|
        participant = false
        schedule.schedule_users.each do |schedule_user|
          break if participant
          participant = schedule_user.uid == user.id
        end
        if participant
          @user_schedules[key][:schedules] << schedule
          if schedule.allday == 1 || schedule.allday == 2
            @user_schedules[key][:allday_flg] = true
            @user_schedules[key][:allday_cnt] += 1
          end
        end
      end

      @user_schedules[key][:schedule_len] = @user_schedules[key][:schedules].length

      if @user_schedules[key][:schedule_len] == 0
        @user_schedules[key][:trc] = "scheduleTableBody"
        @user_schedules[key][:row] = 1
      else
        if @user_schedules[key][:allday_flg] == true
          @user_schedules[key][:trc] = "alldayLine"
          @user_schedules[key][:row] = (@user_schedules[key][:schedule_len] * 2) - ((@user_schedules[key][:allday_cnt] * 2) - 1)
        else
          @user_schedules[key][:trc] = "scheduleTableBody categoryBorder"
          @user_schedules[key][:row] = @user_schedules[key][:schedule_len] * 2
        end
      end
    end

  end

  def new
    init_params

    @item = Gw::Schedule.new({:is_public=>1})
    @system_role_classes = Gw.yaml_to_array_for_select('system_role_classes')
    @js += %w(/_common/modules/ips/ips.js)
    @css += %w(/_common/modules/ips/ips.css)
    if params[:prop_id].present?
      @_props = Array.new
      @_prop = Gw::PropOther.find_by_id(params[:prop_id])
      _get_prop_json_array
      @props_json = @_props.to_json
    end

    # 施設予約ではない、かつユーザーが参加者の選択済みに表示可能な場合、初期値として表示する
    if params[:s_genre] != "other" && @selectable_affiliated_users.map(&:id).include?(@selected_user.id)
      @users_json = ([@selected_user.to_json_option]).to_json
    end

    # 公開所属の初期値
    public_groups = []
    public_groups << @selected_group.to_json_option if @selectable_child_groups.map(&:id).include?(@selected_group.id)
    @public_groups_json = public_groups.to_json

=begin
    if request.mobile?
      unless flash[:mail_to].blank?
        @users_json = set_participants(flash[:mail_to]).to_json
      end
    end
=end
  end

  def quote
    @quote = true
    __edit
  end

  def edit
    __edit
  end

  def __edit
    init_params

    @item = Gw::Schedule.new.find(params[:id])

    # 表示権限
    public_auth = @item.is_public_auth?(@is_gw_admin)
    return authentication_error(403) unless public_auth

    auth_level = @item.get_edit_delete_level(auth = {:is_gw_admin => @is_gw_admin})

    return authentication_error(403) if auth_level[:edit_level] != 1 #&& !@quote
    users = []
    @item.schedule_users.each do |user|
      _name = ''
      if user.class_id == 1
        _name = user.user.display_name if !user.user.blank? && user.user.state == 'enabled'
      else
        group = System::Group.find(:first,  :conditions=>"id=#{user.uid}")
        _name = group.name if !group.blank? && group.state == 'enabled'
      end
      unless _name.blank?
        name = Gw.trim(_name)
        users.push [user.class_id, user.uid, name]
      end
    end

    public_groups = Array.new
    @item.public_roles.each do |public_role|
      name = Gw.trim(public_role.class_id == 2 ? public_role.group.name :
          public_role.user.name)
      public_groups.push ["", public_role.uid, name]
    end

    @_props = Array.new
    @props_items = @item.schedule_props
    @props_items.each do |props_item|
      @_prop = props_item.prop
      _get_prop_json_array
    end

    @users_json = users.to_json
=begin
    if request.mobile?
      if flash[:mail_to].present?
        @users_json = set_participants(flash[:mail_to]).to_json
      end
    end
=end
    @props_json = @_props.to_json
    @public_groups_json = public_groups.to_json
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

  def show_one
    init_params
    @line_box = 1
    @item = Gw::Schedule.find_by_id(params[:id])
    return http_error(404) if @item.blank?
    @schedule_props = @item.schedule_props

    # 表示権限
    public_auth = @item.is_public_auth?(@is_gw_admin)
    return authentication_error(403) unless public_auth

    @auth_level = @item.get_edit_delete_level({:is_gw_admin => @is_gw_admin})

    @repeated = @item.repeated?

    @auth_flg = true

    if @item.schedule_repeat_id.present?
      repeat_items = Gw::Schedule.new.find(:all, :conditions=>"schedule_repeat_id=#{@item.repeat.id}")
      repeat_items.each do |repeat_item|
        if @auth_flg
          schedule_role(repeat_item.id)
          @auth_flg = false if !@schedule_edit_flg
        end
      end
    end

    schedule_role(params[:id])

    @public_show = Gw::Schedule.is_public_show(@item.is_public)

    @prop_edit = true
    @use_prop = false
    if @item.schedule_props.present?
      @use_prop = true

      @item.schedule_props.each do |schedule_prop|
        break if @prop_edit == false
        prop = schedule_prop.prop
        if @prop_edit == true && prop.present?
          @prop_edit = Gw::ScheduleProp.is_prop_edit?(prop.id, {:prop => prop, :is_gw_admin => @is_gw_admin})
        end
      end
      if Gw.is_other_admin?('schedule_prop_admin')
        @prop_edit = true
      end
    end


  end

  class DummyItem
    attr_accessor  :id;
  end

  def create
    init_params
#    if request.mobile?
#      _params = set_mobile_params params
#      _params = reject_no_necessary_params _params
#    else
      _params = reject_no_necessary_params params
#    end
    @item = Gw::Schedule.new()
    if Gw::ScheduleRepeat.save_with_rels_concerning_repeat(@item, _params, :create)
      # 新着情報(新規作成時)を作成
      @item.build_created_remind

      flash[:notice] = I18n.t("rumi.schedule.message.success.action.create")
      redirect_url = "/gw/schedules/#{@item.id}/show_one?m=new"
#      if request.mobile?
#        redirect_url += "&gid=#{params[:gid]}&cgid=#{params[:cgid]}&dis=#{params[:dis]}"
#      end
      redirect_to redirect_url
    else
      respond_to do |format|
        format.html { render :action => "new" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    init_params

#    if request.mobile?
#      _params = set_mobile_params params
#      _params = reject_no_necessary_params _params
#      @item = Gw::Schedule.find(params[:id])
#    else
      _params = reject_no_necessary_params params
      @item = Gw::Schedule.find(params[:id])
      _params = reject_no_necessary_params params
#    end

    if Gw::ScheduleRepeat.save_with_rels_concerning_repeat(@item, _params, :update)
      # 新着情報(更新時)を作成
      # repeat_mode 1: 単体編集, 2: 繰り返し編集
      if params[:init][:repeat_mode].to_i == 2
        @item.repeat.first_day_schedule.build_updated_remind(true)
        flash[:notice] = I18n.t("rumi.schedule.message.success.action.update_repeat")
      else
        @item.build_updated_remind
        flash[:notice] = I18n.t("rumi.schedule.message.success.action.update")
      end

      redirect_url = "/gw/schedules/#{@item.id}/show_one?m=edit"
=begin
      if request.mobile?
        if @item.schedule_parent_id.blank?
          redirect_url += "?gid=#{params[:gid]}&cgid=#{params[:cgid]}&dis=#{params[:dis]}"
        else
          redirect_url += "&gid=#{params[:gid]}&cgid=#{params[:cgid]}&dis=#{params[:dis]}"
        end
      end
=end
      redirect_to redirect_url
    else
      respond_to do |format|
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  # 削除された場合の処理メソッド（論理削除に変更）
  def delete_schedule
    init_params
    schedule_role(params[:id])

    @auth_flg = true
    @auth_flg = false if !@schedule_edit_flg

    @item = Gw::Schedule.find(params[:id])
    st = @item.st_at.strftime("%Y%m%d")
    othlinkflg = false

    if @item.schedule_props.length > 0
      othlinkflg = true
    end

    if othlinkflg
      redirect_url = "/gw/schedule_props/show_week?s_date=#{st}&s_genre=other"
    else
      redirect_url = "/gw/schedules/show_month?s_date=#{st}"
    end

    ret = false
    ret = Gw::Schedule.save_updater_with_states(@item) if @is_gw_admin || @schedule_edit_flg

    if ret
      # 新着情報(論理削除時)を作成
      @item.build_deleted_remind

      flash[:notice] = I18n.t("rumi.schedule.message.success.action.delete")
      redirect_to redirect_url
    else
      respond_to do |format|
        format.html { render :action => "show_one" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  # 繰返し削除された場合の処理メソッド（論理削除に変更）
  def delete_schedule_repeat
    init_params
    @item = Gw::Schedule.find(params[:id])
    st = @item.st_at.strftime("%Y%m%d")
    othlinkflg = false

    if @item.schedule_props.length > 0
      othlinkflg = true
    end

    if othlinkflg
      redirect_url = "/gw/schedule_props/show_week?s_date=#{st}&s_genre=other"
    else
      redirect_url = "/gw/schedules/show_month?s_date=#{st}"
    end

    ret = false
    schedule_repeat_id = @item.schedule_repeat_id
    repeat_items = Gw::Schedule.new.find(:all, :conditions=>"schedule_repeat_id=#{schedule_repeat_id}")
    @auth_flg = true
    repeat_items.each do |repeat_item|
      break if !@auth_flg
      if @auth_flg
        schedule_role(repeat_item.id)
        @auth_flg = false if !@schedule_edit_flg
      end
    end

    if @auth_flg
      repeat_items.each do |repeat_item|
        ret = Gw::Schedule.save_updater_with_states(repeat_item)
      end
    end

    if ret
      # 新着情報(論理削除時)を作成
      @item.reload.build_deleted_remind(true)

      flash[:notice] = I18n.t("rumi.schedule.message.success.action.delete_repeat")
      redirect_to redirect_url
    else
      @item = Gw::Schedule.find(params[:id])
      @auth_level = @item.get_edit_delete_level({:is_gw_admin => @is_gw_admin})
      schedule_role(params[:id])

      @prop_edit = true
      @use_prop = false
      if @item.schedule_props.present?
        @use_prop = true
        @item.schedule_props.each do |schedule_prop|
          break if @prop_edit == false
          prop = schedule_prop.prop
          if @prop_edit == true && prop.present?
            @prop_edit = Gw::ScheduleProp.is_prop_edit?(prop.id, {:prop => prop, :is_gw_admin => @is_gw_admin})
          end
        end
      end
      respond_to do |format|
        format.html { render :action => "show_one" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    init_params
    @item = Gw::Schedule.find(params[:id])
    auth_level = @item.get_edit_delete_level(auth = {:is_gw_admin => @is_gw_admin})
    return authentication_error(403) if auth_level[:delete_level] != 1

    st = @item.st_at.strftime("%Y%m%d")
    othlinkflg = false

    if @item.schedule_props.length > 0
      othlinkflg = true
    end

    if othlinkflg
      location = "/gw/schedule_props/show_week?s_date=#{st}&s_genre=other"
    else
      location = "/gw/schedules/show_month?s_date=#{st}"
    end
#    location = gw_schedules_path({:dis=>params[:dis],:gid=>params[:gid],:cgid=>params[:cgid],:s_date=>params[:s_date]}) if request.mobile?

    _destroy(@item,:success_redirect_uri=>location)
  end

  def destroy_repeat
    init_params
    item = Gw::Schedule.find(params[:id])
    auth_level = item.get_edit_delete_level(auth = {:is_gw_admin => @is_gw_admin})
    return authentication_error(403) if auth_level[:delete_level] != 1

    st = item.st_at.strftime("%Y%m%d")
    otherlinkflg = false;

    item.schedule_props.each do |pro|
      if pro.prop_type == 'Gw::PropOther'
        otherlinkflg = true
      end
    end

    schedule_repeat_id = item.repeat.id

    repeat_items = Gw::Schedule.new.find(:all, :conditions=>"schedule_repeat_id=#{schedule_repeat_id}")
    repeat_items.each { |repeat_item|
      repeat_item.destroy
    }

    if otherlinkflg
      redirect_url = "/gw/schedule_props/show_week?s_date=#{st}&s_genre=other"
    else
      redirect_url = "/gw/schedules/show_month?s_date=#{st}"
    end
#    redirect_url = gw_schedules_path({:dis=>params[:dis],:gid=>params[:gid],:cgid=>params[:cgid],:s_date=>params[:s_date]}) if request.mobile?
    flash[:notice] = I18n.t("rumi.schedule.message.success.action.delete_repeat")
    redirect_to redirect_url
  end

  def setting
    init_params
  end

  def setting_system
    init_params
  end

  def setting_holidays
    init_params
  end

  def setting_gw_link
    init_params
    @item = Gw::SystemProperty.find(:first, :conditions=> {:name => "gw_link"})
  end

  def edit_gw_link
    edit_system_setting "gw_link"
  end

  def edit_system_setting(key)
    init_params
    @item = Gw::SystemProperty.find(:first, :conditions=> {:name => "gw_link"})
    respond_to do |format|
      format.html {
        render :action => "setting_#{key}"
      }
      format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
    end
  end

  def setting_ind
    init_params
  end

  def setting_ind_schedules
    setting_ind_core 'schedules'
  end

  def setting_ind_ssos
    setting_ind_core 'ssos'
  end

  def setting_ind_mobiles
    setting_ind_core 'mobiles'
  end

  def setting_ind_core(key)
    init_params
    @item = Gw::Model::Schedule.get_settings key
  end

  def edit_ind_schedules
    edit_ind 'schedules'
  end

  def edit_ind_ssos
    edit_ind 'ssos'
  end

  def edit_ind_mobiles
    edit_ind 'mobiles'
  end

  def edit_ind(key)
    init_params
    options = {}
    raise ArgumentError, '呼び出しパラメータが不正です。' if %w(schedules ssos mobiles).index(key).nil?
    options[:nodefault] = 1 if !%w(ssos).index(key).nil?
    edit_ind_core key, options
  end

  def edit_ind_core(key, options={})
    _params = params[:item]
    hu = nz(Gw::Model::UserProperty.get(key.singularize), {})
    trans = Gw.yaml_to_array_for_select("gw_#{key}_settings_ind", :rev=>1)
    trans_raw = Gw::NameValue.get('yaml', nil, "gw_#{key}_settings_ind")
    default = Gw::NameValue.get('yaml', nil, "gw_#{key}_settings_system_default") if options[:nodefault].nil?
    cols = trans.collect{|x| x[0]}
    hu[key] = {} if hu[key].nil?
    hu_update = hu[key]
    if key == 'ssos'
      hu[key]['pref_soumu'] = {} if hu[key]['pref_soumu'].nil?
      hu_update = hu[key]['pref_soumu']
    end
    password_fields = trans_raw['_password_fields'].blank? ? [] : trans_raw['_password_fields'].split(':')
    cols.each do |x|
      hu_update[x] = _params[x]
      hu_update[x] = hu_update[x].encrypt if !password_fields.index(x).nil? && !hu_update[x].blank?
    end
    ret = Gw::Model::UserProperty.save(key.singularize, hu, options)
    if key=='mobiles'
      case ret
      when 0
        flash[:notice] = '転送設定編集処理に成功しました。'
        redirect_to "/gw/memo_settings"
      when 2
        flash[:notice] = '転送設定編集処理に成功しました。アドレスフォーマットが独自フォーマットになっているため、転送されない場合があります。'
        redirect_to "/gw/memo_settings"
      else
        respond_to do |format|
          format.html {
            hu_update['errors'] = ret
            hu_update.merge!(default){|k, self_val, other_val| self_val} if options[:nodefault].nil?
            @item = hu[key]
            render :action => "setting_ind_#{key}"
          }
          format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
        end
      end
    else
      if ret == true
        if key=='ssos'
          flash_notice('シングルサインオン設定編集処理', true)
          redirect_to "/"
        else
          flash[:notice] = I18n.t('rumi.schedule.setting_ind.update')
          redirect_to "/gw/schedules/setting_ind"
        end
      else
        respond_to do |format|
          format.html {
            hu_update['errors'] = ret
            hu_update.merge!(default){|k, self_val, other_val| self_val} if options[:nodefault].nil?
            @item = hu[key]
            render :action => "setting_ind_#{key}"
          }
          format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  def search
    init_params
    @group_selected = 'all_group'
    @items = Gwsub.grouplist4(nil, nil, true ,nil , nil, :return_pattern => 1)
    @st_date = Gw.date8_to_date params[:s_date]
  end

  # === 印刷プレビュー表示メソッド
  def print_index
    index
    render action: :index, layout: "admin/template/schedule_print"
  end

  # === 印刷プレビュー表示メソッド
  def print_show_month
    show_month
    render action: :show_month, layout: "admin/template/schedule_print"
  end

  # === 表示切替ボタン（全部表示/一部表示）押下時の処理メソッド
  def schedule_display
    ret = Gw::Controller::Schedule.update_schedule_title_display

    s_params = params[:s_params]
    redirect_to s_params
  end

  # === 既読にするボタン押下時の処理メソッド
  def finish
    init_params
    @item = Gw::Schedule.find(params[:id])
    @item.seen_remind(Site.user.id)

    flash[:notice] = I18n.t("rumi.schedule.message.success.action.already")
    redirect_url = "/gw/schedules/#{@item.id}/show_one?m=finish"
    redirect_to redirect_url
  end


  private
  def set_mobile_params(params_i)
    params_o = params_i.dup
    if params_o[:item][:allday] != "1"
      params_o[:item].delete "allday_radio_id"
    end
    st_at_str = %Q(#{params_o[:item]['st_at(1i)']}-#{params_o[:item]['st_at(2i)']}-#{params_o[:item]['st_at(3i)']} #{params_o[:item]['st_at(4i)']}:#{params_o[:item]['st_at(5i)']})
    params_o[:item].delete "st_at(1i)"
    params_o[:item].delete "st_at(2i)"
    params_o[:item].delete "st_at(3i)"
    params_o[:item].delete "st_at(4i)"
    params_o[:item].delete "st_at(5i)"
    params_o[:item][:st_at]= st_at_str
    ed_at_str = %Q(#{params_o[:item]['ed_at(1i)']}-#{params_o[:item]['ed_at(2i)']}-#{params_o[:item]['ed_at(3i)']} #{params_o[:item]['ed_at(4i)']}:#{params_o[:item]['ed_at(5i)']})
    params_o[:item].delete "ed_at(1i)"
    params_o[:item].delete "ed_at(2i)"
    params_o[:item].delete "ed_at(3i)"
    params_o[:item].delete "ed_at(4i)"
    params_o[:item].delete "ed_at(5i)"
    params_o[:item][:ed_at]= ed_at_str
    users_json = []
    if params_o[:item][:schedule_users].blank?
      users_json << ["1",Site.user.id,"#{Site.user.name}"]
    else
      params_o[:item][:schedule_users].each do |u|
        if u[1].to_i != 0
          user_name = System::User.find_by_id(u[1])
          users_json << ["1",u[1],"#{user_name.name}"]
        end
      end
    end
    params_o[:item][:schedule_users_json] = users_json.to_json
    public_groups_json = []
    if params_o[:item][:public_groups].blank?
      public_groups_json << ["1",Site.user_group.id,"#{Site.user_group.name}"]
    else
      params_o[:item][:public_groups][:gid] = Site.user_group.parent_id
      params_o[:item][:public_groups].each do |g|
        if g[1].to_i != 0
          group_name = System::Group.find_by_id(g[1])
          public_groups_json << ["1",g[1],"#{group_name.name}"]
        end
      end
    end
    params_o[:item][:public_groups_json] = public_groups_json.to_json
    params_o[:init][:public_groups_json] = public_groups_json.to_json
    return params_o
  end

  def set_participants(member_str)
    users = member_str.split(',')
    users_json = []
    unless users.blank?
      users.each do |u|
        user_name = System::User.find_by_id(u)
        users_json << [1,u,"#{user_name.name}"]
      end
    end
    return users_json
  end

  def reject_no_necessary_params(params_i)
    params_o = params_i.dup
    params_o[:item].reject!{|k,v| /^(owner_udisplayname)$/ =~ k}

    case params_o[:init][:repeat_mode]
    when "1"
      params_o[:item].reject!{|k,v| /^(repeat_.+)$/ =~ k}
    when "2"
      params_o[:item].delete :st_at
      params_o[:item].delete :ed_at
      params_o[:item][:repeat_weekday_ids] = Gw.checkbox_to_string(params_o[:item][:repeat_weekday_ids])
      params_o[:item][:allday] = params_o[:item][:repeat_allday]
      params_o[:item].delete :repeat_allday
    else
      raise Gw::ApplicationError, "指定がおかしいです(repeat_mode=#{params_o[:init][:repeat_mode]})"
    end

    params_o[:item].reject!{|k,v| /\(\di\)$/ =~ k}
    params_o
  end

  class DummyItem
    attr_accessor  :id, :name
  end
end
