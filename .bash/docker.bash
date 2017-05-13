# Windows support
docker()
{
    if $WINDOWS; then
        eval winpty docker $(cygpathmap "$@")
    else
        docker "$@"
    fi
}

alias docker-compose='winpty docker-compose'
alias docker-machine='winpty docker-machine'

# Shorthand
alias d='docker'
alias db='docker build'
alias dc='docker-compose'
alias dm='docker-machine'
alias dr='docker run'

# Clean up stopped containers and dangling (untagged) images
dclean()
{
    echo "Cleaning stopped containers..."
    containers="$(docker ps -qf status=exited)"

    if [ -n "$containers" ]; then
        docker rm $containers
    fi

    echo "Cleaning dangling images..."
    images="$(docker images -qf dangling=true)"

    if [ -n "$images" ]; then
        docker rmi $images
    fi

    echo "Done."
}

# Environment
denv()
{
    echo "Switching Docker environment..."
    cmd="$(docker-machine env "${1:-Docker}")" || return
    eval "$cmd"
    echo "Done."
}

# Kill all containers
dkillall()
{
    containers="$(docker ps -q)"

    if [ -n "$containers" ]; then
        docker kill $containers
    fi
}

# Init
dinit()
{
    docker-machine create --driver virtualbox "${1:-Docker}"
    denv "${1:-Docker}"
}

# Remove
dremove()
{
    docker-machine rm "$DOCKER_MACHINE_NAME"
}

# Resume
dresume()
{
    # http://stackoverflow.com/a/37886136/167815
    container="$(docker ps -qlf status=exited)"

    if [ -n "$container" ]; then
        docker start -ai "$container"
    else
        echo "No stopped images found." >&2
        return 1
    fi
}

# Shell
dsh()
{
    # Set up SSH agent forwarding
    if [ -n "$SSH_AUTH_SOCK" ]; then
        opt="--volume \$SSH_AUTH_SOCK:/tmp/ssh-agent --env SSH_AUTH_SOCK=/tmp/ssh-agent"
    else
        opt=
    fi

    # Build the command to run a shell on the specified image
    local cmd="docker run $opt -it --entrypoint '${2:-/bin/bash}' '${1:-ubuntu}'"

    # If using Windows, we need to connect to the Docker VM first
    if $WINDOWS; then
        # -A = Enable agent forwarding, -t = Force TTY allocation
        dssh "$DOCKER_MACHINE_NAME" -At "$cmd"
    else
        # Untested...
        $cmd
    fi
}

# SSH to docker-machine
dssh()
{
    # This avoids using 'docker-machine ssh' which breaks formatting in Cygwin
    machine="${1:-$DOCKER_MACHINE_NAME}"
    shift
    ip="$(docker-machine ip "$machine")" || return
    ssh -i "$HOME/.docker/machine/machines/$machine/id_rsa" "docker@$ip" "$@"
}