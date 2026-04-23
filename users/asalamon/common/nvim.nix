{
  pkgs,
  lib,
  ...
}:
{
  programs.nvf = {
    enable = true;

    settings.vim = {
      globals.mapleader = " ";

      startPlugins = [
        pkgs.vimPlugins.kanagawa-nvim
        pkgs.vimPlugins.lazygit-nvim
      ];

      luaConfigRC.kanagawa = lib.hm.dag.entryAnywhere ''
        require('kanagawa').setup({})
        vim.cmd('colorscheme kanagawa-dragon')
      '';

      luaConfigRC.lazygit = lib.hm.dag.entryAnywhere ''
        vim.keymap.set('n', '<leader>gg', '<cmd>LazyGit<cr>', { desc = 'LazyGit' })
      '';

      options = {
        number = true;
        relativenumber = true;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        scrolloff = 8;
      };

      # ── UI ─────────────────────────────────────────────────────────────────
      statusline.lualine.enable = true;
      binds.whichKey.enable = true;

      # ── Languages ──────────────────────────────────────────────────────────
      lsp.enable = true;

      languages = {
        enableFormat = true;
        enableTreesitter = true;

        nix = {
          enable = true;
          lsp.servers = [ "nixd" ];
          format.type = [ "nixfmt" ];
        };

        markdown.enable = true;
        bash.enable = true;
        typst.enable = true;
        css.enable = true;
        html.enable = true;

        # Elixir: treesitter + format only; LSP handled via expert below
        elixir = {
          enable = true;
          lsp.enable = false;
        };

        python.enable = true;
        rust.enable = true;
        go.enable = true;
        typescript.enable = true; # covers JS + TS
      };

      # ── Expert LSP for Elixir (via lspconfig) ─────────────────────────────
      lsp.servers = {
        "expert" = {
          cmd = [
            "${pkgs.beam.packages.erlang_27.expert}/bin/expert"
            "--stdio"
          ];
          filetypes = [
            "elixir"
            "eelixir"
            "heex"
          ];
          root_markers = [
            "mix.exs"
            "git"
          ];
        };
      };

      # ── Format on save ─────────────────────────────────────────────────────
      lsp.formatOnSave = true;

      # ── Completion ─────────────────────────────────────────────────────────
      autocomplete.blink-cmp.enable = true;
      autopairs.nvim-autopairs.enable = true;

      # ── Git ────────────────────────────────────────────────────────────────
      git = {
        enable = true;
        gitsigns.enable = true;
      };

      terminal = {
        toggleterm = {
          enable = true;
          lazygit.enable = true;
        };
      };

      # ── File tree ──────────────────────────────────────────────────────────
      filetree.neo-tree = {
        enable = true;
      };

      # ── Project-wide find & replace ────────────────────────────────────────
      utility.grug-far-nvim.enable = true;

      # ── Fuzzy finding ──────────────────────────────────────────────────────
      telescope = {
        enable = true;
        mappings = {
          findFiles = "<leader>ff";
          liveGrep = "<leader>fg";
          buffers = "<leader>fb";
          helpTags = "<leader>fh";
        };
      };
    };
  };
}
