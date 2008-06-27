module DemocracyInAction

  # = Direct usage
  # Once you have initialized your API, you can send a direct request to the service:
  #   @api.request :save, { :object => 'supporter', :Email => 'jones@example.org' } 
  # This method will ping any url that the API was initialized with, and append the options hash directly to the query string.
  # 
  # Most actions can be accomplished via the REST methods ( get, post, put, and delete ).  
  #   @api.get    :object => 'groups', :condition => { :Group_Name => 'Peaceful Warriors' }
  #   @api.post   :object => 'graups', :Group_Name => 'Grannies Against the Surge'
  #   @api.put    :object => 'groups', :Group_Name => 'Grannies Against McSame', :key => 234 # requires a key
  #   @api.delete :object => 'groups', :key => 234
  #
  # To retrieve a count of records, use the :count method:
  #   @api.count :object => 'graups, :condition => "Group Name LIKE '%Grannies%'"
  #
  # To save a record that may or may not already exist, use :post or :save
  #   @api.save   :object => 'supporter', :Email => 'jesus@example.org', :First_Name => 'Jesus', :Last_Name => 'Murphy'
  #
  # All actions called with this direct usage syntax *require* an :object to be specified in the options hash.
  #
  # This syntax does not permit single integer arguments for keys, only { :key => value } 
  #
  # = Object syntax
  # Because every API request requires an object type, 
  # the API provides you with a set of object methods to improve the readablity of your code.  
  # The examples above could be written:
  #
  #   @api.groups.get    :condition => { :Group_Name => 'Peaceful Warriors' }
  #   #  => [ DIA::Result ]
  #   @api.groups.post   :Group_Name => 'Grannies Against the Surge'
  #   #  => 234
  #   @api.groups.put    :key => 234, :Group_Name => 'Grannies Against McSame'
  #   #  => 234
  #   @api.groups.count :condition => "Group Name LIKE '%Grannies%'"
  #   #  => 1
  #   @api.groups.delete :key => 234
  #   #  => true
  #   @api.supporter.save :Email => 'jesus@example.org', :First_Name => 'Jesus', :Last_Name => 'Murphy'
  #   #  => 76543
  #
  # == Retrieving data
  # Restrict the number of desired results using the :limit option
  #
  #   @api.groups.get    :condition => 'Group_Name LIKE '%Peaceful%', :limit => 5
  #   # => [ DIA::Result ]
  #
  # Retrieve only one record with the first method. 
  #
  #   @api.groups.first  :condition => 'Group_Name LIKE '%Peaceful%'
  #   #  => DIA::Result ( first returns a single result rather than an array of results )
  #
  # Sort your results with the :orderBy option.
  #   @api.groups.first  :condition => 'Group_Name LIKE '%Peaceful%', :orderBy => 'Date_Created DESC'
  #   #  => DIA::Result (the most recent group)
  #
  # For readability, you may prefer to call get with the all alias.
  #
  #   @api.groups.all     :condition => { :Group_Name => 'Peaceful Warriors' }
  #   # => [ DIA::Result ]
  #
  # If you already have the key(s) of the results you want, you can pass those to get directly:
  #
  #   @api.groups.get(234)
  #   # => DIA::Result
  #   @api.groups.get(234, 235, 236, 237)
  #   # => [ DIA::Result, DIA::Result, DIA::Result, DIA::Result ]
  #
  # == Creating new records
  # All options passed to post or save will attempt to match a field on the object.  Matching options will be saved to the service.
  #   @api.event.post   :Event_Name => 'Mango Street Block Party', :City => 'New York', :State => 'NY'
  #   #  => 334455
  #   @api.event.save   :Event_Name => 'Papaya Way Block Party'
  #   #  => 334456
  #
  # == Linking records
  # It is possible to link records together by passing a :link option to put, post, or save.
  #   @api.supporter.post   :Email => 'dropkick@example.com', :link => { :event => 334455 }
  #   #  => 76544  This supporter is attending Mango Street Block Party
  # Multiple Records can be linked with a single request.
  #   @api.supporter.put   :key => 76544 , :link => { :event => 334455, :group => [ 234, 235 ] }
  #   #  => 76544  This supporter is attending Mango Street Block Party, and is a member of Grannies Against McSame and another group
  #
  # == Updating records
  # Passing a key or email identifier in your save, put, or post request tells the service to update the existing record.
  #   @api.supporter.put   :key => 76544 , :City => 'Albany', :State => 'NY'
  #   #  => 76544  
  #
  # == Deleting records
  # Delete returns true or nil if the delete operation fails.  A numeric key is the only valid option for delete.
  #   @api.groups.delete :key => 234
  #   # => true
  #   @api.groups.delete(234)
  #   # => nil  ( record not found, we deleted it in the previous example )
  #
  # == Restrictions
  # 1. Only these characters are accepted in the :condition clause 
  #      [0-9a-zA-Z_ .'"<>!=%+&@-]
  #    Putting other characters in names ( like , ) make searching by name not work.
  # 2. Cannot search the supporter_groups links by groups_KEY.
  # 3. DIA does not validate link ids.  You can link supporters to invalid group keys (and vice versa).  You are responsible for your data integrity
  # 4. When deleting a group, the linked records in supporter_groups are not erased (but when deleting supporter, they are)
  
  class API
    class InvalidKey < ArgumentError #:nodoc:
    end
    class InvalidData < ArgumentError #:nodoc:
    end
    class InvalidUrl < ArgumentError #:nodoc:
    end
    class NoTableSpecified < ArgumentError #:nodoc:
    end
    class ConnectionInvalid < ArgumentError #:nodoc:
    end

    # A list of known DIA nodes and their associated urls
    NODES = { 
      :sandbox => {
        :authenticate   => 'https://sandbox.democracyinaction.org/api/authenticate.sjs',
        :get            => 'https://sandbox.democracyinaction.org/api/get',
        :save           => 'https://sandbox.democracyinaction.org/api/save',
        :delete     => 'https://sandbox.democracyinaction.org/api/delete',
        :count      => 'https://sandbox.democracyinaction.org/getCount.sjs',
        },
      :salsa => { 
        :authenticate   => 'https://salsa.democracyinaction.org/api/authenticate.sjs',
        :get            => 'http://salsa.democracyinaction.org/dia/api/get.jsp',
        :save        => 'http://salsa.democracyinaction.org/dia/api/process.jsp',
        :delete         => 'http://salsa.democracyinaction.org/dia/deleteEntry.jsp'
        },
      :wiredforchange => { 
        :get     => 'http://salsa.wiredforchange.com/dia/api/get.jsp',
        :save => 'http://salsa.wiredforchange.com/dia/api/process.jsp',
        :delete  => 'http://salsa.wiredforchange.com/dia/deleteEntry.jsp'
        },
      :org2 => { 
        :get     => 'http://org2.democracyinaction.org/dia/api/get.jsp',
        :save => 'http://org2.democracyinaction.org/dia/api/process.jsp',
        :delete  => 'http://org2.democracyinaction.org/dia/api/delete.jsp'
        }
      }

    # The username used to login to your Democracy in Action account.
    attr_reader :username
    # The password used to login to your Democracy in Action account.
    attr_reader :password
    # orgkey is your account identifier on the service 
    # - check the URL when you are logged in if you are unsure of this value.
    attr_reader :orgkey
    # node is a short key representing DIA servers that are known to the library ( see NODES )
    attr_reader :node
    # For new nodes or custom scripts you may wish to specify a hash of custom urls
    attr_reader :urls

    # Requires an options hash containing: :username, :password, :orgkey, and :node
    #   
    # :node can be skipped if :urls hash is included instead.
    #
    # If a :urls hash is used, it should have the form:
    #   :urls => { :get => "get_url", :save => "save_url", :delete => "delete_url" }
    def initialize(options = {})
      unless options && options[:username] && options[:password] && options[:orgkey] && ( options[:node] || options[:urls] ) || self.class.disabled?
        raise ConnectionInvalid.new("Must specify :username, :password, :orgkey, and ( :node or :url )")
      end 

      @username, @password, @orgkey, @node = options.delete(:username), options.delete(:password), options.delete(:orgkey), options.delete(:node)

      @urls = options[:urls] || NODES[@node]
      raise ConnectionInvalid.new("Requested node is not supported.  Use (#{NODES.keys.join(', ')}) or specify a custom array in :urls") unless @urls
      raise ConnectionInvalid.new("Urls must be a hash") unless @urls.is_a?(Hash)
      raise ConnectionInvalid.new("Urls must include at least :get, :save, and :delete") unless @urls[:get] and @urls[:save] and @urls[:delete]
    end

    # Confirm that the API is enabled and the remote service is reachable
    def connected?
      begin
        API.disabled? || !(@username && @password && @orgkey && @node && get( :object => 'supporter', 'desc' => 1 )).nil?
      rescue SocketError #means the library cannot reach the DIA server at all, or no internet is available
        false
      end
    end

    # Prevent the API from contacting the remote service.  Used for development and testing purposes.
    def self.disable!
      @@disabled = true
    end

    # Confirm whether the API is allowed to contact the service.
    def self.disabled?
      @@disabled ||= false
    end

    # Connect to the service and check the current credentials
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


    # A raw request.  Requires the symbol for the url to hit ( ie :save, :get ) and a hash of options to be appended to the query string.
    def request( url_symbol, options = {} )
      raise InvalidUrl.new("Could not find :#{url_symbol} in api url keys") unless @urls.include?(url_symbol)
      send_request @urls[ url_symbol ], options 
    end


    # Return one or more records from the service
    #   
    # Supports
    #   :condition 
    #      * a string or array of strings in the format of SQL WHERE clauses
    #        = and LIKE operators may be used
    #      * a hash in the form of { :field_name => value, :field_name => value }
    #   :limit - an integer or equivalent string representing the maximum number of desired results
    #   :orderBy - a string in the form of an SQL ORDER BY clause, representing the desired sorting pattern of the result set
    #   :key - an integer representing the id of the desired result
    def get(options = {})
      body = send_request(@urls[:get], options_for_get(options))
      parse(body).result unless has_error?( body )
    end
    alias :all :get

    # Returns only the first result in a result set.  
    #
    # Accepts :condition and :orderBy.
    def first(options = {} )
      get( options.merge( :limit => 1 )).first
    end

    # Writes data to the service
    #
    # Supports these identifiers but does not require them.
    #   :key, or [object name]_KEY - identifies the record to write
    #   :Email will also identify a record in the Supporter table
    #   :link - a hash for linking new records to objects already on the service
    #
    # Links should be passed in the form
    #   options = { :link => { :[object name] => key, :[second object name] => key }}
    #
    # Additional options are attributes which should be set on the record
    def save(options = nil)
      send_request(@urls[:save], options.merge(key_param(options))).strip
    end

    # Create a new record
    #
    # The options are attributes which should be set on the new record
    def post( options = {})
      save( options ) 
    end

    # Update an existing record
    #
    # Requires an identifying key such as :key, :[object_name]_KEY, or Email
    #
    # Also requires the attributes to be updated, included in the options hash
    def put( options = {} )
      required_keys = [ :key, 'key', options[:object] + '_KEY', ( options[:object] + '_KEY').to_sym ]
      required_keys += [ 'Email', :Email ] if options[:object] == 'supporter' || options[:object] == :supporter
      raise InvalidKey.new( "You must specify :key, :Email, or #{options[:object]}_KEY to update a record" ) unless options.any? { |optkey, value| required_keys.include?(optkey) }
      save( options ) 
    end

    # Delete an existing record.
    #
    # Requires an identifying key such as :key.
    #
    # Accepts a single integer argument or an array if called via @api.[_object type_].delete()
    #
    # Returns true if it works, nil otherwise.
    def delete(*args)
      options = key_param(key)
      body = send_request(@urls[:delete], options)
    
      # if it contains '<success', it worked, otherwise a failure
      body.include?('<success')
    end

    # Returns an integer for the number of records specified.
    #
    # Allows a :condition to restrict the result set.
    def count(options = {})
      options[:limit] = 1
      xml = send_request(@urls[:get], options_for_get(options))
      parse(xml).count unless has_error?(xml)
    end
    
    # Return a description of the columns for a given object.
    # 
    # The response is a Hash of Result objects, with field names as keys.
    #
    # The fields are described with the keys :field, :type, :null, :key, :default, and :extra
    #
    # Not all keys are specified for all fields.
    def columns(options = {}) #:nodoc:
      body = send_request @urls[:get], options_for_get(options)
      parse( body, DIA_Desc_Listener ).result unless has_error?(body)
    end


    ###################### INTERNAL CODE ###################

    protected
    #private

    #evaluates xml and returns true if it contains an error
    def has_error?(xml)
      xml =~ /<error>Invalid login/
    end

    # Accepts XML and returns an array of DIA::Result objects
    #
    # Accepts a class name to serve as the StreamListener as an optional second argument
    #
    # Returns a populated instance of the passed class 
    def parse(xml, listener_class = DIA_Get_Listener )
      listener = listener_class.new
      parser = REXML::Parsers::StreamParser.new(xml, listener)
      parser.parse
      listener
    end

    # Checks for a method being one of the supported objects and returns a TableProxy if it is
    def method_missing(*args) #:nodoc:
      table_name = args.first
      
      if Tables.list.include?(table_name)
        return TableProxy.new(self, table_name)
      end
      super *args
    end

    # Encodes values for transmission in a POST.
    # ( copied from private function in Net::HTTP )
    def urlencode(str)
      str.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end

    # Evaluates an options hash for the presence of a key and returns a hash in the form { :key => value }
    # if a key is present.  
    #
    # Returns an empty Hash when no key is present.
    def key_param( options = {} )
      return { :key => options } if options && !options.is_a?(Hash)
      
      key_type = options[:key] ? :key : 'key'
      return {} unless key_value = options[key_type]
      key_value = key_value.join(', ') if key_value.is_a?(Array)
      { key_type => key_value }
    end

    # Evaluates an options hash for use with a GET request, returning a valid version for the current service.
    def options_for_get(options={})
      return {} unless options
      options.merge( key_param(options)).merge condition_param( options )
    end

    # Evaluates an options hash for :condition, returning a valid version.
    #
    # Converts a hash of conditions into a single string
    #
    # Returns an empty hash if no :condition is found in the param, otherwise returns a hash { :condition => value }
    def condition_param( options = {} )
      return {} unless condition = options.delete(:condition) 
      return { :condition => condition }  unless condition.is_a?(Hash)
      { :condition => condition.inject( [] ) { |memo, (column, value)| memo << "#{column}=#{value}" } }
    end

    # Converts a link hash to DIA format.
    # 
    # Every key is a object name, with values that are single or multiple records in that table.
    #
    # Returns an empty array if no :link parameter is passed, otherwise returns an array of query param strings.
    def link_hash_param(links={})
      return [] unless links
      raise InvalidData.new("Links should be a hash of the form :link => ( {object => key } or { object => [ key1, key2 ] } )") unless links.is_a?(Hash)

      links.inject([]) do |memo, (table, record_key)|
        record_key = [ record_key ] unless record_key.is_a?( Array )
        memo << record_key.map{ |k| "link=#{table}&linkKey=#{k}" }
      end.flatten
    end

    # Returns the options hash as a url-encoded string of key-value pairs.
    # 
    # Array values have their keys duplicated, creating key-value pairs for each element in the array.
    def build_body(options={})
      initial_memo = link_hash_param(options.delete(:link))
      return initial_memo.join('&') if options.empty?
      options.inject(initial_memo) do |memo, (key, value)|
        value = [ value ] unless value.is_a?( Array )
        memo << value.map { |v| "#{urlencode(key.to_s)}=#{urlencode(v.to_s)}" }
      end.join('&')
    end

    # Creates a new HTTP::Request object from a passed url and an options hash.
    #
    # Adds the authentication values and xml-specifier to the options.
    #
    # Assigns any cookies being held by the API to the Request.
    #
    # Appends all options to the request body as a url-encoded string.
    def build_request(url, options = {}) #:nodoc:
      # make a HTTP post and set the cookies
      request = Net::HTTP::Post.new(url.path)
      cookies.each { |c| request.add_field('Cookie', c) }
      
      # import authentication information
      options[:organization_KEY] = @orgkey if (@orgkey)
      if (@username && @password)
        options[:user] = @username
        options[:password] = @password
      end

      #indicate that xml is the desired response
      options[:xml] = true
      options[:object] ||= options.delete(:table)

      #format request body
      request.body = build_body(options)
      request.set_content_type('application/x-www-form-urlencoded')
      request

    end

    # Sends an HTTP::Request to the base_url. Builds up the request based on the passed options hash.
    #
    # Returns the body of the response.
    def send_request(base_url, options={})
      raise NoTableSpecified.new("You must either include :object in the options hash or use the proxy methods API#[objectname].get") unless options[:object]
      return '' if API.disabled?

      url = URI.parse(base_url) 
      request = build_request(url, options)
      puts request.body if $DEBUG

      # get result
      response = resolve( Net::HTTP.new(url.host, url.port).start { |http| http.request(request) } )

      return response.body
    end

    # Stores returned cookies to the api and checks for error conditions
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

    # Returns any cookies received back from the DIA service
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

  # This class acts as a placeholder for DIA objects.  It automatically includes
  # :object => [object_name] in the options hash that is passed along to the API.
  #
  # All methods not listed in TABLE_PROXY_METHODS are passed along to the API with their original arguments.
  class TableProxy #:nodoc:
    TABLE_PROXY_METHODS = [:get, :save, :delete, :columns, :count, :put, :post, :first, :all ]
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
        return @api.send(method_name, options.merge( :object => @table_name.to_s ) )
      end
      @api.send(method_name, *args)
    end
  end
end
