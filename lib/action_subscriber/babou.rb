module ActionSubscriber
  module Babou
    ##
    # Class Methods
    #

    def self.auto_pop!
      @pop_mode = true
      reload_active_record
      load_subscribers unless subscribers_loaded?
      sleep_time = ::ActionSubscriber.configuration.pop_interval.to_i / 1000.0

      ::ActionSubscriber.start_queues
      logger.info "Action Subscriber is popping messages every #{sleep_time} seconds."

      # How often do we want the timer checking for new pops
      # since we included an eager popper we decreased the
      # default check interval to 100m
      while true
        ::ActionSubscriber.auto_pop! unless shutting_down?
        sleep sleep_time
        break if shutting_down?
      end
    end

    def self.pop?
      !!@pop_mode
    end

    def self.start_subscribers
      @prowl_mode = true
      reload_active_record
      load_subscribers unless subscribers_loaded?

      ::ActionSubscriber.start_subscribers
      logger.info "Action Subscriber connected"

      while true
        sleep 1.0 #just hang around waiting for messages
        break if shutting_down?
      end
    end

    def self.prowl?
      !!@prowl_mode
    end

    def self.load_subscribers
      subscription_paths = ["subscriptions", "subscribers"]
      path_prefixes = ["lib", "app"]
      cloned_paths = subscription_paths.dup

      path_prefixes.each do |prefix|
        cloned_paths.each { |path| subscription_paths << "#{prefix}/#{path}" }
      end

      absolute_subscription_paths = subscription_paths.map{ |path| ::File.expand_path(path) }
      absolute_subscription_paths.each do |path|
        if ::File.exists?("#{path}.rb")
          load("#{path}.rb")
        end

        if ::File.directory?(path)
          ::Dir[::File.join(path, "**", "*.rb")].sort.each do |file|
            load file
          end
        end
      end
    end

    def self.logger
      ::ActionSubscriber::Logging.logger
    end

    def self.reload_active_record
      if defined?(::ActiveRecord::Base) && !::ActiveRecord::Base.connected?
        ::ActiveRecord::Base.establish_connection
      end
    end

    def self.shutting_down?
      !!@shutting_down
    end

    def self.stop_receving_messages!
      @shutting_down = true
      ::Thread.new do
        ::ActionSubscriber.stop_subscribers!
        logger.info "stopped all subscribers"
      end.join
    end

    def self.stop_server!
      # this method is called from within a TRAP context so we can't use the logger
      puts "Stopping server..."
      wait_loops = 0
      ::ActionSubscriber::Babou.stop_receving_messages!

      while ::ActionSubscriber::Threadpool.busy? && wait_loops < ::ActionSubscriber.configuration.seconds_to_wait_for_graceful_shutdown
        puts "waiting for threadpools to empty:"
        ::ActionSubscriber::Threadpool.pools.each do |name, pool|
          puts "  -- #{name} (remaining: #{pool.busy_size})" if pool.busy_size > 0
        end
        Thread.pass
        wait_loops = wait_loops + 1
        sleep 1
      end

      puts "threadpool empty. Shutting down"
    end

    def self.subscribers_loaded?
      !::ActionSubscriber::Base.inherited_classes.empty?
    end
  end
end
