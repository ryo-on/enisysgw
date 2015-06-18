# -*- encoding: utf-8 -*-
class Doclibrary::Folder < Gwboard::CommonDb
  include System::Model::Base
  include System::Model::Base::Content
  include System::Model::Tree
  include Cms::Model::Base::Content
  include Doclibrary::Model::Systemname

  belongs_to :parent_folder, :foreign_key => :parent_id, :class_name => 'Doclibrary::Folder'
  has_many :children, :foreign_key => :parent_id, :class_name => 'Doclibrary::Folder'
  has_many :child_docs, :foreign_key => :category1_id, :class_name => 'Doclibrary::Doc'

  acts_as_tree :order=>'sort_no'

  validates_presence_of :state, :name

  before_destroy :delete_child_docs, :delete_children, :delete_acl_records

  after_save :save_acl_records

  attr_accessor :_acl_create_skip

  # === 有効なフォルダーのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :state_public, where(state: "public")

  # === 管理権限なしフォルダ取得メソッド
  #  管理権限のないフォルダIDを取得するメソッドである。
  # ==== 引数
  #  * title_id: ファイル管理ID
  # ==== 戻り値
  #  管理権限のないフォルダID配列
  def self.without_admin_auth(title_id)
    # 管理者の場合、全てのフォルダに管理権限あり
    return [] if Site.user.admin_in_doclibrarys?(title_id)

    without_admin_ids = []
    root_folder = Doclibrary::Folder.where(level_no: 1).first
    without_admin_ids =
        get_child_without_admin_ids(root_folder, without_admin_ids, false)
    return without_admin_ids
  end

  def delete_child_docs
    self.child_docs.destroy_all
  end

  def delete_children
    self.children.destroy_all
  end

  def delete_acl_records
    Doclibrary::FolderAcl.destroy_all("title_id=#{self.title_id} AND folder_id=#{self.id}")
  end

  # === Doclibrary::FolderAclデータ登録メソッド
  #  カレントフォルダのDoclibrary::FolderAclデータを登録するメソッドである。
  #  各メソッド内で@rec_countをインクリメントする。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def save_acl_records
    # ルートフォルダの場合、終了
    return if self._acl_create_skip

    # カレントフォルダのDoclibrary::FolderAclデータ数リセット
    @rec_count = 0

    # カレントフォルダのDoclibrary::FolderAclデータのリセット
    unless self.admin_groups_json.blank? && self.admins_json.blank? &&
        self.reader_groups_json.blank? && self.readers_json.blank?
      Doclibrary::FolderAcl.destroy_all("title_id=#{self.title_id} AND folder_id=#{self.id}")
    end

    # Doclibrary::FolderAclデータ登録（閲覧グループ権限）
    save_reader_groups_json

    # Doclibrary::FolderAclデータ登録（閲覧個別権限）
    save_readers_json

    # カレントフフォルダのDoclibrary::FolderAclデータ取得
    folder_acls = Doclibrary::FolderAcl.where(title_id: self.title_id,
                                              folder_id: self.id,
                                              acl_flag: [1, 2])

    # カレントフフォルダのDoclibrary::FolderAclデータがある場合
    # （フォルダ閲覧権限が設定されている場合）はDoclibrary::FolderAclデータ登録実行
    # ※フォルダ閲覧権限が設定されていない場合は無条件にフォルダ閲覧可能になるため
    #   管理権限についてはデータ登録しない
    unless folder_acls.count == 0
      # Doclibrary::FolderAclデータ登録（管理グループ権限）
      save_admin_groups_json

      # Doclibrary::FolderAclデータ登録（管理個別権限）
      save_admins_json
    end

    # トータル情報登録
    save_role_json_all
  end

  # === Doclibrary::FolderAclデータ登録メソッド（閲覧グループ権限）
  #  カレントフォルダのDoclibrary::FolderAclデータ（閲覧グループ権限）を登録するメソッドである。
  #  メソッド内で@rec_countをインクリメントする。
  #  acl_flag:制限種別（0 ：権限なし、 1：所属権限　2:ユーザ権限　9：管理者）
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def save_reader_groups_json
    unless self.reader_groups_json.blank?
      groups = JsonParser.new.parse(self.reader_groups_json)
      groups.each do |group|
        item = Doclibrary::FolderAcl.new
        item.title_id = self.title_id
        item.folder_id = self.id
        item.acl_flag = 1
        item.acl_section_id = group[1].to_i
        item.acl_section_code = group_code(group[1])
        item.acl_section_name = group[2]
        item.save!
        @rec_count += 1
      end
    end
  end

  # === Doclibrary::FolderAclデータ登録メソッド（閲覧個別権限）
  #  カレントフォルダのDoclibrary::FolderAclデータ（閲覧個別権限）を登録するメソッドである。
  #  メソッド内で@rec_countをインクリメントする。
  #  acl_flag:制限種別（0 ：権限なし、 1：所属権限　2:ユーザ権限　9：管理者）
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def save_readers_json
    unless self.readers_json.blank?
      users = JsonParser.new.parse(self.readers_json)
      users.each do |user|
        item = Doclibrary::FolderAcl.new
        item.title_id = self.title_id
        item.folder_id = self.id
        item.acl_flag = 2
        item.acl_user_id = user[1].to_i
        item_user = System::User.find(item.acl_user_id)
        if item_user
          item.acl_user_id = item_user[:id]
          item.acl_user_code = item_user[:code]
        end
        item.acl_user_name = user[2]
        item.save!
        @rec_count += 1
      end
    end
  end

  # === Doclibrary::FolderAclデータ登録メソッド（グループ権限）
  #  カレントフォルダのDoclibrary::FolderAclデータ（グループ権限）を登録するメソッドである。
  #  メソッド内で@rec_countをインクリメントする。
  #  acl_flag:制限種別（0 ：権限なし、 1：所属権限　2:ユーザ権限　9：管理者）
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def save_admin_groups_json
    unless self.admin_groups_json.blank?
      groups = JsonParser.new.parse(self.admin_groups_json)
      groups.each do |group|
        # groupのデータは登録済みか？
        folder_acls = Doclibrary::FolderAcl.where(title_id: self.title_id,
                                                  folder_id: self.id,
                                                  acl_flag: 1,
                                                  acl_section_id: group[1].to_i)
        # 未登録であれば登録実行
        if folder_acls.count == 0
          item = Doclibrary::FolderAcl.new
          item.title_id = self.title_id
          item.folder_id = self.id
          item.acl_flag = 1
          item.acl_section_id = group[1].to_i
          item.acl_section_code = group_code(group[1])
          item.acl_section_name = group[2]
          item.save!
          @rec_count += 1
        end
      end
    end
  end

  # === Doclibrary::FolderAclデータ登録メソッド（管理個別権限）
  #  カレントフォルダのDoclibrary::FolderAclデータ（管理個別権限）を登録するメソッドである。
  #  メソッド内で@rec_countをインクリメントする。
  #  acl_flag:制限種別（0 ：権限なし、 1：所属権限　2:ユーザ権限　9：管理者）
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def save_admins_json
    unless self.admins_json.blank?
      users = JsonParser.new.parse(self.admins_json)
      users.each do |user|
        # userのデータは登録済みか？
        folder_acls = Doclibrary::FolderAcl.where(title_id: self.title_id,
                                                  folder_id: self.id,
                                                  acl_flag: 2,
                                                  acl_user_id: user[1].to_i)
        # 未登録であれば登録実行
        if folder_acls.count == 0
          item = Doclibrary::FolderAcl.new
          item.title_id = self.title_id
          item.folder_id = self.id
          item.acl_flag = 2
          item.acl_user_id = user[1].to_i
          item_user = System::User.find(item.acl_user_id)
          if item_user
            item.acl_user_id = item_user[:id]
            item.acl_user_code = item_user[:code]
          end
          item.acl_user_name = user[2]
          item.save!
          @rec_count += 1
        end
      end
    end
  end

  # === Doclibrary::FolderAclデータ登録メソッド（トータル情報）
  #  カレントフォルダのDoclibrary::FolderAclデータ（トータル情報）を登録するメソッドである。
  #  acl_flag:制限種別（0 ：権限なし、 1：所属権限　2:ユーザ権限　9：管理者）
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def save_role_json_all
    if @rec_count == 0
      # 全く権限設定がなかった場合
      item = Doclibrary::FolderAcl.new
      item.acl_flag = 0
      item.title_id = self.title_id
      item.folder_id = self.id
      item.save!
    else
      # 権限設定が1つ以上あった場合
      item = Doclibrary::FolderAcl.new
      item.acl_flag = 9
      item.title_id = self.title_id
      item.folder_id = self.id
      item.save!
    end
  end

  def group_code(id)
    item = System::Group.find_by_id(id)
    ret = ''
    ret = item.code if item
    return ret
  end

  def status_select
    [['公開','public'], ['非公開','closed']]
  end


  def status_name
    {'public' => '公開', 'closed' => '非公開'}
  end

  def level1
    self.and :level_no, 1
    return self
  end

  def level2
    self.and :level_no, 2
    return self
  end

  def level3
    self.and :level_no, 3
    return self
  end

  def search(params)
    params.each do |n, v|
      next if v.to_s == ''
      case n
      when 'kwd'
        and_keywords v, :name
      end
    end if params.size != 0

    return self
  end

  def link_list_path
    return "#{self.item_home_path}docs?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.id}"
  end

  def item_path
    return "#{self.item_home_path}folders?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def show_path
    return "#{self.item_home_path}folders/#{self.id}?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def edit_path
    return "#{self.item_home_path}folders/#{self.id}/edit?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def delete_path
    return "#{self.item_home_path}folders/#{self.id}?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def update_path
    return "#{self.item_home_path}folders/#{self.id}/update?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def child_count
    file_base  = Doclibrary::Doc.new
    file_cond  = "state!='preparation' and category1_id=#{self.id}"
    file_count = file_base.count(:all,:conditions=>file_cond)

    folder_base = Doclibrary::Folder.new
    folder_cond = "state!='preparation' and parent_id=#{self.id}"
    folder_count  = folder_base.count(:all,:conditions=>folder_cond)

    child_count =file_count + folder_count
    return child_count
  end

  def readable_public_children(is_admin = false)
    item = Doclibrary::Folder.new
    item.and 'doclibrary_folders.parent_id', id
    item.and 'doclibrary_folders.title_id', title_id
    item.and 'doclibrary_folders.state', 'public'
    item.and do |c|
      c.or do |c2|
        c2.and 'doclibrary_folder_acls.acl_flag', 0
      end
      c.or do |c2|
        c2.and 'doclibrary_folder_acls.acl_flag', 9
      end if is_admin
      c.or do |c2|
        c2.and 'doclibrary_folder_acls.acl_flag', 1
        c2.and 'doclibrary_folder_acls.acl_section_id', Site.user.user_group_parent_ids
      end
      c.or do |c2|
        c2.and 'doclibrary_folder_acls.acl_flag', 2
        c2.and 'doclibrary_folder_acls.acl_user_id', Core.user.id
      end
    end
    item.join 'INNER JOIN doclibrary_folder_acls on doclibrary_folders.id = doclibrary_folder_acls.folder_id'
    item.order 'doclibrary_folders.sort_no'
    item.find(:all, :select => 'DISTINCT doclibrary_folders.*')
  end

  # === ファイル管理フォルダーの管理権限判定メソッド
  #  指定ユーザーに対してフォルダーの管理権限があるか判定するメソッドである。
  # ==== 引数
  #  * target_user_id: ユーザーID
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def admin_user?(target_user_id = Site.user.id)
    target_user = System::User.find(target_user_id)
    return false if target_user.blank?

    # ファイル管理に対して管理権限のあるユーザーか？
    return true if target_user.admin_in_doclibrarys?(self.title_id)

    # フォルダに対して管理権限のあるユーザーか？
    return admin_user_check(target_user_id)
  end

  # === ファイル管理フォルダーの閲覧権限判定メソッド
  #  指定ユーザーに対してフォルダーの閲覧権限があるか判定するメソッドである。
  # ==== 引数
  #  * target_user_id: ユーザーID
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def readable_user?(target_user_id = Site.user.id)
    target_user = System::User.find(target_user_id)
    return false if target_user.blank?

    # ファイル管理に対して管理権限のあるユーザーか？
    return true if target_user.admin_in_doclibrarys?(self.title_id)

    # ファイル管理に対して閲覧権限のないユーザーの場合、falseを返して終了
    return false unless Doclibrary::Role.has_auth?(self.title_id, target_user_id, 'r')

    # フォルダーに対して管理権限のあるユーザーか？
    return true if admin_user_check(target_user_id)

    # フォルダーに対して閲覧権限のあるユーザーか？
    return readable_user_check(target_user_id)
  end

  # === 子フォルダID取得メソッド
  #  本メソッドは、子フォルダIDを取得するメソッドである。
  # ==== 引数
  #  * folder_ids: 子フォルダID配列
  # ==== 戻り値
  #  子フォルダID配列
  def get_child_folder_ids(folder_ids)
    self.children.each do |child|
      # 子フォルダのIDを子フォルダID配列へ格納
      folder_ids << child.id

      # 次階層の子フォルダIDを取得
      folder_ids = child.get_child_folder_ids(folder_ids)
    end
    return folder_ids
  end


