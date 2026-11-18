# frozen_string_literal: true

# The UI talks to each bounded context only through <Context>::Commands.
# POST /commands/reservations/pre_reserve_desk with args[...] => Reservations::Commands.pre_reserve_desk(**args)
class CommandsController < ApplicationController
  def create
    context = CommandApi.context!(params[:context])
    command = params[:command].to_sym

    begin
      CommandApi.call(context: context.name.underscore, command: command,
                      args: params.fetch(:args, {}).permit!.to_h)
      flash[:notice] = "#{context}::Commands.#{command} ✓ — downstream contexts catch up asynchronously"
    rescue StandardError => e
      flash[:alert] = "#{context}::Commands.#{command} failed — #{e.class}: #{e.message}"
    end

    redirect_to params[:return_to].presence || root_path(live: params[:live].presence, anchor: params[:context])
  end
end
