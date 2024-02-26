## GitHub Runner as macOS Daemon 

GitHub instructions 
https://docs.github.com/en/actions/hosting-your-own-runners/configuring-the-self-hosted-runner-application-as-a-service

Does not work because it launch as LaunchAgent (requires a GUI Session)

Solution : install as a Dameon

```sh
sudo bash 

RUNNER_NAME=github.runner.ec2manager
cat << EOF > /Library/LaunchDaemons/$RUNNER_NAME.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>actions-runner-ec2manager</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/ec2-user/actions-runner-ec2manager/run.sh</string>
    </array>
    <key>KeepAlive</key>
    <dict>
      <key>SuccessfulExit</key>
      <false/>
    </dict> 
    <key>UserName</key>
    <string>ec2-user</string>
    <key>GroupName</key>
    <string>staff</string>  
    <key>WorkingDirectory</key>
    <string>/Users/ec2-user/actions-runner-ec2manager</string>
    <key>RunAtLoad</key>
    <true/>    
    <key>StandardOutPath</key>
    <string>/Users/ec2-user/actions-runner-ec2manager/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/ec2-user/actions-runner-ec2manager/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict> 
      <key>ACTIONS_RUNNER_SVC</key>
      <string>1</string>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>SessionCreate</key>
    <true/>
  </dict>
</plist>
EOF

sudo chown root:wheel /Library/LaunchDaemons/$RUNNER_NAME.plist 
sudo /bin/launchctl load /Library/LaunchDaemons/$RUNNER_NAME.plist
```