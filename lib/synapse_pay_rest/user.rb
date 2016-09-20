module SynapsePayRest
  class User
    # could do these dynamically but this is probably more readable
    # TODO: Login class? Document class?
    attr_reader :client, :logins, :phone_numbers, 
                :legal_names, :note, :supp_id, :is_business, :cip_tag
    attr_accessor :id, :refresh_token

    class << self
      def find(client:, id:)
        response = client.users.get(user_id: id)
        User.new(
          client: client, 
          id: response['_id'], 
          logins: response['logins'], 
          phone_numbers: response['phone_numbers']
        )
      end

      # TODO: cache response and have some parameter for force re-fetch
      def all(client:, page: 1, per_page: 15)
        response = client.users.get(options: {page: page, per_page: per_page})
        response['users'].map do |data|
          args = {
            client: client,
            logins: data['logins'],
            phone_numbers: data['phone_numbers'],
            legal_names: data['legal_names'],
            supp_id: data['extra']['supp_id'],
            is_business: data['extra']['is_business'],
            cip_tag: data['extra']['cip_tag']
          }
          user = User.new(args)
          user.id = data['_id']
          user.refresh_token = data['refresh_token']
          user
        end
      end
    end

    # provide id for existing user or required fields for new user
    # TODO: handle error if id not found
    def initialize(client:, id: nil, **options)
      @client = client

      if id
        @id = id
        fetch_info(id: id)
      else
        validate_minimal_initialization_args(options)
        create_user(options)
      end

      @client.users.client.user_id = @id
    end

    # TODO: validate some kind of proper input was entered
    def update(**options)
      payload = {
        'refresh_token' => refresh_token,
        'update' => {}
      }
      # must have one of these
      payload['update']['login'] = options[:login] if options[:login]
      payload['update']['remove_login'] = options[:remove_login] if options[:remove_login]
      payload['update']['legal_name'] = options[:legal_name] if options[:legal_name]
      payload['update']['phone_number'] = options[:phone_number] if options[:phone_number]
      payload['update']['remove_phone_number'] = options[:remove_phone_number] if options[:remove_phone_number]
      client.users.update(payload: payload)
    end

    def add_documents
    end
    
    # def create_node(node)
    #   @nodes << node
    # end

    # def nodes
    # end

    private

    # TODO: validate format of each arg as well
    # TODO: allow email/password in lieue of logins array
    def validate_minimal_initialization_args(args)
      required_params = [:logins, :phone_numbers, :legal_names]
      required_params.each do |arg|
        unless args[arg]
          raise ArgumentError, "must initialize #{self.class} with either id or #{required_params.join('/')}"
          raise ArgumentError, "#{arg} must be an array"
        end
      end
    end

    # def add_login(email:, password: nil)
    # end

    # TODO: assign all data from response to instance methods (iterating through and creating documents, etc)
    def fetch_info(id:)
      data = client.users.get(user_id: id)
      @logins = data['logins']
      @phone_numbers = data['phone_numbers']
      @legal_names = data['legal_names']
      @supp_id = data['extra']['supp_id']
      @is_business = data['extra']['is_business']
      @cip_tag = data['extra']['cip_tag']
      @refresh_token = data['refresh_token']
    end

    def create_user(info)
      payload = {
        'logins' => info[:logins],
        'phone_numbers' => info[:phone_numbers],
        'legal_names' => info[:legal_names],
        'extra' => {}
      }
      # optional
      payload['extra']['note'] = info[:note] if info[:note]
      payload['extra']['supp_id'] = info[:supp_id] if info[:supp_id]
      payload['extra']['is_business'] = info[:is_business] if info[:is_business]

      response = client.users.create(payload: payload)
      
      @refresh_token = response['refresh_token']
      @id = response['_id']
      info.each { |key, value| instance_variable_set("@#{key}", value) }
    end
  end
end