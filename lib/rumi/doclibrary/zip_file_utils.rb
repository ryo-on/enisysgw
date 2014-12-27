# coding: utf-8

require 'rubygems'
require 'kconv'
require 'zipruby'
require 'fileutils'

# === ファイル管理用zipファイル作成モジュール
# 本モジュールは、ファイル管理用zipファイル作成モジュールである。
# 添付ファイル一括ダウンロード機能のzipファイルを作成する。
module  Rumi::Doclibrary::ZipFileUtils
  # 一時ファイル格納フォルダパス
  TMP_FILE_PATH = Dir.tmpdir
  
  # zipファイルの文字エンコード
  ZIP_ENCODING = 'Shift_JIS'
  
  # === 一括ダウンロードファイル作成用メソッド
  #  本メソッドは、ファイル一括ダウンロード用のzipファイルを作成するメソッドである。
  #  引数filenameのファイルが既に存在している場合は、ファイルを削除してから新規にzipファイルを作成する。
  #  zipファイルに保存する添付ファイルが見つからなかった場合、パス名が長い場合は
  #  zipファイルの作成をキャンセルして例外を発生させる、
  # ==== 引数
  #  * filename: zipファイルのフルパス
  #  * zip_data: zipファイル情報ハッシュ
  #      データ形式
  #      {
  #        {zipファイル内でのフォルダやファイルのパス1, 添付ファイルへのフルパス1},
  #        {zipファイル内でのフォルダやファイルのパス2, 添付ファイルへのフルパス2},
  #          ：
  #        {zipファイル内でのフォルダやファイルのパスN, 添付ファイルへのフルパスN},
  #      }
  #      ※zipファイルにフォルダのみを作成する場合は、「添付ファイルへのフルパス」を空文字('')にする。
  #  * options: オプション
  #      -- fs_encoding 文字エンコード
  #                     指定がない場合、文字コード変換を行わない。
  # ==== 戻り値
  #  なし
  def self.zip(filename, zip_data, options = {})
    # zipファイル情報ハッシュが空の場合は終了
    return if zip_data.blank?
    
    begin
      # 既存ファイルの削除
      File.unlink(filename) if File.exist?(filename)
      
      Zip::Archive.open(filename, Zip::CREATE) {|zf|
        zip_data.each {|entry_name, src|
          # フォルダ・ファイル名の長さチェック
          if entry_name.bytesize >
              Enisys.config.application['sys.max_file_name_length']
            raise Errno::ENAMETOOLONG
          end          
          
          if src.blank?
            # zipファイルへフォルダのみ作成
            zf.add_dir(encode_path(entry_name, options[:fs_encoding]))
          else
            # 添付ファイルの存在チェック
            raise Errno::ENOENT unless File.exist?(src)
            
            # zipファイルへフォルダと添付ファイルを作成
            zf.add_file(encode_path(entry_name, options[:fs_encoding]), src)
          end
        }
      }
    rescue Errno::ENOENT
      raise I18n.t('rumi.doclibrary.message.attached_file_not_found')
    rescue Errno::ENAMETOOLONG
      raise I18n.t('rumi.doclibrary.message.file_name_too_long')
    rescue
      raise I18n.t('rumi.doclibrary.message.cannot_create_zip_file')
    end
  end

private
  # === 文字エンコード用メソッド
  #  本メソッドは、文字エンコードするメソッドである。
  # ==== 引数
  #  * path: 文字エンコード対象文字列
  #  * encode_s: 文字エンコード文字列
  # ==== 戻り値
  #  文字エンコード後の文字列を戻す
  def self.encode_path(path, encode_s)
    return path if encode_s.nil?()
    case(encode_s)
    when('UTF-8')
      return path.toutf8()
    when('Shift_JIS')
      return path.tosjis()
    when('EUC-JP')
      return path.toeuc()
    else
      return path
    end
  end
end