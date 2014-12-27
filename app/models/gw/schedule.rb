# encoding: utf-8
class Gw::Schedule < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  validates_presence_of :title, :is_public
  validates_each :st_at do |record, attr, value|
    d_st = Gw.get_parsed_date(record.st_at)
    d_ed = Gw.get_parsed_date(record.ed_at)
    record.errors.add attr, 'と終了日時の前後関係が異常です。' if d_st > d_ed
  end
  has_many :schedule_props, :foreign_key => :schedule_id, :class_name => 'Gw::ScheduleProp', :dependent=>:destroy
  has_many :schedule_users, :foreign_key => :schedule_id, :class_name => 'Gw::ScheduleUser', :dependent=>:destroy
  belongs_to :repeat, :foreign_key => :schedule_repeat_id, :class_name => 'Gw::ScheduleRepeat'
  has_many :public_roles, :foreign_key => :schedule_id, :class_name => 'Gw::SchedulePublicRole', :dependent=>:destroy
  has_many :normal_reminders, foreign_key: :item_id, class_name: "Gw::Reminder", conditions: { category: "schedule" }, dependent: :destroy
  has_many :prop_reminders, foreign_key: :item_id, class_name: "Gw::Reminder", conditions: { category: "schedule_prop" }, dependent: :destroy
  has_many :reminders, foreign_key: :item_id, class_name: "Gw::Reminder", conditions: ["category like ? and sub_category is null", "schedule%"]

  def self.params_set(params)
    _params = Array.new
    [:uid, :gid, :cgid, :s_date, :ref, :prop_id].each do |col|
      if params.key?(col)
        _params << "#{col}=#{params[col]}"
      end
    end
    ret = ""
    if _params.length > 0
      ret = Gw.join(_params, '&')
      ret = '?' + ret
    end
    return ret
  end
  
  def self.get_ref(params)
    if params[:ref] == "prop"
      :prop
    else
      :schedule
    end
  end

  def self.joined_self(options={})
    op = options.dup
    op[:order] = 'st_at, ed_at' if op[:order].blank?
    op[:joins] = 'left join gw_schedule_users on gw_schedules.id = gw_schedule_users.schedule_id'
    op[:select] = 'gw_schedules.*' if op[:select].blank?
    find(:all, op)
  end

  def self.save_with_rels(item, par_item, mode, prop, delete_props = Array.new, options = {})

    di = par_item.dup
    di.delete :public_groups
    _public_groups = JsonParser.new.parse(par_item[:public_groups_json])
    di.delete :public_groups_json

    di.delete :schedule_users
    _users = JsonParser.new.parse(par_item[:schedule_users_json])
    di.delete :schedule_users_json

    di.delete :form_kind_id

    di = di.merge ret_updator

    if mode == :create || (mode == :update && !options[:restrict_trans].blank?)
      if di[:creator_uid].blank?
        cu = Site.user
        di[:creator_uid] = cu.id
        di[:creator_ucode] = cu.code
        di[:creator_uname] = cu.name
        cg = Site.user_group
        di[:creator_gid] = cg.id
        di[:creator_gcode] = cg.code
        di[:creator_gname] = cg.name
      else
        creator_group = Gw::Model::Schedule.get_group(:gid => di[:creator_gid])
        di[:creator_gid] = creator_group.id
        di[:creator_gcode] = creator_group.code
        di[:creator_gname] = creator_group.name
      end

      ou = Gw::Model::Schedule.get_user(par_item[:owner_uid]) rescue Site.user
      di[:owner_uid] = ou.id
      di[:owner_ucode] = ou.code
      di[:owner_uname] = ou.name
      og = ou.enable_user_groups.first.group
      di[:owner_gid] = og.id
      di[:owner_gcode] = og.code
      di[:owner_gname] = og.name
    end
    if mode == :update
      ou = Gw::Model::Schedule.get_user(par_item[:owner_uid]) rescue Site.user
      di[:owner_uid] = ou.id
      di[:owner_ucode] = ou.code
      di[:owner_uname] = ou.name
      og = ou.enable_user_groups.first.group
      di[:owner_gid] = og.id
      di[:owner_gcode] = og.code
      di[:owner_gname] = og.name

      if di[:created_at].blank?
        created_at = Time.now
      else
        created_at = di[:created_at].to_datetime
      end
      di[:created_at] = created_at
    end
    if mode == :create
      di.delete :created_at
    end

    _props = JsonParser.new.parse(par_item[:schedule_props_json])
    di.delete :schedule_props
    di.delete :schedule_props_json
    di.delete :allday_radio_id
    di.delete :repeat_allday_radio_id

    di[:st_at] = Gw.date_common(Gw.get_parsed_date(par_item[:st_at])) rescue nil
    di[:ed_at] = di[:st_at].blank? ? nil :
      par_item[:ed_at].blank? ? Gw.date_common(Gw.get_parsed_date(di[:st_at]) + 3600) :
      Gw.date_common(Gw.get_parsed_date(par_item[:ed_at])) rescue nil

    item.st_at = Gw.date_common(Gw.get_parsed_date(par_item[:st_at])) rescue nil
    item.ed_at = Gw.date_common(Gw.get_parsed_date(par_item[:ed_at])) rescue nil

    proc_core = lambda{

      if mode == :update
        item.touch
        return false if !item.update_attributes(di)
        Gw::ScheduleUser.destroy_all("schedule_id=#{item.id}")
        Gw::ScheduleProp.destroy_all("schedule_id=#{item.id}")
        Gw::SchedulePublicRole.destroy_all("schedule_id=#{item.id}")
      else
        return false if !item.update_attributes(di)
      end

      _users.each do |user|
        item_sub = Gw::ScheduleUser.new()
        item_sub.schedule_id = item.id
        item_sub.st_at = item.st_at
        item_sub.ed_at = item.ed_at
        item_sub.class_id = user[0].to_i
        item_sub.uid = user[1]

        return false unless item_sub.save
      end
      _props.each do |prop|
        item_sub = Gw::ScheduleProp.new()
        item_sub.schedule_id = item.id
        item_sub.prop_type = "Gw::PropOther"
        item_sub.prop_id = prop[1]
        return false unless item_sub.save
      end
      if par_item[:is_public] == '2'
        _public_groups.each do |_public_group|
          item_public_role = Gw::SchedulePublicRole.new()
          item_public_role.schedule_id = item.id
          item_public_role.class_id = 2
          item_public_role.uid = _public_group[1]
          return false unless item_public_role.save
        end
      end
      return true
    }

    if !options[:restrict_trans].blank?
      return proc_core.call
    else
      begin
        transaction() do
          raise Gw::ARTransError if !proc_core.call
        end
        return true
      rescue => e
        case e.class.to_s
        when 'ActiveRecord::RecordInvalid', 'Gw::ARTransError'
        else
          raise e
        end
        return false
      end
    end
  end

  # === スケジュール削除時の処理
  def self.save_updater_with_states(item)
    update_item = {}
    update_item[:delete_state] = 1
    update_item = update_item.merge ret_updator
    return item.update_attributes(update_item)
  end

  def self.separate_repeat_params(params)
    item_main = HashWithIndifferentAccess.new
    item_repeat = HashWithIndifferentAccess.new
    params[:item].each_key{|k|
      if /^repeat_(.+)/ =~ k.to_s
        item_repeat[$1] = params[:item][k]
      else
        item_main[k] = params[:item][k]
      end
    }
    return [item_main, item_repeat]
  end

  def repeated?
    self.schedule_repeat_id.present?
  end

  def  get_repeat_items
    return Array.new if !self.repeated?
    return self.find(:all, :conditions=>"schedule_repeat_id='#{self.schedule_repeat_id}'", :order=>"st_at, id")
  end

  def repeat_item_first?
    return true if !self.repeated?

    repeat_id = self.schedule_repeat_id
    sche = Gw::Schedule
    item = sche.find(:first, :conditions=>"schedule_repeat_id='#{repeat_id}'", :order=>"st_at")

    if item.id == self.id
      return true
    else
      return false
    end
  end

  def repeat_end_str
    return "" if !self.repeated?

    repeat_id = self.schedule_repeat_id
    sche = Gw::Schedule
    item = sche.find(:first, :conditions=>"schedule_repeat_id='#{repeat_id}'", :order=>"st_at DESC")

    return " ～#{item.ed_at.day.to_s}日"
  end

  def stepped_over?
    st_date = self.st_at.to_date
    ed_data = self.ed_at.to_date

    if st_date + 1 <= ed_data
      return true
    else
      return false
    end
  end

  def stepped_st_date_today?(date = Date.today)
    st_date = self.st_at.to_date
    return st_date == date
  end

  def search(params)
    params.each do |n, v|
      next if v.to_s == ''
      end if params.size != 0
    return self
  end

  def is_actual?
    return nil
  end

  def self.is_schedule_pref_admin?(uid = Site.user.id)
    System::Model::Role.get(1,uid,'schedule_pref','schedule_pref_admin')
  end

  def is_schedule_pref_admin_users?
    pref_admin = Gw::NameValue.get_cache('yaml', nil, "gw_schedule_pref_admin_default")
    pref_admin_code = nf(pref_admin["pref_admin_code"])
    unless pref_admin_code.blank?
      self.schedule_users.each do |user|
        sys_user = System::User.get(user.uid)
        unless sys_user.blank?
          ucode = nz(System::User.get(user.uid).code, "0")
          if pref_admin_code == ucode
            return true
          end
        end
      end
    end
    return false
  end

  def is_public_auth?(is_gw_admin = Gw.is_admin_admin?, options = {})

    if is_gw_admin
      return true  # ログインユーザーがシステム管理者の時、true
    end

    is_public = nz(self.is_public, 1)

    if is_public == 1
      return true # 公開設定の時、true
    end

    uids = []
    gids = []
    uids = [self.creator_uid]
    self.schedule_users.each{|x|
      if x.class_id == 1
        uids = uids + [x.uid]
        unless x.user.blank?
          x.user.user_groups.each{|z|
            gids = gids + [z.group_id] unless x.user.nil?
          }
        end
      elsif x.class_id == 2
        unless x.group.blank?
          x.group.user_group.each{|z|
            uids = uids + [z.user_id]
            gids = gids + [z.group_id]
          }
        end
      end
    }

    # 公開範囲
    self.public_roles.each do |public_role|
      if public_role.class_id == 2
        role_group = public_role.group
        unless role_group.blank?
          gids << role_group.id
          role_group.enabled_children.each do |child|
            gids << child.id
            child.enabled_children.each do |c|
              gids << c.id
            end
          end
        end
      end
    end

    uids.compact! # nil要素を削除
    gids.compact! # nil要素を削除
    uids = uids.sort.uniq
    gids = gids.sort.uniq

    if is_public == 2
      # 所属内の時、参加者および公開所属、および参加者に存在した場合true
      cond = ["user_id = ?", Site.user.id]
      group_flg = false
      user_groups = System::UsersGroup.where(cond)
      user_groups.each do |ug|
        gids.each do |g|
          group_flg = true if ug.group_id == g
        end
      end
      #if self.creator_uid.to_i == Site.user.id || gids.index(Site.user_group.id) || uids.index(Site.user.id)
      if self.creator_uid.to_i == Site.user.id || group_flg || uids.index(Site.user.id)
        return true
      end
    elsif is_public == 3
      if uids.index(Site.user.id)
        return true
      end
    end

    props = self.schedule_props
    props.each do |prop|
      if prop.prop.present?
        if Gw::PropOtherRole.is_admin?(prop.prop.id)
          return true
        end
      end
    end

    return false
  end

  def self.ret_updator
    items = {}
    uu = Site.user
    items[:updater_uid] = uu.id
    items[:updater_ucode] = uu.code
    items[:updater_uname] = uu.name
    ug = Site.user_group
    items[:updater_gid] = ug.id
    items[:updater_gcode] = ug.code
    items[:updater_gname] = ug.name
    return items
  end

  def is_schedule_user?(uid = Site.user.id, gid = Site.user_group.id)
    ret = self.schedule_users.select{|x| ( x.class_id == 1 && x.uid == uid ) || ( x.class_id == 2 && x.uid == gid ) }
    if ret.size > 0
      return true
    else
      return false
    end
  end

  def is_prop_type?
    props = self.schedule_props
    return 0 if props.length == 0
    type = 1
    props.each { |prop|
      if prop.prop_type == "Gw::PropOther"
        type = 1 if type <= 1
      end
    }
    return type
  end

  def get_propnames
    schedule_props = Gw::ScheduleProp.find(:all, :conditions=>["schedule_id = ?", self.id])
    _names = Array.new
    names = ""
    len = schedule_props.length
    if len > 0
      is_user = self.is_schedule_user? # 参加者
      schedule_props.each do |schedule_prop|
        get_prop = schedule_prop.prop
        if get_prop.present? && (get_prop.is_admin_or_editor_or_reader? || is_user)
          if get_prop.delete_state != 1
            _names << get_prop.name
          end
        end
      end
    end
    names = Gw.join(_names, '，')
    return names
  end

