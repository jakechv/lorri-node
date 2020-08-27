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

  PUMBAA_HOST = "http://localhost:8081";
  NALA_HOST = "http://localhost:8080";
  SARABI_HOST = "http://localhost:8082";
  MUFASA_HOST = "http://localhost:8083";
  WWW_HOST = "http://localhost:8082";
  WS_HOST = "ws://localhost:8081";
  DEBUG = "true";

  pumbaa_env = ''
    PUMBAA_HOST=${PUMBAA_HOST}
    NALA_HOST=${NALA_HOST}
    SARABI_HOST=${SARABI_HOST}
    MUFASA_HOST=${MUFASA_HOST}
    WWW_HOST=${WWW_HOST}
    NODE_ENV=development
    APP_ENV=test

    DB_USERNAME=${db_username}
    DB_PASSWORD=${db_password}
    DB_NAME=${db_name}

    DB_HOSTNAME=${secrets.DB_HOSTNAME}
    MAILGUN_API_KEY=${secrets.MAILGUN_API_KEY}
    MAILGUN_DOMAIN=${secrets.MAILGUN_DOMAIN}
    SENDGRID_API_KEY=${secrets.SENDGRID_API_KEY}
    BLOCK_SENDGRID=${secrets.BLOCK_SENDGRID}
    LOCAL_EMAIL=${secrets.LOCAL_EMAIL}
    AUTH_SIGNATURE_KEY=${secrets.AUTH_SIGNATURE_KEY}
    ALLABOLAG_KEY=${secrets.ALLABOLAG_KEY}
    BANKID_URL=${secrets.BANKID_URL}
    BANKID_PW=${secrets.BANKID_PW}
    SLACK_CUSTOMER_WEBHOOK=${secrets.SLACK_CUSTOMER_WEBHOOK}
    SLACK_PUMBAA_LOGGER_WEBHOOK=${secrets.SLACK_PUMBAA_LOGGER_WEBHOOK}
    GOOGLE_API_KEY=${secrets.GOOGLE_API_KEY}
    GOOGLE_APPLICATION_CREDENTIALS=${secrets.GOOGLE_APPLICATION_CREDENTIALS}
    GCP_PROJECT_ID=${secrets.GCP_PROJECT_ID}
    BUCKET_SALES_ATTACHMENTS=${secrets.BUCKET_SALES_ATTACHMENTS}
    BUCKET_AGREEMENTS=${secrets.BUCKET_AGREEMENTS}
    MY_ZONE_NAME=${secrets.MY_ZONE_NAME}
    MY_CONTAINER_NAME=${secrets.MY_CONTAINER_NAME}
    INTERCOM_SECRET_KEY=${secrets.INTERCOM_SECRET_KEY}
    ACTIVATE_GQL_PLAYGROUND=${secrets.ACTIVATE_GQL_PLAYGROUND}
    SLACK_SKIRA_TEAM_ID=${secrets.SLACK_SKIRA_TEAM_ID}
    CALENDAR_SKIRA_GENERAL=${secrets.CALENDAR_SKIRA_GENERAL}
    CALENDAR_SERVICE_ACCOUNT=${secrets.CALENDAR_SERVICE_ACCOUNT}
    PUMBAA_VERSION=${secrets.PUMBAA_VERSION}
  '';

  mufasa_env = ''
    PUMBAA_HOST=${PUMBAA_HOST}
    NALA_HOST=${NALA_HOST}
    SARABI_HOST=${SARABI_HOST}
    MUFASA_HOST=${MUFASA_HOST}

    DOMAIN=localhost
    NODE_ENV=development
    SHOW_DEBUG=${DEBUG}
  '';

  nala_env = ''
    PUMBAA_HOST=${PUMBAA_HOST}
    NALA_HOST=${NALA_HOST}
    SARABI_HOST=${SARABI_HOST}
    MUFASA_HOST=${MUFASA_HOST}
    WS_HOST=${WS_HOST}

    DOMAIN=${secrets.DOMAIN}
    NODE_ENV=${secrets.NODE_ENV}
    REACT_APP_GOOGLE_API_KEY=${secrets.REACT_APP_GOOGLE_API_KEY}
    SHOW_DEBUG=${DEBUG}
    BUCKET_SALES_ATTACHMENTS=${secrets.BUCKET_SALES_ATTACHMENTS}
    BUCKET_AGREEMENTS=${secrets.BUCKET_AGREEMENTS}
    INTERCOM_APP_ID=${secrets.INTERCOM_APP_ID}
    HOTJAR_VERSION=${secrets.HOTJAR_VERSION}
  '';

in pkgs.mkShell {
  buildInputs = [
    nodejs
    (with nodePackages; [ node2nix nodejs bash-language-server eslint ])
    python
    postgresql
  ];
  shellHook = ''
    # alias y='npx yarn'
    # alias yarn='npx yarn'

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
