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
    class ConnectionInvalid < ArgumentError #:nodoc:
    end

    DOMAINS = { 
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

    attr_reader :username, :password, :orgkey, :domain
    attr_reader :urls

    # requires an options hash containing:
    # :username, :password, :orgkey, and :domain
    #   :domain may be omitted if the user specifies a custom service node with a :urls hash
    # the urls hash should be in the form:
    #   :urls => { :get => get_url, :process => process_url, :delete => delete_url }
    def initialize(options = {})
      unless options && options[:username] && options[:password] && options[:orgkey] && ( options[:domain] || options[:urls] ) || self.class.disabled?
        raise ConnectionInvalid.new("Must specify :username, :password, :orgkey, and ( :domain or :url )")
      end 

      @username, @password, @orgkey, @domain = options.delete(:username), options.delete(:password), options.delete(:orgkey), options.delete(:domain)

      @urls = options[:urls] || DOMAINS[@domain]
      raise ConnectionInvalid.new("Requested domain is not supported.  Use (#{DOMAINS.keys.join(', ')}) or specify a custom array in :urls") unless @urls
      raise ConnectionInvalid.new("Urls must be a hash") unless @urls.is_a?(Hash)
      raise ConnectionInvalid.new("Urls must include at least :get, :process, and :delete") unless @urls[:get] and @urls[:process] and @urls[:delete]
    end

  # confirms that the API is enabled and the Democracy in Action service node is reachable
  # returns a boolean
    def connected?
      begin
        API.disabled? || !(@username && @password && @orgkey && @domain && get( :table => 'supporter', 'desc' => 1 )).nil?
      rescue SocketError #means the library cannot reach the DIA server at all, or no internet is available
        false
      end
    end

    def authenticate
      url = URI.parse(@urls[:authenticate])
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = https.post(url.path, "email=#{username}&password=#{password}")

      raise ConnectionInvalid if authentication_failed?(response)
      
      if response['set-cookie']
        response['set-cookie'].each { |c| cookies.push(c.split(';')[0]) }
      end

      @authenticated = true

      response
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
      # make a HTTP post
      body = send_request(@urls[:get], process_get_options(options[:table], options))

      # interpret the results...
      # the description is a different format and needs a different parser
      return nil if parse_error(body)
      return parse_description( body ) if (options['desc'])
      return parse_count( body ) if (options['count'])

      parse_records( body )
    end

    def parse_error(xml)
      xml =~ /<error>Invalid login/
    end

    def parse_count(xml)  
      parse(xml).count
    end
    
    def parse(xml)
      listener = DIA_Get_Listener.new
      parser = REXML::Parsers::StreamParser.new(xml, listener)
      parser.parse
      listener
    end

    def parse_records(xml)
      parse(xml).items.map {|item| Result.new(item)}
    end

    def parse_description(xml)
      listener = DIA_Desc_Listener.new
      parser = REXML::Parsers::StreamParser.new(xml, listener)
      parser.parse
      listener.result
    end

    # options - Hash keys: 'key', 'debug' <br>
    #
    #           String: same as { 'key' => String }
    # TODO: document link option???
    def process(options = nil)
      send_request(@urls[:process], process_process_options( options[:table], options )).strip
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
      table = criteria.delete('table') || criteria.delete(:table)
      options = process_options(table, criteria)
      options.delete('simple')
      options['xml'] = true

      body = send_request(@urls[:delete], criteria)
    
      # if it contains '<success', it worked, otherwise a failure
      if body.include?('<success')
        return true
      else
        puts body if $DEBUG
        return false
      end
    end

    def columns(options)
      #raise (self.class.instance_methods - Object.instance_methods).inspect
      get('table' => options[:table], 'desc' => true)
    end
    alias :describe :columns

    def count(options)
      get('table' => options[:table], 'count' => true, 'limit' => 1)
    end
    
    def self.disable!
      @@disabled = true
    end

    def self.disabled?
      @@disabled ||= false
    end


    ###################### INTERNAL CODE ###################

    protected

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

    # this takes the table name and (possibly nil) options
    # and returns one hash with them all, handling key processing
    def process_options(table, options)
      # handle no options as well as String representing the key value
      if (! options) then 
        options = { }
      elsif (options.class != Hash)
        options = { 'key' => options }
      end

      # default options
      options['table'] = table
      options['simple'] = true

      return options
    end

    def process_multiple_keys( options = {} )
      # if multiple keys (array), join keys with comma
      # (only for get command)
      if options['key'] && (options['key'].class == Array) then
        value = options['key'].join(', ')
        options['key'] = value  
      end
      options

    end

    def process_process_options( table, options)
      options = process_options(table, options)
      options['link'] = linkHashToQueryStringArray(options['link']) if options['link']
      options
    end

    def process_get_options(table, options)
      process_multiple_keys( process_conditions( process_options( table, options )))
    end

    def process_conditions( options = {} )
      conditions = options.delete(:where) || options.delete('where')
      return options unless conditions
      return options.merge(:where => conditions) unless conditions.is_a?(Hash)
      options.merge( :where => conditions.inject( [] ) { |memo, (column, value)| memo << "#{column} = '#{value.gsub(/[']/, '\\\\\'')}'" }.join( ' AND '))
    end

    # links are sent in a Hash.
    # every key is a table name
    # value is either key in that table, or Array of keys in that table
    # return an Array of values that can be added to a query string
    def linkHashToQueryStringArray(links)
      raise "bad links value" unless links && links.is_a?(Hash)

      links.inject([]) do |memo, (table, record_key)|
        record_key = [ record_key ] unless record_key.is_a?( Array )
        memo << record_key.map{ |k| table+'|'+k.to_s }
      end.flatten
    end

    # helper function for send_request to handle multiple entries
    # with same key name
    def build_body(options)
      # in order to handle multiple links, keys...
      # if an option has an Array as value, append each array element
      # as "<key>=<array element>&"
      options.inject([]) do |memo, (key, value)|
        value = [ value ] unless value.is_a?( Array )
        memo << value.map { |v| "#{urlencode(key.to_s)}=#{urlencode(v.to_s)}" }
      end.join('&')
    end

    def build_request(url, options)
      # make a HTTP post and set the cookies
      request = Net::HTTP::Post.new(url.path)
      cookies.each { |c| request.add_field('Cookie', c) }
      
      # import authentication information
      options['organization_KEY'] = @orgkey if (@orgkey)
      if (@username && @password)
        options['user'] = @username
        options['password'] = @password
      end

      #format request body
      request.body = build_body(options)
      request.set_content_type('application/x-www-form-urlencoded')
      request

    end

    # specialized code to handle multiple form entries with same key name
    # also does some error handling
    def send_request(base_url, options)
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
        response.get_fields('Set-Cookie').each { |c| self.cookies.push(c.split(';')[0]) }
      end
      response
    end

    # returns any cookies received back from the DIA service
    def cookies
      @cookies ||= []
    end

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
