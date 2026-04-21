{ globals, ... }:
{
  programs.git = {
    enable = true;

    signing = {
      format = "ssh";
      signByDefault = true;
      key = "key::ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBDmOgdi09i0CnGRAaXDzkOCJ+XAVDvF3jFKgWMl5yfrxeqczLqk0wB9xqVr4I4TQEYJNkM6TiYzh/e9alknR9apD49m68cB3Jl4CuR4Nygcrl51pw8lSzE9JmtIBhsG1tA==";
    };

    settings = {
      user = {
        name = "Adrian Salamon";
        email = "adrian@${globals.domains.alt}";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };

  xdg.configFile."git/allowed_signers".text = ''
    adrian@${globals.domains.alt} ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBDmOgdi09i0CnGRAaXDzkOCJ+XAVDvF3jFKgWMl5yfrxeqczLqk0wB9xqVr4I4TQEYJNkM6TiYzh/e9alknR9apD49m68cB3Jl4CuR4Nygcrl51pw8lSzE9JmtIBhsG1tA==
  '';
}
