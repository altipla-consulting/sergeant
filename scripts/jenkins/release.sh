#!/bin/bash

set -eux

. /opt/ci-toolset/functions.sh

export GOOGLE_PROJECT=altipla-tools

configure-google-cloud

echo $(basename $GERRIT_REFNAME) > release
gcloud alpha storage cp --cache-control 'public, max-age=10' files/install.sh gs://tools.altipla.consulting/sergeant/install
gcloud alpha storage cp --cache-control 'public, max-age=10' files/autoupdate.sh gs://tools.altipla.consulting/sergeant/autoupdate
gcloud alpha storage cp --cache-control 'public, max-age=10' release gs://tools.altipla.consulting/sergeant/release
