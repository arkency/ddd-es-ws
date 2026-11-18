# frozen_string_literal: true

# The only way the UI reaches a bounded context: <Context>::Commands.public_send(command, **args).
# Shared by CommandsController and the scenario runner, so a scenario step is exactly what a
# button on the dashboard does -- nothing more.
module CommandApi
  extend self

  def contexts = ContextMap::CONTEXTS.select { |context| context.const_defined?(:Commands, false) }

  def context!(name)
    contexts.find { |context| context.name.underscore == name.to_s } ||
      raise(ActionController::RoutingError, "no UI entry point for context #{name}")
  end

  def commands_for(context) = context::Commands.public_instance_methods(false)

  def call(context:, command:, args:)
    bounded_context = context!(context)
    name = command.to_sym
    unless commands_for(bounded_context).include?(name)
      raise ActionController::RoutingError, "unknown command #{bounded_context}::Commands.#{name}"
    end

    bounded_context::Commands.public_send(name, **args.symbolize_keys)
  end
end
