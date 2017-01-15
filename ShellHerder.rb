##
# Author: Chris Maddalena
#
# Credit to Carlos Perez for the foundation of this - it's a Frankenstein of an
# old, similar plugin of his. However, his is no longer functional or maintained.
##

require 'open-uri'
require 'net/http'
require 'net/https'

module Msf

	class Plugin::Notify < Msf::Plugin
		include Msf::SessionEvent

		# Checks if the constant is already set, if not it is set
		if not defined?(Notify_yaml)
			Notify_yaml = "#{Msf::Config.get_config_root}/Notify.yaml"
		end


		# Initialize the Class
		def initialize(framework, opts)
			super
			add_console_dispatcher(NotifyDispatcher)
		end


		# Cleans up the event subscriber on unload
		def cleanup
			self.framework.events.remove_session_subscriber(self)
			remove_console_dispatcher('notify')
		end


		# Sets the name of the plguin
		def name
			"notify"
		end


		# Sets the description of the plugin
		def desc
			"Automatically send Slack notifications when sessions are created and closed."
		end


		# Notify Dispatcher Class
		class NotifyDispatcher
			include Msf::Ui::Console::CommandDispatcher

			@webhook_url =  nil
			@user_name = nil
			@channel = "#<CHANNEL_NAME>" # An existing channel or one setup for the alerts
			@bot_name = "Shell Herder" # Whatever you want the bot's name to be
      $source = nil
      $opened = Array.new
      $closed = Array.new


		  # Actions for when a session is created
			def on_session_open(session)
				#print_status("Session received, sending push notification")
				sendslack("#{@user_name} You did it! New session... Source: #{$source}; Session: #{session.sid}; Platform: #{session.platform}; Type: #{session.type}", "http://emojipedia-us.s3.amazonaws.com/cache/a3/d8/a3d8a52b21c3e628e87001c9d5a2d25d.png", session.sid, "open")
				return
			end


			# Actions for when the session is closed
			def on_session_close(session,reason = "")
				begin
					#print_status("Session:#{session.sid} Type:#{session.type} is shutting down")
					if reason == ""
						reason = "unknown, may have been killed with sessions -k"
					end
					sendslack("#{@user_name} You have made a huge mistake... Source: #{$source}; Session: #{session.sid}; Reason: #{session.type} is shutting down - #{reason}", "http://emojipedia-us.s3.amazonaws.com/cache/03/e4/03e423c7d30403af03aecbf20276364b.png", session.sid, "close")
				rescue
					return
				end
				return
			end


			# Sets the name of the plguin
			def name
				"notify"
			end


			# Primary function for sending Slack notifications - creates the "notifier" and sends the "ping"
			# The arrays and "exclude?" checks prevent spam messages as a result of on_session_* triggering many times
			# This is an issue with Metasploit triggering events multiple times very quickly when a session opens or closes
			def sendslack(message, icon, session_id, event)
				if event == "open" and $opened.exclude?(session_id)
					print_status(message)
					data = "{'text': '#{message}', 'channel': '#{@channel}', 'username': '#{@bot_name}', 'icon_emoji': '#{icon}'}"
					url = URI.parse(@webhook_url)
					http = Net::HTTP.new(url.host, url.port)
					http.use_ssl = true
					resp = http.post(url.path, data)
					$opened.push(session_id)
				elsif event == "close" and $closed.exclude?(session_id)
					print_status(message)
					data = "{'text': '#{message}', 'channel': '#{@channel}', 'username': '#{@bot_name}', 'icon_emoji': '#{icon}'}"
					url = URI.parse(@webhook_url)
					http = Net::HTTP.new(url.host, url.port)
					http.use_ssl = true
					resp = http.post(url.path, data)
					$closed.push(session_id)
				end
			end


			# Reads and set the valued from the YAML settings file
			def read_settings
				read = nil
				if File.exist?("#{Notify_yaml}")
					ldconfig = YAML.load_file("#{Notify_yaml}")
					@webhook_url = ldconfig['webhook_url']
					@user_name = ldconfig['user_name']
					$source = ldconfig['source']
					read = true
				else
					print_error("You must create a YAML File with the options")
					print_error("as: #{Notify_yaml}")
					return read
				end
				return read
			end


			# Sets the commands for the Metasploit plugin
			def commands
				{
					'notify_help'					=> "Displays help",
					'notify_start'				=> "Start Notify Plugin after saving settings.",
					'notify_stop'					=> "Stop monitoring for new sessions.",
					'notify_test'					=> "Send test message to make sure confoguration is working.",
					'notify_save'					=> "Save Settings to YAML File #{Notify_yaml}.",
					'notify_set_webhook'	=> "Sets Slack Webhook URL.",
					'notify_set_user'			=> "Set Slack username for messages.",
          'notify_set_source'   => "Set source for identifying the souce of the message.",
					'notify_show_options'	=> "Shows currently set parameters.",

				}
			end


			# Help command to help you help yourself
			def cmd_notify_help
				puts "Run notify_set_user, notify_set_webhook, and notify_set_source to setup Slack config. Then run notify_save to save them for later. Use notify_test to test your config and load it from the YAML file in the future. Finally, run notify_start when you have your listener setup."
			end


			# Re-Read YAML file and set Slack Webhook API configuration
			def cmd_notify_start
				print_status "Session activity will be sent to you via Slack Webhooks, channel: #{@channel}"
				if read_settings()
					self.framework.events.add_session_subscriber(self)
					print_good("Notify Plugin Started, Monitoring Sessions")
				else
					print_error("Could not set Slack Web API settings.")
				end
			end


			# Stop the module and unsubscribe from the session events
			def cmd_notify_stop
				print_status("Stopping the monitoring of sessions to Slack")
				self.framework.events.remove_session_subscriber(self)
			end


			# Send a test notification to Slack
			def cmd_notify_test
				print_status("Sending tests message")
				if read_settings()
					self.framework.events.add_session_subscriber(self)
					data = "{'text': '#{@user_name} Metasploit is online on #{$source}! Hack the Planet!', 'channel': '#{@channel}', 'username': '#{@bot_name}', 'icon_emoji': 'http://emojipedia-us.s3.amazonaws.com/cache/46/2e/462e369e465fd7b52537f6370227b52b.png'}"
					url = URI.parse(@webhook_url)
					http = Net::HTTP.new(url.host, url.port)
					http.use_ssl = true
					resp = http.post(url.path, data)
				else
					print_error("Could not set Slack Web API settings.")
				end
			end


			# Save settings to text file for later use
			def cmd_notify_save
				print_status("Saving options to config file")
				if @user_name and @webhook_url and $source
					config = {'user_name' => @user_name, 'webhook_url' => @webhook_url, 'source' => $source}
					File.open(Notify_yaml, 'w') do |out|
						YAML.dump(config, out)
					end
					print_good("All settings saved to #{Notify_yaml}")
				else
					print_error("You have not provided all the parameters!")
				end
			end


			# Set the username for Slack alerts
			def cmd_notify_set_user(*args)
				if args.length > 0
					print_status("Setting the Slack handle to #{args[0]}")
					@user_name = args[0]
				else
					print_error("Please provide a value")
				end
			end


			# Set the Slack Webhook URL - it's hard-coded above
			def cmd_notify_set_webhook(*args)
				if args.length > 0
					print_status("Setting the Webhook URL to #{args[0]}")
					@webhook_url = args[0]
				else
					print_error("Please provide a value")
				end
			end


			# Set the message source, e.g. Phish5
			def cmd_notify_set_source(*args)
				if args.length > 0
					print_status("Setting the Source to #{args[0]}")
					$source = args[0]
				else
					print_error("Please provide a value")
				end
			end


			# Show the parameters set on the Plug-In
			def cmd_notify_show_options
				print_status("Parameters:")
				print_good("Webhook URL: #{@webhook_url}")
				print_good("Slack User: #{@user_name}")
				print_good("Source: #{$source}")
			end
		end
	end
end
