#!/usr/bin/env bash
cd $(dirname $0)
set -e # exit when any command fails

./down.sh
docker-compose build parity1 parity2

if [ -z "$CI" ]; then
  ./build.sh $@
else
  ./pull.sh $@
fi

docker network create --driver bridge ultimate || true
docker-compose up -d parity1 parity2 e2e

startValidator () {
    db_env="-e ORACLE_QUEUE_URL=amqp://$4 -e ORACLE_REDIS_URL=redis://$3"

    docker-compose $1 run -d --name $3 redis
    docker-compose $1 run -d --name $4 rabbit

    if [[ -z "$MODE" || "$MODE" == erc-to-native ]]; then
      docker-compose $1 run $2 $db_env -d oracle-erc20-native yarn watcher:signature-request
      docker-compose $1 run $2 $db_env -d oracle-erc20-native yarn watcher:collected-signatures
      docker-compose $1 run $2 $db_env -d oracle-erc20-native yarn watcher:affirmation-request
      docker-compose $1 run $2 $db_env -d oracle-erc20-native yarn watcher:transfer
    fi
    if [[ -z "$MODE" || "$MODE" == amb ]]; then
      docker-compose $1 run $2 $db_env -d oracle-amb yarn watcher:signature-request
      docker-compose $1 run $2 $db_env -d oracle-amb yarn watcher:collected-signatures
      docker-compose $1 run $2 $db_env -d oracle-amb yarn watcher:affirmation-request
      docker-compose $1 run $2 $db_env -d oracle-amb yarn watcher:information-request
    fi

    docker-compose $1 run $2 $db_env -d oracle-amb yarn sender:home
    docker-compose $1 run $2 $db_env -d oracle-amb yarn sender:foreign
    docker-compose $1 run $2 $db_env -d oracle-amb yarn manager:shutdown
}

while [ "$1" != "" ]; do
  if [ "$1" == "oracle" ]; then
    startValidator "-p validator1" "" redis rabbit
  fi

  if [ "$1" == "oracle-validator-2" ]; then
    oracle2Values="-e ORACLE_VALIDATOR_ADDRESS=0xdCC784657C78054aa61FbcFFd2605F32374816A4 -e ORACLE_VALIDATOR_ADDRESS_PRIVATE_KEY=5a5c3645d0f04e9eb4f27f94ed4c244a225587405b8838e7456f7781ce3a9513"
    startValidator "-p validator2" "$oracle2Values" redis2 rabbit2
  fi

  if [ "$1" == "oracle-validator-3" ]; then
    oracle3Values="-e ORACLE_VALIDATOR_ADDRESS=0xDcef88209a20D52165230104B245803C3269454d -e ORACLE_VALIDATOR_ADDRESS_PRIVATE_KEY=f877f62a1c19f852cff1d29f0fb1ecac18821c0080d4cc0520c60c098293dca1"
    startValidator "-p validator3" "$oracle3Values" redis3 rabbit3
  fi

  if [ "$1" == "alm" ]; then
    docker-compose up -d alm

    docker-compose run -d -p 3004:3000 alm serve -p 3000 -s .
  fi

  if [ "$1" == "deploy" ]; then
    docker-compose run e2e e2e-commons/scripts/deploy.sh
  fi

  if [ "$1" == "blocks" ]; then
    docker-compose up -d blocks
  fi

  if [ "$1" == "monitor" ]; then
    case "$MODE" in
      amb)
        docker-compose up -d monitor-amb
        ;;
      erc-to-native)
        docker-compose up -d monitor-erc20-native
        ;;
      *)
        docker-compose up -d monitor-erc20-native monitor-amb
        ;;
    esac
  fi

  if [ "$1" == "alm-e2e" ]; then
    MODE=amb

    startValidator "-p validator1" "" redis rabbit

    oracle2Values="-e ORACLE_VALIDATOR_ADDRESS=0xdCC784657C78054aa61FbcFFd2605F32374816A4 -e ORACLE_VALIDATOR_ADDRESS_PRIVATE_KEY=5a5c3645d0f04e9eb4f27f94ed4c244a225587405b8838e7456f7781ce3a9513"
    startValidator "-p validator2" "$oracle2Values" redis2 rabbit2

    oracle3Values="-e ORACLE_VALIDATOR_ADDRESS=0xDcef88209a20D52165230104B245803C3269454d -e ORACLE_VALIDATOR_ADDRESS_PRIVATE_KEY=f877f62a1c19f852cff1d29f0fb1ecac18821c0080d4cc0520c60c098293dca1"
    startValidator "-p validator3" "$oracle3Values" redis3 rabbit3
  fi

  shift # Shift all the parameters down by one
done
