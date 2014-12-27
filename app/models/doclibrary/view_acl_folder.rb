class Doclibrary::ViewAclFolder < Gwboard::CommonDb
  include System::Model::Base
  include System::Model::Base::Content
  include System::Model::Tree
  include Cms::Model::Base::Content
  include Doclibrary::Model::Systemname

  self.primary_key = :id

  has_many :children, :foreign_key => :parent_id, :class_name => 'Doclibrary::ViewAclFolder'

  acts_as_tree :order=>'sort_no'

  def link_list_path
    return "#{Site.current_node.public_uri}?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.id}"
  end

  def item_path
    return "#{Site.current_node.public_uri}?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def show_path
    return "#{Site.current_node.public_uri}#{self.id}?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def edit_path
    return "#{Site.current_node.public_uri}#{self.id}/edit?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def delete_path
    return "#{Site.current_node.public_uri}#{self.id}/delete?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def update_path
    return "#{Site.current_node.public_uri}#{self.id}/update?title_id=#{self.title_id}&state=CATEGORY&cat=#{self.parent_id}"
  end

  def enabled_children
    folders = self.class.new.find(:all, :conditions=>["parent_id = ? AND state = ?", self.id, "public"],
      :select => 'id, parent_id, state, created_at, updated_at, title_id, sort_no, level_no, name, acl_flag, acl_section_id, acl_section_code, acl_user_id, acl_user_code',
      :order=>"sort_no")
  end

  def count_children
    folders = self.class.new
    folders.and :parent_id, self.id
    folders.order 'sort_no'
    folders.find(:all, :select => 'id, name')
  end

  # === 子フォルダ取得メソッド
  #  本メソッドは、子フォルダを取得するメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  子フォルダID配列
  def get_child_folders
    f = Doclibrary::ViewAclFolder.select("id").group("id")
    return f
  end
end
