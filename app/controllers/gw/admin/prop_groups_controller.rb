# encoding: utf-8
class Gw::Admin::PropGroupsController < Gw::Admin::PropGenreCommonController
  include System::Controller::Scaffold
  layout "admin/template/schedule"

  def initialize_scaffold
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    Page.title = "施設グループマスタ"
    @sp_mode = :prop
    @schedule_prop_admin = System::Model::Role.get(1, Core.user.id ,'schedule_prop_admin', 'admin')
    @is_gw_admin = Gw.is_admin_admin? || @schedule_prop_admin

    @genre = 'group'
    @model = Gw::PropGroup
    return authentication_error(403) unless @is_gw_admin
    if params[:id].blank?
      @parent = Gw::PropGroup.find(:all, :select => "id,name",
        :conditions => ["state = ? and parent_id = ?", "public","1"],
        :order => "sort_no")
    else
      @parent = Gw::PropGroup.find(:all, :select => "id,name",
        :conditions => ["state = ? and parent_id = ? and id != ?", "public","1",(params[:id])],
        :order => "sort_no")
    end
  end

  def index
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)

    @group = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and id > ? and parent_id=?", "public","1","1"],
      :order => "sort_no")
    @child = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and parent_id > ?", "public","1"],
      :order => "sort_no")

    @groupitems = Array.new
    @group.each do | item|
      @dummy = DummyItem3.new
      @dummy.id = item.id
      @dummy.name = item.name
      @parent.each do | pare|
        if item.parent_id == pare.id
          @dummy.parent_name = pare.name
        end
      end
      @dummy.sort_no = item.sort_no
      @groupitems << @dummy
      @child.each do |child|
        if child.parent_id == item.id
          @dummy = DummyItem3.new
          @dummy.id = child.id
          @dummy.name = "　　"+child.name
          @parent.each do | pare|
            if child.parent_id == pare.id
              @dummy.parent_name = pare.name
            end
          end
          @dummy.sort_no = child.sort_no
          @groupitems << @dummy
        end
      end
    end
  end

  def show
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    @groupitem = Gw::PropGroup.find_by_id(params[:id])
    @parent = Gw::PropGroup.find(:all, :select => "id,name",
      :conditions => ["state = ? and parent_id = ? and id != ?", "public","1",(params[:id])],
      :order => "sort_no")
    return http_error(404) if @groupitem.blank? || @groupitem.state == "delete"
    _show @groupitem
  end

  def new
    @groupitem = Gw::PropGroup.new
    @parent = Gw::PropGroup.find(:all, :select => "id,name",
       :conditions => ["state = ? and parent_id = ?", "public","1"],
       :order => "sort_no")
  end

  def create
    @groupitem = Gw::PropGroup.new(params[:groupitem])
    @groupitem.state = "public"
    _create @groupitem
  end

  def edit
    @groupitem = Gw::PropGroup.find_by_id(params[:id])
    @parent = Gw::PropGroup.find(:all, :select => "id,name",
      :conditions => ["state = ? and parent_id = ? and id != ?", "public","1",(params[:id])],
      :order => "sort_no")
    return http_error(404) if @groupitem.blank? || @groupitem.state == "delete"
  end

  def update
    @groupitem = Gw::PropGroup.find_by_id(params[:id])
    return http_error(404) if @groupitem.blank? || @groupitem.state == "delete"
    @childitems = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and parent_id = ?", "public",params[:id]],
      :order => "sort_no")
    @groupitem.attributes = params[:groupitem]
    if @childitems.blank?
    else
      if @groupitem.parent_id!=1
        @childitems.each do | child|
          child.parent_id  = 1
          child.save
        end
      end
    end

    _update @groupitem
  end

  def destroy
    @groupitem = Gw::PropGroup.find_by_id(params[:id])
    return http_error(404) if @groupitem.blank? || @groupitem.state == "delete"
    @groupitem.state = "delete"
    @groupitem.deleted_at  = Time.now
    @childitems = Gw::PropGroup.find(:all,
      :conditions => ["state = ? and parent_id = ?", "public",params[:id]],
      :order => "sort_no")
    if @childitems.blank?
    else
      @childitems.each do | child|
        child.state = "delete"
        child.deleted_at  = Time.now
        child.save
      end
    end
    _update @groupitem, :notice => "削除処理は完了しました。"
  end

  class DummyItem3
    attr_accessor  :id, :name, :parent_name, :sort_no
  end
end