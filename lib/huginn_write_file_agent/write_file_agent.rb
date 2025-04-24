module Agents
  class WriteFileAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The FileWriterAgent writes files to the filesystem with specified parameters.
  
      This agent can be used to generate files at specific locations with defined content,
      permissions, and ownership.
  
      `path` - The full path where the file should be written
      `content` - The content of the file to write
      `mode` - The file permissions (e.g., "0644", "0755")
      `owner` - The file owner (in "user:group" format)
      `expected_receive_period_in_days` - How many days can pass without receiving an event before this agent is considered inactive
      `debug` - Debug mode (true/false), displays additional information in logs
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "status": "success",
            "path": "/tmp/huginn_output.txt",
            "size": 15,
            "mode": "0644",
            "owner": "huginn:huginn",
            "timestamp": 1745522629
          }

    MD

    def default_options
      {
        'path' => '/tmp/huginn_output.txt',
        'content' => 'Default content',
        'mode' => '0644',
        'owner' => 'huginn:huginn',
        'expected_receive_period_in_days' => '10',
        'debug' => 'false'
      }
    end

    form_configurable :path, type: :string
    form_configurable :content, type: :text
    form_configurable :mode, type: :string
    form_configurable :owner, type: :string
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :debug, type: :boolean
    def validate_options
#      errors.add(:base, "type has invalid value: should be 'generate'") if interpolated['type'].present? && !%w(generate).include?(interpolated['type'])

      unless options['path'].present?
        errors.add(:base, "path is a required field")
      end

      unless options['mode'].present?
        errors.add(:base, "mode is a required field")
      end

      unless options['owner'].present?
        errors.add(:base, "owner is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          write_file
        end
      end
    end

    def check
      write_file
    end

    private


    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "request status : #{code}"
        log "body"
        log body
      end

    end

#    def push_model(model)
#
#      log_curl_output(response.code,response.body)
#
#    end

    def write_file
      begin
        log "Attempting to write file at #{interpolated['path']}" if boolify(interpolated['debug'])
        
        # Check if parent directory exists, create if not
        dir = File.dirname(interpolated['path'])
        unless File.directory?(dir)
          FileUtils.mkdir_p(dir)
#          log "Created parent directory: #{dir}" if boolify(interpolated['debug'])
        end
        
        # Write content to file
        File.write(interpolated['path'], interpolated['content'])
        log "File successfully written: #{interpolated['path']}" if boolify(interpolated['debug'])
        
        # Convert mode to integer (from octal string)
        mode_int = interpolated['mode'].to_i(8)
        File.chmod(mode_int, interpolated['path'])
#        log "Permissions applied: #{interpolated['mode']}" if boolify(interpolated['debug'])
        
        # Change ownership
        user, group = interpolated['owner'].split(':')
        user_id = Etc.getpwnam(user).uid
        group_id = Etc.getgrnam(group).gid
        File.chown(user_id, group_id, interpolated['path'])
#        log "Ownership changed: #{interpolated['owner']}" if boolify(interpolated['debug'])
        
        # Create output event
        create_event(payload: {
          'status' => 'success',
          'path' => interpolated['path'],
          'size' => File.size(interpolated['path']),
          'mode' => interpolated['mode'],
          'owner' => interpolated['owner'],
          'timestamp' => Time.now.to_i
        })
        
      rescue => e
        error_message = "Error writing file: #{e.message}"
#        log error_message, :error
        
        create_event(payload: {
          'status' => 'error',
          'path' => interpolated['path'],
          'error' => error_message,
          'timestamp' => Time.now.to_i
        })
      end
    end
  
    def is_positive_integer?(string)
      begin
        value = Integer(string)
        return value > 0
      rescue
        return false
      end
    end
  end
end
