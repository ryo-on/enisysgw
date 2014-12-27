# encoding: utf-8
#require 'digest/sha1'
class System::ScheduleRole < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include Cms::Model::Base::Content
  include System::Model::Base::Content

  validates_presence_of :target_uid, :message => "を選択してください。"

  # === 権限対象者からログインユーザー以外を抽出するスコープ
  #
  # ==== 引数
  #  * user_id: ログインユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :get_target_uids, lambda { |user_id|
    cond = "system_schedule_roles.target_uid not in ( " + user_id + ")"
    .where(cond)
  }

  # === 権限付与者を抽出するスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :get_auth_users, lambda { |user_id|
    select("system_schedule_roles.target_uid")
    .where("system_schedule_roles.user_id is not null")
    .where(user_id: user_id)
  }

  # === ログインユーザーが権限付与者である権限対象者以外を抽出するスコープ
  #
  # ==== 引数
  #  * target_uid: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :auth_users, lambda { |targets|
    cond = "system_schedule_roles.target_uid not in ( #{targets})"
    where(cond)
  }

  # === 権限付与所属を抽出するスコープ
  #
  # ==== 引数
  #  * group_id: グループID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :get_auth_groups, lambda { |group_id|
    select("system_schedule_roles.target_uid")
    .where("system_schedule_roles.group_id is not null")
    .where(group_id: group_id)
  }

  # === ログインユーザーの所属が権限付与所属である権限対象者以外を抽出するスコープ
  #
  # ==== 引数
  #  * target_uid: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :auth_groups, lambda { |target_uid|
    cond = "target_uid not in ( #{target_uid}) "
    where(cond)
  }

  # === 権限付与者に設定されているユーザーの状態が無効のユーザー以外を抽出するスコープ
  #
  # ==== 引数
  #  * target_uid: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable_user, lambda { |users|
    cond = "(user_id not in ( #{users}) or user_id is null)"
    where(cond)
  }

  # === 権限付与所属に設定されているグループの状態が無効のグループ以外を抽出するスコープ
  #
  # ==== 引数
  #  * target_uid: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable_group, lambda { |groups|
    cond = "(group_id not in ( #{groups}) or group_id is null)"
    where(cond)
  }

  def self.get_target_uids(user_id = nil)
    user_id ||= Site.user.id

    cond = "target_uid not in ( #{user_id} )"
    target_uids = System::ScheduleRole.unscoped.where(cond)

    #状態が無効の権限付与者を排除
    targets = target_uids
    disabled_user = System::User.without_enable
    users = ''
    cnt = 0
    targets.each do |t_uid|
      disabled_user.each do |d_user|
        users = users + " , #{d_user.id.to_s} " if t_uid.user_id == d_user.id && cnt == 1
        if t_uid.user_id == d_user.id && cnt == 0
          users = " #{d_user.id.to_s} "
          cnt = 1
        end
      end
    end
    target_uids = target_uids.without_disable_user(users) if users.present?

    #状態が無効の権限付与所属を排除
    targets = target_uids
    disabled_group = System::Group.without_enable
    groups = ''
    cnt = 0
    targets.each do |t_uid|
      disabled_group.each do |d_group|
        groups = groups + " , #{d_group.id.to_s} " if t_uid.group_id == d_group.id && cnt == 1
        if t_uid.group_id == d_group.id && cnt == 0
          groups = " #{d_group.id.to_s} "
          cnt = 1
        end
      end
    end
    target_uids = target_uids.without_disable_group(groups) if groups.present?

    #権限付与者に設定されているログインユーザーを含む対象ユーザーを排除
    _auth_user = System::ScheduleRole.get_auth_users(user_id)
    _target_uids = ''
    cnt = 0
    _auth_user.each do |a_user|
      _target_uids = a_user.target_uid.to_s if cnt == 0
      _target_uids = _target_uids + " , " + a_user.target_uid.to_s if cnt == 1
      cnt = 1
    end
    target_uids = target_uids.auth_users(_target_uids) if _target_uids.present?

    #権限付与所属に設定されているログインユーザーの所属を含む対象ユーザーを排除
    user_group = System::UsersGroup.schedule_role_user_group(user_id)
    _target_uids = ''
    cnt = 0
    user_group.each do |u_group|
      _auth_group = System::ScheduleRole.get_auth_groups(u_group.group_id)
      _auth_group.each do |a_group|
        _target_uids = a_group.target_uid.to_s if cnt == 0
        _target_uids = _target_uids + " , " + a_group.target_uid.to_s if cnt == 1
        cnt = 1
      end
      target_uids = target_uids.auth_groups(_target_uids) if _target_uids.present?
      cnt = 0
    end

    target_uids = target_uids.group("target_uid")

    return target_uids
  end

  def self.get_target_uids_schedule_user(user_id = nil, schedule_id = nil)
    cond = "target_uid not in ( #{user_id} )"

    user = System::User.without_disable
    schedule_user = Gw::ScheduleUser.find(:all, :select => "uid", :conditions => ["schedule_id = ?", (schedule_id)])
    if schedule_user.present?
      s_user = " ( "
      cnt = 0
      schedule_user.each do |s|
        user.each do |u|
          if s.uid == u.id
            s_user += " #{s.uid} " if cnt == 0
            s_user += " , #{s.uid} " if cnt == 1
            cnt = 1
          end
        end
      end
      s_user += " ) "
      cond += " and target_uid in " + s_user if cnt == 1
      cond = " id = 0 " if cnt == 0
    else
      cond = " id = 0 "
    end
    target_uids = System::ScheduleRole.unscoped.where(cond)

    #状態が無効の権限付与者を排除
    targets = target_uids
    disabled_user = System::User.without_enable
    users = ''
    cnt = 0
    targets.each do |t_uid|
      disabled_user.each do |d_user|
        users = users + " , #{d_user.id.to_s} " if t_uid.user_id == d_user.id && cnt == 1
        if t_uid.user_id == d_user.id && cnt == 0
          users = " #{d_user.id.to_s} "
          cnt = 1
        end
      end
    end
    target_uids = target_uids.without_disable_user(users) if users.present?

    #状態が無効の権限付与所属を排除
    targets = target_uids
    disabled_group = System::Group.without_enable
    groups = ''
    cnt = 0
    targets.each do |t_uid|
      disabled_group.each do |d_group|
        groups = groups + " , #{d_group.id.to_s} " if t_uid.group_id == d_group.id && cnt == 1
        if t_uid.group_id == d_group.id && cnt == 0
          groups = " #{d_group.id.to_s} "
          cnt = 1
        end
      end
    end
    target_uids = target_uids.without_disable_group(groups) if groups.present?

    #権限付与者に設定されているログインユーザーを含む対象ユーザーを排除
    _auth_user = System::ScheduleRole.get_auth_users(user_id)
    _target_uids = ''
    cnt = 0
    _auth_user.each do |a_user|
      _target_uids = a_user.target_uid.to_s if cnt == 0
      _target_uids = _target_uids + " , " + a_user.target_uid.to_s if cnt == 1
      cnt = 1
    end
    target_uids = target_uids.auth_users(_target_uids) if _target_uids.present?

    #権限付与所属に設定されているログインユーザーの所属を含む対象ユーザーを排除
    user_group = System::UsersGroup.schedule_role_user_group(user_id)
    _target_uids = ''
    cnt = 0
    user_group.each do |u_group|
      _auth_group = System::ScheduleRole.get_auth_groups(u_group.group_id)
      _auth_group.each do |a_group|
        _target_uids = a_group.target_uid.to_s if cnt == 0
        _target_uids = _target_uids + " , " + a_group.target_uid.to_s if cnt == 1
        cnt = 1
      end
      target_uids = target_uids.auth_groups(_target_uids) if _target_uids.present?
      cnt = 0
    end

    target_uids = target_uids.group("target_uid")

    return target_uids
  end

  def self.is_admin?(uid = Site.user.id)
    System::Model::Role.get(1, uid ,'_admin', 'admin')
  end
end
