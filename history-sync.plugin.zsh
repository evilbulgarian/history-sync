# ----------------------------------------------------------------
# Description
# -----------
# An Oh My Zsh plugin for GPG encrypted, Internet synchronized Zsh
# history using Git.
#
# ----------------------------------------------------------------
# Authors
# -------
#
# * James Fraser <wulfgar.pro@gmail.com>
#   https://www.wulfgar.pro
# ----------------------------------------------------------------
#
autoload -U colors && colors

alias zhpl=history_sync_pull
alias zhps=history_sync_push
alias zhsync="history_sync_pull && history_sync_push"

GIT=$(which git)

ZSH_HISTORY_REPO="${HOME}/repo/history.ares"
ZSH_HISTORY_NAME=".zsh_history"
ZSH_HISTORY_FILE_PATH="${HOME}/${ZSH_HISTORY_NAME}"
ZSH_HISTORY_REPO_FILE_PATH="${ZSH_HISTORY_REPO}/${ZSH_HISTORY_NAME}"
GIT_COMMIT_MSG="latest $(date)"

function _print_git_error_msg() {
    echo "$bold_color${fg[red]}There's a problem with git repository: ${ZSH_HISTORY_REPO}.$reset_color"
    return
}

function _print_gpg_encrypt_error_msg() {
    echo "$bold_color${fg[red]}GPG failed to encrypt history file.$reset_color"
    return
}

function _print_gpg_decrypt_error_msg() {
    echo "$bold_color${fg[red]}GPG failed to decrypt history file.$reset_color"
    return
}

function _usage() {
    echo "Usage: [ [-r <string> ...] [-y] ]" 1>&2
    echo
    echo "Optional args:"
    echo
    echo "      -r receipients"
    echo "      -y force"
    return
}

# Pull current master, decrypt, and merge with .zsh_history
function history_sync_pull() {
    DIR=$(pwd)

    # Backup
    ~/bin/bak $ZSH_HISTORY_FILE_PATH 1>&2

    # Pull
    cd "$ZSH_HISTORY_REPO" && "$GIT" pull
    if [[ "$?" != 0 ]]; then
        _print_git_error_msg
        cd "$DIR"
        return
    fi

    # Merge
    cat "$ZSH_HISTORY_FILE_PATH" "$ZSH_HISTORY_REPO_FILE_PATH" | awk '/:[0-9]/ { if(s) { print s } s=$0 } !/:[0-9]/ { s=s"\n"$0 } END { print s }' | LC_ALL=C sort -u > "$ZSH_HISTORY_FILE_PATH"
    cd  "$DIR"
}

# Encrypt and push current history to master
function history_sync_push() {
    # Get options recipients, force
    local recipients=()
    local force=false
    while getopts r:y opt; do
        case "$opt" in
            r)
                recipients+="$OPTARG"
                ;;
            y)
                force=true
                ;;
            *)
                _usage
                return
                ;;
        esac
    done

    cp $ZSH_HISTORY_FILE_PATH $ZSH_HISTORY_REPO_FILE_PATH

    # Commit
    if [[ $force = false ]]; then
        echo -n "$bold_color${fg[yellow]}Do you want to commit current local history file (y/N)?$reset_color "
        read commit
    else
        commit='y'
    fi

    if [[ -n "$commit" ]]; then
        case "$commit" in
            [Yy]* )
                DIR=$(pwd)
                cd "$ZSH_HISTORY_REPO" && "$GIT" add $ZSH_HISTORY_REPO_FILE_PATH && "$GIT" commit -m "$GIT_COMMIT_MSG"

                if [[ $force = false ]]; then
                    echo -n "$bold_color${fg[yellow]}Do you want to push to remote (y/N)?$reset_color "
                    read push
                else
                    push='y'
                fi

                if [[ -n "$push" ]]; then
                    case "$push" in
                        [Yy]* )
                            "$GIT" push
                            if [[ "$?" != 0 ]]; then
                                _print_git_error_msg
                                cd "$DIR"
                                return
                            fi
                            cd "$DIR"
                            ;;
                    esac
                fi

                if [[ "$?" != 0 ]]; then
                    _print_git_error_msg
                    cd "$DIR"
                    return
                fi
                ;;
            * )
                ;;
        esac
    fi
}
