# frozen_string_literal: true

# structured input for new ConfluenceTask objects
class Query
  attr_reader :runner, :method, :uri
  def initialize(method:, uri:, payload: nil, headers: {})
    @method = method
    @uri = uri
    @payload = payload
    @headers = process_headers(headers)
    @runner = query_runner
    log_status
  end

  def process_headers(headers)
    headers[:limit] = Maybe(headers[:limit]).or_else(config['default_page_limit']).to_s
    headers[:accept] = Maybe(headers[:accept]).or_else('application/json')
    headers
  end

  def log_status
    File.open(path(config['log_file']), 'a') do |f|
      f.puts erb('query-log', binding)
    end
  end

  def query_runner
    query = api_query
    lambda do |conn|
      response = query.call(conn)
      puts "TASK INFO: [#{@method}] request to '#{@uri}' returned #{response.status} response code."
      Response.new(response.status, response.headers, response.body)
    end
  end

  def api_query
    {
      get: construct_get_request,
      delete: construct_delete_request,
      post: construct_post_request,
      put: construct_put_request
    }[@method]
  end

  def construct_get_request
    @headers[:expand] = ConfluenceUtil.parse_expand_attributes(@headers[:expand])
    ->(conn) { conn.get(@uri, @headers) }
  end

  def construct_delete_request
    ->(conn) { conn.delete(@uri, @headers) }
  end

  def construct_post_request
    @headers[:content_type] = 'application/json'
    @payload = @payload.to_json
    ->(conn) { conn.post(@uri, @payload, @headers) }
  end

  def construct_put_request
    @headers[:content_type] = 'application/json'
    ->(conn) { conn.put(@uri, @payload, @headers) }
  end

  def to_s
    puts "method: #{@method}"
    puts "uri: #{@uri}"
    puts "payload: #{@payload}"
    puts "headers: #{@headers}"
    puts "query: #{@query}"
  end
end
