{
  config,
  inputs,
  pkgs,
  ...
}:
let
  excludes = pkgs.writeText "excludes.list" ''
    /Users/*/Library/Caches
    /Users/*/Library/Logs
    /Users/*/Library/Applications

    # Dev stuff
    # --- build / dev artifacts ---
    **/node_modules
    **/bower_components
    **/.next
    **/.nuxt
    **/dist
    **/build
    **/target
    **/deps
    **/__pycache__
    **/.venv
    **/venv
    **/env
    **/.tox
    **/.mypy_cache
    **/.elixir_ls
    **/.expert
    **/.terraform
    **/.ollama/models

    # --- temporary & misc ---
    **/.DS_Store
    **/.Trash
    **/.TemporaryItems
    **/.fseventsd
    **/.Spotlight-V100
    **/.DocumentRevisions-V100
    **/.localized
    **/packer_cache/
    **/*.tmp

    # macOS home directory equivalents
    /Users/*/.ansible_async
    /Users/*/.ansible
    /Users/*/.atom
    /Users/*/.cache
    /Users/*/.cups
    /Users/*/.docker
    /Users/*/.colima
    /Users/*/.dropbox
    /Users/*/.gem
    /Users/*/.local
    /Users/*/.npm
    /Users/*/.nvm
    /Users/*/.packer.d
    /Users/*/.python-virtualenvs
    /Users/*/.rvm
    /Users/*/.terraform.d
    /Users/*/.Trash
    /Users/*/.vagrant.d
    /Users/*/.vscode
    /Users/*/.cargo
    /Users/*/.rustup
    /Users/*/.julia
    /Users/*/.stack
    /Users/*/.platformio
    /Users/*/go
    /Users/*/.BurpSuite
    /Users/*/.ghcup
    /Users/*/.hex
    /Users/*/Applications
    /Users/*/Documents/$RECYCLE.BIN
    /Users/*/Documents/Snagit/Autosaved Captures.localized
    /Users/*/Documents/Virtual Machines.localized
    /Users/*/Dropbox
    /Users/*/Google Drive
    /Users/*/Library/Caches
    /Users/*/Library/Containers/com.docker.docker
    /Users/*/Library/Dropbox
    /Users/*/Library/Logs
    /Users/*/Library/VirtualBox
    /Users/*/Library/WebKit
    /Users/*/odrive
    /Users/*/OneDrive
    /Users/*/tmp
    /Users/*/VboxShared
    /Users/*/Virtual Machines.localized
    /Users/*/VirtualBox VMs

    # Caches
    [cC]ache/
    [cC]ache[sd]/
    .[cC]ache/
    .[cC]ache[sd]/
    [cC]ache[^a-z]*/
    [cC]ache[sd][^a-z]*/
    *[^A-Z]Cache/
    *[^A-Z]Cache[sd]/
    *[^a-z]cache/
    *[^a-z]cache[sd]/
    *[^a-z]cache[^a-z]*/
    *[^a-z]cache[sd][^a-z]*/
    *[^A-Z]Cache[^a-z]*/
    *[^A-Z]Cache[sd][^a-z]*/
    *[^A-Z]CACHE[^a-z]*/
    *[^A-Z]CACHE[SD][^a-z]*/

    # Others that don't match the above
    __pycache__/
    GPUCache/
    LRUCache/

    # Common VM and image files
    *.box
    *.BOX
    *.img
    *.IMG
    *.iso
    *.ISO
    *.ova
    *.OVA
    *.ovf
    *.OVF
    *.vdi
    *.VDI
    *.vmdk
    *.VMDK

    # mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'"
    /Users/*/Library/Passes/RemoteDevices.archive
    /Users/*/Library/Passes/UserNotifications.archive
    /Users/*/Library/Passes/NotificationServiceTasks_v6.archive
    /Users/*/Library/Passes/PaymentWebServiceContext.archive
    /Users/*/Library/Passes/ScheduledActivities.archive
    /Users/*/Library/HTTPStorages/com.apple.nbagent
    /Users/*/Library/Passes/AuxiliaryCapabilityTasks_v6.archive
    /Users/*/Library/Passes/WebServiceTasks_v6.archive
    /Users/*/Library/HTTPStorages/com.apple.ciphermld
    /Library/OSAnalytics/Preferences
    /Users/*/Library/HTTPStorages/com.apple.akd
    /Users/*/Library/HTTPStorages/com.apple.amsaccountsd
    /Users/*/Library/HTTPStorages/askpermissiond
    /Users/*/Library/HTTPStorages/com.apple.FeatureAccessAgent
    /Users/*/Library/HTTPStorages/com.apple.siriknowledged
    /Users/*/Library/HTTPStorages/com.apple.SetupAssistant
    /Users/*/Library/HTTPStorages/com.apple.iCloudHelper
    /Users/*/Library/HTTPStorages/com.apple.AOSPushRelay
    /Users/*/Library/HTTPStorages/familycircled
    /Users/*/Library/HTTPStorages/com.apple.iCloudNotificationAgent
    /Users/*/Library/HTTPStorages/com.apple.appstorecomponentsd
    /Users/*/Library/HTTPStorages/mbuseragent
    /Users/*/Library/HTTPStorages/com.apple.jetpackassetd
    /Users/*/Library/HTTPStorages/com.apple.amsondevicestoraged
    /Users/*/Library/HTTPStorages/com.apple.storekitagent
    /Users/*/Library/HTTPStorages/com.apple.AddressBookSourceSync
    /Users/*/Library/Passes/Cards/EEG7A42fKxqU7lz5aHhev4bYpLQ=.pkpass
    /Users/*/Library/Passes/Cards/HPQLqXX8hxgUMyYbqScYw8WQdbI=.pkpass
    /Users/*/Library/Passes/PaymentWebServiceBackgroundContext.archive
    /Users/*/Library/HTTPStorages/com.apple.Family-Settings.extension
    /Users/*/Library/Finance/finance_cloud_ckAssets
    /Users/*/Library/Application Support/Animoji/CoreDataBackend/avatars_ckAssets
    /Users/*/Library/HTTPStorages/com.apple.tipsd
    /Users/*/Library/HTTPStorages/com.apple.translationd
    /Users/*/Library/HTTPStorages/com.apple.SoftwareUpdateNotificationManager
    /Users/*/Library/homeenergyd
    /Users/*/Library/HTTPStorages/com.apple.icloudwebd
    /Users/*/Library/HTTPStorages/com.apple.ctcategories.service
    /Users/*/Library/HTTPStorages/com.apple.managedappdistributionagent
    /Users/*/Library/HTTPStorages/com.apple.weatherd
    /Users/*/Library/HTTPStorages/softwareupdate
    /Users/*/Library/HTTPStorages/com.spotify.client
    /Users/*/Library/HTTPStorages/com.apple.accountsd
    /Users/*/Library/HTTPStorages/com.apple.appleaccountd
    /Users/*/Library/HTTPStorages/com.apple.appstoreagent
    /Users/*/Library/Passes/PeerPaymentWebServiceContext.archive
    /Users/*/Library/Finance
    /Users/*/Library/HTTPStorages/com.apple.itunescloudd
    /Users/*/Library/HTTPStorages/com.apple.ap.PromotedContentJetService
    /Users/*/Library/HTTPStorages/com.apple.AMPLibraryAgent
    /Users/*/Library/HTTPStorages/com.apple.betaenrollmentagent
    /Users/*/Library/HTTPStorages/com.apple.helpd
    /Users/*/Library/HTTPStorages/MiniLauncher
    /Users/*/Library/ResponseKit/sv-dynamic.lm
    /Users/*/Library/HTTPStorages/org.pqrs.Karabiner-Updater
    /Users/*/Library/HTTPStorages/pro.betterdisplay.BetterDisplay
    /Library/OSAnalytics/Diagnostics
    /Users/*/Library/HTTPStorages/com.raycast.macos
    /Users/*/Library/Application Support/com.raycast.macos/posthog.registerProperties
    /Users/*/Library/Application Support/com.raycast.macos/posthog.anonymousId

    # from initial errors export errors
    /Users/*/Library/Accounts
    /Users/*/Library/AppleMediaServices
    /Users/*/Library/Application Support/AddressBook
    /Users/*/Library/Application Support/CallHistoryDB
    /Users/*/Library/Application Support/CallHistoryTransactions
    /Users/*/Library/Application Support/CloudDocs
    /Users/*/Library/Application Support/DifferentialPrivacy
    /Users/*/Library/Application Support/FaceTime
    /Users/*/Library/Application Support/FileProvider
    /Users/*/Library/Application Support/Knowledge
    /Users/*/Library/Application Support/MobileSync
    /Users/*/Library/Application Support/com.apple.*
    /Users/*/Library/Assistant/SiriVocabulary
    /Users/*/Library/Autosave Information
    /Users/*/Library/Biome
    /Users/*/Library/Calendars
    /Users/*/Library/ContainerManager
    /Users/*/Library/Preferences/com.apple.*
    /Users/*/Library/Containers/*/.com.apple.containermanagerd.metadata.plist
    /Users/*/Library/Containers/com.apple.*
    /Users/*/Library/Group Containers/com.apple.*
    /Users/*/Library/Group Containers/group.com.apple.*
    /Users/*/Library/Mobile Documents
    /Users/*/Library/Cookies
    /Users/*/Library/CoreFollowUp
    /Users/*/Library/Daemon Containers
    /Users/*/Library/Containers/*/\.com\.apple\.containermanagerd\.metadata\.plist
    /Users/*/Library/DoNotDisturb
    /Users/*/Library/DuetExpertCenter
    /Users/*/Library/Cookies
    /Users/*/Library/CoreFollowUp
    /Users/*/Library/Daemon Containers
    /Users/*/Library/HomeKit
    /Users/*/Library/IdentityServices
    /Users/*/Library/IntelligencePlatform
    /Users/*/Library/DoNotDisturb
    /Users/*/Library/DuetExpertCenter
    /Users/*/Library/Google/GoogleSoftwareUpdate/Stats/Keystone.stats
    /Users/*/Library/Mail
    /Users/*/Library/Messages
    /Users/*/Library/PersonalizationPortrait
    /Users/*/Library/Reminders
    /Users/*/Library/Safari
    /Users/*/Library/Saved Application State/com.izotope.installer.RX-11-Elements.savedState
    /Users/*/Library/Sharing
    /Users/*/Library/Shortcuts
    /Users/*/Library/StatusKit
    /Users/*/Library/Suggestions
    /Users/*/Library/Trial
    /Users/*/Library/Weather
    /Users/*/Library/WebDriver
    /Users/*/Library/com.apple.aiml.instrumentation
    /Users/*/Library/Metadata/CoreSpotlight
    /Users/*/Library/Metadata/com.apple.IntelligentSuggestions
  '';

  configFile = pkgs.writeText "backrest-config.json" (
    builtins.toJSON {
      modno = 1;
      version = 4;
      instance = "eos";
      repos = [
        {
          id = "hermes";
          uri = "rclone:";
          guid = "35ab998213ce455c825f09b2136ba4a3494c6d359ed5c035f77339b62a378c76";
          env = [ "RESTIC_PASSWORD_FILE=${config.age.secrets.backrest-hermes-password.path}" ];
          flags = [
            "-o rclone.program='ssh adrian@hermes-files.internal -o IdentitiesOnly=yes -F /dev/null -i ${config.age.secrets.adrian-restic-ssh-key.path}'"
          ];
          prunePolicy = {
            schedule = {
              disabled = true;
              clock = "CLOCK_LAST_RUN_TIME";
            };
            maxUnusedPercent = 10;
          };
          checkPolicy = {
            schedule = {
              disabled = true;
              clock = "CLOCK_LAST_RUN_TIME";
            };
            readDataSubsetPercent = 10;
          };
          autoUnlock = true;
          commandPrefix = { };
        }
        {
          id = "hetzner";
          uri = "rclone:";
          guid = "99ddca76a007567515b064b57076be234ee0b3ce90de653354276d5a7cde6d34";
          env = [ "RESTIC_PASSWORD_FILE=${config.age.secrets.backrest-hetzner-password.path}" ];
          flags = [
            "-o rclone.program='ssh -p23 u498058-sub3@u498058.your-storagebox.de -o IdentitiesOnly=yes -F /dev/null -i ${config.age.secrets.adrian-restic-ssh-key.path}'"
          ];
          prunePolicy = {
            schedule = {
              disabled = true;
              clock = "CLOCK_LAST_RUN_TIME";
            };
            maxUnusedPercent = 10;
          };
          checkPolicy = {
            schedule = {
              disabled = true;
              clock = "CLOCK_LAST_RUN_TIME";
            };
            readDataSubsetPercent = 10;
          };
          autoUnlock = true;
          commandPrefix = { };
        }
      ];
      plans = [
        {
          id = "hermes";
          repo = "hermes";
          paths = [ "/Users/asalamon" ];
          schedule = {
            cron = "0 1 * * *";
            clock = "CLOCK_LAST_RUN_TIME";
          };
          retention.policyKeepAll = true;
          backup_flags = [
            "--exclude-file ${excludes}"
          ];
        }
        {
          id = "hetzner";
          repo = "hetzner";
          paths = [ "/Users/asalamon" ];
          schedule = {
            cron = "0 1 1,4,13,16,25,28 * *";
            clock = "CLOCK_LAST_RUN_TIME";
          };
          retention.policyKeepAll = true;
          backup_flags = [
            "--exclude-file ${excludes}"
          ];
        }
      ];
      auth.disabled = true;
    }
  );

  startScript = pkgs.writeShellScript "backrest-start" ''
    mkdir -p "$HOME/.local/share/backrest"
    cp ${configFile} "$HOME/.local/share/backrest/config.json"
    chmod 600 "$HOME/.local/share/backrest/config.json"
    exec ${pkgs.backrest}/bin/backrest -config-file "$HOME/.local/share/backrest/config.json"
  '';
in
{
  age.secrets.adrian-restic-ssh-key = {
    rekeyFile = inputs.self.outPath + "/secrets/restic/adrian-eos-ssh-key.age";
    generator.script = "ssh-ed25519";
    owner = "asalamon";
  };

  age.secrets.backrest-hermes-password = {
    rekeyFile = inputs.self.outPath + "/secrets/restic/adrian-hermes-encryption-key.age";
    owner = "asalamon";
  };

  age.secrets.backrest-hetzner-password = {
    rekeyFile = inputs.self.outPath + "/secrets/restic/adrian-hetzner-encryption-key.age";
    owner = "asalamon";
  };

  launchd.user.agents.backrest = {
    serviceConfig = {
      ProgramArguments = [ "${startScript}" ];
      KeepAlive = true;
    };
  };
}
