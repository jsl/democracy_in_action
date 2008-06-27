module DemocracyInAction

  # There are a lot of functions that take the same variable names..
  # Here is a description of common arguments
  #   table - SQL table name (String)
  #   options - SQL options (Hash) (ex. {"limit" => 4} )
  #       (sometimes it takes one value with assumed name,
  #        read individual functions for more info)
  #   data - SQL column names/values to insert (Hash)
  #           (ex.  {'key' => key, 'First_Name' => name } )
  #   criteria - SQL column names/values for WHERE clause (HASH)
  #         (ex. {'Email' => email} mean "WHERE Email == email" )
  # More details on individual functions
  #
  # API notes:  there are some bug(?) in the DIA side...
  #   1. only characters accepted in where clause [0-9a-zA-Z_ .'"<>!=%+&@-]
  #      therefore, don't put others (like ,) in names or you can't search
  #   2. you cannot search the supporter_groups links by groups_KEY
  #   3. you can link supporters to invalid group keys (and visa versa)
  #   4. when you delete a group, the links in supporter_groups are not erased
  #      (but if you delete a suporter, they are)
  #      i think this discrepancy has to do with (2)
  
  class API
    #include DemocracyInAction::Util
    class InvalidKey < ArgumentError #:nodoc:
    end
    class InvalidData < ArgumentError #:nodoc:
    end
    class NoTableSpecified < ArgumentError #:nodoc:
    end
    class ConnectionInvalid < ArgumentError #:nodoc:
    end

    NODES = { 
      :sandbox => {
        :authenticate   => 'https://sandbox.democracyinaction.org/api/authenticate.sjs',
        :get            => 'http://salsa.democracyinaction.org/dia/api/get.jsp',
        :process        => 'http://salsa.democracyinaction.org/dia/api/process.jsp',
        :delete         => 'http://salsa.democracyinaction.org/dia/deleteEntry.jsp'
        },
      :salsa => { 
        :authenticate   => 'https://salsa.democracyinaction.org/api/authenticate.sjs',
        :get            => 'http://salsa.democracyinaction.org/dia/api/get.jsp',
        :process        => 'http://salsa.democracyinaction.org/dia/api/process.jsp',
        :delete         => 'http://salsa.democracyinaction.org/dia/deleteEntry.jsp'
        },
      :wiredforchange => { 
        :get     => 'http://salsa.wiredforchange.com/dia/api/get.jsp',
        :process => 'http://salsa.wiredforchange.com/dia/api/process.jsp',
        :delete  => 'http://salsa.wiredforchange.com/dia/deleteEntry.jsp'
        },
      :org2 => { 
        :get     => 'http://org2.democracyinaction.org/dia/api/get.jsp',
        :process => 'http://org2.democracyinaction.org/dia/api/process.jsp',
        :delete  => 'http://org2.democracyinaction.org/dia/api/delete.jsp'
        }
      }

    attr_reader :username, :password, :orgkey, :node
    attr_reader :urls

    # Requires an options hash containing:
    #
    # :username, :password, :orgkey, and :node
    #   
    # You can omit :node if you specify a custom service node with a :urls hash.
    #
    # If a :urls hash is used, it should have the form:
    #   :urls => { :get => "get_url", :process => "process_url", :delete => "delete_url" }
    def initialize(options = {})
      unless options && options[:username] && options[:password] && options[:orgkey] && ( options[:node] || options[:urls] ) || self.class.disabled?
        raise ConnectionInvalid.new("Must specify :username, :password, :orgkey, and ( :node or :url )")
      end 

      @username, @password, @orgkey, @node = options.delete(:username), options.delete(:password), options.delete(:orgkey), options.delete(:node)

      @urls = options[:urls] || NODES[@node]
      raise ConnectionInvalid.new("Requested node is not supported.  Use (#{NODES.keys.join(', ')}) or specify a custom array in :urls") unless @urls
      raise ConnectionInvalid.new("Urls must be a hash") unless @urls.is_a?(Hash)
      raise ConnectionInvalid.new("Urls must include at least :get, :process, and :delete") unless @urls[:get] and @urls[:process] and @urls[:delete]
    end

  # confirms that the API is enabled and the Democracy in Action service node is reachable
  # returns a boolean
    def connected?
      begin
        API.disabled? || !(@username && @password && @orgkey && @node && get( :table => 'supporter', 'desc' => 1 )).nil?
      rescue SocketError #means the library cannot reach the DIA server at all, or no internet is available
        false
      end
    end

    # Prevent the API from contacting any Democracy In Action node.  Used for development and testing purposes.
    def self.disable!
      @@disabled = true
    end

    # Determine whether the API is allowed to contact remote nodes.
    def self.disabled?
      @@disabled ||= false
    end

    def authenticate
      response = authentication_request
      if !authentication_failed?(response) && response['set-cookie']
        response['set-cookie'].each { |c| cookies.push(c.split(';')[0]) }
        @authenticated = true
      else
        @authenticated = false
