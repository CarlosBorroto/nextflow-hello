#!/usr/bin/env nextflow

cheers = Channel.from 'Bonjour', 'Ciao', 'Hello', 'Hola'

process sayHello {
  container 'ubuntu:bionic'

  input:
    val x from cheers

  output:
    stdout result

  script:
    """
    cat /etc/lsb-release | xargs echo
    echo '$x world!'
    """
}

process echoHello {
  container 'echo:latest'

  input:
    val y from result

  script:
    """
    echo.sh '$y'
    """
}
