#!/bin/bash
#
# Copyright 2021, Seqera Labs, S.L. All Rights Reserved.
#
set -eo pipefail

on_exit() {
  ret=$?
  # upload log file
  dx upload $LOG_NAME --path $DX_LOG --wait --brief --no-progress --parents || true
  # backup cache
  dx rm -r "$DX_PROJECT_CONTEXT_ID:/.nextflow/cache/$NXF_UUID/*" || true
  dx upload ".nextflow/cache/$NXF_UUID" --path "$DX_PROJECT_CONTEXT_ID:/.nextflow/cache/$NXF_UUID" --no-progress --brief --wait -p -r || true
  # done
  exit $ret
}

dx_path() {
  local str=${1#"dx://"}
  case $str in
    project-*)
      dx cat $str ;;
    container-*)
      dx cat $str ;;
    *)
    echo $str ;;
  esac
}

# Main entry point for this app.
main() {
    [[ $debug ]] && set -x && env | grep -v license | sort

    export NXF_HOME=/opt/nextflow
    export NXF_UUID=${resume_id:-$(uuidgen)}
    export NXF_XPACK_LICENSE=$(dx_path $license)
    export NXF_IGNORE_RESUME_HISTORY=true
    export NXF_ANSI_LOG=false
    export NXF_EXECUTOR=dnanexus
    export NXF_PLUGINS_DEFAULT=xpack-dnanexus
    export NXF_DOCKER_LEGACY=true

    trap on_exit EXIT

    # log file name
    LOG_NAME="nextflow-$(date +"%y%m%d-%H%M%S").log"
    DX_WORK=${work_dir:-$DX_WORKSPACE_ID:/scratch/}
    DX_LOG=${log_file:-$DX_PROJECT_CONTEXT_ID:$LOG_NAME}

    echo "============================================================="
    echo "=== NF work-dir ${DX_WORK}"
    echo "=== NF Resume ID ${NXF_UUID}"
    echo "=== NF log file ${DX_LOG}"
    echo "============================================================="

    if [[ $scm_file ]]; then
      dx_path $scm_file > $NXF_HOME/scm
    fi

    # restore cache
    mkdir -p .nextflow/cache/$NXF_UUID
    dx download "$DX_PROJECT_CONTEXT_ID:/.nextflow/cache/$NXF_UUID/*" -o ".nextflow/cache/$NXF_UUID" --no-progress -r -f 2>&1 || true

    # Load Docker images
    for img in /home/dnanexus/docker/*; do
      docker load -i $img
    done

    # prevent glob expansion
    set -f
    # launch nextflow
    nextflow -trace nextflow.plugin \
          $opts \
          -log $LOG_NAME \
          run $pipeline \
          -resume $NXF_UUID \
          -work-dir dx://$DX_WORK \
          $args
    # restore glob expansion
    set +f
}

nf_task_exit() {
  ret=$?
  if [ -f .command.log ]; then
    dx upload .command.log --path "${cmd_log_file}" --brief --no-progress || true
  else
    >&2 echo "Missing Nextflow .command.log file"
  fi
  dx-jobutil-add-output exit_code "$ret" --class=int
}

nf_task_entry() {
  # capture the exit code
  trap nf_task_exit EXIT
  # run the task
  dx cat "${cmd_launcher_file}" > .command.run
  bash .command.run > >(tee .command.log) 2>&1
}
