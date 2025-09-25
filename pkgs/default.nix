_inputs: [
  (final: prev: {
    kea-ddns-consul = prev.callPackage ./kea-ddns-consul { };
    nebula-keygen-age = prev.callPackage ./nebula-keygen-age { };

    firezone-server = prev.firezone-server.overrideAttrs (oldAttrs: {

      src = "${
        prev.fetchFromGitHub {
          owner = "firezone";
          repo = "firezone";
          rev = "09fb5f927410503b0d6e7fc6cf6a2ba06cb5a281";
          hash = "sha256-/JwmIPaTrz9udlO01GmjER07Suahw7uQD2WfDRO8bKk=";

          # This is necessary to allow sending mails via SMTP, as the default
          # SMTP adapter is current broken: https://github.com/swoosh/swoosh/issues/785
          #
          # We also add our own patch to add `ssl: [middlebox_comp_mode: false]`
          postFetch = ''
            ${prev.lib.getExe prev.gitMinimal} -C $out apply ${./0000-add-mua.patch}
          '';
        }
      }/elixir";
    });

  })
]
