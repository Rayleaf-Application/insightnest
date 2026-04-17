{
  description = "Basic Elixir Application";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      project_name="myproject";
      pkgs = import nixpkgs { inherit system; };
      erlang = pkgs.beam.packages.erlang_28.erlang;
      elixir = pkgs.beam.packages.erlang_28.elixir;
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.fswatch
          erlang
          elixir
          pkgs.inotify-tools
          pkgs.postgresql
          pkgs.nodejs_24
          pkgs.vscode-langservers-extracted
          pkgs.pnpm
          pkgs.prettier
        ];
	       shellHook = ''
          export PG=$PWD/.dev_postgres
          export PGDATA=$PG/data
          export PGPORT=5432
          export PGHOST=localhost
          export PGUSER=$USER
          export LANG="en_US.UTF-8"
          export ERL_AFLAGS="-kernel shell_history enabled"
          alias pg_setup="\
        	  initdb -D $PGDATA &&
    		  echo \"unix_socket_directories = \
                '$PGDATA'\" >> $PGDATA/postgresql.conf &&\
		    pg_start &&\
		    createdb &&\
		    mix ecto.create &&\
		    mix ecto.migrate"
          alias pg_stop='pg_ctl -D $PGDATA stop'
          alias pg_start='pg_ctl -D $PGDATA -l $PG/postgres.log start'
        '';
      };
    };
}