=begin
  def get_usernames
    _names = Array.new
    names = ""
    schedule_users = Gw::ScheduleUser.find(:all, :conditions=>["schedule_id = ?", self.id])
    len = schedule_users.length
    if len > 0
      schedule_users.each do |schedule_user|
        begin
          case schedule_user.class_id
          when 0
          when 1
            user = schedule_user.user
            _names << user.name if user.present? && user.state == 'enabled'
          when 2
            group = schedule_user.group
            _names << group.name if group.present? && group.state == 'enabled'
          end
        rescue
        end
      end
    end
    names = Gw.join(_names, '，')
    return names
  end
=end

  def get_usernames
    Gw::ScheduleUser.includes(:user).where(schedule_id: self.id)
                    .map {|x| x.user.name }.join(', ')
  end

  def self.schedule_linked_time_save(item, st_at, ed_at)

    item.schedule_props.each do |item_prop|
      item_prop.st_at = st_at
      item_prop.ed_at = ed_at
      item_prop.save!
    end

    item.schedule_users.each do |item_user|
      item_user.st_at = st_at
      item_user.ed_at = ed_at
      item_user.save!
    end

  end

  def self.save_with_rels_part(item, params)

    _params = params[:item].dup
    if params[:item][:st_at].present?
      st_at, ed_at = Gw.get_parsed_date(params[:item][:st_at]), Gw.get_parsed_date(params[:item][:ed_at])
      d_st_at, d_ed_at = Gw.get_parsed_date(st_at), Gw.get_parsed_date(ed_at)
      item.errors.add :st_at, 'と終了日時の前後関係が不正です。'  if st_at > ed_at
      item.errors.add :st_at, 'と終了日時は１年以内でなければいけません。' if (d_ed_at - d_st_at) > 86400 * 365
    end

    if !params[:item][:allday_radio_id].blank?
      if params[:init][:repeat_mode] == "1"
        _params[:allday] = params[:item][:allday_radio_id]
      elsif params[:init][:repeat_mode] == "2"
        _params[:allday] = params[:item][:repeat_allday_radio_id]
      end
    else
      _params[:allday] = nil
    end

    if item.errors.length == 0

      if !params[:item][:st_at].blank?
        _params[:st_at] = st_at.strftime("%Y-%m-%d %H:%M:%S")
        _params[:ed_at] = ed_at.strftime("%Y-%m-%d %H:%M:%S")
        schedule_linked_time_save(item, st_at, ed_at)
      end

      if !params[:item][:allday_radio_id].blank?
        _params[:allday] = _params[:allday_radio_id]
      end

      _params = _params.merge ret_updator
      _params[:updated_at] = Time.now.strftime("%Y-%m-%d %H:%M:%S")

      _params[:admin_memo] = params[:item][:admin_memo]

      if !params[:item][:schedule_users_json].blank?
        _users = JsonParser.new.parse(params[:item][:schedule_users_json])
        Gw::ScheduleUser.destroy_all("schedule_id=#{item.id}")
        _users.each do |user|
          item_sub = Gw::ScheduleUser.new()
          item_sub.schedule_id = item.id
          item_sub.st_at = st_at
          item_sub.ed_at = ed_at
          item_sub.class_id = user[0].to_i
          item_sub.uid = user[1]
          return false if !item_sub.save
        end
      end

      _params = _params.reject{|k,v|!%w(ed_at(1i) ed_at(2i) ed_at(3i) ed_at(4i) ed_at(5i) st_at(1i) st_at(2i) st_at(3i) st_at(4i) st_at(5i) schedule_users_json schedule_users allday_radio_id allday_radio_id form_kind_id).index(k).nil?}

      item.update_attributes(_params)
      return true

    else
      return false
    end

  end

  def self.ret_auth_hash(auth = {})
    if !auth.key?(:is_gw_admin)
      auth[:is_gw_admin] = Gw.is_admin_admin?
    end
    return auth
  end

  def get_edit_delete_level(auth = {})
    # auth_level[:edit_level]
    #    1：編集可能
    #    2：開始日時、終了日時、終日、管理者メモのみ編集可能
    #    3：参加者を編集可能
    #    4：管理者メモのみ編集可能
    #    100：編集不可
    # auth_level[:delete_level]
    #    1：削除可能
    #    100：削除不可

    auth = Gw::Schedule.ret_auth_hash(auth)
    auth_level = {:edit_level => 100, :delete_level => 100}

    if auth[:is_gw_admin]
      auth_level[:edit_level] = 1
      auth_level[:delete_level] = 1
      return auth_level
    end

    uid = Site.user.id

    if self.creator_uid == uid
      creator = true
    else
      creator = false
    end

    schedule_uids = self.schedule_users.select{|x|x.class_id==1}.collect{|x| x.uid}
    participant = schedule_uids.index(uid).present?

    if participant # 参加者
      auth_level[:edit_level] = 1
      auth_level[:delete_level] = 1
    end

    if creator # 作成者
      auth_level[:edit_level] = 1
      auth_level[:delete_level] = 1
    end

    # prop
    props = self.schedule_props

    prop_admin = true
    if props.length == 0
      prop_admin = false
      # 施設予約がなければ、全員が編集/削除可能とする
      auth_level[:edit_level] = 1
      auth_level[:delete_level] = 1
    end
    #施設マスタ権限を持つユーザーかの情報
    schedule_prop_admin = Gw.is_other_admin?('schedule_prop_admin')
    props.each do |prop|
      unless Gw::PropOtherRole.is_admin?(prop.prop.id) || Gw::PropOtherRole.is_edit?(prop.prop.id) || schedule_prop_admin
        prop_admin = false
      end
    end
    if prop_admin
      auth_level[:edit_level] = 1
      auth_level[:delete_level] = 1
    end

    return auth_level
  end

  def self.schedule_tabbox_struct(tab_captions, selected_tab_idx = nil, radio = nil, options = {})

    tab_current_cls_s = ' ' + Gw.trim(nz(options[:tab_current_cls_s], 'current'))
    id_prefix = Gw.trim(nz(options[:id_prefix], nz(options[:name_prefix], '')))
    id_prefix = "[#{id_prefix}]" if !id_prefix.blank?
    
    tabs = <<-"EOL"
