_akpedia() {
  local -a commands modules types
  commands=(
    'run:start dev servers'
    'branch:create (if needed) and checkout AKP-<number>'
    'commit:commit as type(AKP-<number>): message'
  )
  modules=('server:Spring Boot API' 'ml:FastAPI ML service' 'client:Vue frontend')
  types=(
    'feat:new feature' 'fix:bug fix' 'docs:documentation' 'style:formatting'
    'refactor:code change without behavior change' 'perf:performance improvement'
    'test:tests' 'chore:maintenance' 'build:build system' 'ci:CI config' 'revert:revert commit'
  )

  if (( CURRENT == 2 )); then
    _describe 'command' commands
    return
  fi

  case "${words[2]}" in
    run) _describe 'module' modules ;;
    commit) (( CURRENT == 3 )) && _describe 'type' types ;;
  esac
}

compdef _akpedia akpedia
