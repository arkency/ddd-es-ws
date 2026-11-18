# frozen_string_literal: true

module ApplicationHelper
  def money(cents) = cents ? format("%.2f PLN", cents / 100.0) : "—"

  def short(id) = id.to_s.first(8)

  # The one action ProcessGuide says comes next in the demo flow.
  def next_step
    return @next_step if defined?(@next_step)

    @next_step = ProcessGuide.next_step
  end

  # One form = one command of one bounded context. Fields must be named args[...].
  # The first form matching the next step gets the highlight.
  def command_form(context, command, label, inline: false, next_args: {}, &fields)
    classes = ["cmd"]
    classes << "inline" if inline
    classes << "is-next" if highlight_next_form?(context, command, next_args)
    form_with(url: command_path(context, command), method: :post, class: classes.join(" ")) do
      safe_join([
        hidden_field_tag(:live, params[:live]),
        fields ? capture(&fields) : "".html_safe,
        submit_tag(label),
      ])
    end
  end

  # A command alone is ambiguous (every desk row has a "Set hours" form): the step's
  # args must also match the row's args.
  def highlight_next_form?(context, command, next_args)
    return false if @next_form_highlighted

    step = next_step
    return false unless step && step.context == context.to_s && step.command == command.to_s

    args = next_args.to_h.stringify_keys
    return false unless step.args.all? { |name, value| args[name.to_s].to_s == value.to_s }

    @next_form_highlighted = true
  end

  def arg(name, value = nil, **options) = text_field_tag("args[#{name}]", value, id: nil, placeholder: name.to_s.humanize, **options)

  def arg_number(name, value = nil, **options) = number_field_tag("args[#{name}]", value, id: nil, placeholder: name.to_s.humanize, **options)

  def arg_hidden(name, value) = hidden_field_tag("args[#{name}]", value, id: nil)

  # Empty choices render a visible hint instead of a blank, collapsed select.
  def arg_select(name, choices, empty: "nothing to choose yet")
    options = choices.empty? ? content_tag(:option, "— #{empty} —", value: "", disabled: true, selected: true) : options_for_select(choices)
    select_tag("args[#{name}]", options, id: nil)
  end

  # Role badges of a context, read straight from config/context_map.rb.
  def context_roles(name)
    up = ContextMap::EDGES.select { |edge| edge.upstream == name }
    down = ContextMap::EDGES.select { |edge| edge.downstream == name }
    badges =
      down.map { |edge| tag.span("#{edge.downstream_role} of #{edge.upstream}", class: "badge down #{edge.downstream_role.downcase}", title: edge.transport) } +
      up.map { |edge| tag.span("#{edge.upstream_role} for #{edge.downstream}", class: "badge up", title: edge.transport) }
    safe_join(badges, " ")
  end

  def panel(name, title: name.titleize, &body)
    is_next = next_step&.panel == name.underscore
    heading = safe_join([title, " ", context_roles(name), (tag.span("next", class: "badge next") if is_next)].compact)
    tag.section(id: name.underscore, class: "panel#{' is-next' if is_next}") do
      safe_join([tag.h2 { heading }, capture(&body)])
    end
  end

  # One role word for a context, as it appears on the map (ACL / Conformist / OHS[ /PL]).
  def context_kind(name)
    context = name.to_s.camelize.safe_constantize
    downstream = ContextMap::EDGES.find { |edge| edge.downstream == context }&.downstream_role
    upstream = ContextMap::EDGES.find { |edge| edge.upstream == context }&.upstream_role
    downstream || upstream
  end

  def scenario_event_public?(type) = type.split("::")[1] == "Public"
  def scenario_event_name(type) = type.split("::").last

  # Long ids read better shortened; everything else is shown as the scenario wrote it.
  def scenario_arg_value(value) = value.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/) ? short(value) : value
end