<div class="tabBox">
<table class="tabtable">
<tbody>
<tr>
<td id="spaceLeft" class="spaceLeft"></td>
EOL
    tab_idx = 0
    tab_captions.each_with_index{|x, idx|
      tab_idx += 1
      _name = "tabBox#{id_prefix}[#{tab_idx}]"
      _id = Gw.idize(_name)
      tabs.concat %Q(<td class="tab#{selected_tab_idx - 1 == idx ? tab_current_cls_s : nil}" id="#{_id}">#{x}</td>) +
        (tab_captions.length - 1 == idx ? '' : '<td id="spaceCenter" class="spaceCenter"></td>')
    }
    tabs.concat <<-"EOL"
<td id="spaceRight" class="spaceRight">#{radio}</td>
</tr>
</tbody>
</table>
</div><!--tabBox-->
EOL
    return tabs
  end

  def public_groups_display
    ret = Array.new
    self.public_roles.each do |public_role|
      if public_role.class_id == 2
        if public_role.uid == 0
          ret << "制限なし"
        else
          group = System::GroupHistory.find_by_id(public_role.uid)
          if !group.blank?
            if group.state == "disabled"
              ret << "<span class=\"required\">#{group.name}</span>"
            else
              ret << [group.name]
            end
          else
            ret << "<span class=\"required\">削除所属 gid=#{public_role.uid}</span>"
          end
        end
      end
    end
    return ret
  end
  
  def self.repeat_weekday_select
    items = [['日曜日', 0], ['月曜日', 1], ['火曜日', 2], ['水曜日', 3], ['木曜日', 4], ['金曜日', 5], ['土曜日', 6]]
    return items
  end
  def self.repeat_weekday_show
    is_public_items = [['公開（誰でも閲覧可）', 1],['所属内（参加者の所属および公開所属）', 2],['非公開（参加者のみ）',3]]
    return is_public_items
  end

  def self.is_public_select
    is_public_items = [['公開（誰でも閲覧可）', 1],['所属内（参加者の所属および公開所属）', 2],['非公開（参加者のみ）',3]]
    return is_public_items
  end

  def self.is_public_show(is_public)
    is_public_items = [[1,'公開（誰でも閲覧可）'],[2,'所属内（参加者の所属および公開所属）'],[3,'非公開（参加者のみ）']]
    show = is_public_items.assoc(is_public)
    if show.blank?
      return nil
    else
      return show[1]
    end
  end

  def time_show
    if nz(self.allday, 0) == 0
      st_at_s = self.st_at.strftime('%H:%M')
      ed_at_s = self.ed_at.strftime('%H:%M')
    elsif self.allday == 1
      st_at_s = "時間未定"
      ed_at_s = "時間未定"
    elsif self.allday == 2
      st_at_s = "終日"
      ed_at_s = "終日"
    end
    return {:st_at_show => st_at_s, :ed_at_show => ed_at_s}
  end
  
  def date_between(date)
    flg = date == self.st_at.to_date || date == self.ed_at.to_date || (self.st_at.to_date < date && date < self.ed_at.to_date)
    return flg
  end
  
  def show_time(date, view = :pc)
    # view
    # :pc、:smart_phone、:mobile
    case self.allday
    when 1
      if view == :pc
        return "（時間未定）"
      else
        return "時間未定"
      end
    when 2
      if view == :pc
        return ""
      else
        return "終日"
      end
    else
      date_array = Gw.date_array(self.st_at, self.ed_at)
      case date_array.length
      when 1
        return "#{Gw.time_str(self.st_at)}-#{Gw.time_str(self.ed_at)}"
      else
        if date == self.st_at.to_date
          return "#{Gw.time_str(self.st_at)}-"
        elsif date == self.ed_at.to_date
          return "-#{Gw.time_str(self.ed_at)}"
        else
          return ""
        end
      end
    end
  end

  # === スケジュール件名省略時の表示情報作成
  def show_time_ellipsis(date, view = :pc)
    # view
    # :pc、:smart_phone、:mobile
    case self.allday
    when 1
      return I18n.t("rumi.schedule.schedule_title.time_no_set")
    when 2
      return ""
    else
      date_array = Gw.date_array(self.st_at, self.ed_at)
      case date_array.length
      when 1
        return "#{Gw.time_str(self.st_at)}-"
      else
        if date == self.st_at.to_date
          return "#{Gw.time_str(self.st_at)}-"
        elsif date == self.ed_at.to_date
          return "-#{Gw.time_str(self.ed_at)}"
        else
          return ""
        end
      end
    end
  end
  
  def show_day_date_range(st_date)
    if self.ed_at.to_date > st_date
      ed_at = 23.5
    else
      ed_at = self.ed_at.hour
      ed_at += 0.5 if self.ed_at.min > 30
      ed_at -= 0.5 if self.ed_at.min == 0 && ed_at != 0 && self.st_at != self.ed_at
    end
    if self.st_at.to_date < st_date
      st_at = 0
    else
      st_at =  self.st_at.hour
      st_at += 0.5 if  self.st_at.min >= 30
    end
    
    return st_at, ed_at
  end
  
  def get_category_class
    return "category#{nz(self.title_category_id, 0)}"
  end

  # === 新着情報(新規作成時)を作成するメソッド
  #  参加者(作成者以外)のユーザーに対して通知する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def build_created_remind
    # 参加者 + 作成者のユーザーに対して作成する
    user_ids = schedule_users.map(&:uid)
    user_ids << creator_uid
    user_ids.uniq!

    is_repeat_operation = repeat.present?
    user_ids.each { |user_id| build_remind(user_id, created_at, "create", is_repeat_operation) }

    # 作成者の該当スケジュールの通知を全て既読にする
    seen_remind(creator_uid)
  end

  # === 新着情報(更新時)を作成するメソッド
  #  参加者 + 作成者 - 更新者のユーザーに対して通知する
  #  また、参加者から外されたユーザーの新着情報から該当スケジュール分を全て削除する
  # ==== 引数
  #  * is_repeat_operation: 繰り返し編集かどうか?
  # ==== 戻り値
  #  なし
  def build_updated_remind(is_repeat_operation = false)
    # 参加者 + 作成者のユーザーに対して作成する
    user_ids = schedule_users.map(&:uid)
    user_ids << creator_uid
    user_ids.uniq!

    # 繰り返し編集された場合
    if is_repeat_operation
      # 繰り返し予約を単体編集した場合の通知はGw::Schedule削除と併せて自動で削除されるため
      # 繰り返し編集された場合は、過去の繰り返し予約に対する通知を削除する
      repeat.reminders.destroy_all

    # 単体編集された場合
    else
      # 該当スケジュールに対する過去の通知で現在の参加者 + 作成者ではないユーザーの通知を削除する
      destroy_reminder_of_unconcerned_user(reminders)

      # 繰り返し予約の初日が単体編集された場合は、過去の繰り返し予約に対する通知を対象に初日の参加者 + 作成者ではないユーザーの通知を既読にする
      if repeat.present? && id == repeat.first_day_schedule.id
        # 削除対象のremindersからユーザーIDを抽出し、過去の参加者IDとして扱う
        old_user_ids = repeat.reminders.map(&:user_id).uniq
        # 過去の参加者IDから現在の参加者 + 作成者のユーザーIDを減算して、関係者(参加者 + 作成者)ではないユーザーIDを算出する
        (old_user_ids - user_ids).each { |user_id| seen_remind(user_id) }
      end
    end

    user_ids.each { |user_id| build_remind(user_id, updated_at, "update", is_repeat_operation) }

    # 更新者の該当スケジュールの通知を全て既読にする
    seen_remind(updater_uid)
  end

  # === 新着情報(論理削除時)を作成するメソッド
  #  参加者 + 作成者 - 更新者のユーザーに対して通知する
  # ==== 引数
  #  * is_repeat_operation: 連続一括削除かどうか?
  # ==== 戻り値
  #  なし
  def build_deleted_remind(is_repeat_operation = false)
    # 参加者 + 作成者のユーザーに対して作成する
    user_ids = schedule_users.map(&:uid)
    user_ids << creator_uid
    user_ids.uniq!

    user_ids.each { |user_id| build_remind(user_id, updated_at, "delete", is_repeat_operation) }

    # 更新者の該当スケジュールの通知を全て既読にする
    seen_remind(updater_uid)
  end

  # === 新着情報を作成するメソッド
  #  ユーザーに対して作成する
  # ==== 引数
  #  * user_id: ユーザーID
  #  * datetime: 日付
  #  * action: 操作名
  #  * is_repeat_operation: 繰り返し予約の新規作成、繰り返し編集、連続一括削除か?
  # ==== 戻り値
  #  Gw::Reminder
  def build_remind(user_id, datetime, action, is_repeat_operation)
    if schedule_props.present?
      category = "schedule_prop"
    else
      category = "schedule"
    end

    if repeat.present? && is_repeat_operation
      item_id = repeat.id
      sub_category = "schedule_repeat"

      if action == "delete"
        # 連続一括削除の場合はボタンをクリックしたスケジュールへのURLとなる
        url_id = id
      else
        # 繰り返し予約の新規作成、繰り返し編集の通知URLは繰り返し予約の初日のスケジュールへのURLとなる
        url_id = repeat.first_day_schedule.id
      end
    else
      item_id = id
      url_id = id
      sub_category = nil
    end

    return Gw::Reminder.create(category: category, sub_category: sub_category,
        user_id: user_id, item_id: item_id, title: title, datetime: datetime,
        action: action, url: "/gw/schedules/#{url_id}/show_one")
  end

  # === 参加者 + 作成者ではないユーザーの新着情報を削除するメソッド
  #
  # ==== 引数
  #  * destroy_reminders: 削除対象のreminders
  # ==== 戻り値
  #  なし
  def destroy_reminder_of_unconcerned_user(destroy_reminders)
    # 現在の関係者(参加者 + 作成者)のユーザーID
    concerned_user_ids = schedule_users.map(&:uid)
    concerned_user_ids << creator_uid
    concerned_user_ids.uniq!
    # 削除対象のremindersからユーザーIDを抽出し、過去の参加者IDとして扱う
    old_user_ids = destroy_reminders.map(&:user_id).uniq
    # 過去の参加者IDから現在の参加者 + 作成者のユーザーIDを減算して、関係者(参加者 + 作成者)ではないユーザーIDを算出する
    unconcerned_user_ids = (old_user_ids - concerned_user_ids)
    # 関係者ではないユーザーの新着情報を全て削除する
    destroy_reminders.where("user_id in (?)", unconcerned_user_ids).destroy_all if unconcerned_user_ids.present?
  end

  # === 新着情報を既読にするメソッド
  #  ユーザーに対して実行する
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  なし
  def seen_remind(user_id)
    if repeat.present?
      repeat.reminders.extract_user_id(user_id).each do |reminder|
        # 既読にする
        reminder.seen
      end

      repeat.schedules.each do |schedule|
        schedule.reminders.extract_user_id(user_id).each do |reminder|
          # 既読にする
          reminder.seen
        end
      end
    end

    reminders.extract_user_id(user_id).each do |reminder|
      # 既読にする
      reminder.seen
    end
  end

  # === 未読か評価するメソッド
  #  ユーザーに対して実行する
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  boolean true: 未読あり false: 全て既読
  def unseen?(user_id)
    return reminders.extract_user_id(user_id).exists? || 
      (repeat.present? && repeat.reminders.extract_user_id(user_id).exists?)
  end

  def self.find_for_show_schedule(uids, first_day, end_day,user_id)
    cond_date = "('#{first_day.strftime('%Y-%m-%d 0:0:0')}' <= gw_schedules.ed_at" +
            " and '#{end_day.strftime('%Y-%m-%d 23:59:59')}' >= gw_schedules.st_at)"
    cond = "gw_schedule_users.uid in (#{Gw.join(uids, ',')})" + " and gw_schedules.delete_state = 0" +
          " and #{cond_date}"
    join = "left outer join (select gw_reminders.item_id,user_id,seen_at from gw_reminders" +
          " where gw_reminders.seen_at is NULL and gw_reminders.category like 'schedule%'" +
          " and gw_reminders.user_id = #{Site.user.id}) reminder" +
          " on (reminder.item_id = gw_schedules.id or reminder.item_id = gw_schedules.schedule_repeat_id)"
    select("gw_schedules.*, reminder.user_id, reminder.seen_at as remind_seen_at")
      .where(cond).order("gw_schedules.allday DESC, gw_schedules.st_at, gw_schedules.ed_at, gw_schedules.id")
      .joins(:schedule_users)
      .joins(join)
      .group("gw_schedules.id")
  end

  def self.find_for_show(prop_ids, first_day, end_day,user_id)
    cond_date = "('#{first_day.strftime('%Y-%m-%d 0:0:0')}' <= gw_schedules.ed_at" +
            " and '#{end_day.strftime('%Y-%m-%d 23:59:59')}' >= gw_schedules.st_at)"
    cond = "gw_schedule_props.prop_id in (#{Gw.join(prop_ids, ',')})" + " and gw_schedules.delete_state = 0" +
          " and #{cond_date}"
    join = "left outer join (select gw_reminders.item_id,user_id,seen_at from gw_reminders" +
          " where gw_reminders.seen_at is NULL and gw_reminders.category like 'schedule%'" +
          " and gw_reminders.user_id = #{Site.user.id}) reminder" +
          " on (reminder.item_id = gw_schedules.id or reminder.item_id = gw_schedules.schedule_repeat_id)"
    select("gw_schedules.*, reminder.user_id, reminder.seen_at as remind_seen_at")
      .where(cond).order("gw_schedules.allday DESC, gw_schedules.st_at, gw_schedules.ed_at, gw_schedules.id")
      .joins(:schedule_props)
      .joins(join)
      .group("gw_schedules.id")
  end

  def remind_unseen?(schedule)
    return schedule.user_id.to_s == Site.user.id.to_s && schedule.remind_seen_at.blank?
  end

  # === 既読した日時を返すメソッド
  #  ユーザーに対して実行する
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  DateTime
  def seen_at(user_id)
    unscoped_reminders = Gw::Reminder.unscoped.extract_schedule_like_category
    # 繰り返し予約ではない新着情報の既読日時
    normal_seen_at = unscoped_reminders.extract_seen(id, user_id).where(sub_category: nil).last.try(:seen_at)
    repeat_seen_at = nil

    if repeat.present?
      # 繰り返し予約の新着情報の既読日時
      repeat_seen_at = unscoped_reminders.extract_seen(repeat.id, user_id).where(sub_category: "schedule_repeat").last.try(:seen_at)
    end

    if normal_seen_at && repeat_seen_at
      return normal_seen_at >= repeat_seen_at ? normal_seen_at : repeat_seen_at
    else
      return normal_seen_at if normal_seen_at
      return repeat_seen_at if repeat_seen_at
    end
  end

  class << self

    # === 新着情報取得メソッド
    #  新着情報に表示する未読のスケジュール、施設・施設予約を取得する
    # ==== 引数
    #  * user_id: ユーザーID
    #  * sort_key: 並び替えするKey（日付／概要）
    #  * order: 並び順（昇順／降順）
    # ==== 戻り値
    #  スケジュール情報(Hashオブジェクト)
    def remind(user_id, sort_key, order)
      return Gw::Reminder::to_rumi_format(Gw::Reminder.extract_schedule_like(user_id, sort_key, order))
    end

    # === 通知件数取得メソッド(予約種別：通常)
    #  下記の条件に当てはまるスケジュール(予約種別：通常)の件数を取得する
    #  * 他ユーザーに作成されたログインユーザーが参加する未読のスケジュール件数
    #  * 他ユーザーに更新されたログインユーザーが参加するスケジュールかつ更新操作後のスケジュールが未読のスケジュール件数
    #  * 他ユーザーに削除されたログインユーザーが参加するスケジュールかつ削除操作後のスケジュールが未読のスケジュール件数
    # ==== 引数
    #  * user_id: ユーザーID
    # ==== 戻り値
    #  通知件数(整数)
    def normal_notification(user_id)
      return Gw::Reminder.extract_schedule(user_id, nil, nil).count
    end

    # === 通知件数取得メソッド(予約種別：施設)
    #  下記の条件に当てはまるスケジュール(予約種別：施設)の件数を取得する
    #  * 他ユーザーに作成されたログインユーザーが参加する未読のスケジュール件数
    #  * 他ユーザーに更新されたログインユーザーが参加するスケジュールかつ更新操作後のスケジュールが未読のスケジュール件数
    #  * 他ユーザーに削除されたログインユーザーが参加するスケジュールかつ削除操作後のスケジュールが未読のスケジュール件数
    # ==== 引数
    #  * user_id: ユーザーID
    # ==== 戻り値
    #  通知件数(整数)
    def prop_notification(user_id)
      return Gw::Reminder.extract_schedule_prop(user_id, nil, nil).count
    end

  end
end
