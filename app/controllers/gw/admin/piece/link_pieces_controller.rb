# encoding: utf-8
class Gw::Admin::Piece::LinkPiecesController < ApplicationController
  include System::Controller::Scaffold
  layout 'base'
  
  def index
    @items = Gw::EditLinkPiece.extract_location_left
  end
end
