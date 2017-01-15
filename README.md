# Shell Herder
This Metasploit plugin was created to monitor sessions, new ones and those closing. The idea is to provide a way for consultants to see new sessions coming in when they might not have access to their listener(s). Perhaps you have stepped away from your computer with an active phishing campaign? Maybe you're using a Rubber Ducky in an office and want to get a mobile notification if your payload succeeds?

A future version use the Metasploit remote API to monitor sessions and Empire REST API to support both Meterpreter sessions and Empire agents.

ShellHerder uses session subscriptions to monitor activity and then sends an alert to Slack using Slack's Incoming WebHooks. The alert is sent using the WebHook URL and a POST request and will tag a specified username (you could also use @channel or @here) and provide the computer name of the server with the session (if set).

Ruby gems like slack-notifier are not used because that would require installing a dependency and telling Metasploit to use it. Unfortunately, this can be an annoying process (getting msfconsole to recognize the gem) and your changes can be wiped out when msfconsole is updated. The HTTP requests work just as well and make all of this simpler.

## Setup
Place the ShellHerder.rb file inside "/usr/share/metasploit-framework/plugins/" or a folder you have linked to this primary plugins folder.

Then create a new Incoming WebHook for Slack. You may also want to create a new channel for the alerts, like #shell-alerts.

## Sample Usage
The ShellHerder plugin can be used like any other Metasploit plugin. Begin by loading ShellHerder and setting your options. Then you will need to run notify_start to subscribe to session events. See the following example:

  msf exploit(handler) > load notify

  [\*] Successfully loaded plugin: notify

  msf exploit(handler) > notify_set_user @chrismaddalena

  [\*] Setting the Slack handle to @chrismaddalena

  msf exploit(handler) > notify_set_webhook <Your hooks.slack.com URL>

  [\*] Setting the Webhook URL to <Your hooks.slack.com URL>

  msf exploit(handler) > notify_set_source Test_VM

  [\*] Setting the Source to Test_VM

  msf exploit(handler) > notify_test

  [\*] Sending tests message

  msf exploit(handler) >

  [\*] Encoded stage with x86/shikata_ga_naiv

  [\*] Sending encoded stage (958029 bytes) to 10.10.1.10

  [\*] Meterpreter session 1 opened (10.10.1.11:4444 -> 10.10.1.10:49713) at 2016-11-15 10:54:23 -0500

  msf exploit(handler) > sessions -k 1

  [\*] Killing the following session(s): 1

  [\*] Killing session 1

  [\*] 10.10.1.10 - Meterpreter session 1 closed.

This will result in three Slack messages, one confirming setup (notify_test) and one each for the new session and the session being killed.

<@username> You did it! New session... Source: Test_VM; Session: 1; Platform: Windows; Type: Meterpreter"
<@username> You have made a huge mistake... Source: Test_VM; Session: 1; Reason: Meterpreter is shutting down
