#!/usr/bin/env bash
set -euo pipefail

opt=$1
case ${opt} in
    h)
        help
        exit 0;
        ;;
    s)
        startdb
        exit 0;
        ;;
    p)
        stopdb
        exit 0;
        ;;
    r)
        resetdb
        exit 0;
        ;;
    \? )
        help
        echo "Invalid option: -$OPTARG" 1>&2
        exit 1
        ;;
    : )
        help
        echo "Invalid option: -$OPTARG requires an argument" 1>&2
        exit 1
        ;;
esac
