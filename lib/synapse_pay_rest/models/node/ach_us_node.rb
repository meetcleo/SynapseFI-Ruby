module SynapsePayRest
  class AchUsNode < BaseNode

    # TODO: add error message when trying to perform methods on unverified node
    class << self
      # TODO: validate bank_name in supported banks
      # https://synapsepay.com/api/v3/institutions/show
      def create_via_bank_login(user:, bank_name:, username:, password:)
        payload = payload_for_create_via_bank_login(bank_name: bank_name, username: username, password: password)
        user.authenticate
        response = user.client.nodes.add(payload: payload)
        # MFA questions
        if response['mfa']
          create_unverified_node(user, response)
        else
          create_from_bank_login_response(user, response['nodes'])
        end
      end

      def payload_for_create(nickname:, account_number:, routing_number:, 
        account_type:, account_class:, **options)
        payload = {
          'type' => 'ACH-US',
          'info' => {
            'nickname'    => nickname,
            'account_num' => account_number,
            'routing_num' => routing_number,
            'type'        => account_type,
            'class'       => account_class
          }
        }
        # optional payload fields
        extra = {}
        extra['supp_id']            = options[:supp_id] if options[:supp_id]
        extra['gateway_restricted'] = options[:gateway_restricted] if options[:gateway_restricted]
        payload['extra'] = extra if extra.any?

        payload
      end

      def payload_for_create_via_bank_login(bank_name:, username:, password:)
        {
          'type' => 'ACH-US',
          'info' => {
            'bank_id'   => username,
            'bank_pw'   => password,
            'bank_name' => bank_name
          }
        }
      end

      def create_from_response(user, response)
        node = self.new(
          user:            user,
          id:              response['_id'],
          is_active:       response['is_active'],
          account_number:  response['info']['account_num'],
          routing_number:  response['info']['routing_num'],
          bank_long_name:  response['info']['bank_long_name'],
          account_class:   response['info']['class'],
          account_type:    response['info']['type'],
          name_on_account: response['info']['name_on_account'],
          nickname:        response['info']['nickname'],
          permissions:     response['allowed'],
          supp_id:         response['extra']['supp_id']
        )
        user.nodes << node
        node
      end

      def create_from_bank_login_response(user, response)
        response.map do |node_data|
          node = self.new(
            user:            user,
            id:              node_data['_id'],
            is_active:       node_data['is_active'],
            account_number:  node_data['info']['account_num'],
            routing_number:  node_data['info']['routing_num'],
            bank_name:       node_data['info']['bank_name'],
            bank_long_name:  node_data['info']['bank_long_name'],
            account_class:   node_data['info']['class'],
            account_type:    node_data['info']['type'],
            name_on_account: node_data['info']['name_on_account'],
            nickname:        node_data['info']['nickname'],
            balance:         node_data['info']['balance']['amount'],
            currency:        node_data['info']['balance']['currency'],
            permissions:     node_data['allowed'],
            supp_id:         node_data['extra']['supp_id'],
            verified:        true
          )
          user.nodes << node
          node
        end
      end
      
      def create_unverified_node(user, response)
        unverified_node = UnverifiedNode.new(
          user: user,
          mfa_access_token: response['mfa']['access_token'],
          mfa_message:      response['mfa']['message'],
          mfa_verified:     false
        )
        user.nodes << unverified_node
        unverified_node
      end
    end

    # TODO: raise error if already verified
    # TODO: raise error if too many attempts
    # TODO: validate inputs as floats
    def verify_microdeposits(amount1:, amount2:)
      payload = verify_microdeposits_payload(amount1: amount1, amount2: amount2)
      response = user.client.nodes.patch(node_id: id, payload: payload)
      @permissions = response['allowed']
      self
    end

    private

    def verify_microdeposits_payload(amount1:, amount2:)
      {
        'micro' => [amount1, amount2]
      }
    end
  end
end
