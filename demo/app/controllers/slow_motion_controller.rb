# frozen_string_literal: true

class SlowMotionController < ApplicationController
  def update
    seconds = Integer(params.require(:seconds))
    SlowMotion.seconds = seconds if SlowMotion::CHOICES.include?(seconds)
    redirect_back fallback_location: root_path
  end
end
