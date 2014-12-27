# coding: utf-8
module Gw::RumiHelper

  def truncate_group_names(groups)
    names = [groups.first]
    names << "他（#{groups.count - 1}）" if groups.count >= 2
    names.join(" ").html_safe
  end

  def select_prop_group_tree(partition=nil)
    group_lists = []
    roots = Gw::PropGroup.find(:all, :conditions=>"parent_id=1 and state='public' and id > 1",:order => "sort_no, id")
    return group_lists if roots.blank?
    group_lists << ["-----------------" , "-" ] if (partition == 'partition' or partition == 'partition_updown')
    roots.each do |r|
      group_lists << [r.name, "groups_#{r.id}"]
      group_lists = get_prop_group_childs(group_lists,r)
    end
    group_lists << ["-----------------" , "-" ] if (partition == 'partition_updown')
    return group_lists
  end

  def get_prop_group_childs(group_lists, parent)
    c_lists = group_lists
    childs = Gw::PropGroup.find(:all, :conditions=>"state='public' and parent_id=#{parent.id}", :order => "sort_no, id")
    return c_lists if childs.blank?
    childs.each do |c|
      c_lists << ["　#{c.name}", "groups_#{c.id}"]
      c_lists = get_prop_group_childs(c_lists,c)
    end
    return c_lists
  end

  def select_prop_type(all=nil)
    type_lists = []
    type_lists << ['すべて',0] if all == 'all'
    prop_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => "sort_no, id")
    prop_types.each do |prop_type|
      type_lists << [prop_type.name, "type_#{prop_type.id}" ]
    end
    return type_lists
  end

end
