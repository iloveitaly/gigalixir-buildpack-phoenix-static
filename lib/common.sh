info() {
  #echo "`date +\"%M:%S\"`  $*"
  echo "       $*"
}

indent() {
  while read LINE; do
    echo "       $LINE" || true
  done
}

head() {
  echo ""
  echo "-----> $*"
}

file_contents() {
  if test -f $1; then
    echo "$(cat $1)"
  else
    echo ""
  fi
}

detect_phoenix() {
  if [ -e $build_dir/deps/phoenix/mix.exs ]; then
    info "Detecting Phoenix version"
    local lcl_phx_ver=$(grep -P "^\s+@version \"\d+\.\d+\.\d+\"" $build_dir/deps/phoenix/mix.exs | sed -e 's%.*"\(.*\)".*%\1%')
    if [ -z "$lcl_phx_ver" ]; then
      info "WARNING: unable to detect phoenix version"
    else
      info "* $lcl_phx_ver"
      read -r phx_major phx_minor <<< $(echo $lcl_phx_ver | sed -e 's%\([0-9]\+\)\.\([0-9]\+\)\..*%\1 \2%')
      info "* Major: $phx_major"
      info "* Minor: $phx_minor"

      # detect mix command
      if [ -z "$phoenix_ex" ]; then
        if [[ $phx_major -lt 1 ]] || [[ $phx_major -lt 2 && $phx_minor -lt 3 ]]; then
          phoenix_ex=${phoenix_ex:-phoenix}
          info "* Phoenix 1.2.x or prior detected, using phoenix_ex=${phoenix_ex}"
        else
          phoenix_ex=${phoenix_ex:-phx}
          info "* Phoenix 1.3.x or later detected, using phoenix_ex=${phoenix_ex}"
        fi
      fi
    fi
  fi
}

load_config() {
  info "Loading config..."

  local custom_config_file="${build_dir}/phoenix_static_buildpack.config"

  # Source for default versions file from buildpack first
  source "${build_pack_dir}/phoenix_static_buildpack.config"

  if [ -f $custom_config_file ]; then
    source $custom_config_file
  else
    info "The config file phoenix_static_buildpack.config wasn't found"
    info "Using the default config provided from the Phoenix static buildpack"
  fi

  fix_node_version
  fix_npm_version

  phoenix_dir=$build_dir/$phoenix_relative_path

  detect_phoenix

  info "Detecting assets directory"
  if [ -f "$phoenix_dir/$assets_path/package.json" ]; then
    # Check phoenix custom sub-directory for package.json
    info "* package.json found in custom directory"
  elif [ -f "$phoenix_dir/package.json" ]; then
    # Check phoenix root directory for package.json, phoenix 1.2.x and prior
    info "* package.json found in root directory"
    assets_path=.
  else
    # Check phoenix custom sub-directory for package.json, phoenix 1.3.x and later
    info "WARNING: no package.json detected in root nor custom directory, assuming './assets/'"
    assets_path=assets
  fi

  assets_dir=$phoenix_dir/$assets_path
  info "Will use phoenix configuration:"
  info "* assets path ${assets_path}"
  info "* mix tasks namespace ${phoenix_ex}"

  info "Will use the following versions:"
  info "* Node ${node_version}"
}

export_config_vars() {
  whitelist_regex=${2:-''}
  blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH)$'}
  if [ -d "$env_dir" ]; then
    info "Will export the following config vars:"
    for e in $(ls $env_dir); do
      echo "$e" | grep -E "$whitelist_regex" | grep -vE "$blacklist_regex" &&
      export "$e=$(cat $env_dir/$e)"
      :
    done
  fi
}

export_mix_env() {
  if [ -z "${MIX_ENV}" ]; then
    if [ -d $env_dir ] && [ -f $env_dir/MIX_ENV ]; then
      export MIX_ENV=$(cat $env_dir/MIX_ENV)
    else
      export MIX_ENV=prod
    fi
  fi

  info "* MIX_ENV=${MIX_ENV}"
}

fix_node_version() {
  node_version=$(echo "${node_version}" | sed 's/[^0-9.]*//g')
}

fix_npm_version() {
  npm_version=$(echo "${npm_version}" | sed 's/[^0-9.]*//g')
}
