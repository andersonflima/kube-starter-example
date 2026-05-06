if [ -f .env ]; then
  while IFS='=' read -r name value || [ -n "$name" ]; do
    case "$name" in
      "" | \#*)
        continue
        ;;
    esac

    case "$name" in
      *[!A-Za-z0-9_]*)
        continue
        ;;
    esac

    eval "already_set=\${$name+x}"

    if [ -z "$already_set" ]; then
      case "$value" in
        \"*\")
          value=${value#\"}
          value=${value%\"}
          ;;
        \'*\')
          value=${value#\'}
          value=${value%\'}
          ;;
      esac

      export "$name=$value"
    fi
  done < .env
fi
