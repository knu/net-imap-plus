require 'net/imap'

class Net::IMAP
  class UnsupportedOperationError < Error
    def initialize(name)
      super "#{name} extension is unsupported by the server"
    end
  end

  alias capability_minus capability

  class ResponseParser
    alias capability_response_minus capability_response
    def capability_response
      capability_response_minus.tap { |response|
        @capability = response.data
      }
    end
    attr_reader :capability
  end

  # Returns a list of capabilities advertised as supported by the
  # server.
  #
  # QUOTA:: RFC 2087
  # SORT:: RFC 5256
  # THREAD:: RFC 5256
  # UIDPLUS:: RFC 4315
  def capability
    @parser.capability || capability_minus
  end

  # Sends a UID EXPUNGE command to permanently remove from the
  # currently selected mailbox all messages that both have the
  # \Deleted flag set and have a UID that is included in the specified
  # sequence set.
  def uid_expunge(set)
    synchronize do
      send_command("UID EXPUNGE", MessageSet.new(set))
      return @responses.delete("EXPUNGE")
    end
  end

  {
    :quota	=> [:getquota, :getquotaroot, :setquota],
    :sort	=> [:sort, :uid_sort],
    :thread	=> [:thread],
    :uidplus	=> [:uid_expunge],
  }.each { |cap, methods|
    sCAP = cap.to_s.upcase
    eval %{
      def #{cap}?
        @#{cap}_p ||= capability.include?('#{sCAP}')
      end

      def #{cap}!
        raise UnsupportedOperationError.new('#{sCAP}')
      end
      private :#{cap}!
    }
    methods.each { |sym|
      eval %{
        alias #{sym}_minus #{sym}
        def #{sym}(*args, &block)
          #{cap}!
          #{sym}_minus(*args, &block)
        end
      }
    }
  }
end