protected

  # === 管理権限なしフォルダ取得メソッド
  #  子フォルダを辿り、管理権限のないフォルダIDを取得するメソッドである。
  # ==== 引数
  #  * parent_folder: 親フォルダ（Doclibrary::Folder）
  #  * without_admin_ids: 管理権限なしフォルダID配列
  #  * is_parent_admin: 親フォルダに管理権限があるか？
  #  * target_user: 対象ユーザー（System::User）
  # ==== 戻り値
  #  管理権限なしフォルダID配列
  def self.get_child_without_admin_ids(parent_folder, without_admin_ids, is_parent_admin,
      target_user = Site.user)
    # 親フォルダに管理権限がある場合、下位フォルダ全てに管理権限があるので終了
    return without_admin_ids if is_parent_admin

    # 親フォルダの管理権限フラグ
    is_admin = false

    # 親フォルダの管理グループ権限情報、管理個人権限情報を取得
    admin_groups = (parent_folder.admin_groups_json.nil?)?
        [] : admin_groups = JsonParser.new.parse(parent_folder.admin_groups_json)
    admins = (parent_folder.admins_json.nil?)?
        [] : JsonParser.new.parse(parent_folder.admins_json)

    # 対象ユーザーがグループ管理権限に含まれるか？
    user_group_ids = target_user.groups.map(&:id)
    admin_groups.each do |group|
      if user_group_ids.include?(group[1].to_i)
        is_admin = true
        break
      end
    end

    # 指定ユーザーがグループ管理権限に含まれない場合、個人管理権限に含まれるか？
    unless is_admin
      admins_ids = admins.map{|admin| admin[1]}
      is_admin = true if admins_ids.include?(target_user.id)
    end

    # 親フォルダに管理権限がない場合
    unless is_admin
      # 管理権限なしフォルダID配列に追加
      without_admin_ids << parent_folder.id

      # 子フォルダ情報の取得
      parent_folder.children.state_public.each do |child|
        # 子フォルダの管理権限をチェック
        without_admin_ids =
            get_child_without_admin_ids(child, without_admin_ids, is_admin, target_user)
      end
    end

    return without_admin_ids
  end

  # === フォルダーの管理権限判定メソッド
  #  指定ユーザーに対してフォルダーの管理権限があるか判定するメソッドである。
  # ==== 引数
  #  * target_user_id: ユーザーID
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def admin_user_check(target_user_id)
    is_admin = false

    # グループ管理権限、個人管理権限の両方がnil場合、管理権限なし
    return false if self.admin_groups_json.nil? && self.admins_json.nil?

    admin_groups = JsonParser.new.parse(self.admin_groups_json)
    admins = JsonParser.new.parse(self.admins_json)

    # グループ管理権限、個人管理権限の両方が設定されていない場合、管理権限なし
    return false if admin_groups.blank? && admins.blank?

    # 指定ユーザーがグループ管理権限に含まれるか？
    target_user = System::User.find(target_user_id)
    user_group_ids = target_user.groups.map(&:id)
    admin_groups.each do |group|
      return true if user_group_ids.include?(group[1].to_i)
    end

    # 指定ユーザーが個人管理権限に含まれるか？
    admins_ids = admins.map{|admin| admin[1].to_i}
    return true if admins_ids.include?(target_user_id)

    return is_admin
  end

  # === フォルダーの閲覧権限判定メソッド
  #  指定ユーザーに対してフォルダーの閲覧権限があるか判定するメソッドである。
  # ==== 引数
  #  * target_user_id: ユーザーID
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def readable_user_check(target_user_id)
    is_readable = false

    # 管理権限あり場合、閲覧権限あり
    return true if self.admin_user?(target_user_id)

    # グループ閲覧権限、個人閲覧権限の両方がnil場合、閲覧権限あり
    return true if self.reader_groups_json.nil? && self.readers_json.nil?

    reader_groups = JsonParser.new.parse(self.reader_groups_json)
    readers = JsonParser.new.parse(self.readers_json)

    # グループ閲覧権限、個人閲覧権限の両方が設定されていない場合、閲覧権限あり
    return true if reader_groups.blank? && readers.blank?

    # 指定ユーザーがグループ閲覧権限に含まれるか、グループ閲覧権限に制限なしが設定されているか？
    target_user = System::User.find(target_user_id)
    user_group_ids = target_user.groups.map(&:id)
    reader_groups.each do |group|
      return true if group[1].to_i == 0 || group[2] == "制限なし"
      return true if user_group_ids.include?(group[1].to_i)
    end

    # 指定ユーザーが個人閲覧権限に含まれるか？
    readers_ids = readers.map{|reader| reader[1].to_i}
    return true if readers_ids.include?(target_user_id)

    return false
  end
end
