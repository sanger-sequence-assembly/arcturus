#!/bin/csh

if ( ! $?LSF_ENVDIR ) then
  if ( -e /etc/lsf.conf ) then
    setenv LSF_ENVDIR /etc

    foreach d ( /lsf/conf /usr/local/lsf/conf /usr/local/lsfv42/conf /software/lsf/conf )
      if ( -f $d/cshrc.lsf ) then
        source $d/cshrc.lsf
        break
      endif
    end

  endif
endif

lsplace -R "mem>8000"

exit
