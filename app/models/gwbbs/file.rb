# -*- encoding: utf-8 -*-
class Gwbbs::File < Gwboard::CommonDb
  include System::Model::Base
  include System::Model::Base::Content
  include Cms::Model::Base::Content
  include Gwbbs::Model::Systemname
  include Gwboard::Model::AttachFile
  include Gwboard::Model::AttachesFile

  belongs_to :parent, :foreign_key => :parent_id, :class_name => 'Gwbbs::Doc'

  before_create :before_create
  after_create :after_create
  after_destroy :after_destroy
  validates_presence_of :filename, :message => "ファイルが指定されていません。"

  def search(params)
    params.each do |n, v|
      next if v.to_s == ''
      case n
      when 'kwd'
        and_keywords v, :filename
      #作成者を検索条件に追加
      when 'creater'
        search_creator(params)
      #公開日を検索条件に追加
      when 'startdate'
        self.and :able_date, '>=', v+" 00:00:00"
      when 'enddate'
        self.and :able_date, '<=', v+" 23:59:59"
      end
    end if params.size != 0

    return self
  end

  # === 作成者検索の条件追加用メソッド
  #  作成者検索の条件を追加するメソッドである。
  # 　掲示板の作成者名と作成者所属名から検索を行い、入力値と部分一致する掲示板を抽出する。
  # ==== 引数
  #  * params: アクションパラメータ
  # ==== 戻り値
  #  作成者検索条件のConditionオブジェクトを戻す
  def search_creator(params)
    params.each do |n, v|
      next if v.to_s == ''
      case n
      #作成者を検索条件に追加
      when 'creater'
        cond = Condition.new
        quote_string = connection.quote_string(v).gsub(/([_%])/, '\\\\\1')
        cond.and do |c|
          # == 作成者名での部分一致検索条件 ==
          c.or :creater, 'LIKE', "%#{quote_string}%"

          # == 所属名での部分一致検索条件 ==
          # 所属名で部分一致するSystem::Groupを取得
          groups = System::Group.where("name LIKE '%#{quote_string}%'")

          # 所属コード配列を取得
          # ※Gwbbs::Doc.createrdivision_idには所属コードが登録されているので
          # 　検索条件には所属コードを使用する
          group_codes = groups.map(&:code)
          c.or :createrdivision_id, group_codes
        end

        self.and cond
      end
    end if params.size != 0

    return self
  end

  def item_path
    return "/gwbbs/docs?title_id=#{self.title_id}&p_id=#{self.parent_id}"
  end

  def edit_memo_path(title,item)
    return "/gwbbs/docs/#{self.parent_id}/edit_file_memo/#{self.id}?title_id=#{self.title_id}"
  end

  def item_parent_path
    return "/gwbbs/docs/#{self.parent_id}?title_id=#{self.title_id}&cat=#{self.parent.category1_id}"
  end

  def item_doc_path(title,item)
    return "/gwbbs/docs/#{self.parent_id}?title_id=#{self.title_id}"
  end

  def delete_path
    return "/gwbbs/docs/#{self.id}/delete?title_id=#{self.title_id}&p_id=#{self.parent_id}"
  end

end
