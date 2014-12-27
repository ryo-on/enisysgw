# encoding: utf-8
module Doclibrary::Admin::Piece::MenusHelper

  def doclibrary_folder_trees(items)
    return if items.blank?
    return if items.size == 0
    count = []
    class_str = %Q(level#{items[0].level_no})
    html = "<li><ul class='#{class_str}'>\n"

    count[items[0].level_no] = 1

    # 現在展開表示中のフォルダIDを取得
    open_folders = []
    if params[:state].present? &&
        (params[:state] == 'CATEGORY' || params[:state] == 'DATE') &&
        params[:open_folders].nil?
      if items[0].level_no == 1
        # 内容一覧（日付順）の場合、カレントフォルダをルートフォルダに設定
        params[:cat] = items[0].id.to_s if params[:state] == 'DATE' && params[:cat].blank?

        # 全てのフォルダからカレントフォルダ取得し、最初だけカレントフォルダを展開状態にする
        child_folders = [items[0]]
        child_folders = items[0].get_child_folders
        child_folders.each do |folder|
          if folder.id == params[:cat].to_i
            open_folders = folder.parent_tree.map(&:id)
            open_folders.uniq!
          end
        end
      end
    elsif params[:open_folders].present?
      open_folders = params[:open_folders].split(',').map{|id| id.to_i} 
    end
    params[:open_folders] = open_folders.join(',')

    items.each do |item|
     unless @iname == item.id
      @iname = item.id

      html << "#{doclibrary_folder_li(item, open_folders)}\n"
      count[items[0].level_no] =  count[items[0].level_no]+1
      if open_folders.include?(item.id)
        str_html = ''
        sub_folders = category_sub_folders(item)
        str_html = doclibrary_folder_trees(sub_folders) unless sub_folders.count == 0 unless sub_folders.blank?
        html << str_html unless str_html.blank?
      end if item.children.size > 0
     end
    end
    html << "</ul></li>\n"
    return html.html_safe
  end

  def user_group_parent_ids
    unless @user_group_parent_ids
      @user_group_parent_ids = Site.user.user_group_parent_ids
    end
    return @user_group_parent_ids
  end

  def group_sub_folders(item)
    return item.children.select{|x| x.state == 'public'}
  end

  def category_sub_folders(item)
    enabled_children = item.enabled_children
    sub_folders = enabled_children.select{|x|
      if @is_admin
        ((x.state == 'public') and (x.acl_flag == 0)) || ((x.state == 'public') and (x.acl_flag == 9))
      else
        ((x.state == 'public') and (x.acl_flag == 0)) ||
        ((x.state == 'public') and (x.acl_flag == 1) and (user_group_parent_ids.include?(x.acl_section_id))) ||
        ((x.state == 'public') and (x.acl_flag == 2) and (x.acl_user_id == Site.user.id))
      end
    }.uniq
    return sub_folders
  end

  def doclibrary_folder_li(item, open_folders)
    ret = ''
    sub_folders = category_sub_folders(item)
    if item.state == 'public'
      level_no = 'folder'
      if item.level_no == 1 && params[:state].present? && 
          (params[:state] == 'CATEGORY' || params[:state] == 'DATE')
        if open_folders.include?(item.id)
          level_no = 'root folder open'
        else
          level_no = 'root folder close'
        end
      end

      if open_folders.include?(item.id)
        level_no = 'folder open'
      end
      if item.id.to_s == params[:cat].to_s
        level_no += ' current'
      end
      level_no += ' someFolder' unless sub_folders.count == 0

      strparam = ''
      strparam += "&state=#{params[:state]}" unless params[:state]== 'DRAFT' unless params[:state].blank?
      if /open/ =~ level_no
        strparam += "&f=op" unless item.id.to_s == '1'
      end unless sub_folders.count == 0

      if (action_name == 'index' || action_name == 'refresh_folder_trees') &&
          (params[:state] == "CATEGORY" || params[:state].blank?)
        draggable = (item.level_no != 1 && @has_some_folder_admin)? ' draggable' : ''
      end

      ret << %Q(<li class="#{level_no}">)
      ret << '<table><tbody><tr><td width=12 valign="top">'
      if sub_folders.count == 0
        ret << '<div class="noneFolder">&nbsp;</div>'
      else
        folder_open_state = (/open/ =~ level_no)? 'open' : 'close'
        ajax_url = "#{root_url}doclibrary/piece/menus/refresh_folder_trees.js" +
            "?title_id=#{@title.id}&cat=#{params[:cat]}&state=#{params[:state]}" +
            "&open_folders=#{open_folders.join(',')}&folder_id=#{item.id}" +
            "&folder_open_state=#{folder_open_state}"

        ret << link_to(raw('&nbsp;'),
                       "#",
                       {:id => "toggle_folder_#{item.id}",
                        :class => "toggle_folder #{folder_open_state}",
                        :remote => true,
                        :onclick => "rumi.folder_trees.changeToggle('#{ajax_url}');return false;"})
      end
      ret << '</td><td width=18 valign="top">'
      ret << '<div class="someFolder">&nbsp;</div>'
      ret << '</td><td>'
      ret << link_to(item.name,
                     "#{@title.item_home_path}docs?title_id=#{item.title_id}&cat=#{item.id}#{strparam}",
                     {:id => "dragfolder_#{item.id}", :class => "folder_name droppable#{draggable}"})
      ret << '</td></tr></tbody></table>'
      ret << %Q(</li>)
    end
    return ret
  end
end
