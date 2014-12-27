module Doclibrary::Model::DbnameAlias

  def admin_flags(title_id)
    @is_sysadm = true if System::Role.has_auth?(Site.user.id, 'doclibrary', 'admin')
    @is_bbsadm = true if @is_sysadm
    unless @is_bbsadm
      item = Doclibrary::Adm.new
      item.and :user_id, 0
      item.and :group_id, Site.user.user_group_parent_ids
      item.and :title_id, title_id unless title_id == '_menu'
      items = item.find(:all)
      @is_bbsadm = true unless items.blank?

      unless @is_bbsadm
        item = Doclibrary::Adm.new
        item.and :user_id, Site.user.id
        item.and :title_id, title_id unless title_id == '_menu'
        items = item.find(:all)
        @is_bbsadm = true unless items.blank?
      end
    end

    @is_admin = true if @is_sysadm
    @is_admin = true if @is_bbsadm
  end

  # === フォルダの管理権限判定メソッド
  #  ファイル管理の全フォルダのうち、いずれかのフォルダに管理権限があるか判定するメソッドである。
  #  判定結果は@has_some_folder_adminに保存する。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def set_has_some_folder_admin_flag
    @has_some_folder_admin = false
    if @is_admin
      # ファイル管理の管理権限がある場合は、フォルダの管理権限もあり
      @has_some_folder_admin = true
      return
    end

    # フォルダの管理権限チェック
    unless @has_some_folder_admin

      condition = "(admins_json IS NOT NULL AND admins_json != '[]') OR " +
                  "(admin_groups_json IS NOT NULL AND admin_groups_json != '[]') "
      cnn = doclib_db_alias(Doclibrary::Folder)
      roles = cnn.where(title_id: @title.id)
                 .where(condition)

      roles.each do |role|
        admin_groups = JsonParser.new.parse(role.admin_groups_json)
        admins = JsonParser.new.parse(role.admins_json)

        # ログインユーザーがグループ管理権限に含まれるか？
        user_group_ids = Site.user.groups.map(&:id)
        admin_groups.each do |group|
          if user_group_ids.include?(group[1].to_i)
            @has_some_folder_admin = true
            return
          end
        end
        # ログインユーザーが個人管理権限に含まれるか？
        admins_ids = admins.map{|admin| admin[1].to_i}
        if admins_ids.include?(Site.user.id)
          @has_some_folder_admin = true
          return
        end
      end
      Doclibrary::Folder.remove_connection
    end
  end

  def get_readable_flag
    @is_readable = true if @is_admin
    unless @is_readable
      sql = Condition.new
      sql.and :role_code, 'r'
      sql.and :title_id, @title.id
      items = Doclibrary::Role.find(:all, :order=>'group_code', :conditions => sql.where)
      items.each do |item|
        @is_readable = true if item.group_code == '0'
        for user_group in Site.user.enable_user_groups
          @is_readable = true if item.group_code == user_group.group_code
          @is_readable = true if item.group_code == user_group.group.parent.code unless user_group.group.parent.blank?
          break if @is_readable
        end
        break if @is_readable
      end
    end

    unless @is_readable
      item = Doclibrary::Role.new
      item.and :role_code, 'r'
      item.and :title_id, @title.id
      item.and :user_code, Site.user.code
      item = item.find(:first)
      @is_readable = true if item.user_code == Site.user.code unless item.blank?
    end
  end

  def doclib_db_alias(item)

    title_id = params[:title_id]
    title_id = @title.id unless @title.blank?

    cnn = item.establish_connection

    cn = cnn.spec.config[:database]

    dbname = ''
    dbname = @title.dbname unless @title.blank?

    unless dbname == ''
      cnn.spec.config[:database] = @title.dbname.to_s
    else
      l = 0
      l = cn.length if cn
      if l != 0
        i = cn.rindex "_", cn.length
        cnn.spec.config[:database] = cn[0,i] + '_doc'
      else
        cnn.spec.config[:database] = "dev_jgw_doc"
      end

      unless title_id.blank?
        if is_integer(title_id)
          cnn.spec.config[:database] +=  '_' + sprintf("%06d", title_id)
        end
      end
    end
    Gwboard::CommonDb.establish_connection(cnn.spec.config)
    return item

  end

  def is_integer(no)
    if no == nil
      return false
    else
      begin
        Integer(no)
      rescue
        return false
      end
    end
  end

end