#        raise ConnectionInvalid if authentication_failed?(response)
      end
    end

    def authentication_request
      url = URI.parse(@urls[:authenticate])
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      https.post(url.path, "email=#{username}&password=#{password}")
    end

    def authentication_failed?(response)
      response['location'] =~ /login/ 
    end

    def authenticated?
      @authenticated
    end

    # i imagine this will get refactored into the new version of send_request, and that authenticate will use that
    def make_https_request(url)
      url = URI.parse(url)
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = https.get(url.request_uri, 'Cookie' => cookies.join(';')) #can also use Net::HTTP::Get
    end



    # gets an "XML" document with the table info
    # if options['count'], returns integer (number of matches)
    # if options['desc'], returns TableDesc instance
    # else, returns Array of Hashes, each Hash is one database row 
    #
    # options - Hash keys: 'key', 'column', 'order', 'limit', 'where', 'desc' 
    #
    #           String:  same as { 'key' => String }
    def get(options = {})
      body = send_request(@urls[:get], options_for_get(options))
      parse_records( body ) unless has_error?( body )
    end

    # options - Hash keys: 'key', 'debug' <br>
    #
    #           String: same as { 'key' => String }
    # TODO: document link option???
    def process(options = nil)
      send_request(@urls[:process], options.merge(key_param(options))).strip
    end

  #create a new record
  def post( options = {})
    process( options ) 
  end

  #update an existing record
  def put( options = {} )
    required_keys = [ :key, 'key', options[:table] + '_KEY', ( options[:table] + '_KEY').to_sym ]
    required_keys += [ 'Email', :Email ] if options[:table] == 'supporter' || options[:table] == :supporter
    raise InvalidKey.new( "You must specify :key, :Email, or #{options[:table]}_KEY to update a record" ) unless options.any? { |optkey, value| required_keys.include?(optkey) }
    process( options ) 
  end

    # delete code
    # returns true if it works, false otherwise
    # takes an hash like {'key' => key}
    # haven't found other options to work
    #
    # criteria - any value column/values pair on the table (as Hash) 
    # 
    #            if String, same as { 'key' => String }
    def delete(criteria)
      #table = criteria.delete('table') || criteria.delete(:table)
      options = key_param(criteria)
      #indicate that xml is the desired response
      options[:xml] = true

      body = send_request(@urls[:delete], criteria)
    
      # if it contains '<success', it worked, otherwise a failure
      if body.include?('<success')
        return true
      else
        puts body if $DEBUG
        return false
      end
    end

    # Return a description of the columns for a given table
    # the response is a Hash of Result objects, with field names as keys 
    # the fields are described with the keys :field, :type, :null, :key, :default, and :extra
    # not all keys are specified for all fields
    # 
    # Requires a :table
    def columns(options = {}) #:nodoc:
      body = send_request @urls[:get], options_for_get(options)
      parse_description( body ) unless has_error?(body)
    end
    alias :describe :columns

    # Returns an integer for the number of records specified.
    #
    # Requires a :table and allows a :where to restrict the result set.
    def count(options = {})
      #get(options.merge('count' => true, 'limit' => 1))
      options[:limit] = 1
      xml = send_request(@urls[:get], options_for_get(options))
      parse(xml).count unless has_error?(xml)
    end
    

    ###################### INTERNAL CODE ###################

    #protected
    private

    def has_error?(xml)
      xml =~ /<error>Invalid login/
    end

    def parse(xml, listener_class = DIA_Get_Listener )
      listener = listener_class.new
      parser = REXML::Parsers::StreamParser.new(xml, listener)
      parser.parse
      listener
    end

    def parse_records(xml)
      parse(xml).items.map {|item| Result.new(item)}
    end

    def parse_description(xml)
      parse( xml, DIA_Desc_Listener ).result
    end
    def method_missing(*args) #:nodoc:
      table_name = args.first
      
      if Tables.list.include?(table_name)
        return TableProxy.new(self, table_name)
      end
      super *args
    end

    # encodes values for transmission in a POST
    # copied from private function in Net::HTTP
    def urlencode(str)
      str.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end

    def key_param( options = {} )
      return { :key => options } if options && !options.is_a?(Hash)
      
      key_type = options[:key] ? :key : 'key'
      return {} unless key_value = options[key_type]
      key_value = key_value.join(', ') if key_value.is_a?(Array)
      { key_type => key_value }
    end

    def options_for_get(options={})
      return {} unless options
      options.merge( key_param(options)).merge where_param( options )
    end

    def where_param( options = {} )
      conditions = options.delete(:where) || options.delete('where')
      return options unless conditions
      return options.merge(:where => conditions) unless conditions.is_a?(Hash)
      { :where => conditions.inject( [] ) { |memo, (column, value)| memo << "#{column} = '#{value.gsub(/[']/, '\\\\\'')}'" }.join( ' AND ') }
    end

    # links are sent in a Hash.
    # every key is a table name
    # value is either key in that table, or Array of keys in that table
    # return an Array of values that can be added to a query string
    def link_hash_param(links={})
      return [] unless links
      raise InvalidData.new("Links should be a hash of the form :link => ( {table => key } or { table => [ key1, key2 ] } )") unless links.is_a?(Hash)

      links.inject([]) do |memo, (table, record_key)|
        record_key = [ record_key ] unless record_key.is_a?( Array )
        memo << record_key.map{ |k| "link=#{table}&linkKey=#{k}" }
      end.flatten
    end

    # helper function for send_request to handle multiple entries
    # with same key name
    def build_body(options)
      # in order to handle multiple links, keys...
      # if an option has an Array as value, append each array element
      # as "<key>=<array element>&"
      initial_memo = link_hash_param(options.delete(:link))
      return initial_memo.join('&') if options.empty?
      options.inject(initial_memo) do |memo, (key, value)|
        value = [ value ] unless value.is_a?( Array )
        memo << value.map { |v| "#{urlencode(key.to_s)}=#{urlencode(v.to_s)}" }
      end.join('&')
    end

    def build_request(url, options) #:nodoc:
      # make a HTTP post and set the cookies
      request = Net::HTTP::Post.new(url.path)
      cookies.each { |c| request.add_field('Cookie', c) }
      
      # import authentication information
      options['organization_KEY'] = @orgkey if (@orgkey)
      if (@username && @password)
        options['user'] = @username
        options['password'] = @password
      end

      #indicate that xml is the desired response
      options['xml'] = true

      #format request body
      request.body = build_body(options)
      request.set_content_type('application/x-www-form-urlencoded')
      request

    end

    # specialized code to handle multiple form entries with same key name
    # also does some error handling
    def send_request(base_url, options)
      raise NoTableSpecified.new("You must either include :table in the options hash or use the proxy methods API#[tablename].get") unless options[:table]
      return '' if API.disabled?

      url = URI.parse(base_url) 
      request = build_request(url, options)
      puts request.body if $DEBUG

      # get result
      response = resolve( Net::HTTP.new(url.host, url.port).start { |http| http.request(request) } )

      return response.body
    end

    # stores returned cookies to the api and checks for error conditions
    def resolve( response )
      # error handling
      #  you see java.lang.Exception if there was an error
      return ( response.error! and response ) unless response.is_a?( Net::HTTPSuccess )

      # Good, now grab any cookies we can
      if response.get_fields('Set-Cookie')
        response.get_fields('Set-Cookie').each { |c| cookies.push(c.split(';')[0]) }
      end
      response
    end

    # returns any cookies received back from the DIA service
    def cookies
      @cookies ||= []
    end

    def authenticated_response?(response)
      response['set-cookie'].nil? || (response['set-cookie'] =~ /JSESSIONID=/).nil?
    end

    def unauthenticated_response?(response)
      !authenticated_response?(response)
    end

    class InvalidKey < ArgumentError; end
  end

  # This class acts as a placeholder for DIA tables.  It automatically includes
  # :table => [table_name] in the options hash that is passed along to the API.
  #
  # All methods not listed in TABLE_PROXY_METHODS are passed along to the API with their original arguments.
  class TableProxy #:nodoc:
    TABLE_PROXY_METHODS = [:get, :process, :delete, :columns, :describe, :count, :put, :post ]
    TABLE_PROXY_METHODS.each { |method| undef_method( method ) if instance_methods.include?( method.to_s ) }

    def initialize(api, table_name)
      @api = api
      @table_name = table_name
    end

    private

    def method_missing(*args)
      start_args = args.dup
      method_name = args.shift
      if TABLE_PROXY_METHODS.include?(method_name)
        options = args.shift || {}
        return @api.send(method_name, options.merge( :table => @table_name.to_s ) )
      end
      @api.send(method_name, *args)
    end
  end
end
