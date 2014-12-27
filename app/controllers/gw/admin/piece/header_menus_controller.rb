# coding: utf-8
class Gw::Admin::Piece::HeaderMenusController < ApplicationController
  include System::Controller::Scaffold
  layout 'base'
  
  # ヘッダーメニュー表示action
  def index
    @items = Rumi::PieceApi.header_menus(URI.parse(root_url), Site.user.code, Site.user.password)
  end
end
