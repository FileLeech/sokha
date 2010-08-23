module Sokha::Helpers
  def render_flash(flash)
    html = flash.send(:values).map do |key, value|
      content_tag(:div, value, :class => key) 
    end
    content_tag(:div, html.join, :id => 'flash') 
  end
  
  def queue_action_buttons(job = nil, options = {})
    [
      [:clear, [:done, :error]],
      [:stop, :active],
      [:dequeue, :queued],
      [:requeue, :stopped],
      [:retry, proc { |job| job.state == "error" && job.error_retry }],
      [:delete, nil],
      [:download, :done],
    ].map do |action, states|
      if action.not_in?(options[:skip] || []) && 
         (!job || !states || (states.is_a?(Proc) && states.call(job)) || 
          job.state.in?(Array(states).map(&:to_s)))
        name = job ? "#{action}-#{job.id}" : action
        tag(:input, :type => 'submit', :name => name, :value => action.to_s.capitalize)
      end
    end.compact.join
  end
end
