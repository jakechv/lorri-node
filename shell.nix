{ pkgs ? import <nixpkgs> { } }:
with pkgs;
let
  inherit (lib) optional optionals;
  nodejs = nodejs-12_x;
  postgresql = postgresql_10;
  secrets = import ./secrets.nix;

  db_username = "skira";
  db_password = "skira";
  db_name = "skira";
  test_db_name = "${db_name}_test";
in pkgs.mkShell {
  buildInputs = [
    nodejs
    (with nodePackages; [ node2nix nodejs bash-language-server eslint ])
    python
    postgresql
  ];
  shellHook = ''
    alias startdb='pg_ctl -l $LOG_PATH -o "-c unix_socket_directories=$PGHOST" start'
    alias stopdb='pg_ctl stop'

    PATH=$PATH:$PWD/node_modules/.bin
    export PATH=$PATH:$PWD/node_modules/.bin

    export PGDATA=$PWD/postgres_data
    export PGHOST=$PWD/postgres
    export LOG_PATH=$PWD/postgres/LOG
    export PGDATABASE=${db_name}
    export DATABASE_URL="postgresql:///postgres?host=$PGHOST"
    export PG_COLOR="always"

    # Generates .env files
    function gen-env-files() {
      if [ -f $PWD/pumbaa/.env ]; then
         echo "Pumbaa .env file already exists. Not overwriting."
      else
         echo "Generating .env file for Pumbaa..."
         echo "${pumbaa_env}" >> $PWD/pumbaa/.env
      fi

      if [ -f $PWD/nala/.env ]; then
         echo "Nala .env file already exists. Not overwriting."
      else
         echo "Generating .env file for Nala..."
         echo "${nala_env}" >> $PWD/nala/.env
      fi

      if [ -f $PWD/mufasa/.env ]; then
         echo "Mufasa .env file already exists. Not overwriting."
      else
        echo "Generating .env file for Mufasa..."
        echo "${mufasa_env}" >> $PWD/mufasa/.env
      fi
    }

    # Creates database users.
    function create-db-users() {
      echo "${db_password} ${db_password}" | createuser -d -l ${db_username}
      if [ $? -eq 0 ]; then
          echo "Added user ${db_username} with password ${db_password}."
      else
          echo "Could not create the user ${db_username}."
      fi
    }

    # Creates databases required by Pumbaa.
    function create-dbs() {
      createdb ${db_name}
      createdb ${test_db_name}
    }

    # Starts or restarts the database.
    function restart-db() {
      echo "Attempting to start the database server..."
      startdb
      if ! [[ $? -eq 0 ]]; then
        echo "The database server was running. Restarting..."
        stopdb
        startdb
      fi
    }

    # Initializes the database.
    function init-db-structure() {
      if [ ! -d $PGHOST ]; then
        mkdir -p $PGHOST
      fi

      if [ ! -d $PGDATA ]; then
        echo 'Initializing postgresql database...'
        initdb $PGDATA --auth=trust >/dev/null
      fi

      restart-db
      create-db-users
      create-dbs
    }

    # resets the database configuration
    function reset-db() {
      rm -rf $PGDATA
      rm -rf $PGHOST
      killall postgres
      init-db-structure
    }

    function start-skira() {
        # go to skira dir
        cd $HOME/$USER/skira &&
        # stop database
        stopdb &&
        # start database
        startdb &&
        cd $PWD/pumbaa &&
        yarn reset-db &&
        yarn start &
        cd $PWD/mufasa &&
        yarn dev &
        cd $PWD/nala &
        yarn dev &
    }
  '';
}
