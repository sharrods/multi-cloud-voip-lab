# Bash completion for justfile
_just_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local recipes=$(just --summary 2>/dev/null)
    COMPREPLY=( $(compgen -W "${recipes}" -- ${cur}) )
}

complete -F _just_completion just
