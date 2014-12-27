# coding: utf-8
class Gw::Reminder < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  attr_accessible :user_id, :category, :sub_category, :title_id, :item_id,
    :title, :datetime, :url, :action, :seen_at, :expiration_datetime

  # === デフォルトのスコープを未読の新着情報のみとする。
  #  Gw::Reminder.allとした場合でも既読の新着情報は無視される。
  default_scope { where(seen_at: nil) }

  # === 既読した新着情報に抽出するためのスコープ
  #
  # ==== 引数
  #  * item_id: レコードID
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_seen, lambda { |item_id, user_id|
    # Usage: Gw::Reminder.unscoped.extract_seen
    where("seen_at is not null").where(item_id: item_id).extract_user_id(user_id).order(:seen_at)
  }

  # === カテゴリ別に抽出するためのスコープ
  #
  # ==== 引数
  #  * category: 機能を表すString
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_category, lambda { |category|
    where(category: category)
  }

  # === ユーザーID別に抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_user_id, lambda { |user_id|
    where(user_id: user_id)
  }

  # === 並び替えのためのスコープ
  #
  # ==== 引数
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  並び替え結果(ActiveRecord::Relation)
  scope :rumi_order, lambda { |sort_key = "datetime", order = "desc"|
    order("#{sort_key} #{order}")
  }

  # === 機能：スケジュール(予約種別：通常)を抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_schedule, lambda { |user_id, sort_key, order|
    extract_category("schedule").extract_user_id(user_id).rumi_order(sort_key, order)
  }

  # === 機能：スケジュール(予約種別：施設)を抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_schedule_prop, lambda { |user_id, sort_key, order|
    extract_category("schedule_prop").extract_user_id(user_id).rumi_order(sort_key, order)
  }

  # === 機能：スケジュール(予約種別：通常と施設)を抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_schedule_like_category, where("category like ?", "schedule%")

  # === 機能：スケジュール(予約種別：通常と施設)を抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_schedule_like, lambda { |user_id, sort_key, order|
    extract_schedule_like_category.extract_user_id(user_id).rumi_order(sort_key, order)
  }

  # === 機能：掲示板を抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_bbs, lambda { |user_id, sort_key, order|
    extract_category("bbs").extract_public_bbs
                           .extract_show_bbs
                           .extract_readable_bbs(user_id)
                           .extract_open_doc
                           .rumi_order(sort_key, order)
  }

  # === 機能：掲示板において公開中掲示板内の記事を抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_public_bbs, lambda {
    controls = Gwbbs::Control.where("state = ?", "public")
    where("title_id IN (?)", controls.map(&:id))
  }

  # === 機能：掲示板においてタイトル一覧表示中掲示板内の記事を抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_show_bbs, lambda {
    controls = Gwbbs::Control.where("view_hide = ?", true)
    where("title_id IN (?)", controls.map(&:id))
  }

  # === 機能：掲示板において記事の閲覧権限を持つもののみ抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_readable_bbs, lambda { |user_id|
    user = System::User.find(user_id)
    # 各掲示板の閲覧権限が設定されているか確認
    controls = Gwbbs::Control.all.to_a
    controls.select! do |control|
      group_ids = []
      user_ids = []
      control.role.each do |role|
        group_ids << role.group_id
        user_ids << role.user_id
      end
      group_ids = group_ids.flatten.compact.uniq
      user_ids = user_ids.flatten.compact.uniq
      user_group_ids = user.groups.map(&:id).uniq

      # 制限なし(0) もしくは ユーザーID、所属が閲覧、編集、管理権限に設定されているか確認
      group_ids.include?(0) || user_ids.include?(user_id) ||
        user_group_ids != (user_group_ids - group_ids)
    end

    # 今現在、権限があるか絞り込む
    where("title_id in (?)", controls.map(&:id)).extract_user_id(user_id)
  }

  # === 機能：掲示板において公開期日内の記事を抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_open_doc, lambda {
    current_time = DateTime.now
    # 公開開始日 <= 現在時刻 <= 公開期日
    where("datetime <= ?", current_time).where("expiration_datetime >= ?", current_time)
  }

  # === 機能：ファイル管理を抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_doclibrary, lambda { |user_id, sort_key, order|
    extract_category('doclibrary').extract_user_id(user_id).rumi_order(sort_key, order)
  }

  # === 機能：ファイル管理において承認依頼のものを抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_request, lambda {
    # 操作名が'request'のものを抽出
    where(action: 'request')
  }

  # === 機能：回覧板を抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: ユーザーID
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_gwcircular, lambda { |user_id, sort_key, order|
    extract_category('circular').extract_user_id(user_id).rumi_order(sort_key, order)
  }

  # === 既読にするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  保存結果(boolean)
  def seen
    update_attribute(:seen_at, DateTime.now)
  end

  class << self

    # === 新着情報の表示フォーマット変換メソッド
    #
    # ==== 引数
    #  * relation: ActiveRecord::Relation
    # ==== 戻り値
    #  Hash
    def to_rumi_format(relation)
      total_count = relation.count
      return nil if total_count.zero?
      return {
        total_count: total_count,
        factors: relation.limit(20).to_a
      }
    end

  end

end
